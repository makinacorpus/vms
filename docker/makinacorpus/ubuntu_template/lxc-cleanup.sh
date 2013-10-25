#!/usr/bin/env bash
# disabling fstab
for i in /lib/init/fstab /etc/fstab;do
    echo > $i || /bin/true
done
# redirecting console to docker log
for i in console tty0 tty1 tty2 tty3 tty4 tty5 tty6 tty7;do
    rm -f /dev/$i || /bin/true
    ln -s /dev/tty /dev/$i || /bin/true
done
# pruning old logs & pids
rm -rf /var/run/network/*
for i in /var/run/*.pid /var/run/dbus/pid;do
    if [ -e $i ];then
        rm -f $i || /bin/true
    fi
done
# disabling useless and harmfull services
for f in \
    $(find /etc/init -name resolvconf.conf)\
    $(find /etc/init -name console.conf)\
    $(find /etc/init -name console-setup.conf)\
    $(find /etc/init -name dmesg.conf)\
    $(find /etc/init -name tty[1-9].conf)\
    $(find /etc/init -name plymouth*.conf)\
    $(find /etc/init -name hwclock*.conf)\
    $(find /etc/init -name module*.conf)\
    $(find /etc/init -name udev*.conf)\
    $(find /etc/init -name upstart*.conf)\
    $(find /etc/init -name ureadahead*.conf)\
    $(find /etc/init -name hostname.conf)\
    $(find /etc/init -name control-alt-delete.conf)\
    $(find /etc/init -name networking.conf)\
    $(find /etc/init -name mountall-net.conf )\
    $(find /etc/init -name mountall-reboot.conf)\
    $(find /etc/init -name mountall-shell.conf)\
    $(find /etc/init -name mountall.conf)\
    $(find /etc/init -name setvtrgb.conf)\
    $(find /etc/init -name network-interface-security.conf)\
    $(find /etc/init -name upstart-dbus-bridge.conf)\
    ;do
    echo manual>$(basename $i .conf).override
    mv -f $f $f.orig
done
# disabling useless and harmfull sysctls
for i in \
    vm.mmap_min_addr\
    kernel.yama.ptrace_scope\
    kernel.kptr_restrict\
    kernel.printk;do
        sed -re "s/^($i)/#\1/g" -i \
        /etc/sysctl*/*  /etc/sysctl.conf
done
# vim:set et sts=4 ts=4 tw=80:
