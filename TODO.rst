.. contents::
READ THE TODO ON THE MASTER BRANCH

IN PROGRESS
===========
* docker support: **kiorky**

* salt + docker managment **kiorky**

* dev env: **regilero**

  * postfix
  * dev.sls


TODO
====
* Fix /etc/hosts editing to not have the first 127.0.0.1 appended at the end of file but at the init.

* Better route teardown (do not leave a cluttered route table on exist)

* Integrate a state for apt-cahe-ng-and similar

* In devhost, configure the host itself & dockers to use apt-cacher on the host

* make provision less ubuntu specific, and make debian a first class citizen
  (kiorky made progress on that)

* make makina-states less ubuntu specific, and make debian a first class citizen

* integrate a X11 display in dockers using fluxbox and tightvnserver

* integrate Virtualbox Extension pack

  * btw: integrate rdesktop bridge to the host in the vagrantfile

* on salt docker vm, make an upstart script to accelerate the first run start which result
  nowoday with timeouts on master/minion concilliation, and also auto accept the key like with boot-salt.sh

DONE
====
* :24/10/2013: Saucy(ubuntu-current) is master
* :24/10/2013: lucid(ubuntu-current-lts) work again
* :22/10/2013: Reduce the space used on the VM (at least add a call to apt-clean)
* :22/10/2013: Automate a zerofree call on the vm with the manage script
* :22/10/2013: handle correctly dev.sls & core.sls
* :16/10/2013: export / import
* :16/10/2013: Vagrantfile initialisation for ubuntu raring & LTS
* :16/10/2013: Multi Virtualbox with multi networks
* :16/10/2013: Saltack based base system configuration & organisation
* :16/10/2013: Mastersalt base states & integration
* :01/10/2013: saltstack state trees architecture
* :01/10/2013: SaltStack from scratch install script
* :01/10/2013: Vagrant vm provision script
* :01/10/2013: Docker base images for debian & ubuntu (ubuntu! from official docker images or from a debootstrap)
* :01/10/2013: Developpement scripts for debugging lxc & docker from sources with gdb
