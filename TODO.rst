.. contents::
READ THE TODO ON THE MASTER BRANCH

IN PROGRESS
===========
* Make saucy the master: **kiorky**

* Make lucid work again: **kiorky**

* docker support: **kiorky**

* salt + docker managment **kiorky**

* dev env: **regilero**

  * postfix
  * dev.sls
    

TODO
====
* Fix /etc/hosts editing to not have the first 127.0.0.1 appended at the end of file but at the init.

* Integrate a state for apt-cahe-ng-and similar

* In devhost, configure the host itself & dockers to use apt-cacher on the host
 
* make makina-states less ubuntu specific, and make debian a first class citizen

* integrate a X11 display in dockers using fluxbox and tightvnserver

* integrate Virtualbox Extension pack

  * btw: integrate rdesktop bridge to the host in the vagrantfile

DONE
====
* Reduce the space used on the VM (at least add a call to apt-clean)
* Automate a zerofree call on the vm with the manage script
* handle correctly dev.sls & core.sls
* export / import
* Vagrantfile initialisation for ubuntu raring & LTS
* Multi Virtualbox with multi networks
* Saltack based base system configuration & organisation
* Mastersalt base states & integration
* saltstack state trees architecture
* SaltStack from scratch install script
* Vagrant vm provision script
* Docker base images for debian & ubuntu (ubuntu! from official docker images or from a debootstrap)
* Developpement scripts for debugging lxc & docker from sources with gdb
