#!/usr/bin/env bash
# freeze hostile packages
FROZEN_PACKAGES="udev whoopsie ntp resolvconf fuse grub-common grub-pc grub-pc-bin grub2-common"
for i in $FROZEN;do
    echo $i hold | dpkg --set-selections || /bin/true
done

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
rm -rf /var/run/network/* || /bin/true
for i in /var/run/*.pid /var/run/dbus/pid /etc/nologin;do
    if [ -e $i ];then
        rm -f $i || /bin/true
    fi
done
# no apparmor in container
update-rc.d -f apparmor remove || /bin/true
# disabling useless and harmfull services
for f in \
    $(find /etc/init -name acpid.conf)\
    $(find /etc/init -name cloud-init.conf)\
    $(find /etc/init -name cloud-init-container.conf)\
    $(find /etc/init -name cloud-init-local.conf)\
    $(find /etc/init -name cloud-init-nonet.conf)\
    $(find /etc/init -name apport.conf)\
    $(find /etc/init -name console.conf)\
    $(find /etc/init -name console-setup.conf)\
    $(find /etc/init -name control-alt-delete.conf)\
    $(find /etc/init -name cryptdisks-enable.conf)\
    $(find /etc/init -name cryptdisks-udev.conf)\
    $(find /etc/init -name dmesg.conf)\
    $(find /etc/init -name failsafe.conf)\
    $(find /etc/init -name hostname.conf)\
    $(find /etc/init -name hwclock*.conf)\
    $(find /etc/init -name module*.conf)\
    $(find /etc/init -name mountall-net.conf )\
    $(find /etc/init -name mountall-reboot.conf)\
    $(find /etc/init -name mountall-shell.conf)\
    $(find /etc/init -name networking.conf)\
    $(find /etc/init -name network-interface-security.conf)\
    $(find /etc/init -name plymouth*.conf)\
    $(find /etc/init -name resolvconf.conf)\
    $(find /etc/init -name setvtrgb.conf)\
    $(find /etc/init -name tty[1-9].conf)\
    $(find /etc/init -name udev*.conf)\
    $(find /etc/init -name upstart*.conf)\
    $(find /etc/init -name upstart-dbus-bridge.conf)\
    $(find /etc/init -name ureadahead*.conf)\
    ;do
    echo manual>"/etc/init/$(basename $f .conf).override"
    mv -f "$f" "$f.orig"
done
# disabling useless and harmfull sysctls
for i in \
    vm.mmap_min_addr\
    fs.protected_hardlinks\
    fs.protected_symlinks\
    kernel.yama.ptrace_scope\
    kernel.kptr_restrict\
    kernel.printk;do
        sed -re "s/^($i)/#\1/g" -i \
        /etc/sysctl*/*  /etc/sysctl.conf || /bin/true
done
en=/etc/network
if [[ -f $en/if-up.d/000resolvconf ]];then
    mv -f $en/if-up.d/000resolvconf $en/if-up.d_000resolvconf.bak || /bin/true
fi
if [[ -f $en/if-down.d/resolvconf ]];then
    mv -f $en/if-down.d/resolvconf $en/if-down.d_resolvconf.bak || /bin/true
fi
sed -re "s/^(session.*\spam_loginuid\.so.*)/#\\1/g" -i /etc/pam.d/* || /bin/true
exit 0
# vim:set et sts=4 ts=4 tw=80:
