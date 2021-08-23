#!/bin/bash
set -e
# Install script for https://github.com/13pgeiser/debian_stretch_XE303C12
# Run as a normal user. Expect sudo, cgpt, lsblk, parted to be on the PATH

# Check user ID and number of arguments.
# As a user, there is no arguments, the list of device available is shown
# As root, the argument is the device path to erase

function stop() {
	echo "$1"
	exit 1
}

function usage() {
	echo "As normal user: $0"
	echo "As root: $0 <device to erase and write>"
	echo ""
	echo "Example to install on /dev/sdh"
	echo "sudo $0 /dev/sdh"
	stop
}

function check_tool() {
	if [ ! -x "$(command -v "$1")" ]; then
		stop "Please install $1"
	fi
}

function scan_devices() {
	mapfile -t names < <(lsblk -d -n -p -o NAME)
	mapfile -t transports < <(lsblk -d -n -p -o TRAN)
	mapfile -t hotplugs < <(lsblk -d -n -p -o HOTPLUG)
	mapfile -t models < <(lsblk -d -n -p -o MODEL)
	mapfile -t vendors < <(lsblk -d -n -p -o VENDOR)
	mapfile -t sizes < <(lsblk -d -n -p -o SIZE)
	echo "Discovered devices"
	echo "------------------"
	for item in ${!names[*]}; do
		printf "Path=%s\\tSize=%s\\tModel=%s\\tVendor=%s\\tTransport=%s\\tHotplug=%d\\n" "${names[$item]}" "${sizes[$item]}" "${models[$item]}" "${vendors[$item]}" "${transports[$item]}" "${hotplugs[$item]}"
	done
	echo ""
	echo "Hotplug USB devices"
	echo "-------------------"
	count=0
	devices=()
	for item in ${!names[*]}; do
		if [ "${transports[$item]}" == "usb" ] && [ "${hotplugs[$item]}" -ne 0 ]; then
			printf "%d: Path=%s\\tModel=%s\\tVendor=%s\\tTransport=%s\\tHotplug=%d\\n" "$count" "${names[$item]}" "${models[$item]}" "${vendors[$item]}" "${transports[$item]}" "${hotplugs[$item]}"
			devices[$count]="${names[$item]}"
			count=$((count + 1))
		fi
	done
	read -rp "Your choice: " choice
	if [ -z "$choice" ]; then
		stop "Invalid choice"
	fi
	echo "CHOICE: $choice"
	if [ -z "${devices[$choice]}" ]; then
		stop "Invalid choice: $choice"
	fi
	echo "Using: ${devices[$choice]}"
	sudo bash "$0" "${devices[$choice]}"
}

function unmount_partitions() {
	for partition in $(fdisk "$1" -l | grep "^/dev/" | cut -d" " -f1); do
		if [ "$(mount | grep "$partition")" != "" ]; then
			umount "$partition"
		fi
	done
}

function format_device() {
	echo ""
	echo "********************"
	echo "* BIG FAT WARNING! *"
	echo "********************"
	echo "$1 will be completely erased!"
	read -rp "Are you sure? type yes to proceed: " sure
	if [ "$sure" != "yes" ]; then
		stop "Stopped by the user"
	fi
	unmount_partitions "$1"
	parted "$1" --script -- mklabel gpt
	cgpt create -z "$1"
	cgpt create "$1"
	cgpt add -i 1 -t kernel -b 8192 -s 32768 -l KERN-A -S 1 -T 5 -P 10 "$1"
	cgpt add -i 2 -t kernel -b 40960 -s 32768 -l KERN-B -S 1 -T 5 -P 5 "$1"
	cgpt add -i 3 -t data -b 73728 -s "$(("$(cgpt show "$1" | grep 'Sec GPT table' | awk '{ print $1 }')" - 73728))" -l Root "$1"
	blockdev --rereadpt "$1"
	#cgpt show $1
	if [ "$(echo "$1" | grep mmcblk)" == "" ]; then
		drive="${1}" # partitions: /dev/sdx[1,2,3]
		kernel="kernel_usb.bin"
	else
		drive="${1}p" # partitions: /dev/mmcblk0p[1,2,3]
		kernel="kernel_emmc_ext4.bin"
	fi
	echo "Formating ..."
	mkfs.ext4 -F -L rootfs "${drive}3"
	# mkfs.btrfs -O ^skinny-metadata -L rootfs ${drive}3
	echo "Mounting ..."
	mkdir -p /mnt/xe303c12
	mount "${drive}3" /mnt/xe303c12 -t ext4 -o noatime
	# mount ${drive}3 /mnt/xe303c12 -t btrfs noatime,compress=lzo,commit=0,ssd_spread,autodefrag
	echo "Unpacking ..."
	tar xJf rootfs.tar.xz -C /mnt/xe303c12/
	if [ "$(echo "$1" | grep mmcblk)" == "" ]; then
		echo "Copying archive and install script"
		cp rootfs.tar.xz /mnt/xe303c12/root/
		cp ./*.sh /mnt/xe303c12/root/
		cp ./*.bin /mnt/xe303c12/root/
	else
		cp ./xfce_install.sh /mnt/xe303c12/root/
	fi
	echo "Syncing"
	sync
	umount "${drive}3"
	echo "Writing kernels..."
	dd if=$kernel of="${drive}1"
	dd if=$kernel of="${drive}2"
	sync
	echo "Installation finished!"
}

if [ "$EUID" -ne 0 ]; then
	if [ "$#" -ne 0 ]; then
		usage
	fi
	check_tool lsblk
	scan_devices
else
	if [ "$#" -ne 1 ]; then
		echo "This will install a new kernel on /dev/mmcblk0p1"
		read -rp "Are you sure? type yes to proceed: " sure
		if [ "$sure" != "yes" ]; then
			stop "Stopped by the user"
		fi
		tar xJf rootfs.tar.xz -C / lib/modules/
		dd if=kernel_emmc_ext4.bin of=/dev/mmcblk0p1
	else
		check_tool cgpt
		check_tool parted
		check_tool blockdev
		check_tool mkfs.ext4
		format_device "$1"
	fi
fi

exit
