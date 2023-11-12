# vim:set ft=dockerfile:
# Debian base.
FROM debian:bullseye-slim
MAINTAINER Pascal Geiser <pgeiser@pgeiser.com>

RUN echo 'deb-src http://deb.debian.org/debian bullseye main' >> /etc/apt/sources.list

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
    && apt-get build-dep -y \
	linux-source-5.10 \
    && apt-get install -y \
	linux-source-5.10 \
	crossbuild-essential-armhf \
    && apt-get clean \
    && rm -rf /var/cache/apt/archives/* /var/lib/apt/lists/*




