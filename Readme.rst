Installing Debian on an ARM Chromebook (XE303C12)
#################################################


:date: 2018-02-25 14:00
:modified: 2023-11-17 10:00
:tags: debian, arm, chromebook
:authors: Pascal Geiser
:summary: Debian installation on Samsung's ARM chromebook.

.. contents::

|ci-badge|

.. |ci-badge| image:: https://github.com/13pgeiser/debian_chromebook_XE303C12/actions/workflows/publish.yml/badge.svg
              :target: https://github.com/13pgeiser/debian_chromebook_XE303C12/actions/workflows/publish.yml/

Work heavily based on Kali ARM scripts: https://gitlab.com/kalilinux/build-scripts/kali-arm

Kernel config taken from: https://github.com/archlinuxarm/PKGBUILDs/tree/master/core/linux-armv7

I still use the machine as a remote desktop client and I do it rarely. Do not expect much support if it does fit work you!

**Use at your own risk!**

Introduction
************

Chromebooks and ChromeOS are giving an excellent browsing experience. The system
is fast and with an ARM Chromebook the battery life is incredible.

The main issue with ChromeOS is the lack of good applications. All the google services
are perfectly integrated but apart from this, the overall application library is poor.
This fact has been partially addressed by the newest versions of ChromeOS with support
of Android applications. Sadly, my old Chromebook is slowly reaching end of life (July 2018
according to google: https://support.google.com/chrome/a/answer/6220366?hl=en) and it never
got support for Android applications.

As the HW still works perfectly, I decided to try installing my favorite OS: `Debian! <https://www.debian.org/>`__
The main debian page looks old and did not provide too much information:
https://wiki.debian.org/InstallingDebianOn/Samsung/ARMChromebook

The best source of information is from the guys of `Kali Linux <https://www.kali.org/>`__. They provide
`ARM images <https://www.offensive-security.com/kali-linux-arm-images/>`__ for a lot of different systems.

The scripts used to generate these images are available on `Gitlab <https://gitlab.com/kalilinux/build-scripts/kali-arm>`__
They provide an excellent basis to prepare a debian image.

Developer Mode
**************

The first step to take control of the Chromebook is to switch to developer mode. This disable the kernel signature verification
and let U run any firmware on the machine with the drawback of having at each startup an annoying warning screen...

* First, turn off the machine
* Press ESC + Refesh(F5) and Power-on @ the same time.
* On the recovery screen appears, press CTRL-D
* Confirm the switch by pressing enter and wait a (long) while.

Once developer mode is enabled, it's possible to enable USB boot:

* Boot the machine (pressing CTRL-D right after power-on).
* Once chrome is ready, press CTRL-F2
* Log as `chronos` with no password.
* su - # Should give you root access.
* Enable usb boot with: crossystem dev_boot_usb=1 dev_boot_signed_only=0

For more, look here:
 * Chrome documentation: https://chromium.googlesource.com/chromiumos/docs/+/HEAD/developer_mode.md
 * ArchArm linux: https://archlinuxarm.org/platforms/armv7/samsung/samsung-chromebook

USB stick preparation (on a Linux host)
***************************************

- Download the latest zip archive from the [releases page](https://github.com/13pgeiser/debian_chromebook_XE303C12/releases) and unpack it.
- Open a terminal in the extracted folder
- plug a USB key to hold the debian installation image
- run *./install.sh* and select the USB key in the list.

**BEWARE it will erase all data on the selected disk!**

**Make sure you've selected the right one! You've been warned!**

Boot on USB stick
*****************

Once the USB key is ready, plug it in the **black** usb connector (ie USB 2.0) of
the chromebook . Start the machine and press ctrl-u (assuming you've already configured the
developer mode). Wait for the system to boot.

user: root

passwd: toor

To install on the local emmc drive, run as root (from the USB key):

::

	./install.sh /dev/mmcblk0

**This will wipe out the entire disk. You've been warned! ;-)**

Once done, shutdown the machine with `poweroff`. Do not `reboot` or you will get a black screen (bug in the backpanel driver?).

Have fun!

Installing XFCE
***************

Start the machine and hit ctrl-d to boot on the emmc (or ctrl-u if you want to test on a USB key first) and log as root:

user: root

passwd: toor

Setup a network connection:
`nmtui`

Run the provided XFCE installation script::

	./xfce_install.sh

Wait for the installation to finish and `poweroff` before jumping in your prefered desktop (with power-on and ctrl-d).

Kernel upgrade
**************

The same script can be used to update the kernel and the modules on the emmc drive.

- Download the zip archive and unpack it from the running debian installation
- Open a terminal in the depacked folder
- run *sudo ./install.sh*

Known issues
************

The final result is usable but far from production quality.

1. Currently the machine does not like the reboot much. This leads to a back screen -> shutdown and restart each time.
2. Change the password!!! ;-)
3. Plenty of other problems not described here.

Rebuilding locally
******************

The scripts have been prepared to work in docker. To rebuild:
 * Install docker for your distro
 * Clone the repository: *git clone https://github.com/13pgeiser/debian_chromebook_XE303C12.git*
 * Jump in the folder: *cd debian_chromebook_XE303C12*
 * Call make: *make* and wait a while depending on your machine...

Have fun!

