# vim:set ft=dockerfile:
# Debian base.
FROM debian:buster
MAINTAINER Pascal Geiser <pgeiser@pgeiser.com>

# Install base deps
RUN set -ex \
    && apt-get update \
    && apt-get dist-upgrade -y \
    && apt-get install -y --no-install-recommends \
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
	fakeroot \
	kernel-wedge \
	quilt \
	dh-exec \
	rsync \
	python3 \
	cpio \
    && apt-get clean \
    && rm -rf /var/cache/apt/archives/* /var/lib/apt/lists/*

RUN echo 'deb-src http://deb.debian.org/debian buster main' >> /etc/apt/sources.list
RUN echo 'deb http://deb.debian.org/debian buster-backports main' >> /etc/apt/sources.list
RUN echo 'deb-src http://deb.debian.org/debian buster-backports main' >> /etc/apt/sources.list

RUN set -ex \
    && apt-get update \
    && apt-get install -y gcc-multilib \
    && apt-get install -y linux-source-4.19 \
    && apt-get -t buster-backports build-dep -y linux-source-5.10 \
    && apt-get -t buster-backports install -y linux-source-5.10 \
    && apt-get clean \
    && rm -rf /var/cache/apt/archives/* /var/lib/apt/lists/*

RUN set -ex \
    && apt-get update \
    && apt-get install -y crossbuild-essential-armhf \
    && apt-get clean \
    && rm -rf /var/cache/apt/archives/* /var/lib/apt/lists/*

