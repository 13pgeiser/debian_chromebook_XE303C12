#!/bin/bash
# This script must run in a container with priviledges! (chroot, bin_fmt)
set -e

figlet "CPUs: $(grep -c processor /proc/cpuinfo)"

#
kernel_option="debian_4.19"
#kernel_option="debian_5.4"
#kernel_option="rcn_5.4"
#kernel_option="rcn_4.19"

if [ "$kernel_option" == "debian_4.19" ]; then
	release="buster"
	build_armsoc_xorg=true
	tar xJf /usr/src/linux-source-4.19.tar.xz
	cd linux-source-4.19

elif [ "$kernel_option" == "debian_5.4" ]; then
	release="bullseye"
	build_armsoc_xorg=false
	tar xJf /usr/src/linux-source-5.4.tar.xz
	cd linux-source-5.4
	export kernel_version=5.4.19

elif [ "$kernel_option" == "rcn_4.19" ]; then
	release="buster"
	build_armsoc_xorg=true
	kernel_version=4.19.127
	rcn_patch=https://rcn-ee.com/deb/sid-armhf/v4.19.127-bone53/patch-4.19.127-bone53.diff.gz
	patches="0005-net-smsc95xx-Allow-mac-address-to-be-set-as-a-parame.patch"
	for patch_to_apply in $patches; do
		wget https://raw.githubusercontent.com/archlinuxarm/PKGBUILDs/master/core/linux-armv7/$patch_to_apply
	done
	wget -nv $rcn_patch
	rcn_patch=$(basename $rcn_patch)
	gzip -d "$rcn_patch"
	wget -nv https://mirrors.edge.kernel.org/pub/linux/kernel/v4.x/linux-$kernel_version.tar.xz
	tar xJf linux-$kernel_version.tar.xz
	(
		cd linux-$kernel_version || exit
		git apply "../${rcn_patch%.*}"
		for patch_to_apply in $patches; do
			patch -p1 --no-backup-if-mismatch <../$patch_to_apply
		done
	)
	cd linux-$kernel_version

elif [ "$kernel_option" == "rcn_5.4" ]; then
	release="bullseye"
	build_armsoc_xorg=false
	kernel_version=5.4.52
	rcn_patch=https://rcn-ee.com/deb/sid-armhf/v5.4.52-armv7-x31/patch-5.4.52-armv7-x31.diff.gz
	patches="0005-net-smsc95xx-Allow-mac-address-to-be-set-as-a-parame.patch"
	for patch_to_apply in $patches; do
		wget https://raw.githubusercontent.com/archlinuxarm/PKGBUILDs/master/core/linux-armv7/$patch_to_apply
	done
	wget -nv $rcn_patch
	rcn_patch=$(basename $rcn_patch)
	gzip -d "$rcn_patch"
	wget -nv https://mirrors.edge.kernel.org/pub/linux/kernel/v5.x/linux-$kernel_version.tar.xz
	tar xJf linux-$kernel_version.tar.xz
	(
		cd linux-$kernel_version || exit
		git apply "../${rcn_patch%.*}"
		for patch_to_apply in $patches; do
			patch -p1 --no-backup-if-mismatch <../$patch_to_apply
		done
	)
	cd linux-$kernel_version

else
	echo "Unsupported kernel_option: $kernel_option"
	exit 1
fi

kernel_version="$(make kernelversion)"
export kernel_version
figlet "KERNEL: $kernel_version"

export ARCH=arm
export CROSS_COMPILE=arm-linux-gnueabihf-
MAKEFLAGS="-j$(grep -c processor /proc/cpuinfo)"
export MAKEFLAGS

# Get TI firmwares (not mandatory)...
mkdir -p firmware
wget https://github.com/beagleboard/linux/blob/4.19/firmware/am335x-bone-scale-data.bin?raw=true -O firmware/am335x-bone-scale-data.bin
wget https://github.com/beagleboard/linux/blob/4.19/firmware/am335x-evm-scale-data.bin?raw=true -O firmware/am335x-evm-scale-data.bin
wget https://github.com/beagleboard/linux/blob/4.19/firmware/am335x-pm-firmware.bin?raw=true -O firmware/am335x-pm-firmware.bin
wget https://github.com/beagleboard/linux/blob/4.19/firmware/am335x-pm-firmware.elf?raw=true -O firmware/am335x-pm-firmware.elf
wget https://github.com/beagleboard/linux/blob/4.19/firmware/am43x-evm-scale-data.bin?raw=true -O firmware/am43x-evm-scale-data.bin

