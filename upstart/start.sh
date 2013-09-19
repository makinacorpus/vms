#!/usr/bin/env bash
/sbin/init-ubuntu&
CORE="rsyslog cron ssh"
SERVICES=""
for i in $CORE $SERVICES;do
    echo "$i start"
    service $i start || service $i restart
done
echo changed
mkdir /var/run/sshd
mount
#/usr/sbin/sshd -dD
#while true;do echo "\o/" done
# vim:set et sts=4 ts=4 tw=80:
