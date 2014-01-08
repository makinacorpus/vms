.. contents:: :local:

Summary
=======

This git project contains vagrant virtualbox's Vagrantfile to help you work in development with Ubuntu Server + salt-stack + docker. It also contains some Docker images.

Development VM
==============

This schema should help you visualize interactions between the VM and the development host

.. image:: https://raw.github.com/makinacorpus/vms/master/vagrant/schema.png

Organization
-------------
Vagrant boxes
++++++++++++++
For vagrant images, we provide on specific branch those boxes:

- **master**: Ubuntu saucy / 64 bits Ubuntu
- **vagrant-ubuntu-1304-raring64**: Ubuntu raring / 64 bits
- **vagrant-ubuntu-lts-precise64**: Ubuntu raring / 64 bits
- **vagrant-debian-7-wheezy64**: Vagrant box for Debian wheezy 7.2 / 64 bits

Docker images
++++++++++++++++
For docker, we use a docker subfolder with the appropriate stuff to build the base docker images insides.

Ubuntu
~~~~~~
**WARNING** You need to comment out all the /etc/apparmor.d/usr.bin.ntpd profile and do **sudo invoke-rc.d apparmor reload**

- **makinacorpus/ubuntu**: `minimal ubuntu system <https://github.com/makinacorpus/vms/tree/master/docker/ubuntu/ubuntu>`_
- **makinacorpus/ubuntu_salt**: `ubuntu + salt master + salt minion <https://github.com/makinacorpus/vms/tree/master/docker/ubuntu/salt>`_
- **makinacorpus/ubuntu_mastersalt**: `ubuntu + salt master + salt minion + mastersalt minion <https://github.com/makinacorpus/vms/tree/master/docker/ubuntu/mastersalt>`_
- **makinacorpus/ubuntu_deboostrap**: `ubuntu deboostrapped <https://github.com/makinacorpus/vms/tree/master/docker/ubuntu-debootstrap>`_

Debian
~~~~~~~
- **makinacorpus/debian**: `minimal debian system <https://github.com/makinacorpus/vms/tree/master/docker/debian>`_

Packer images
+++++++++++++

Debian
~~~~~~

- **debian-7.2.0-amd64**: base vagrant box for the official makinacorpus/vms debian based vagrant box

Install Development VM
=======================
Following theses instructions you can install this git repository on a directory of your local host, then start a Virtualbox vm from this directory. this virtualbox VM handled by vagrant will then run the docker VMs. All files used in the VirtualBox VM and in the docker mounts will be editable from your host as this VM will ensure your current user will be member of the right group, shared with the VM, and that all important files used by the vm are shared from your development host via nfs

Prerequisites
-------------
You need to have ``virtualbox``, ``vagrant``, ``sshfs`` and ``NFS`` (as a server).

On macosx, sshfs is also known as MacFuse or MacFusion.

By default file transferts between host and guest is **really, really slow**.
We have improved performances by some techniques:

    * Increasing the **MTU to 9000** (jumbo frames) on host and guest Ethernet nics
    * Leaving most of files on the guest side, leaving up to you to access the files
      on the guest. We recommend and also  integrate this access to be via sshfs.

sshfs documentation
++++++++++++++++++++
Linux / *BSD
~~~~~~~~~~~~~~
- Install your sshfs distribution package (surely **sshfs**).
- Relog into a new session or reboot

MacOSX
~~~~~~
- Install `macfusion <http://macfusionapp.org>`_
- Relog into a new session or reboot

Vagrant
+++++++
You could make you a supersudoer without password to avoid sudo questions when lauching the VMs (not required)::

    # visudo
    # Allow members of group sudo to execute any command
    %sudo   ALL=(ALL:ALL) NOPASSWD:ALL

