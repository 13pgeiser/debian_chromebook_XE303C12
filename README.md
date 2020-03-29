# Debian Buster on Samsung Chromebook Serie 3 (XE303C12, ARM Exynos)

[![Build Status](https://dev.azure.com/pascalgeiser/debian_chromebook_XE303C12/_apis/build/status/13pgeiser.debian_chromebook_XE303C12?branchName=master)](https://dev.azure.com/pascalgeiser/debian_chromebook_XE303C12/_build/latest?definitionId=8&branchName=master)

Work heavily based on Kali ARM scripts: https://gitlab.com/kalilinux/build-scripts/kali-arm

Kernel config taken from: https://github.com/archlinuxarm/PKGBUILDs/tree/master/core/linux-armv7

I still use the machine as a remote desktop client and I do it rarely. Do not expect much support if it does fit work you!

**Use at your own risk!**

# Installation

## Developer mode

The first step to take control of the Chromebook is to switch to developer mode.
This disable the kernel signature verification and let you run any firmware on the machine with the drawback of having at each startup an annoying warning screen…

    First, turn off the machine
    Press ESC + Refesh(F5) and Power-on @ the same time.
    On the recovery screen appears, press CTRL-D
    Confirm the switch by pressing enter and wait a (long) while.

Once developer mode is enabled, it’s possible to enable USB boot:

    Boot the machine (pressing CTRL-D right after power-on).
    Once chrome is ready, press CTRL-F2
    Log as chronos with no password.
    su - # Should give you root access.
    Enable usb boot with: crossystem dev_boot_usb=1 dev_boot_signed_only=0

## USB stick preparation

- Download the latest zip archive from the [releases page](https://github.com/13pgeiser/debian_chromebook_XE303C12/releases) and unpack it.
- Open a terminal in the depacked folder
- plug a USB key to hold the debian installation image
- run _./install.sh_ and select the USB key in the list.

**BEWARE it will erase all data on the selected disk!**

**Make sure you've selected the right one! You've been warned!**

## Boot on USB stick

Once the USB key is ready, plug it in the black usb connector (ie USB 2.0) of
the chromebook . Start it and press ctrl-u (assuming you've already configured the
developer mode). Wait for the system to boot.

user: root

passwd: toor

To install on the local emmc drive, run as root (from the USB key):

```
./install.sh /dev/mmcblk0
```

**This will wipe out the entire disk. You've been warned! ;-)**

Once done, shutdown the machine with `poweroff`. Do not `reboot`or you will get a black screen (bug in the backpanel driver?).

Have fun!

## Installing a desktop

Start the machine and hit ctrl-d to boot on the emmc (or ctrl-u if you want to test on a USB key first) and log as root:

user: root

passwd: toor

Setup a network connection:
`nmtui`

And install you prefered desktop (xfce as an example):
`apt-get install task-xfce-dektop xserver-xorg-input-synaptics`

Wait for the installation to finish and `poweroff` before jumping in your prefered desktop (with power-on and ctrl-d).

## Kernel upgrade

The same script can be used to update the kernel and the modules on the emmc drive.

- Download the zip archive and unpack it from the running debian installation
- Open a terminal in the depacked folder
- run _sudo ./install.sh_

# Known issues

The final result is usable but far from production quality.

1. Currently the machine does not like the reboot much. This leads to a back screen -> shutdown and restart each time.
2. Sound card is not configured (and may not work).
3. There is no graphic acceleration.
4. Change the password!!! ;-)
5. Plenty of other problems not described here.
