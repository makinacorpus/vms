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
You need to have ``virtualbox``, ``vagrant`` (with ``vagrant-vbguest`` plugin) and ``sshfs``.

On macosx, sshfs is also known as MacFuse or MacFusion.

By default file transferts between host and guest is **really, really slow**.
We have improved performances by some techniques:

    * Increasing the **MTU to 9000** (jumbo frames) on host and guest Ethernet nics
    * Leaving most of files on the guest side, leaving up to you to access the files
      on the guest. We recommend and also integrate this access to be via sshfs.
      On previous versions tests were made with NFS, having project files stored on
      the host and shared in the guest. This was too slow for read-heavy services
      like salt and plone, for example, so we finally choose to share files from the
      guest to the host.


Virtualbox
++++++++++
Install Oracle Virtualbox at at least the **4.3** version and more generally the
most up to date virtualbox release. Check `<https://www.virtualbox.org/>`_ for
details.

Typically on Debian and Ubuntu::

	wget -q http://download.virtualbox.org/virtualbox/debian/oracle_vbox.asc -O- | sudo apt-key add -
	if [[ -f /etc/lsb-release ]];then . /etc/lsb-release;distrib="$DISTRIB_CODENAME";
	elif [[ -f /etc/os-release ]];then . /etc/os-release;distrib="$(echo $VERSION|sed -re "s/.*\((.*)\)/\1/g")";fi
	echo "deb http://download.virtualbox.org/virtualbox/debian $distrib contrib">/etc/apt/sources.list.d/vbox.list
	apt-get update
	apt-get install virtualbox-4.3

On MacOSX, Install `<http://download.virtualbox.org/virtualbox/4.3.6/VirtualBox-4.3.6-91406-OSX.dmg>`_

Vagrant
+++++++
You could make you a supersudoer without password to avoid sudo questions when lauching the VMs (not required)::

    # visudo
    # Allow members of group sudo to execute any command
    %sudo   ALL=(ALL:ALL) NOPASSWD:ALL

For a Debian / Ubuntu deb-like host:

    url="https://dl.bintray.com/mitchellh/vagrant/vagrant_1.4.3_x86_64.deb";wget "$url"
    sudo dpkg -i vagrant_1.3.5_x86_64.deb

For macosx, use `<https://dl.bintray.com/mitchellh/vagrant/Vagrant-1.4.3.dmg>`_

**IMPORTANT** THE VBGUEST PLUGIN, to sync the guest addition packages from your
host virtualbox version::

    vagrant plugin install vagrant-vbguest


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

Optimizations (optional but recommended)
++++++++++++++++++++++++++++++++++++++++

Host kernel optimisations
~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Take care with this part, it can prevent your system from booting.

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

Installation & control
------------------------------
Now you can start the vm installation with vagrant. Note that this repository will be the base directory for your projects source code managment.
You will have to use ``./manage.sh``, a wrapper to ``vagrant`` in the spirit but do much more.

- Take a base location on your home::

    mkdir -p ~/makina/
    cd ~/makina/

- Get this project in the vms subdirectory of this base place
  note that you can alter the last name to choose another
  directory::

    git clone https://github.com/makinacorpus/vms.git vms
    cd vms

- Alternatively if you want the precise64 LTS ubuntu server use::

    git clone https://github.com/makinacorpus/vms.git -b vagrant-ubuntu-lts-precise64 vms-precise
    cd vms-precise

