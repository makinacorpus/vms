# To boot a fancy LXC container with upstart we need some extra stuff:
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
RUN apt-get install -y cron;\
    apt-get install -y dialog;\
    apt-get install -y git-core;\
    apt-get install -y language-pack-en;\
    apt-get install -y language-pack-fr;\
    apt-get install -y locales;\
    apt-get install -y logrotate;\
    apt-get install -y man;\
    apt-get install -y man-db;\
    apt-get install -y manpages;\
    apt-get install -y manpages-de;\
    apt-get install -y manpages-fr;\
    apt-get install -y net-tools;\
    apt-get install -y openssh-server;\
    apt-get install -y python-software-properties;\
    apt-get install -y rsyslog;\
    apt-get install -y screen;\
    apt-get install -y snmpd;\
    apt-get install -y ssh;\
    apt-get install -y sudo;\
    apt-get install -y tmux;\
    apt-get install -y tree;\
    apt-get install -y tzdata;\
    apt-get install -y ubuntu-minimal;\
    apt-get install -y ubuntu-standard;\
    apt-get install -y vim;\
    rm -rf /var/cache/apt/archives/*deb;
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
