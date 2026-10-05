#!/bin/sh
# usage: configure.sh [profile]
# Phase 2: converge this machine on its profile. Safe to re-run and usable on an
# already-installed Arch system. Run as a regular user, never through doas.
# Per profile: packages.txt, services.txt ("user:<unit>" for user units).
set -eu

here=$(cd "$(dirname "$0")" && pwd)
# shellcheck disable=SC1091
. "$here/lib.sh"

refuse_root
[ -f /etc/arch-release ] || die "not Arch Linux"
command -v doas > /dev/null 2>&1 || die "doas is not installed"
doas true || die "doas refused"

profile=${1:-$(cat /etc/dsam/profile 2>/dev/null || true)}
[ -n "$profile" ] || die "usage: configure.sh <profile>"
pdir=$here/profiles/$profile
[ -f "$pdir/profile.conf" ] || die "unknown profile: $profile"

if [ "$(cat /etc/dsam/profile 2>/dev/null || true)" != "$profile" ]; then
	as_root mkdir -p /etc/dsam
	printf '%s\n' "$profile" | as_root tee /etc/dsam/profile > /dev/null
fi
if [ ! -e /usr/local/bin/dsam ]; then
	as_root ln -s "$here/dsam" /usr/local/bin/dsam
fi

say "prerequisites"
need=
for p in git base-devel; do
	pacman -Qq "$p" > /dev/null 2>&1 || need="$need $p"
done
# shellcheck disable=SC2086
if [ -n "$need" ]; then as_root pacman -S --needed --noconfirm $need; fi

if ! command -v paru > /dev/null 2>&1; then
	say "building paru"
	build=${XDG_CACHE_HOME:-$HOME/.cache}/dsam
	rm -rf "$build/paru"
	mkdir -p "$build"
	git clone --depth 1 https://aur.archlinux.org/paru.git "$build/paru"
	printf '. /etc/makepkg.conf\nPACMAN_AUTH=(doas)\n' > "$build/makepkg.conf"
	(cd "$build/paru" && makepkg --config "$build/makepkg.conf" -s --noconfirm)
	as_root pacman -U --noconfirm "$build"/paru/paru-[0-9]*.pkg.tar.*
	rm -rf "$build/paru"
fi
link_dotfiles paru

[ "$here" = "$HOME/dsam" ] || warn "repo is not at ~/dsam, so paru.conf's Path will not find packages/"

say "packages"
if [ -f "$pdir/packages.txt" ]; then
	# shellcheck disable=SC2046
	pkg_install $(clean "$pdir/packages.txt")
fi

say "services"
if [ -f "$pdir/services.txt" ]; then
	for u in $(clean "$pdir/services.txt"); do
		case $u in
			user:*) systemctl --user enable "${u#user:}" ;;
			*) as_root systemctl enable "$u" ;;
		esac
	done
fi

say "drift report"
"$here/dsam" diff
exit "$DSAM_RC"
