# (ubuntu+corepkg)
from makinacorpus/base
# do the same thing as the lxc-ubuntu template
#ADD lxc-init.sh /lxc-init.sh
#run /lxc-init.sh
#run cd /tmp && mkdir up && cd up && \
#    apt-get -yd install --reinstall upstart \
#    && dpkg-deb -x /var/cache/apt/archives/up*deb .;ls;cp sbin/init /init-ubuntu
run cp /sbin/init /sbin/init-upstart
ADD lxc-init.sh  /lxc-init.sh
ADD start.sh /start.sh
run chmod +x /start.sh /lxc-init.sh
run /lxc-init.sh
run chmod +x start.sh
cmd ["/start.sh"]
EXPOSE  4022:22
