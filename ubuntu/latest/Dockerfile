# base vm with core packages and ssh in place to
# be finished to install via salt
from makinacorpus/ubuntu/base
# do the same thing as the lxc-ubuntu template
ADD lxc-init.sh /lxc-init.sh
run chmod +x /lxc-init.sh && /lxc-init.sh
# workaround as the installed ssh server failed to create the dir during
# the first ru without upstart
run mkdir /var/run/sshd && chmod 700 /var/run/sshd
cmd ["/sbin/init"]
# special init script which reinstall ssh server with upstart in place
ADD ssh.conf /etc/init/ssh.conf
USER root
