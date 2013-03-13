#!/usr/bin/env bash
# s. rannou <mxs@sbrk.org>
#
# this script creates a initrd image that includes a ssh server to
# remotely mount encrypted partitions.

SSH_PKG="openssh-6.1p1-x86_64-1.txz"

if ! [ -f $SSH_PKG ]
then
    echo "error: this script requires $SSH_PKG"
    exit
fi

# temporary directory used by mkinitrd
rm -rf /boot/initrd-tree /boot/inird.gz

# build the image with support of cryptsetup and lvm
mkinitrd -u -L -f ext4 -k 3.7.10-sbrk-custom -C '/dev/sda2:/dev/sdb1' -r /dev/mapper/cryptvg-root

# replace the init script with a custom one that starts a sshd server
cp init-custom /boot/initrd-tree/init
echo yes > /boot/initrd-tree/luksremotekey

# add support of a dhcp client
cp udhcpc.script /boot/initrd-tree/bin/
ln -sf busybox /boot/initrd-tree/bin/route
touch /boot/initrd-tree/run/resolv.conf
ln -sf ../run/resolv.conf /boot/initrd-tree/etc/resolv.conf

# add ssh support
installpkg --root /boot/initrd-tree/ $SSH_PKG
cp sshd_config /boot/initrd-tree/etc/ssh/
sed -i 's#/bin/bash#/bin/sh#' /boot/initrd-tree/etc/passwd
chroot /boot/initrd-tree/ /bin/passwd

cp -a /dev/console /boot/initrd-tree/dev
cp -a /dev/null /boot/initrd-tree/dev
cp -a /dev/urandom /boot/initrd-tree/dev
cp -a /dev/random /boot/initrd-tree/dev
cp -a /dev/tty1 /boot/initrd-tree/dev
cp -a /dev/tty2 /boot/initrd-tree/dev
mkdir -p /boot/initrd-tree/dev/pts
echo "devpts                 /dev/pts      devpts    defaults            0      0" >> /boot/initrd-tree/etc/fstab
echo "shm                    /dev/shm      tmpfs     nodev,nosuid        0      0" >> /boot/initrd-tree/etc/fstab

# required to properly mount partitions
cp -a /dev/sda /boot/initrd-tree/dev
cp -a /dev/sda1 /boot/initrd-tree/dev
cp -a /dev/sda2 /boot/initrd-tree/dev
cp -a /dev/sdb /boot/initrd-tree/dev
cp -a /dev/sdb1 /boot/initrd-tree/dev

# rebuild the image with our modifications
mkinitrd -L -f ext4 -k 3.7.10-sbrk-custom -C '/dev/sda2:/dev/sdb1' -r /dev/mapper/cryptvg-root

# commit changes to the disk
lilo

# clean up
rm -rf /boot/initrd-tree
