# with the ./lxc-ubuntu script we got a debootstrap with some extra packages
# To boot a fancy LXC container we need some extra stuff:
# - Re configure some packages
# - Disable some services at boot
# - Configure locales
FROM makinacorpus/ubuntu_debootstrap/base
ENV DEBIAN_FRONTEND noninteractive
RUN sed -re \
    "s/ main$/ main restricted universe multiverse/g" \
    -e "s:/archive\.:/fr.archive\.:g" \
    -i /etc/apt/sources.list
RUN apt-get -q update
RUN apt-get upgrade -y
RUN for i in\
        cron\
        dialog\
        git-core\
        language-pack-en
        language-pack-fr\
        locales\
        logrotate\
        man\
	man-db\
	manpages\
	manpages-de\
	manpages-fr\
        net-tools\
        openssh-server\
        python-software-properties\
        rsyslog\
        screen\
        snmpd\
        ssh\
        sudo\
	tmux\
        tree\
        tzdata\
        ubuntu-minimal\
        ubuntu-standard\
	vim\
	,do apt-get install -y $i,done
RUN for i in openssh-server cron logrotate;do dpkg-reconfigure --force $i;done
RUN /usr/sbin/update-rc.d -f ondemand remove
RUN rm -f /etc/init/console.conf
ADD console.conf /etc/init/console.conf
ADD udev-fake.conf /etc/init/udev-fake.conf
RUN for i in /lib/init/fstab /etc/fstab;do echo > $i;done
# Move those service away and make sure even if an upgrade spawn again
# the servvice file to mark it as-no-starting
RUN cd /;\
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
    done
RUN echo>/etc/locale.gen
RUN echo "en_US.UTF-8 UTF-8">>/etc/locale.gen
RUN echo "en_US ISO-8859-1">>/etc/locale.gen
RUN echo "de_DE.UTF-8 UTF-8">>/etc/locale.gen
RUN echo "de_DE ISO-8859-1">>/etc/locale.gen
RUN echo "de_DE@euro ISO-8859-15">>/etc/locale.gen
RUN echo "fr_FR.UTF-8 UTF-8">>/etc/locale.gen
RUN echo "fr_FR ISO-8859-1">>/etc/locale.gen
RUN echo "fr_FR@euro ISO-8859-15">>/etc/locale.gen
RUN echo 'LANG="fr_FR.utf8"'>/etc/default/locale
RUN echo "export LANG=\${LANG:-fr_FR.UTF-8}">>$d/etc/profile.d/0_lang.sh
RUN /usr/sbin/locale-gen
RUN update-locale LANG=fr_FR.utf8
RUN echo "ubuntu:ubuntu" | chpasswd
CMD ["/sbin/init"]
