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

# Download compiler
RUN set -ex \
    && mkdir -p exynos \
    && cd exynos \
    && wget -nv https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu-a/8.2-2018.08/gcc-arm-8.2-2018.08-x86_64-arm-linux-gnueabihf.tar.xz \
    && tar xJf gcc-arm-8.2-2018.08-x86_64-arm-linux-gnueabihf.tar.xz \
    && rm gcc-arm-8.2-2018.08-x86_64-arm-linux-gnueabihf.tar.xz \
    && mv gcc-arm-8.2-2018.08-x86_64-arm-linux-gnueabihf gcc-linaro-arm-linux
