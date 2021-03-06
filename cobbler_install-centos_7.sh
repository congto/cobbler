#!/bin/bash
#
# Script to deploy a working cobbler installation in CentOS 7
# Author: Luis Henrique Bolson <luis@luisb.net>
#
# Please run as root (don't use sudo <script>)
#
# curl -s https://raw.githubusercontent.com/luisbolson/cobbler/master/cobbler_install-centos_7.sh | bash -s 192.168.56.102 192.168.56.201 192.168.56.245 > /tmp/cobbler_install.log

# External Variables

# Services IP Address on the server
IP_ADDR=172.16.69.237
# DHCP Server IP Range. First and Last
DHCP_MIN_HOST=172.16.69.30
DHCP_MAX_HOST=172.16.69.39

# Install epel-release
yum install -y epel-release
# Installs cobbler and related packages
yum install -y cobbler cobbler-web dhcp wget perl bzip2 pykickstart fence-agents bc

# As of the writing of this script there was no el7 version for debmirror on epel. Using here el6 version.
yum install -y https://dl.fedoraproject.org/pub/epel/6/x86_64/debmirror-2.14-2.el6.noarch.rpm

# Get network information for the given IP
NETMASK=255.255.255.0
NETDEVICE=eth1
NETPREFIX=24
NETWORK=172.16.69.0

# Change IP and manage_dhcp in cobbler settings
sed -i "s/127\.0\.0\.1/${IP_ADDR}/" /etc/cobbler/settings
sed -i "s/manage_dhcp: .*/manage_dhcp: 1/" /etc/cobbler/settings

# Change DHCP server template to match the given network configuration
sed -i "s/subnet .* netmask .* {/subnet $NETWORK netmask $NETMASK {/" /etc/cobbler/dhcp.template
sed -i "/option routers             172.16.69.1;/d" /etc/cobbler/dhcp.template
sed -i "/option domain-name-servers 8.8.8.8;/d" /etc/cobbler/dhcp.template
sed -i "s/range dynamic-bootp .*/range dynamic-bootp        ${DHCP_MIN_HOST} ${DHCP_MAX_HOST};/" /etc/cobbler/dhcp.template

# Enable tftp service
sed -i "s/disable.*/disable\t\t\t= no/" /etc/xinetd.d/tftp

# Comment out 'dists' on /etc/debmirror.conf for proper debian support
# Comment out 'arches' on /etc/debmirror.conf for proper debian support
sed -i "s/^@dists/#@dists/" /etc/debmirror.conf
sed -i "s/^@arches/#@arches/" /etc/debmirror.conf

# Generate a new django secret key
SECRET_KEY=$(python -c 'import re;from random import choice; import sys; sys.stdout.write(re.escape("".join([choice("abcdefghijklmnopqrstuvwxyz0123456789^&*(-_=+)") for i in range(100)])))')
sed -i "s/^SECRET_KEY = .*/SECRET_KEY = '${SECRET_KEY}'/" /usr/share/cobbler/web/settings.py

# Enable and start services
systemctl enable httpd
systemctl enable cobblerd
systemctl start httpd
systemctl start cobblerd

# Don't go to fast!!!
sleep 5

# Get cobbler loaders and update signature
cobbler get-loaders
cobbler signature update

# Sync cobbler and restart
cobbler sync
systemctl restart httpd
systemctl restart cobblerd
