#!/bin/bash
# This script must run in a container with priviledges! (chroot, bin_fmt)
set -e

release="bullseye"
figlet "Release: $release"

figlet "CPUs: $(nproc)"

kernel_option="debian_5.x"
#kernel_option="rcn_5.x"

if [ "$kernel_option" == "debian_5.x" ]; then
	tar xJf /usr/src/linux-source-5.10.tar.xz
	cd linux-source-5.10
	kernel_version="$(make kernelversion)"

elif [ "$kernel_option" == "rcn_5.x" ]; then
	kernel_version=5.10.131
	rcn_patch="https://rcn-ee.com/deb/sid-armhf/v5.10.131-armv7-x65/patch-5.10.131-armv7-x65.diff.gz"
	wget -nv $rcn_patch
	rcn_patch=$(basename $rcn_patch)
	gzip -d "$rcn_patch"
	wget -nv https://mirrors.edge.kernel.org/pub/linux/kernel/v5.x/linux-$kernel_version.tar.xz
	tar xJf linux-$kernel_version.tar.xz
	(
		cd linux-$kernel_version || exit
		git apply "../${rcn_patch%.*}"
	)
	cd linux-$kernel_version
	kernel_version="$(make kernelversion)"
else
	echo "Unsupported kernel_option: $kernel_option"
	exit 1
fi

