#!/usr/bin/env bash
export SALT_BOOT="vm"
cd /tmp
wget http://raw.github.com/makinacorpus/makina-states/master/_scripts/boot-salt.sh -O /tmp/boot
chmod +x /tmp/boot
/tmp/boot || exit -1
ps aux|grep salt-master|awk '{print $2}'|xargs kill -9
ps aux|grep salt-minion|awk '{print $2}'|xargs kill -9
find /etc/*salt*/pki -type f -delete
rm -rf /var/cache/apt/archives/*deb
sed -re "s/PasswordAuthentication\s.*/PasswordAuthentication yes/g" -i /etc/ssh/sshd_config;
/sbin/lxc-cleanup.sh
# vim:set et sts=4 ts=4 tw=80:
