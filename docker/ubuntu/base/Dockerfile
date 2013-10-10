# add package to base ubuntu image
FROM ubuntu:latest
ENV DEBIAN_FRONTEND noninteractive
# mitigate half configured packages by installing them separatly
RUN sed -re \
    "s/ main$/ main restricted universe multiverse/g" \
    -e "s:/archive\.:/fr.archive\.:g" \
    -i /etc/apt/sources.list && apt-get -q update && apt-get upgrade -y
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
CMD ["/sbin/init"]
