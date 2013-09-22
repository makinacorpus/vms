# NEED DOCKER >= 0.6.2
from ubuntu:latest
ENV DEBIAN_FRONTEND noninteractive
RUN sed -re \
    "s/ main$/ main restricted universe multiverse/g" \
    -e "s:/archive\.:/fr.archive\.:g" \
    -i /etc/apt/sources.list
RUN apt-get -q update
RUN apt-get upgrade -y
# install each package separatly to mitigate some packages which are half configured
# without having upstart running like sshd
RUN for i in\
        ubuntu-minimal\
        ubuntu-standard\
        dialog\
        cron\
        locales\
        python-software-properties\
        git-core\
        logrotate\
        net-tools\
        man\
        rsyslog\
        openssh-server\
        screen\
        snmpd\
        ssh\
        sudo\
        tree\
        tzdata\
        vim\
        language-pack-en language-pack-fr \
        ;do  apt-get install -y --force-yes $i;done

RUN echo >/etc/locale.gen &&\
    echo "en_US.UTF-8 UTF-8">>/etc/locale.gen &&\
    echo "en_US ISO-8859-1">>/etc/locale.gen &&\
    echo "de_DE.UTF-8 UTF-8">>/etc/locale.gen &&\
    echo "de_DE ISO-8859-1">>/etc/locale.gen &&\
    echo "de_DE@euro ISO-8859-15">>/etc/locale.gen &&\
    echo "fr_FR.UTF-8 UTF-8">>/etc/locale.gen &&\
    echo "fr_FR ISO-8859-1">>/etc/locale.gen &&\
    echo "fr_FR@euro ISO-8859-15">>/etc/locale.gen &&\
    echo 'LANG="fr_FR.utf8"'>/etc/default/locale &&\
    /usr/sbin/locale-gen --purge

# one cli to avoid intermediate commits
# make upstart happy on containers
# mv /sbin/initctl /sbin/initctl.sav &&
#     ln -sf /bin/true /sbin/initctl &&
#     dpkg-divert --local --rename --add /sbin/initctl &&
