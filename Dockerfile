# vim:set ft=dockerfile:
# Debian base.
FROM debian:9.7-slim
MAINTAINER Pascal Geiser <pgeiser@pgeiser.com>

# Install qemu-static
RUN set -ex \
    && apt-get update -q2 \
    && apt-get install -q2 -y --no-install-recommends \
	qemu-user-static \
	debootstrap \
	binfmt-support \
	build-essential \
	git \
	ca-certificates \
	u-boot-tools \
	device-tree-compiler \
	vboot-kernel-utils \
	xz-utils \
	zip \
	gzip \
	bison \
	flex \
	bc \
	libssl-dev \
	kmod \
	ncurses-dev \
	figlet \
    && apt-get clean \
    && rm -rf /var/cache/apt/archives/* /var/lib/apt/lists/*

# Install i386 required libraries (for Linaro gcc...)
RUN set -ex \
    && dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get install -q2 -y --no-install-recommends \
	libc6:i386 \
	libstdc++6:i386 \
	libz1:i386 \
    && apt-get clean \
    && rm -rf /var/cache/apt/archives/* /var/lib/apt/lists/*

# Download compiler
RUN set -ex \
    && mkdir -p exynos \
	&& cd exynos \
    && wget -nv https://releases.linaro.org/archive/12.12/components/toolchain/binaries/gcc-linaro-arm-linux-gnueabihf-4.7-2012.12-20121214_linux.tar.bz2 \
    && tar xjf gcc-linaro-arm-linux-gnueabihf-4.7-2012.12-20121214_linux.tar.bz2 \
    && rm gcc-linaro-arm-linux-gnueabihf-4.7-2012.12-20121214_linux.tar.bz2 \
    && mv gcc-linaro-arm-linux-gnueabihf-4.7-2012.12-20121214_linux gcc-linaro-arm-linux
