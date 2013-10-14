
.. contents:: :local:


Vagrant VMs
============
Their use is to facilitate the learning of docker and to mitigate current
installation issues by providing a ready-to-use docker+salt virtualised host.

Master branch of this repository is using an `Ubuntu Raring-64 Vagrantfile VM <https://github.com/makinacorpus/vms/tree/master/Vagrantfile>`_.
Check other branches to find LTS precise versions.

check the Install part on this documentation for installation instructions

As of now, we needed to backport those next-ubuntu stuff (saucy) for things to behave correctly and efficiently:

    - Lxc >= 1.0b
    - Kernel >= 3.11
    - Virtualbox >= 4.2.15

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
- **makinacorpus/ubuntu**: `minimal ubuntu system <https://github.com/makinacorpus/vms/tree/master/docker/ubuntu/ubuntu>`_
- **makinacorpus/ubuntu_salt**: `ubuntu + salt master + salt minion <https://github.com/makinacorpus/vms/tree/master/docker/ubuntu/salt>`_
- **makinacorpus/ubuntu_mastersalt**: `ubuntu + salt master + salt minion + mastersalt minion <https://github.com/makinacorpus/vms/tree/master/docker/ubuntu/mastersalt>`_
- **makinacorpus/ubuntu_deboostrap**: `ubuntu deboostrapped <https://github.com/makinacorpus/vms/tree/master/docker/ubuntu-debootstrap>`_

Debian
--------
- **makinacorpus/debian**: `minimal debian system <https://github.com/makinacorpus/vms/tree/master/docker/debian>`_

Install
=======

Following theses instructions you can install this git repository on a directory of your local host, then start a Virtualbox vm from this directory. this virtualbox VM handled by vagrant will then run the docker VMs. All files used in the VirtualBox VM and in the docker mounts will be editable from your host as this VM will ensure your current user will be member of the right group, shared with the VM, and that all important files used by the vm are shared from your development host via nfs 

Prerequisitements
-----------------

You need to have ``virtualbox``, ``vagrant`` and ``NFS`` (as a server).


For a debian-like host this would be ok with theses commands::

  sudo apt-get install nfs-kernel-server nfs-common portmap virtualbox

For Vagrant you need to have a recent Vagrant version (vagrant is a virtualbox VM manager, to make it simple). But version ``1.3.4`` `is broken <https://github.com/mitchellh/vagrant/issues/2309>`_, so waiting for ``1.3.5`` you should use version ``1.3.3``. Get latest vagrant from `official download site <http://downloads.vagrantup.com/>`_.

For a debian/ubuntu deb-like host, version 1.3.3 64 bits::

  wget http://files.vagrantup.com/packages/db8e7a9c79b23264da129f55cf8569167fc22415/vagrant_1.3.3_x86_64.deb
  sudo dpkg -i vagrant_1.3.3_x86_64.deb

Installation
---------------

Now you can start the vm installation with vagrant. Note that this repository will be the base directory for your projects source code managment::

  # Take a base location on your home
  mkdir -p ~/makina/
  cd ~/makina/
  # get this project in the vms subdirectory of this base place
  git clone https://github.com/makinacorpus/vms.git
  cd vms
  # Optionnaly preload the base image
  vagrant box add raring64 http://cloud-images.ubuntu.com/vagrant/raring/current/raring-server-cloudimg-amd64-vagrant-disk1.box
  # Optionnaly, read the Vagrantfile top section, containing VM cpu and memory settings
  vi Vagrantfile
  # start the VM a first time, this will launch the VM creation and provisioning
  vagrant up
  # you will certainly need one or to reload to finish the provision steps
  vagrant reload

Daily usage
------------

Now that vagrant as created a vistualbox image for you you should always manipulate this virtualbox VM with vagrant.

To launch a Vagrant command always ``cd`` to the VM base directory::

  cd ~/makina/vms

Starting the VM is simple::

  vagrant up

connecting to the VM in ssh with the ``vagrant`` user (sudoer) is::

  vagrant ssh

Stoping the VM can be done like that::

  vagrant halt # classical
  vagrant -f halt # try to enforce it
  vagrant suspend # faster on up, but requires disk space to store current state

Reloading the vm is::

  vagrant reload # with sometimes tiemout problems on stop, redo-it.

To remove an outdated or broken VM::

  vagrant destroy

Note that all the files mounted on the ``/srv`` vm directory are in fact stored on the base directory of this project and will not be removed after a vagrant destroy. so you can easily destroy a VM without loosing really important files. then redo a ``vagrant up`` to rebuild a new VM with all needed dependencies.