# Copy config, apply and build kernel
cp /configs/linux_config ./.config
make olddefconfig
make bindeb-pkg
make -j
make dtbs
make modules_install INSTALL_MOD_PATH="/debian_root"
kver=$(make kernelrelease)
export kver
echo "KVER: ${kver}"

# Create exynos-kernel, /kernel_usb.bin, /kernel_emmc_ext4.bin
cd arch/arm/boot
cat <<__EOF__ >kernel-exynos.its
/dts-v1/;

/ {
    description = "Chrome OS kernel image with one or more FDT blobs";
    images {
        kernel@1{
            description = "kernel";
            data = /incbin/("zImage");
            type = "kernel_noload";
            arch = "arm";
            os = "linux";
            compression = "none";
            load = <0>;
            entry = <0>;
          };
        fdt@1 {
            description = "exynos5250-snow.dtb";
            data = /incbin/("dts/exynos5250-snow.dtb");
            type = "flat_dt";
            arch = "arm";
            compression = "none";
            hash@1 {
                algo = "sha1";
            };
        };
        fdt@2 {
            description = "exynos5250-snow-rev5.dtb";
            data = /incbin/("dts/exynos5250-snow-rev5.dtb");
            type = "flat_dt";
            arch = "arm";
            compression = "none";
            hash@1 {
                algo = "sha1";
            };
        };
        fdt@3 {
            description = "exynos5250-spring.dtb";
            data = /incbin/("dts/exynos5250-spring.dtb");
            type = "flat_dt";
            arch = "arm";
            compression = "none";
            hash@1 {
                algo = "sha1";
            };
        };
      };
    configurations {
        default = "conf@1";
        conf@1{
            kernel = "kernel@1";
            fdt = "fdt@1";
          };
        conf@2{
            kernel = "kernel@1";
            fdt = "fdt@2";
          };
        conf@3 {
            kernel = "kernel@1";
            fdt = "fdt@3";
          };
      };
  };
__EOF__
mkimage -D "-I dts -O dtb -p 2048" -f kernel-exynos.its exynos-kernel
dd if=/dev/zero of=bootloader.bin bs=512 count=1
echo 'noinitrd console=tty0 root=PARTUUID=%U/PARTNROFF=2 rootwait rw rootfstype=ext4' >cmdline
vbutil_kernel --arch arm --pack /kernel_usb.bin --keyblock /usr/share/vboot/devkeys/kernel.keyblock \
	--signprivate /usr/share/vboot/devkeys/kernel_data_key.vbprivk --version 1 --config cmdline \
	--bootloader bootloader.bin --vmlinuz exynos-kernel
echo 'noinitrd console=tty0 root=/dev/mmcblk0p3 rootwait rw rootfstype=ext4' >cmdline
vbutil_kernel --arch arm --pack /kernel_emmc_ext4.bin --keyblock /usr/share/vboot/devkeys/kernel.keyblock \
	--signprivate /usr/share/vboot/devkeys/kernel_data_key.vbprivk --version 1 --config cmdline \
	--bootloader bootloader.bin --vmlinuz exynos-kernel
cd /

# Make sure qemu-arm can execute transparently ARM binaries.
mount binfmt_misc -t binfmt_misc /proc/sys/fs/binfmt_misc
update-binfmts --enable qemu-arm

# Extract debian!
qemu-debootstrap --arch=armhf $release debian_root http://httpredir.debian.org/debian

if [ "$release" == "buster" ]; then
	# Update Apt sources for buster
	cat <<EOF >debian_root/etc/apt/sources.list
deb http://httpredir.debian.org/debian buster main non-free contrib
deb-src http://httpredir.debian.org/debian buster main non-free contrib
deb http://security.debian.org/debian-security buster/updates main contrib non-free
EOF
else
	# Update Apt sources for bullseye
	cat <<EOF >debian_root/etc/apt/sources.list
deb http://httpredir.debian.org/debian $release main non-free contrib
deb-src http://httpredir.debian.org/debian $release main non-free contrib
EOF
fi

# Change hostname
echo "chromebook" >debian_root/etc/hostname

# Add it to the hosts
cat <<EOF >debian_root/etc/hosts
127.0.0.1       chromebook    localhost
::1             localhost ip6-localhost ip6-loopback
fe00::0         ip6-localnet
ff00::0         ip6-mcastprefix
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters
EOF

# Add loopback interface
cat <<EOF >debian_root/etc/network/interfaces
auto lo
iface lo inet loopback
EOF

# And configure default DNS (google...)
cat <<EOF >debian_root/etc/resolv.conf
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF

