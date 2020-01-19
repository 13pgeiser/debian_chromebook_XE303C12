# vim:set ft=dockerfile:
# Debian base.
FROM debian:10.2-slim
MAINTAINER Pascal Geiser <pgeiser@pgeiser.com>

# Install qemu-static
RUN set -ex \
    && apt-get update -q2 \
    && apt-get dist-upgrade -q2 \
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
    && wget -nv https://developer.arm.com/-/media/Files/downloads/gnu-a/9.2-2019.12/binrel/gcc-arm-9.2-2019.12-x86_64-arm-none-linux-gnueabihf.tar.xz \
    && tar xJf gcc-arm-9.2-2019.12-x86_64-arm-none-linux-gnueabihf.tar.xz \
    && rm gcc-arm-9.2-2019.12-x86_64-arm-none-linux-gnueabihf.tar.xz \
    && mv gcc-arm-9.2-2019.12-x86_64-arm-none-linux-gnueabihf gcc-linaro-arm-linux
