#!/usr/bin/env bash
export SALT_BOOT="vm"
cd /tmp
wget http://raw.github.com/makinacorpus/makina-states/master/_scripts/boot-salt.sh -O - | bash
ps aux|grep salt-master|awk '{print $2}'|xargs kill -9
ps aux|grep salt-minion|awk '{print $2}'|xargs kill -9
find /etc/*salt*/pki -type f -delete
rm -rf /var/cache/apt/archives/*deb
# vim:set et sts=4 ts=4 tw=80:
