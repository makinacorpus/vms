# To boot a fancy LXC container with upstart we need some extra stuff:
# - Re configure some packages
# - Disable some services at boot
# - Configure locales
FROM ubuntu:latest
ENV DEBIAN_FRONTEND noninteractive
RUN dpkg-divert --add --rename --divert /etc/init/console.conf.ubuntu /etc/init/console.conf &&\
    dpkg-divert --add --rename --divert /etc/init/udev-fake.conf.ubuntu /etc/init/udev-fake.conf
ADD console.conf /etc/init/console.conf
ADD udev-fake.conf /etc/init/udev-fake.conf
#
# We use a postinst script to be runned in PRIVILEGIED MODE
# to finish the installation
# 
ADD postinst.sh /tmp/postinst.sh
CMD ["/sbin/init"]
