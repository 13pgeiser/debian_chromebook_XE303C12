#!/bin/sh
drive=/dev/mmcblk0
echo "Will erase everything on ${drive}. Hit Ctrl-C to stop now!"
read t
umount ${drive}p1
umount ${drive}p2
umount ${drive}p3
parted ${drive} --script -- mklabel gpt
cgpt create -z ${drive}
cgpt create ${drive}
cgpt add -i 1 -t kernel -b 8192 -s 32768 -l KERN-A -S 1 -T 5 -P 10 ${drive}
cgpt add -i 2 -t kernel -b 40960 -s 32768 -l KERN-B -S 1 -T 5 -P 5 ${drive}
cgpt add -i 3 -t data -b 73728 -s `expr $(cgpt show ${drive} | grep 'Sec GPT table' | awk '{ print \$1 }')  - 73728` -l Root ${drive}
blockdev --rereadpt ${drive}
dd if=/dev/zero of=${drive}p3 bs=1M count=1
mkfs.ext4 -O ^flex_bg -O ^metadata_csum -L rootfs ${drive}p3
cgpt show ${drive}

