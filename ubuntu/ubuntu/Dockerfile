# with the ./lxc-ubuntu script we got a debootstrap with some extra packages
# To boot a fancy LXC container we need some extra stuff:
# - Re configure some packages
# - Disable some services at boot
# - Configure locales
FROM ubuntu:latest
ENV DEBIAN_FRONTEND noninteractive
RUN sed -re \
    "s/ main$/ main restricted universe multiverse/g" \
    -e "s:/archive\.:/fr.archive\.:g" \
    -i /etc/apt/sources.list && apt-get -q update && apt-get upgrade -y
# mitigate half configured packages by installing them separatly
RUN apt-get install -y cron
RUN apt-get install -y dialog
RUN apt-get install -y git-core
RUN apt-get install -y language-pack-en
RUN apt-get install -y language-pack-fr
RUN apt-get install -y locales
RUN apt-get install -y logrotate
RUN apt-get install -y man
RUN apt-get install -y man-db
RUN apt-get install -y manpages
RUN apt-get install -y manpages-de
RUN apt-get install -y manpages-fr
RUN apt-get install -y net-tools
RUN apt-get install -y openssh-server
RUN apt-get install -y python-software-properties
RUN apt-get install -y rsyslog
RUN apt-get install -y screen
RUN apt-get install -y snmpd
RUN apt-get install -y ssh
RUN apt-get install -y sudo
RUN apt-get install -y tmux
RUN apt-get install -y tree
RUN apt-get install -y tzdata
RUN apt-get install -y ubuntu-minimal
RUN apt-get install -y ubuntu-standard
RUN apt-get install -y vim
# Move those service away and make sure even if an upgrade spawn again
# the servvice file to mark it as-no-starting
RUN cd /;\
    for i in openssh-server cron logrotate;do dpkg-reconfigure --force $i;done;\
    for i in /lib/init/fstab /etc/fstab;do echo > $i;done;\
    rm -f /etc/init/console.conf;\
    /usr/sbin/update-rc.d -f ondemand remove;\
    for f in \
    $(find /etc/init -name console-setup.conf)\
    $(find /etc/init -name tty[2-9].conf)\
    $(find /etc/init -name plymouth*.conf)\
    $(find /etc/init -name hwclock*.conf)\
    $(find /etc/init -name module*.conf)\
    $(find /etc/init -name udev*.conf)\
    $(find /etc/init -name upstart*.conf)\
    $(find /etc/init -name ureadahead*.conf)\
    ;do \
        echo manual>$(basename $i .conf).override;\
        mv -f $f $f.orig;\
    done;\
    echo "ubuntu:ubuntu" | chpasswd;\
    echo>/etc/locale.gen;\
    echo "en_US.UTF-8 UTF-8">>/etc/locale.gen;\
    echo "en_US ISO-8859-1">>/etc/locale.gen;\
    echo "de_DE.UTF-8 UTF-8">>/etc/locale.gen;\
    echo "de_DE ISO-8859-1">>/etc/locale.gen;\
    echo "de_DE@euro ISO-8859-15">>/etc/locale.gen;\
    echo "fr_FR.UTF-8 UTF-8">>/etc/locale.gen;\
    echo "fr_FR ISO-8859-1">>/etc/locale.gen;\
    echo "fr_FR@euro ISO-8859-15">>/etc/locale.gen;\
    echo 'LANG="fr_FR.utf8"'>/etc/default/locale;\
    echo "export LANG=\${LANG:-fr_FR.UTF-8}">>$d/etc/profile.d/0_lang.sh;\
    /usr/sbin/locale-gen;\
    update-locale LANG=fr_FR.utf8;
ADD console.conf /etc/init/console.conf
ADD udev-fake.conf /etc/init/udev-fake.conf
CMD ["/sbin/init"]
