#!/bin/sh
mount /dev/mmcbl0p3 /mnt btrfs noatime,compress=lzo,commit=0,ssd_spread,autodefrag
