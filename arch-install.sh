#!/bin/bash
#
##################################################################
#title		: installscript
#description    : Automated installation script for arch linux
#author		: teateawhy , based on archinstaller.sh by Dennis Anfossi .
#contact	: https://bbs.archlinux.org/profile.php?id=57887
#date		: 10-08
#version	: 0.1
#license	: GPLv2
#usage		: ./installscript
##################################################################
#

# MBR AND BIOS ONLY. NO UEFI SUPPORT.

## -------------
## CONFIGURATION

# Confirm before running (yes/no)
confirm='yes'

# This drive will be formatted (/dev/sdx)
dest_disk='/dev/sda'
# example:
# dest_disk='/dev/sda'

# swap (yes/no)
swap='yes'

# Partition sizes ( Append G for Gibibytes, M for Mebibytes )
swap_size='2G'
root_size='2G'

# mirror
mirrorlist=''
# example:
# mirrorlist='Server = http://mirror.de.leaseweb.net/archlinux/$repo/os/$arch'

# Install base-devel group (yes/no)
base_devel='yes'

# language
locale_gen='en_US.UTF-8 UTF-8'
locale_conf='LANG=en_US.UTF-8'
keymap='KEYMAP=us'
font='FONT=Lat2-Terminus16'

# timezone (only one slash in the middle)
timezone='Europe/Warsaw'
# example: timezone='Europe/Berlin'

# hostname
hostname='$1'
# example:
# hostname='myhostname'

## END CONFIGURATION
## -----------------

start_time=$(date +%s)

# functions
config_fail() {
echo
echo 'installscript:'
echo "Configuration error, please check variable $1 ."
exit 1
}

# Paranoid shell
set -e -u

# Check configuration
[ -z "$confirm" ] && config_fail 'confirm'
[ -z "$dest_disk" ] && config_fail 'dest_disk'
[ -z "$swap" ] && config_fail 'swap'
if [ "$swap" = 'yes' ]; then
	[ -z "$swap_size" ] && config_fail 'swap_size'
fi
[ -z "$root_size" ] && config_fail 'root_size'
[ -z "$base_devel" ] && config_fail 'base_devel'
[ -z "$locale_gen" ] && config_fail 'locale_gen'
[ -z "$locale_conf" ] && config_fail 'locale_conf'
[ -z "$keymap" ] && config_fail 'keymap'
[ -z "$font" ] && config_fail 'font'
[ -z "$timezone" ] && config_fail 'timezone'
[ -z "$hostname" ] && config_fail 'hostname'

## Check if dest_disk is a valid block device
udevadm info --query=all --name=$dest_disk | grep DEVTYPE=disk || config_fail 'dest_disk'

# Check internet connection
wget -q --tries=10 --timeout=5 http://www.google.com -O /tmp/index.google
if [ ! -s /tmp/index.google ];then
	echo
	echo 'installscript:'
	echo 'Error, please check your network connection.'
	exit 1
fi

# Initializing
REPLY='yes'
if [ "$confirm" != 'no' ]; then
	echo
	echo 'installscript:'
	echo 'WARNING:'
	echo '---------------------------------------'
	echo 'The destination drive will be formatted.'
	echo "All data on" $dest_disk "will be lost!"
	echo '---------------------------------------'
	read -p 'Continue (yes/no)? '
fi
if [ "$REPLY" = 'yes' ]; then
	umount $dest_disk* || :
        wipefs -a $dest_disk
        dd if=/dev/zero of=$dest_disk count=100 bs=512; partprobe $dest_disk; sync; partprobe -s; sleep 5
else
	exit 0
fi

# Partitioning
## swap_partition
if [ "$swap" = 'yes' ]; then
	swap_part_number=1
	root_part_number=2
	home_part_number=3
else
	root_part_number=1
	home_part_number=2
fi

if [ "$swap" = 'yes' ]; then
echo -e "n\n \
                  p\n \
                  ${swap_part_number}\n \
                  \n \
                 +${swap_size}\n \
                  t\n \
                  82\n
                 w" | fdisk ${dest_disk}

	## wait a moment
	sleep 1
fi

## root_partition
echo -e "n\n \
                  p\n \
                  ${root_part_number}\n \
                  \n \
                 +${root_size}\n \
                 w" | fdisk ${dest_disk}

## wait a moment
sleep 1

# home_partition
echo -e "n\n \
                  p\n \
                  ${home_part_number}\n \
                  \n \
                  \n \
                 w" | fdisk ${dest_disk}

# Create filesystems
## swap
if [ "$swap" = 'yes' ]; then
	mkswap ${dest_disk}${swap_part_number}
	swapon ${dest_disk}${swap_part_number}
fi

## root
mkfs.ext4 ${dest_disk}${root_part_number}

## home
mkfs.ext4 ${dest_disk}${home_part_number}

# mounting partition
## root
mount ${dest_disk}${root_part_number} /mnt

## home
mkdir /mnt/home
mount ${dest_disk}${home_part_number} /mnt/home

## mirrorlist
# echo "$mirrorlist" > /etc/pacman.d/mirrorlist

# pacstrap
if [ "$base_devel" = 'yes' ]; then
	pacstrap /mnt base base-devel
else
	pacstrap /mnt base
fi

# configure system
## fstab
genfstab -L /mnt > /mnt/etc/fstab

## locale
echo "$locale_gen" >> /mnt/etc/locale.gen
echo "$locale_conf" > /mnt/etc/locale.conf
arch-chroot /mnt /usr/bin/locale-gen

## console font and keymap
echo "$keymap" > /mnt/etc/vconsole.conf
echo "$font" >> /mnt/etc/vconsole.conf

## timezone
ln -s /usr/share/zoneinfo/$timezone /mnt/etc/localtime

## hardware clock
hwclock --systohc --utc

## hostname
echo "$hostname" > /mnt/etc/hostname

#  mkinitcpio
arch-chroot /mnt mkinitcpio -p linux

## password
echo root:$root_password | arch-chroot /mnt /usr/bin/chpasswd
echo -e $new_pass"\n"$new_pass | arch-chroot /mnt /usr/bin/passwd

# install grub & os prober packages
pacstrap /mnt grub os-prober

# write grub to mbr
arch-chroot /mnt /usr/bin/grub-install $dest_disk
# configure grub
arch-chroot /mnt /usr/bin/grub-mkconfig -o /boot/grub/grub.cfg

echo
echo 'installscript:'
echo 'Successfully installed base system.'

# Exit
cd /
umount /mnt/home
umount /mnt

echo
echo 'installscript:'
echo 'Installation completed!'
echo 'Eject any DVD or remove USB installation media and reboot!'

# Report
finish_time=$(date +%s)
min=$(( $((finish_time - start_time)) /60 ))

echo
echo 'installscript:'
echo -e "\nTotal install time:" $min 'minutes.'
exit 0
