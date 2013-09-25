
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
    - screen

Ubuntu
------------

Working images:

    - **makinacorpus/ubuntu**: minimal ubuntu system

    - **makinacorpus/ubuntu_salt**: ubuntu + salt master + salt minion

    - **makinacorpus/ubuntu_mastersalt**: ubuntu + salt master + salt minion + mastersalt minion


Debian
--------
- **Working**
- Working on adapting the base lxc-debian lxc template script to
make a suitable base for docker use



