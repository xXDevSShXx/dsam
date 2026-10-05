#!/bin/sh
# usage: base.sh <profile> <disk>
set -eu

here=$(cd "$(dirname "$0")" && pwd)
profile=${1:?usage: base.sh <profile> <disk>}
disk=${2:?usage: base.sh <profile> <disk>}

die() { printf '%s\n' "$*" >&2; exit 1; }

[ -d /run/archiso ] || die "base.sh must be run from the Arch ISO"
[ "$(id -u)" -eq 0 ] || die "must run as root"
[ -d /sys/firmware/efi ] || die "UEFI required"
[ -f "$here/profiles/$profile/profile.conf" ] || die "unknown profile: $profile"
[ -b "$disk" ] || die "not a block device: $disk"

# shellcheck disable=SC1090
. "$here/profiles/$profile/profile.conf"

: "${HOST_NAME:?}" "${TIMEZONE:?}" "${LOCALE:?}" "${ESP_SIZE:?}" "${ROOT_SIZE:?}" "${SWAP:?}"
[ -e "/usr/share/zoneinfo/$TIMEZONE" ] || die "unknown timezone: $TIMEZONE"
grep -q "^#*$LOCALE UTF-8" /etc/locale.gen || die "unknown locale: $LOCALE"

live=$(findmnt -n -o SOURCE /run/archiso/bootmnt 2>/dev/null || true)
case $live in "$disk"*) die "$disk holds the live medium" ;; esac

case $SWAP in
	none|zram|hibernate) ;;
	*) die "bad SWAP: $SWAP" ;;
esac

lsblk -o NAME,SIZE,MODEL,MOUNTPOINTS "$disk"
printf 'This ERASES %s. Type the device path to continue: ' "$disk"
read -r answer
[ "$answer" = "$disk" ] || die "aborted"
printf 'Username: '
read -r username
case $username in
	''|[!a-z_]*|*[!a-z0-9_-]*) die "invalid username: $username" ;;
esac

case $disk in
	*[0-9]) p=${disk}p ;;
	*) p=$disk ;;
esac

swapoff -a
umount -R /mnt 2>/dev/null || true
wipefs -af "$disk"
sgdisk --zap-all "$disk"

sgdisk -n "1:0:+$ESP_SIZE" -t 1:ef00 -c 1:esp "$disk"
sgdisk -n "2:0:+$ROOT_SIZE" -t 2:8304 -c 2:root "$disk"
if [ "$SWAP" = hibernate ]; then
	ram_mib=$(awk '/^MemTotal:/ { print int(($2 + 1023) / 1024) }' /proc/meminfo)
	sgdisk -n "3:0:+${ram_mib}M" -t 3:8200 -c 3:swap "$disk"
	sgdisk -n 4:0:0 -t 4:8302 -c 4:home "$disk"
	swap_part=${p}3
	home_part=${p}4
else
	sgdisk -n 3:0:0 -t 3:8302 -c 3:home "$disk"
	home_part=${p}3
fi
esp_part=${p}1
root_part=${p}2
partprobe "$disk"
udevadm settle

mkfs.fat -F32 -n ESP "$esp_part"
mkfs.ext4 -F -L root "$root_part"
mkfs.ext4 -F -L home "$home_part"

mount "$root_part" /mnt
mkdir -p /mnt/boot /mnt/home
mount -o umask=0077 "$esp_part" /mnt/boot
mount "$home_part" /mnt/home

swap_uuid=
if [ "$SWAP" = hibernate ]; then
	mkswap -L swap "$swap_part"
	swapon "$swap_part"
	swap_uuid=$(blkid -s UUID -o value "$swap_part")
fi
root_uuid=$(blkid -s UUID -o value "$root_part")

case $(awk -F': ' '/^vendor_id/ { print $2; exit }' /proc/cpuinfo) in
	GenuineIntel) extra=intel-ucode ;;
	AuthenticAMD) extra=amd-ucode ;;
	*) extra= ;;
esac
if [ "$SWAP" = zram ]; then
	extra="$extra zram-generator"
fi

# shellcheck disable=SC2046,SC2086
pacstrap -K /mnt $(grep -Ev '^[[:space:]]*(#|$)' "$here/base-packages.txt") $extra
genfstab -U /mnt > /mnt/etc/fstab

install -m 0755 "$here/post-base.sh" /mnt/root/chroot.sh
arch-chroot /mnt /root/chroot.sh \
	"$HOST_NAME" "$TIMEZONE" "$LOCALE" "$SWAP" "$root_uuid" "$swap_uuid" "$username"
rm /mnt/root/chroot.sh

mkdir -p /mnt/etc/dsam
printf '%s\n' "$profile" > /mnt/etc/dsam/profile

cp -a "$here" "/mnt/home/$username/dsam"
arch-chroot /mnt chown -R "$username:" "/home/$username/dsam"
ln -sf "/home/$username/dsam/dsam" /mnt/usr/local/bin/dsam

swapoff -a
umount -R /mnt
printf 'Done. Reboot into the new system.\n'
