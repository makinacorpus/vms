
.. contents:: :local:


Vagrant VMs
============
Their use is to facilitate the learning of docker and to mitigate current
installation issues by providing a ready-to-use docker+salt virtualised host.

Master branch of this repository is using an `Ubuntu Raring-64 Vagrantfile VM <https://github.com/makinacorpus/vms/tree/master/Vagrantfile>`_.
Check other branches to find LTS precise versions.

check the Install part on this documentation for installation instructions

Notes for specific ubuntu release packages:
Precise (LTS)
--------------
- Recent Virtualbox
- Linux hardware enablement stack kernel (3.8)

Raring
-------
As of now, we needed to backport those next-ubuntu stuff (saucy) for things to behave correctly and efficiently:

    - Lxc >= 1.0b
    - Kernel >= 3.11
    - Virtualbox >= 4.2.16

Saucy
---------
Mainline packages


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

For Vagrant you need to have a recent Vagrant version (vagrant is a virtualbox VM manager, to make it simple). But version ``1.3.4`` `is broken <https://github.com/mitchellh/vagrant/issues/2309>`_, so use ``1.3.3`` or ``1.3.5`` or greater. Get latest vagrant from `official download site <http://downloads.vagrantup.com/>`_, where you can find msi, dmg, rpm and deb packages.

For a debian/ubuntu deb-like host, version 1.3.5 64 bits::

  wget http://files.vagrantup.com/packages/a40522f5fabccb9ddabad03d836e120ff5d14093/vagrant_1.3.5_x86_64.deb
  sudo dpkg -i vagrant_1.3.5_x86_64.deb


Installation
---------------

Now you can start the vm installation with vagrant. Note that this repository will be the base directory for your projects source code managment::

  # Take a base location on your home
  mkdir -p ~/makina/
  cd ~/makina/
  # get this project in the vms subdirectory of this base place
  git clone https://github.com/makinacorpus/vms.git
  cd vms
  # Alternatively if you want the precise64 LTS ubuntu server use:
  git clone https://github.com/makinacorpus/vms.git -b vagrant-ubuntu-lts-precise64 vms-precise
  cd vms-precise
  # Optionnaly preload the base image
  vagrant box add raring64 http://cloud-images.ubuntu.com/vagrant/raring/current/raring-server-cloudimg-amd64-vagrant-disk1.box
  # Optionnaly, read the Vagrantfile top section, containing VM cpu and memory settings
  vi Vagrantfile
  # start the VM a first time, this will launch the VM creation and provisioning
  ./manage.sh
  # you will certainly need one or to reload to finish the provision steps (normally the first time, the script do it for you)
  vagrant reload

Daily usage
------------

Now that vagrant as created a virtualbox image for you, you should always manipulate this virtualbox VM with ``vagrant`` command.

To launch a Vagrant command always ``cd`` to the VM base directory::

  cd ~/makina/vms

Starting the VM is simple::

  ./manage.sh up

connecting to the VM in ssh with the ``vagrant`` user (sudoer) is::

  ./manage.sh down

Stoping the VM can be done like that::

  ./manage.sh down # classical
  ./manage.sh suspend # faster on up, but requires disk space to store current state

Reloading the vm is::

  ./manage.sh reload # with sometimes tiemout problems on stop, redo-it.

To remove an outdated or broken VM::

  ./manage.sh destroy

To export in **package.tar.bz2**, to share this development host with someone::

  ./manage.sh export

To  import from a **package.tar.bz2** file, simply place the package in the working
directory and issue::

  ./manage.sh import

Note that all the files mounted on the ``/srv`` vm directory are in fact stored on the base directory of this project and will not be removed after a vagrant destroy. so you can easily destroy a VM without loosing really important files. Then redo a ``vagrant up`` to rebuild a new VM with all needed dependencies.

Manage several Virtualboxes
----------------------------

The default install cloned the git repository in ~makina/vms.
By cloning this same git repository on another place you can manage another vagrant based virtualbox vm.
So for example in a vm2 diectory::

  mkdir -p ~/makina/
  cd ~/makina/
  # get this project in the vms subdirectory of this base place
  git clone https://github.com/makinacorpus/vms.git vm2
  cd vm2

You must read at least once the Vagrantfile, it will be easier for you to know how to alter MAX_CPU_USAGE_PERCENT,CPUS & MEMORY settings for example. or more useful, change this second vm IP and Subnet.

You will indeed realise that there is a magic DEVHOST_NUM setting which is by default 42 (so it's 42 for your first VM and we need a new number).

You can then this settings, along with the other settings in **vagrant_config.rb** .
By default this file is not yet created and will be created on first usage. But we can enforce it right before the first ``vagrant up``::

    cat  > vagrant_config.rb << EOF
    module MyConfig
      DEVHOST_NUM="22"
    end
    EOF

This way the second vagrant VM is now using IP: **10.1.22.43** instead of **10.1.42.43** for the private network
and the docker network on this host will be **172.31.22.0** and not **172.31.42.0**.
The box hostname will be **devhost22.local** instead of devhost42.local.


