from ubuntu
# make upstart happy on containers
#run if [ ! -f /sbin/initctl.sav];then if [ -f rm /sbin/initctl ];then mv /sbin/initctl /sbin/initctl.sav;fi;fi
#run dpkg-divert --local --rename --add /sbin/initctl
#run ln -s /bin/true /sbin/initctl
ENV DEBIAN_FRONTEND noninteractive
run sed -re "s/ main$/ main restricted universe multiverse/g" -i /etc/apt/sources.list
run apt-get update
run apt-get install -y cron
run apt-get install -y locales
run apt-get install -y logrotate
run apt-get install -y man
run apt-get install -y rsyslog
run apt-get install -y screen
run apt-get install -y snmpd
run apt-get install -y ssh
run apt-get install -y sudo
run apt-get install -y tree
run apt-get install -y tzdata
run apt-get install -y vim
