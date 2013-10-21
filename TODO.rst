.. contents::

IN PROGRESS
===========

* docker support: **kiorky**

* salt + docker managment **kiorky**


* export / import: **kiorky**

* dev env: **regilero**

  * postfix
  * dev.sls
    


TODO
====

* Reduce the space used on the VM (at least add a call to apt-clean)

* Automate a zerofree call on the vm with the manage script

* Make saucy the master

* Make lucid work again

* integrate Virtualbox Extension pack

  * btw: integrate rdesktop bridge to the host in the vagrantfile

* integrate a X11 display in dockers using fluxbox and tightvnserver
 

DONE
====

* Vagrantfile initialisation for ubuntu raring & LTS
* Multi Virtualbox with multi networks
* Saltack based base system configuration & organisation
* Mastersalt base states & integration
* saltstack state trees architecture
* SaltStack from scratch install script
* Vagrant vm provision script
* Docker base images for debian & ubuntu (ubuntu! from official docker images or from a debootstrap)
* Developpement scripts for debugging lxc & docker from sources with gdb