if [ -n "${kernel_version}" ]; then
	export kernel_version
	figlet "KERNEL: $kernel_version"
	# shellcheck disable=SC2206
	vers=(${kernel_version//./ })
	version="${vers[0]}.${vers[1]}"
	figlet "VERSION: $version"

	# Get TI firmwares (not mandatory)...
	mkdir -p firmware
	wget https://github.com/beagleboard/linux/blob/"$version"/firmware/am335x-bone-scale-data.bin?raw=true -O firmware/am335x-bone-scale-data.bin
	wget https://github.com/beagleboard/linux/blob/"$version"/firmware/am335x-evm-scale-data.bin?raw=true -O firmware/am335x-evm-scale-data.bin
	wget https://github.com/beagleboard/linux/blob/"$version"/firmware/am335x-pm-firmware.bin?raw=true -O firmware/am335x-pm-firmware.bin
	wget https://github.com/beagleboard/linux/blob/"$version"/firmware/am335x-pm-firmware.elf?raw=true -O firmware/am335x-pm-firmware.elf
	wget https://github.com/beagleboard/linux/blob/"$version"/firmware/am43x-evm-scale-data.bin?raw=true -O firmware/am43x-evm-scale-data.bin

	# Copy config, apply and build kernel
	export ARCH=arm
	export CROSS_COMPILE=arm-linux-gnueabihf-
	cp /configs/"$version" ./.config
	make olddefconfig
	make bindeb-pkg "-j$(nproc)"
	make dtbs
	kver=$(make kernelrelease)
	export kver
	figlet "KVER: $kver"
	cp ./arch/arm/boot/dts/exynos5250*.dtb /
fi

cd /

# Make sure qemu-arm can execute transparently ARM binaries.
mount binfmt_misc -t binfmt_misc /proc/sys/fs/binfmt_misc
update-binfmts --enable qemu-arm

# Extract debian!
debootstrap --arch=armhf $release debian_root http://httpredir.debian.org/debian

# Update Apt sources for bullseye
cat <<EOF >debian_root/etc/apt/sources.list
deb http://httpredir.debian.org/debian $release main non-free contrib
deb-src http://httpredir.debian.org/debian $release main non-free contrib
deb https://security.debian.org/debian-security bullseye-security main contrib non-free
EOF

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

# Make sure to get new SSH keys on installation
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
	rm -f /0
	rm -f /hs_err*
	rm -rf /root/.bash_history
	rm -f /usr/bin/qemu*
}

# Prepare third-stage
cat <<"EOF" >debian_root/root/third-stage
#!/bin/bash
set -ex
apt-get update
echo "root:toor" | chpasswd
export DEBIAN_FRONTEND=noninteractive
apt-get -y --no-install-recommends install \
	abootimg cgpt fake-hwclock u-boot-tools vboot-utils vboot-kernel-utils \
	initramfs-tools parted sudo xz-utils wpasupplicant  \
	locales-all ca-certificates initramfs-tools u-boot-tools locales \
	console-common less network-manager git laptop-mode-tools \
	alsa-utils pulseaudio python3 task-ssh-server \
	firmware-realtek firmware-linux firmware-libertas firmware-samsung
apt-get -y dist-upgrade
apt-get -y autoremove
apt-get clean
# Enable ssh key regeneration
systemctl enable regenerate_ssh_host_keys
EOF
run_in_chroot

if [ -z "$kernel_version" ]; then
	cat <<"EOF" >debian_root/root/third-stage
#!/bin/bash
set -ex
apt-get update
echo "root:toor" | chpasswd
export DEBIAN_FRONTEND=noninteractive
apt-get -y --no-install-recommends install linux-image-armmp 
apt-get -y dist-upgrade
apt-get -y autoremove
apt-get clean
EOF
	run_in_chroot
else
	cp ./*.deb debian_root/
	cat <<"EOF" >debian_root/root/third-stage
#!/bin/bash
set -ex
apt-get install /*.deb
apt-get clean
EOF
	run_in_chroot
	rm -f debian_root/*.deb
fi

cat <<"EOF" >debian_root/root/third-stage
#!/bin/bash
set -ex
depmod -a "$(ls /lib/modules)"
EOF
run_in_chroot

# Xorg
mkdir -p debian_root/etc/X11/xorg.conf.d/
cat <<EOF >debian_root/etc/X11/xorg.conf.d/10-synaptics-chromebook.conf
Section "InputClass"
        Identifier          	  "touchpad"
        MatchIsTouchpad     "on"
        Driver                       "synaptics"
        Option                      "TapButton1"    "1"
        Option                      "TapButton2"    "3"
        Option                      "TapButton3"    "2"
        Option                      "FingerLow"     "5"
        Option                      "FingerHigh"    "10"
        Option                      "HorizTwoFingerScroll" "on"
        Option                      "VertTwoFingerScroll" "on"
EndSection
EOF

# Latop-mode
# By default, it goes to powersave that reduces cpu freq to 200 Hz!
sed -i 's/BATT_CPU_GOVERNOR=ondemand/BATT_CPU_GOVERNOR=conservative/' debian_root/etc/laptop-mode/conf.d/cpufreq.conf
sed -i 's/LM_AC_CPU_GOVERNOR=ondemand/LM_AC_CPU_GOVERNOR=performance/' debian_root/etc/laptop-mode/conf.d/cpufreq.conf
sed -i 's/NOLM_AC_CPU_GOVERNOR=ondemand/NOLM_AC_CPU_GOVERNOR=performance/' debian_root/etc/laptop-mode/conf.d/cpufreq.conf

# Create exynos-kernel, /kernel_usb.bin, /kernel_emmc_ext4.bin
cat <<__EOF__ >debian_root/boot/kernel-exynos.its
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
cd debian_root/boot/
cp vmlinuz* zImage

mkdir -p dts
cd dts
if [ -n "${kernel_version}" ]; then
	cp /*.dtb .
else
	wget http://ftp.debian.org/debian/dists/bullseye/main/installer-armhf/current/images/device-tree/exynos5250-snow-rev5.dtb
	wget http://ftp.debian.org/debian/dists/bullseye/main/installer-armhf/current/images/device-tree/exynos5250-snow.dtb
	wget http://ftp.debian.org/debian/dists/bullseye/main/installer-armhf/current/images/device-tree/exynos5250-spring.dtb
fi
cd .. # dts

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
rm -rf ./dts
rm -f zImage cmdline exynos-kernel kernel-exynos.its bootloader.bin
cd ..

cd /debian_root
tar pcJf ../rootfs.tar.xz ./*
(
	cd .. || exit
	mkdir -p xe303c12/
	cp /kernel_usb.bin xe303c12/kernel_usb.bin
	mv /kernel_emmc_ext4.bin xe303c12/kernel_emmc_ext4.bin
	mv rootfs.tar.xz xe303c12/rootfs.tar.xz
	cp ../scripts/install.sh xe303c12/install.sh
	cat <<'EOF' >xe303c12/xfce_install.sh
#!/bin/bash
# Install packages
apt-get update
apt-get dist-upgrade -y
apt-get install -y \
	task-xfce-desktop xserver-xorg-input-synaptics \
	apparmor-profiles-extra gvfs-backends xfce4-indicator-plugin xfce4-mpc-plugin  \
	libglx-mesa0 libgl1-mesa-dri mesa-opencl-icd mesa-va-drivers mesa-vdpau-drivers
apt-get clean
# Wait 1s before starting up the display manager
sed -i -e 's/\[Service\]/\[Service\]\nExecStartPre=\/usr\/bin\/sleep 1/g' /etc/systemd/system/display-manager.service
# Configure audio settings.
amixer cset numid=5,iface=MIXER,name='Headphone Switch' 1
amixer cset numid=1,iface=MIXER,name='Headphone Volume' 50
amixer cset numid=43,iface=MIXER,name='Left Speaker Mixer Left DAC1 Switch' 1
amixer cset numid=52,iface=MIXER,name='Right Speaker Mixer Right DAC1 Switch' 1
amixer cset numid=31,iface=MIXER,name='Left Headphone Mixer Left DAC1 Switch' 1
amixer cset numid=38,iface=MIXER,name='Right Headphone Mixer Right DAC1 Switch' 1
EOF
	chmod +x xe303c12/xfce_install.sh
	zip -r ./xe303c12.zip xe303c12/
	mkdir -p release
	if [ -n "${kernel_version}" ]; then
		mv ./*.deb /release/
	fi
	mv ./xe303c12.zip /release/
	echo "/"
	ls -1 /
	echo "/release"
	ls -1 /release
	echo "Done!"
)