For a Debian / Ubuntu deb-like host, version 1.3.5 64 bits::

    wget http://files.vagrantup.com/packages/a40522f5fabccb9ddabad03d836e120ff5d14093/vagrant_1.3.5_x86_64.deb
    sudo dpkg -i vagrant_1.3.5_x86_64.deb

Optimizations (optional but recommended)
++++++++++++++++++++++++++++++++++++++++

NFS Optmimisations
~~~~~~~~~~~~~~~~~~~
* The important thing here is to tuneup the number of avalaible workers for nfs
  server operations.

    * NOTE: [RECOMMENDED] **256** threads == **~512MO** ram allocated for nfs

    * NOTE: **128** threads == **~302MO** ram allocated for nfs

    * **512** is a lot faster but the virtualbox ethernet interfaces had some bugs
      (kernel guest oops) at this speed.

* On Debian / Ubuntu:

    * Install nfs::

        sudo apt-get install nfs-kernel-server nfs-common portmap virtualbox

    * Edit  **/etc/default/nfs-kernel-server** and increase the **RPCNFSDCOUNT**
      variable to 256.

    * Restart the server::

        sudo /etc/init.d/nfs-kernel-server restart

* On Archlinux:

    * Edit  **/etc/conf.d/nfs-server.conf** and increase the **NFSD_COUNT**
      variable to 256.

    * Enable at boot / Restart the services::

        modprobe nfs # may return an error if already loaded
        for i in rpc-idmapd.service and rpc-mountd.service nfsd.service;do
            systemctl enable $i
            service $i start
        done

* On MacOSX:

    * Edit  **/etc/nfs.conf** and increase the **nfs.server.nfsd_threads**
      variable to 512 or 256.
    * Select, active & restart the NFS service in server admin

For Vagrant you need to have a recent Vagrant version (vagrant is a virtualbox VM manager, to make it simple). But version ``1.3.4`` `is broken <https://github.com/mitchellh/vagrant/issues/2309>`_, so use ``1.3.3`` or ``1.3.5`` or greater. Get latest vagrant from `official download site <http://downloads.vagrantup.com/>`_, where you can find msi, dmg, rpm and deb packages.

Host kernel optimisations
~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Take care with this part, it can prevent your system from booting.

We need to speed up things to:

    * Tuning the nfs & kernel options on the host
    * **Increasing** the nfs worker **threads**
    * Using **NFS** as sharing filesystem

* On MacOSX, edit **/etc/sysctl.conf**

    * add or edit a line::

        kern.aiomax=2048
        kern.aioprocmax=512
        kern.aiothreads=128

    * Reload the settings::

        sysctl -p

* On linux, edit **/etc/sysctl.conf**

    * add or edit a line::

        fs.aio-max-nr = 1048576
        fs.file-max = 6815744

    * Reload the settings::

        sysctl -p


Installation
------------

Now you can start the vm installation with vagrant. Note that this repository will be the base directory for your projects source code managment::

  # Take a base location on your home
  mkdir -p ~/makina/
  cd ~/makina/
  # get this project in the vms subdirectory of this base place
  # note that you can alter the last name to choose another
  # directory
  git clone https://github.com/makinacorpus/vms.git vms
  cd vms
  # Alternatively if you want the precise64 LTS ubuntu server use:
  git clone https://github.com/makinacorpus/vms.git -b vagrant-ubuntu-lts-precise64 vms-precise
  cd vms-precise
  # Or for Debian (see that the last word is free, it's the destination directory):
  git clone https://github.com/makinacorpus/vms.git -b vagrant-debian-7-wheezy64 vmfoo
  cd vmfoo
  # Optionnaly preload the base image
  vagrant box add saucy64 http://cloud-images.ubuntu.com/vagrant/saucy/current/saucy-server-cloudimg-amd64-vagrant-disk1.box
  # Optionnaly, read the Vagrantfile top section, containing VM cpu and memory settings
  vi Vagrantfile
  # From there, as explained, you should create a .vagrant_config.rb file, to alter
  # MEMORY (by default 1Go) and CPU (by default 2) and MAX_CPU_USAGE_PERCENT (by default 50%)
  # If it is not your first VM managed via this project alter DEVHOST_NUM (and read the part
  # Manage several Virtualboxes below)
  #
  # start the VM a first time, this will launch the VM creation and provisioning
  ./manage.sh up
  # you will certainly need one or to reload to finish the provision steps (normally the first time, the script do it for you) but to do it on your own you could use:
  vagrant reload #or:
  ./manage.sh reload

