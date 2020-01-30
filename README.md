# Debian Buster on Samsung Chromebook (XE303C12, ARM Exynos)

[![Build Status](https://dev.azure.com/pascalgeiser/debian_chromebook_XE303C12/_apis/build/status/13pgeiser.debian_chromebook_XE303C12?branchName=master)](https://dev.azure.com/pascalgeiser/debian_chromebook_XE303C12/_build/latest?definitionId=8&branchName=master)

Work heavily based on Kali ARM scripts: https://gitlab.com/kalilinux/build-scripts/kali-arm

Kernel config taken from: https://github.com/archlinuxarm/PKGBUILDs/tree/master/core/linux-armv7

## Installation

- Download the latest zip archive from the [releases page](https://github.com/13pgeiser/debian_chromebook_XE303C12/releases) and unpack it.
- Open a terminal in the depacked folder
- plug a USB key to hold the debian installation image
- run _./install.sh_ and select the USB key in the list.

BEWARE it will erase all data on the selected disk!
Make sure you've selected the right one! You've been warned!

Once the key is ready, plug it in the black usb connector (ie USB 2.0) of
the chromebook . Start it and press ctrl-u (assuming you've already configured the
developer mode). Wait for the system to boot.

user: root
passwd: toor

To install on the local emmc drive, run as root (from the USB key):

```
./install.sh /dev/mmcblk0
```

This will wipe out the entire disk. You've been warned! ;-)

Have fun!

## Kernel upgrade

The same script can be used to update the kernel and the modules on the emmc drive.

- Download the zip archive and unpack it from the running debian installation
- Open a terminal in the depacked folder
- run _sudo ./install.sh_

