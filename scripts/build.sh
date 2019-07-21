#!/bin/bash
set -e

kernel_version=5.2.1
rcn_patch=http://rcn-ee.net/deb/sid-armhf/v5.2.0-armv7-x2/patch-5.2-armv7-x2.diff.gz
patches="0005-net-smsc95xx-Allow-mac-address-to-be-set-as-a-parame.patch"

mkdir -p exynos
cd exynos
export PATH=`pwd`/gcc-linaro-arm-linux/bin:$PATH
export ARCH=arm
export CROSS_COMPILE=arm-linux-gnueabihf-

figlet "CPUs: $(grep -c processor /proc/cpuinfo)"

if [ ! -e  kernel ]; then
    for patch_to_apply in $patches; do
        wget https://raw.githubusercontent.com/archlinuxarm/PKGBUILDs/master/core/linux-armv7/$patch_to_apply
    done
    wget -nv $rcn_patch
    rcn_patch=$(basename $rcn_patch)
    gzip -d $rcn_patch
    wget -nv https://mirrors.edge.kernel.org/pub/linux/kernel/v5.x/linux-$kernel_version.tar.xz
    tar xJf linux-$kernel_version.tar.xz
    rm -f linux-$kernel_version.tar.xz
    cd linux-$kernel_version
    git apply ../${rcn_patch%.*}
    for patch_to_apply in $patches; do
        patch -p1 --no-backup-if-mismatch < ../$patch_to_apply
    done
    cd ..
    rm -f patch-$kernel_version-$rcn_patch.diff
    mv linux-$kernel_version kernel
fi

cp ../configs/$kernel_version kernel/.config
cd kernel
make olddefconfig
make -j $(grep -c processor /proc/cpuinfo)
make dtbs
make modules_install INSTALL_MOD_PATH=`pwd`/../root
cd arch/arm/boot
cat << __EOF__ >kernel-exynos.its
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
    };
};
__EOF__
mkimage -D "-I dts -O dtb -p 2048" -f kernel-exynos.its exynos-kernel
dd if=/dev/zero of=bootloader.bin bs=512 count=1
echo 'noinitrd console=tty0 root=PARTUUID=%U/PARTNROFF=2 rootwait rw rootfstype=ext4' > cmdline
vbutil_kernel --arch arm --pack kernel_usb.bin --keyblock /usr/share/vboot/devkeys/kernel.keyblock \
	--signprivate /usr/share/vboot/devkeys/kernel_data_key.vbprivk --version 1 --config cmdline \
	--bootloader bootloader.bin --vmlinuz exynos-kernel
echo 'noinitrd console=tty0 root=/dev/mmcblk0p3 rootwait rw rootfstype=ext4' > cmdline
vbutil_kernel --arch arm --pack kernel_emmc_ext4.bin --keyblock /usr/share/vboot/devkeys/kernel.keyblock \
	--signprivate /usr/share/vboot/devkeys/kernel_data_key.vbprivk --version 1 --config cmdline \
	--bootloader bootloader.bin --vmlinuz exynos-kernel
cd ../../../..

# This script must run in a container with priviledges!
# Make sure qemu-arm can execute transparently ARM binaries.
mount binfmt_misc -t binfmt_misc /proc/sys/fs/binfmt_misc  
update-binfmts --enable qemu-arm

# Extract debian!
qemu-debootstrap --arch=armhf buster root http://httpredir.debian.org/debian

# Update Apt sources
cat << EOF > root/etc/apt/sources.list
deb http://httpredir.debian.org/debian buster main non-free contrib
deb-src http://httpredir.debian.org/debian buster main non-free contrib
deb http://security.debian.org/debian-security buster/updates main contrib non-free
EOF

# Change hostname
echo "chromebook" > root/etc/hostname

# Add it to the hosts
cat << EOF > root/etc/hosts
127.0.0.1       chromebook    localhost
::1             localhost ip6-localhost ip6-loopback
fe00::0         ip6-localnet
ff00::0         ip6-mcastprefix
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters
EOF

# Add loopback interface
cat << EOF > root/etc/network/interfaces
auto lo
iface lo inet loopback
EOF

# And configure default DNS (google...)
cat << EOF > root/etc/resolv.conf
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF

# Prepare third-stage
cat << EOF > root/root/third-stage
#!/bin/bash
apt-get update
echo "root:toor" | chpasswd
export DEBIAN_FRONTEND=noninteractive
apt-get -y --no-install-recommends install abootimg cgpt fake-hwclock u-boot-tools vboot-utils vboot-kernel-utils \
        initramfs-tools parted sudo xz-utils wpasupplicant firmware-linux firmware-libertas \
	firmware-samsung locales-all ca-certificates initramfs-tools u-boot-tools locales \
	console-common less network-manager git laptop-mode-tools
apt-get -y dist-upgrade
apt-get -y autoremove
apt-get clean
depmod -a $kernel_version
rm -f /0
rm -f /hs_err*
rm -rf /root/.bash_history
rm -f /usr/bin/qemu*
EOF

# Run third-stage
mount -t proc proc root/proc
mount -o bind /dev/ root/dev/
mount -o bind /dev/pts root/dev/pts
chmod +x root/root/third-stage
LANG=C chroot root /root/third-stage
umount root/dev/pts
umount root/dev/
umount root/proc
rm -f root/root/third-stage

# Xorg
mkdir -p root/etc/X11/xorg.conf.d/
cat << EOF > root/etc/X11/xorg.conf.d/10-synaptics-chromebook.conf
Section "InputClass"
        Identifier          "touchpad"
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
cat << EOF > root/etc/udev/rules.d/50-mali.rules
KERNEL=="mali0", MODE="0660", GROUP="video"
EOF

# Video rules aka media-rules package in ChromeOS
cat << EOF > root/etc/udev/rules.d/50-media.rules
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

# Latop-mode
# By default, it goes to powersave that reduces cpu freq to 200 Hz!
sed -i 's/BATT_CPU_GOVERNOR=ondemand/BATT_CPU_GOVERNOR=conservative/' root/etc/laptop-mode/conf.d/cpufreq.conf
sed -i 's/LM_AC_CPU_GOVERNOR=ondemand/LM_AC_CPU_GOVERNOR=performance/' root/etc/laptop-mode/conf.d/cpufreq.conf
sed -i 's/NOLM_AC_CPU_GOVERNOR=ondemand/NOLM_AC_CPU_GOVERNOR=performance/' root/etc/laptop-mode/conf.d/cpufreq.conf

cd root
tar pcJf ../rootfs.tar.xz *
cd ..
mkdir -p xe303c12/
cp kernel/arch/arm/boot/kernel_usb.bin xe303c12/kernel_usb.bin
mv kernel/arch/arm/boot/kernel_emmc_ext4.bin xe303c12/kernel_emmc_ext4.bin
mv rootfs.tar.xz xe303c12/rootfs.tar.xz
cp ../scripts/install.sh xe303c12/install.sh
zip -r ./xe303c12.zip xe303c12/

cd .. # Out of exynos