Daily usage
------------
VM control
++++++++++++

Now that vagrant as created a virtualbox image for you, you should always manipulate this virtualbox VM with ``vagrant`` command.

Please note that when the vm is running, we will try to mount the VM root as
root user with sshfs in the ``./VM`` folder.

To launch a Vagrant command always ``cd`` to the VM base directory::

  cd ~/makina/vms

Starting the VM is simple::

  ./manage.sh up

Stoping the VM can be done like that::

  ./manage.sh down # classical
  ./manage.sh suspend # faster on up, but requires disk space to store current state

Reloading the vm is::

  ./manage.sh reload # with sometimes tiemout problems on stop, redo-it.

To remove an outdated or broken VM::

  ./manage.sh destroy

Connecting to the vm
+++++++++++++++++++++
- We have made a wrapper similar to ``vagrant ssh``.
- but this one use the hostonly interface to improve transfer and shell reactivity.
- We also configured the vm to accept the current host user to connect as **root** and **vagrant** users.
- Thus, you can sonnect to the VM in ssh with either ``root`` or the ``vagrant`` user (sudoer) is::

  ./manage.sh ssh (default to vagrant)

- or::

  ./manage.sh ssh -l root

Export/Import
++++++++++++++

To export in **package.tar.bz2**, to share this development host with someone::

  ./manage.sh export

To  import from a **package.tar.bz2** file, simply place the package in the working
directory and issue::

  ./manage.sh import

Note that all the files mounted on the ``/vagrant`` vm directory are in fact stored on the base directory of this project.