# Taken as-is from https://github.com/RPi-Distro/raspberrypi-sys-mods/blob/master/debian/raspberrypi-sys-mods.regenerate_ssh_host_keys.service
cat <<EOF >debian_root/etc/systemd/system/regenerate_ssh_host_keys.service
[Unit]
Description=Regenerate SSH host keys
Before=ssh.service
ConditionFileIsExecutable=/usr/bin/ssh-keygen

[Service]
Type=oneshot
ExecStartPre=-/bin/dd if=/dev/hwrng of=/dev/urandom count=1 bs=4096
ExecStartPre=-/bin/sh -c "/bin/rm -f -v /etc/ssh/ssh_host_*_key*"
ExecStart=/usr/bin/ssh-keygen -A -v
ExecStartPost=/bin/systemctl disable regenerate_ssh_host_keys

[Install]
WantedBy=multi-user.target
EOF

run_in_chroot() {
	mount -t proc proc debian_root/proc
	mount -o bind /dev/ debian_root/dev/
	mount -o bind /dev/pts debian_root/dev/pts
	chmod +x debian_root/root/third-stage
	LANG=C chroot debian_root /root/third-stage
	umount debian_root/dev/pts
	umount debian_root/dev/
	umount debian_root/proc
	rm -f debian_root/root/third-stage
}

# Prepare third-stage
cat <<EOF >debian_root/root/third-stage
#!/bin/bash
set -ex
apt-get update
echo "root:toor" | chpasswd
export DEBIAN_FRONTEND=noninteractive
apt-get -y --no-install-recommends install abootimg cgpt fake-hwclock u-boot-tools vboot-utils vboot-kernel-utils \
  initramfs-tools parted sudo xz-utils wpasupplicant firmware-linux firmware-libertas \
  firmware-samsung locales-all ca-certificates initramfs-tools u-boot-tools locales \
  console-common less network-manager git laptop-mode-tools python3 task-ssh-server \
  alsa-utils pulseaudio
apt-get -y dist-upgrade
apt-get -y autoremove
apt-get clean
depmod -a $kernel_version
rm -f /0
rm -f /hs_err*
rm -rf /root/.bash_history
rm -f /usr/bin/qemu*
# Enable ssh key regeneration
systemctl enable regenerate_ssh_host_keys
EOF
run_in_chroot

# XORG driver
if [ "$build_armsoc_xorg" = true ]; then
	cat <<EOF >debian_root/root/third-stage
#!/bin/bash
set -ex
apt-get -y install xserver-xorg-dev libtool automake xutils-dev libudev-dev build-essential pkg-config git
git clone https://github.com/paolosabatino/xf86-video-armsoc.git
cd xf86-video-armsoc
./autogen.sh
./configure --enable-maintainer-mode --prefix=/usr
make
make install
cd ..
apt-get -y remove xserver-xorg-dev libtool automake xutils-dev libudev-dev build-essential pkg-config git
apt-get -y autoremove
rm -rf xf86-video-armsoc
EOF
	run_in_chroot
fi

# Xorg
mkdir -p debian_root/etc/X11/xorg.conf.d/
cat <<EOF >debian_root/etc/X11/xorg.conf.d/10-synaptics-chromebook.conf
Section "InputClass"
        Identifier          	    "touchpad"
        MatchIsTouchpad             "on"
        Driver                      "synaptics"
        Option                      "TapButton1"    "1"
        Option                      "TapButton2"    "3"
        Option                      "TapButton3"    "2"
        Option                      "FingerLow"     "15"
        Option                      "FingerHigh"    "20"
        Option                      "FingerPress"   "256"
EndSection
EOF

# Mali GPU rules aka mali-rules package in ChromeOS
cat <<EOF >debian_root/etc/udev/rules.d/50-mali.rules
KERNEL=="mali", MODE="0660", GROUP="video"
KERNEL=="mali[0-9]", MODE="0660", GROUP="video"
EOF

