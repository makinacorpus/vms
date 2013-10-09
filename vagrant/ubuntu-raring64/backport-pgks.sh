#!/usr/bin/env bash
#
# BACPORT Virtualbox, and kernel Packages from next ubuntu
#
. /etc/lsb-release
UBUNTU_NEXT_RELEASE="saucy"
KERNEL_PKGS="linux-source linux-image-generic linux-headers-generic linux-image-extra-virtual"
LXC_PKGS=" lxc apparmor apparmor-profiles"
VB_PKGS="virtualbox virtualbox-dkms virtualbox-source virtualbox-guest-additions-iso virtualbox-qt"
# XXX: too much backports here
#VB_PKGS="$VB_PKGS virtualbox-guest-dkms virtualbox-guest-source"
UBUNTU_RELEASE="$DISTRIB_CODENAME"
CHRONO="\\$(date "+%F_%H-%M-%S")"
output() {
    echo "$@" >&2
}
die_if_error() {
    if [[ "$?" != "0" ]];then
        output "There were errors"
        sed -re "s/${UBUNTU_NEXT_RELEASE}/${UBUNTU_RELEASE}/g" -i /etc/apt/sources.list
        apt-get update -qq
        exit 1
    fi
}
cp /etc/apt/sources.list /etc/apt/sources.list.$CHRONO.sav

output " [*] Backporting Saucy Virtualbox packages"
sed -re "s/(precise|${UBUNTU_RELEASE})/${UBUNTU_NEXT_RELEASE}/g" -i /etc/apt/sources.list
apt-get update -qq

output " [*] Backporting Saucy kernel ($KERNEL_PKGS)"
apt-get install -y --force-yes $KERNEL_PKGS
die_if_error

output " [*] Backporting Saucy kernel ($LXC_PKGS)"
apt-get install -y --force-yes $LXC_PKGS
die_if_error

output " [*] Installing: $VB_PKGS"
apt-get install -y --force-yes $VB_PKGS
die_if_error

sed -re "s/${UBUNTU_NEXT_RELEASE}/${UBUNTU_RELEASE}/g" -i /etc/apt/sources.list
apt-get update -qq
die_if_error
output " [*] You need now to reboot"
# vim:set et sts=4 ts=4 tw=80:
