#!/bin/bash
set -e
apt-get install python3 task-ssh-server
useradd -m -s /bin/bash localadmin || true
passwd localadmin
adduser localadmin sudo || true
sed -i 's/%sudo	ALL=(ALL:ALL) ALL/%sudo	ALL=(ALL:ALL) NOPASSWD:ALL/' /etc/sudoers
echo "ready"
exit
