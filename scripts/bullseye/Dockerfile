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
	ca-certificates \
	u-boot-tools \
        device-tree-compiler \
	vboot-kernel-utils \
	figlet \
	wget \
	zip \
        xz-utils \
    && apt-get clean \
    && rm -rf /var/cache/apt/archives/* /var/lib/apt/lists/*