- Or for Debian (see that the last word is up to you, it's the destination directory)::

    git clone https://github.com/makinacorpus/vms.git -b vagrant-debian-7-wheezy64 vm-debian
    cd vm-debian
	
- start the VM a first time, this will launch the base vm download from DNS, then VM creation and
  provisioning::

    ./manage.sh init

- You will certainly need one or to reload to finish the provision steps (normally the first time, the script do it for you) but to do it on your own you could use::

    ./manage.sh reload

Now that vagrant as created a virtualbox image for you, you should always manipulate this virtualbox VM with ``./manage.sh`` command and use directly ``vagrant`` at last resort.

Please note that when the vm is running, we will try to mount the VM root as
root user with sshfs in the ``./VM`` folder.

To launch a Vagrant command always ``cd`` to the VM base directory::

  cd ~/makina/vms

Initialising from scratch (low level base iOS mage) rather than from a preconfigured
makina corpus image::

  ./manage.sh up

Starting the VM after creation is indeed the same command, but use the preconfigured VM under the hood if already initialized::

  ./manage.sh up

Stoping the VM can be done like that::

  ./manage.sh down # classical
  ./manage.sh suspend # faster on up, but requires disk space to store current state

Reloading the vm is::

  ./manage.sh reload # with sometimes tiemout problems on stop, redo-it.

To remove an outdated or broken VM::

  ./manage.sh destroy
	
Daily usage
------------

Manage several Virtualboxes
+++++++++++++++++++++++++++
You can tweak some settings via a special config file: ``vagrant_config.rb``

  - Read the Vagrantfile top section, containing VM cpu and memory settings and even more.
  - From there, as explained, you should create a .vagrant_config.rb file, to alter what you need.
For exemple, you can clone the **vms** git repository on another place where you can manage another vagrant based virtualbox vm.

Clone a vm from an existing one
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Take not that it will provision the base vm of the template and not the running VM.
If you want a full clone, use export & import.

Automatic way
**************
To create a new vm from an already existing one is damn easy
::

  cd ~/makina/<VM-TEMPLATE>
  ./manage.sh clonevm /path/to/a/new/vm/directory

Manual way
************
- lasting Slash are importants with rsync
::

  cd ~/makina/
  rsync -azv --exclude=VM --exclude="*.tar.bz2" <VM-template>/ <NEW-VM>/
  cd <NEW-VM>
  ./manage reset && ./manage init ../<VM-TEMPLATE>/<devhost_master*tar.bz2> # the downloaded archive at init time
  
New clone
~~~~~~~~~~~~~~

  mkdir -p ~/makina/
  cd ~/makina/
  # get this project in the vms subdirectory of this base place
  git clone https://github.com/makinacorpus/vms.git vm2
  cd vm2
  or c
  
m ID and Subnet.

Edit VM core settings 
++++++++++++++++++++++
You must read at least once the Vagrantfile, it will be easier for you to know how to alter the vm settings.
Such settings can go from MAX_CPU_USAGE_PERCENT,CPUS & MEMORY settings. to more useful: change this second v

DEVHOST_NUM
~~~~~~~~~~~~
**You will indeed realise that there is a magic DEVHOST_NUM setting (take the last avalaible one as a default).**

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

DEVHOST_AUTO_UPDATE
~~~~~~~~~~~~~~~~~~~~~~
You can tell to the provision script to run system updates and reprovision salt entirely by setting the **DEVHOST_AUTO_UPDATE** setting to ``true``.

Hostnames managment
+++++++++++++++++++++
- We add the hosts presents in the VM to the /etc/hosts of the host at up &
  reload stages (you ll be asked for)
- Read makina-states.nodetypes.vagrantvm if you want to know which hostnames are
  exported.
- You can optionnaly sync those hosts with::

  ./manage.sh sync_hosts

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

To import from a **package.tar.bz2** file, either:

    - Give an url to the archive
    - Give an absolute path to the archive
    - place the archive in ./package.box.tar.bz2

Then issue::

  ./manage.sh import [ FILE_ARCHiVE | URL | ./package.box.tar.bz2 ]

Note that all the files mounted on the ``/vagrant`` vm directory are in fact stored on the base directory of this project.

Purge old VMs
++++++++++++++
Time to time, it can be useful to regain free space by deleting old imported devhost base boxes, list them::

    vagrant box list

Look for lines beginning by **devhost-**.
None of those boxes are linked to your running vms, you can safely remove them.

You can then delete them by using::

    vagrant box remove <id>

File edition and access
++++++++++++++++++++++++++++
Base mountpoints and folders
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- **/mnt/parent_home**: Host user Home folder
- **/vagrant/share**: ``Current working directory/share`` in the host (where ./manage.sh up has been done
- **/vagrant/packer**: ``Current working directory/packer`` in the host (where ./manage.sh up has been done
- **/vagrant/docker**: ``Current working directory/docker`` in the host (where ./manage.sh up has been done
- **/vagrant/vagrant**: ``Current working directory/vagrant`` in the host (where ./manage.sh up has been done
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



Troubleshooting
===============

NFS
---

If the provision script of the vm halt on file share mounts you will have to check several things:

    * do you have some sort of firewalling preventing connections from your host to the vm? Maybe also apparmor or selinux?
    * do you have a correct /etc/hosts with a first 127.0.[0|1].1 record associated with localhost name and your short and long hostname?
    * did you clone this repository in an encrypted folder (e.g.: home folder on Ubuntu)?
    * On Mac OS X you can try `sudo nfsd checkexports`
    * try to run the commands but do prior to that::

        export VAGRANT_LOG=INFO

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

Do a release
++++++++++++++

- Run ./manage.sh release which will at once:

    - Edit and increment version.txt's version
    - Do a snapshot of the current vm to the desired release name
      (devhost-$branch_$ver.tar.tbz2)
    - Upload the tarball to the CDN, actually sourceforge


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

Use NFS Shared folders (obsolete)
-----------------------------------
* Install your OS NFS server
* Edit vagrant_config.rb and set ``DEVHOST_HAS_NFS=true``.
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



.. vim:set ts=4 sts=4:
