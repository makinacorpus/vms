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

* timeout: 120

* Fix /etc/hosts editing to not have the first 127.0.0.1 appended at the end of file but at the init.

* Better route teardown (do not leave a cluttered route table on exist)

* Integrate a state for apt-cahe-ng-and similar

* In devhost, configure the host itself & dockers to use apt-cacher on the host

* make provision less ubuntu specific, and make debian a first class citizen
  (kiorky made progress on that)
* integrate a X11 display in dockers using fluxbox and tightvnserver
* integrate Virtualbox Extension pack

DONE
====
* **00/12/2013**: killer chef/puppet on start
* **00/12/2013**: saltmaster: dev: workerthread1 -> local.conf dans master.d
* **00/12/2013**: yaml_utf8: true
* **00/12/2013**: salt: automatic configuration
* **00/12/2013**: vagrant+salt: begin to move the vagrant provision into makina-states.
* **00/12/2013**: vagrant: integrate jumbo frames for NFS
* **00/12/2013**: vagrant: debug slowness and integrate jumbo frames
* **00/12/2013**: docker: bugreporting
* **00/12/2013**: salt: bootstrap

    * refactor
    * robustness fixes
    * initial keys handshake negocation & retries

* **00/12/2013**: salt: Reorganise & improve states:

    * services: mysql, php, apache, lxc, docker, ssh, ntp, nscd, saltcore,
      shorewall, tomcat7, solr4, postfix dovecot
    * localsettings: git, ssh, jdk, dotdeb, sudo, users
    * servers: dockercontainer, lxccontainer, devhost, mastersalt_minion,
      mastersalt_mastern salt_minion, salt_master, server, vm, devhost
      vagrant vm
    * localsettings: git, ssh, jdk, dotdeb, sudo, users

* **00/12/2013**: all: port to debian
* **00/12/2013**: vagrant: vm debian
* **00/11/2013**: salt-project: WIP on project layouts & examples, ckan example
* **00/11/2013**: salt-project: WIP on ckan example
* **24/10/2013**: Saucy(ubuntu-current) is master
* **24/10/2013**: lucid(ubuntu-current-lts) work again
* **22/10/2013**: Reduce the space used on the VM (at least add a call to apt-clean)
* **22/10/2013**: Automate a zerofree call on the vm with the manage script
* **22/10/2013**: handle correctly dev.sls & core.sls
* **16/10/2013**: export / import
* **16/10/2013**: Vagrantfile initialisation for ubuntu raring & LTS
* **16/10/2013**: Multi Virtualbox with multi networks
* **16/10/2013**: Saltack based base system configuration & organisation
* **16/10/2013**: Mastersalt base states & integration
* **01/10/2013**: saltstack state trees architecture
* **01/10/2013**: SaltStack from scratch install script
* **01/10/2013**: Vagrant vm provision script
* **01/10/2013**: Docker base images for debian & ubuntu (ubuntu! from official docker images or from a debootstrap)
* **01/10/2013**: Developpement scripts for debugging lxc & docker from sources with gdb
