# shellcheck shell=sh disable=SC2154,SC2034

# shared by dsam and configure.sh; the caller sets $here (repo root) first.
# packages/<name>/ holds a PKGBUILD, an optional post-install.sh (run as the
# user) and an optional .dotfiles/ tree (mirrors ~/, symlinked into place).

DSAM_RC=0

die() { printf '%s: %s\n' "${0##*/}" "$*" >&2; exit 1; }
warn() { printf '%s: %s\n' "${0##*/}" "$*" >&2; }
say() { printf '==> %s\n' "$*"; }
as_root() { doas "$@"; }
clean() { sed 's/#.*//; s/[[:space:]]*$//; /^[[:space:]]*$/d' "$@" 2>/dev/null | sort -u; }

refuse_root() {
	[ "$(id -u)" -ne 0 ] || die "do not run as root, privileged steps use doas"
}

# paru with the repo's own config, which makes packages/ a PKGBUILD repo
aur() { paru --sudo doas "$@"; }

is_custom() { [ -f "$here/packages/$1/PKGBUILD" ]; }
has_dir() { [ -d "$here/packages/$1" ]; }

# .SRCINFO is generated (never committed); paru and the version check read it
sync_srcinfo() {
	for d in "$here"/packages/*/; do
		[ -f "${d}PKGBUILD" ] || continue
		if [ ! -f "${d}.SRCINFO" ] || [ "${d}PKGBUILD" -nt "${d}.SRCINFO" ]; then
			(cd "$d" && makepkg --printsrcinfo > .SRCINFO.new && mv .SRCINFO.new .SRCINFO)
		fi
	done
}

srcinfo_version() {
	awk -F' = ' '
		/^\tepoch =/ { e = $2 }
		/^\tpkgver =/ { v = $2 }
		/^\tpkgrel =/ { r = $2 }
		END { print (e != "" ? e ":" : "") v "-" r }
	' "$here/packages/$1/.SRCINFO"
}

installed_version() { pacman -Q -- "$1" 2>/dev/null | awk '{ print $2 }'; }

# symlink every file of packages/<name>/.dotfiles into ~ (what stow does,
# per file); never overwrites, conflicts are reported and set DSAM_RC
link_dotfiles() {
	src=$here/packages/$1/.dotfiles
	[ -d "$src" ] || return 0
	list=$(mktemp)
	(cd "$src" && find . \( -type f -o -type l \) | sed 's|^\./||') > "$list"
	while IFS= read -r f; do
		dest=$HOME/$f
		want=$src/$f
		if [ -L "$dest" ]; then
			cur=$(readlink -- "$dest")
			[ "$cur" != "$want" ] || continue
			case $cur in
				"$here"/packages/*) ln -sfn -- "$want" "$dest"; continue ;;
			esac
		fi
		if [ -e "$dest" ] || [ -L "$dest" ]; then
			warn "conflict, not overwriting: $dest"
			DSAM_RC=1
			continue
		fi
		mkdir -p "$(dirname "$dest")"
		ln -s -- "$want" "$dest"
	done < "$list"
	rm -f "$list"
}

run_hook() {
	if [ -x "$here/packages/$1/post-install.sh" ]; then
		(cd "$here/packages/$1" && ./post-install.sh)
	fi
}

# packages/<name> may build a package (PKGBUILD) and/or carry .dotfiles and a hook
sync_package() {
	dir=$here/packages/$1
	if is_custom "$1"; then
		if grep -q '^pkgver()' "$dir/PKGBUILD"; then
			pacman -Qq -- "$1" > /dev/null 2>&1 || aur -Bi "$dir"
		else
			want=$(srcinfo_version "$1")
			have=$(installed_version "$1")
			if [ -z "$have" ] || [ "$(vercmp "$have" "$want")" -ne 0 ]; then
				aur -Bi "$dir"
			fi
		fi
	fi
	link_dotfiles "$1"
	run_hook "$1"
}


# pkg_install <name>...
# PKGBUILD directories are built, everything else comes from paru; any
# packages/<name> directory then gets its dotfiles linked and its hook run.
# Declared packages are marked explicit so they never look like orphans.
pkg_install() {
	sync_srcinfo
	repo=
	for p; do
		is_custom "$p" && continue
		pacman -Qq -- "$p" > /dev/null 2>&1 || repo="$repo $p"
	done
	# shellcheck disable=SC2086
	if [ -n "$repo" ]; then aur -S --needed $repo; fi
	for p; do
		if has_dir "$p"; then sync_package "$p"; fi
		if pacman -Qdq -- "$p" > /dev/null 2>&1; then
			as_root pacman -D --asexplicit -- "$p" > /dev/null
		fi
	done
}

