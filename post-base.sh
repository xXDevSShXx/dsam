#!/bin/sh
set -eu

host=$1 tz=$2 locale=$3 swap=$4 root_uuid=$5 swap_uuid=$6 user=$7

ln -sf "/usr/share/zoneinfo/$tz" /etc/localtime
hwclock --systohc

sed -i "s/^#\($locale UTF-8\)/\1/" /etc/locale.gen
locale-gen
printf 'LANG=%s\n' "$locale" > /etc/locale.conf
printf '%s\n' "$host" > /etc/hostname

if [ "$swap" = hibernate ]; then
	mkdir -p /etc/mkinitcpio.conf.d
	cat > /etc/mkinitcpio.conf.d/dsam.conf <<'EOF'
HOOKS=(base udev resume autodetect microcode modconf kms keyboard keymap consolefont block filesystems fsck)
EOF
fi

if [ "$swap" = zram ]; then
	cat > /etc/systemd/zram-generator.conf <<'EOF'
[zram0]
zram-size = min(ram / 2, 4096)
EOF
fi

mkinitcpio -P

bootctl install
mkdir -p /boot/loader/entries
cat > /boot/loader/loader.conf <<'EOF'
default arch.conf
timeout 3
editor no
EOF
options="root=UUID=$root_uuid rw"
if [ -n "$swap_uuid" ]; then
	options="$options resume=UUID=$swap_uuid"
fi
cat > /boot/loader/entries/arch.conf <<EOF
title Arch Linux
linux /vmlinuz-linux
initrd /initramfs-linux.img
options $options
EOF

printf 'permit persist :wheel\n' > /etc/doas.conf
chmod 0400 /etc/doas.conf
doas -C /etc/doas.conf

useradd -m -G wheel "$user"
until passwd "$user"; do :; done
passwd -l root

systemctl enable NetworkManager systemd-timesyncd fstrim.timer
