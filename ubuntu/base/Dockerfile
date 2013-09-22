# add package to base ubuntu image
FROM ubuntu:latest
ENV DEBIAN_FRONTEND noninteractive
RUN sed -re \
    "s/ main$/ main restricted universe multiverse/g" \
    -e "s:/archive\.:/fr.archive\.:g" \
    -i /etc/apt/sources.list && apt-get -q update && apt-get upgrade -y
# mitifate half configured packages by installing them separatly
RUN apt-get upgrade -y
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
CMD ["/sbin/init"]