File edition and access
++++++++++++++++++++++++++++
Base mountpoints and folders
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- **/mnt/parent_etc**: Host /etc folder
- **/mnt/parent_home**: Host user Home folder
- **/vagrant**: Current working directory in the host (where ./manage.sh up has been done
- **/srv/salt**: Salt state tree
- **/srv/projects**: makina Salt projects installation root
- **/srv/pillar**: Pillar data

Base file operations
~~~~~~~~~~~~~~~~~~~~~~~~
- To edit or access the files from your host system, youn ll just  have to use **./VM**
which is a mountpoint for the``/`` of the vm exported from
the vm as the **root** user.

- For example, you can configure **<here>/VM/srv/projects/foo** as the project
workspace root for your eclipse setup.

- **You should do git or large operations from within the VM as it will not use
  the shared network and will be faster**

ssh (git) credential
~~~~~~~~~~~~~~~~~~~~~~
- At each vm access

    - We copy to the **root** and **vagrant** users:

        - the current user ssh-keys
        - the current user ssh-config

    - We copy **vagrant** authorized_keys to **root/.ssh**.
    - All of this is managed in **/vagrant/vagrant/install_keys.sh**

This allow you from the host:

    - To log as vagrant or root user
    - To mount the guest filesystem as root (used in the core setup)
    - git push/pull from the guest as if you were on the host

If your project has custom users, just either (via saltstates):

    - copy the **vagrant** ssh keys to your user $HOME
    - Use an identity parameter pointing to the **vagrant** key pair

Manage several Virtualboxes
+++++++++++++++++++++++++++

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

Troubleshooting
===============

NFS
---

If the provision script of the vm halt on nfs mounts you will have to check several things:

* do you have some sort of firewalling preventing NFS from your host to the vm? Maybe also apparmor orselinux?
* do you have a correct /etc/hosts with a first 127.0.[0|1].1 record associated with localhost name and your short and long hostname?
* did you clone this repository in an encrypted folder (e.g.: home folder on Ubuntu)?
* On Mac OS X you can try `sudo nfsd checkexports`
* try to run the vagrant up with `VAGRANT_LOG=INFO vagrant up`
* try to run `sudo exportfs -a` for more debug information on host side.

Mac OS
-------
On Mavericks, you may encounter several issues, usually you need at least to reinstall virtualbox:
* ``There was an error while executing VBoxManage``: https://github.com/mitchellh/vagrant/issues/1809 try to use ``sudo launchctl load /Library/LaunchDaemons/org.virtualbox.startup.plist`` (4.3) and ``sudo /Library/StartupItems/VirtualBox/VirtualBox restart`` (before)
* ``There was an error executing the following command with VBoxManage: ["hostonlyif", "create"]`` : http://stackoverflow.com/questions/14404777/vagrant-hostonlyif-create-not-working
* shutdown problems: https://www.virtualbox.org/ticket/12241 you can try ``VBoxManage hostonlyif remove vboxnet0``

TO VMS Developers
==================
Vagrant images
--------------
Their use is to facilitate the learning of docker and to mitigate current
installation issues by providing a ready-to-use docker+salt virtualised host.
This vagrant Virtualbox management can be also used without Docker usage.

Master branch of this repository is using an `Ubuntu Saucy Vagrantfile VM <https://github.com/makinacorpus/vms/tree/master/Vagrantfile>`_.
Check other branches to find LTS precise versions.

check the Install part on this documentation for installation instructions

Notes for specific ubuntu release packages:

Ubuntu
+++++++
All the images are constructed from ubuntu cloud archives images.

Precise LTS - 12.04 - git: vagrant-ubuntu-lts-precise64
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
- Recent Virtualbox
- Linux hardware enablement stack kernel (3.8)

Raring - 13.04  - git: vagrant-ubuntu-1304-raring64)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
As of now, we needed to backport those next-ubuntu stuff (saucy) for things to behave correctly and efficiently:

- Lxc >= 1.0b
- Kernel >= 3.11
- Virtualbox >= 4.2.16

Saucy - 13.10 - git: master
~~~~~~~~~~~~~~~~~~~~~~~~~~
Mainline packages


Debian
+++++++
Debian Wheezy - 7 - git: vagrant-debian-7-wheezy64
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Mainline packages

Packer boxes
------------
Debian
++++++
We maintain some handmade Packer images from the official debian netinst iso
           (see packer subdir)
For packer, we use a docker subfolder with the appropriate stuff to build the base docker images insides.
Goal is to use packer to construct base images for the vagrant ones when there are no base images avalaible from trusted sources.
::

    apt-get -t wheezy-backports install linux-image-3.10-0.bpo.3-amd64
    linux-headers-3.10-0.bpo.3-amd64 initramfs-tools


Docker Images
--------------
- Contruct base environments to work with docker. (kernel, aufs, base setup)
- Install a functional makina-states installation inside in ``server`` mode
- Whereas the single process docker mainstream approach, we want to use the init systems
providen by the underlying distribution to manage a bunch of things.

Goal is to have in working state:

    - init system
    - cron
    - logrotate
    - sshd
    - sudo
    - syslog
    - screen
    - makina-states in server mode (vm)

Installing lxcutils & docker from git repositories
-----------------------------------------------------
For now you need docker from git and lxc from git also to fix:
- https://github.com/dotcloud/docker/issues/2278
- https://github.com/dotcloud/docker/issues/1960

You can install them in the vm with
::

    vagrant ssh
    sudo su
    cd /srv/docker
    ./make.sh inst

And uninstall them with
::

    vagrant ssh
    sudo su
    cd /srv/docker
    ./make.sh teardown
.. vim:set ts=4 sts=4:
