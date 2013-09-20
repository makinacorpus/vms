
Docker VMs
==========
- Contruct base environments to work with docker.
- Whereas the single process, we want to use the system providen by the
  underlying distribution to manage a bunch of things.

Goal is to have in working state:

    - init system
    - cron
    - logrotate
    - sshd
    - sudo
    - syslog
    - ntp
    - snmpd
    - screen

Ubuntu
------------
- **NOGO**
- Tried to make a rootfs similar to what i would have got with lxc-create -t
- ubuntu
Did not managed to get upstart running as docker has its own init script spawnning at pid=1;
- i dont see how to make it start


Debian
--------
- **Working**
- Working on adapting the base lxc-debian lxc template script to
make a suitable base for docker use