# Video rules aka media-rules package in ChromeOS
cat <<EOF >debian_root/etc/udev/rules.d/50-media.rules
ATTR{name}=="s5p-mfc-dec", SYMLINK+="video-dec"
ATTR{name}=="s5p-mfc-enc", SYMLINK+="video-enc"
ATTR{name}=="s5p-jpeg-dec", SYMLINK+="jpeg-dec"
ATTR{name}=="exynos-gsc.0*", SYMLINK+="image-proc0"
ATTR{name}=="exynos-gsc.1*", SYMLINK+="image-proc1"
ATTR{name}=="exynos-gsc.2*", SYMLINK+="image-proc2"
ATTR{name}=="exynos-gsc.3*", SYMLINK+="image-proc3"
ATTR{name}=="rk3288-vpu-dec", SYMLINK+="video-dec"
ATTR{name}=="rk3288-vpu-enc", SYMLINK+="video-enc"
ATTR{name}=="go2001-dec", SYMLINK+="video-dec"
ATTR{name}=="go2001-enc", SYMLINK+="video-enc"
ATTR{name}=="mt81xx-vcodec-dec", SYMLINK+="video-dec"
ATTR{name}=="mt81xx-vcodec-enc", SYMLINK+="video-enc"
ATTR{name}=="mt81xx-image-proc", SYMLINK+="image-proc0"
EOF

# ALSA
mkdir -p debian_root/usr/share/alsa/ucm/Snow-I2S-MAX98095
cat <<EOF >debian_root/usr/share/alsa/ucm/Snow-I2S-MAX98095/HiFi.conf
SectionVerb {
        # ALSA PCM
        Value {
                TQ "HiFi"

                # ALSA PCM device for HiFi
                PlaybackPCM "hw:SnowI2SMAX98095,0"
		PlaybackChannels 2
        }
	EnableSequence [
		cdev "hw:SnowI2SMAX98095"
		cset "name='Left Speaker Mixer Left DAC1 Switch' on"
		cset "name='Right Speaker Mixer Right DAC1 Switch' on"
		cset "name='Left Headphone Mixer Left DAC1 Switch' on"
		cset "name='Right Headphone Mixer Right DAC1 Switch' on"
	]
	DisableSequence [
	]
}
SectionDevice."Headphone".0 {
	Value {
		JackName "SnowI2SMAX98095 Headphone Jack"
	}

	EnableSequence [
		cdev "hw:SnowI2SMAX98095"
		cset "name='Left Headphone Mixer Left DAC1 Switch' on"
		cset "name='Right Headphone Mixer Right DAC1 Switch' on"
	]
	DisableSequence [
		cdev "hw:SnowI2SMAX98095"
		cset "name='Left Speaker Mixer Left DAC1 Switch' on"
		cset "name='Right Speaker Mixer Right DAC1 Switch' on"
	]
}
EOF
cat <<EOF >debian_root/usr/share/alsa/ucm/Snow-I2S-MAX98095/Snow-I2S-MAX98095.conf
Comment "Snow internal card"

SectionUseCase."HiFi" {
	File "HiFi.conf"
	Comment "Default"
}
EOF
cat <<EOF >debian_root/etc/asound.conf
pcm.!default {
  type hw
  card 0
}

ctl.!default {
  type hw
  card 0
}
EOF
sed -i 's/#load-module module-alsa-sink/load-module module-alsa-sink device=sysdefault/' debian_root/etc/pulse/default.pa

# Latop-mode
# By default, it goes to powersave that reduces cpu freq to 200 Hz!
sed -i 's/BATT_CPU_GOVERNOR=ondemand/BATT_CPU_GOVERNOR=conservative/' debian_root/etc/laptop-mode/conf.d/cpufreq.conf
sed -i 's/LM_AC_CPU_GOVERNOR=ondemand/LM_AC_CPU_GOVERNOR=performance/' debian_root/etc/laptop-mode/conf.d/cpufreq.conf
sed -i 's/NOLM_AC_CPU_GOVERNOR=ondemand/NOLM_AC_CPU_GOVERNOR=performance/' debian_root/etc/laptop-mode/conf.d/cpufreq.conf

cd /debian_root
tar pcJf ../rootfs.tar.xz ./*
(
	cd .. || exit
	mkdir -p xe303c12/
	cp /kernel_usb.bin xe303c12/kernel_usb.bin
	mv /kernel_emmc_ext4.bin xe303c12/kernel_emmc_ext4.bin
	mv rootfs.tar.xz xe303c12/rootfs.tar.xz
	cp ../scripts/install.sh xe303c12/install.sh
	cat <<EOF >xe303c12/xfce.sh
#!/bin/bash
apt-get install -y task-xfce-desktop xserver-xorg-input-synaptics libglx-mesa0 libgl1-mesa-dri mesa-opencl-icd mesa-va-drivers mesa-vdpau-drivers
alsaucm -c Snow-I2S-MAX98095
EOF
	chmod +x xe303c12/xfce.sh
	zip -r ./xe303c12.zip xe303c12/
	mkdir -p debs
	cp ./*.deb /debs/
	ls -1 /
)
