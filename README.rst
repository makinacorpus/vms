.. contents:: :local:

Summary
=======
Makina-States based vagrant development cluster builder
Included support for a docker cluster.

Organization
-------------
We use one branch for one os and one os version, and those are the currently
under support boxes:

- **vagrant-ubuntu-1504-vivid64** Ubuntu vivid / 64 bits

Install Development VMs
--------------------------
Following theses instructions you can install this git repository on a directory of your local host,
then start a Virtualbox vm from this directory.
this virtualbox VM(s) is handled by vagrant and will then run the docker VMs or any
part of your project.
You will be able to edit any files on the vm from your host, via the **VM/<hostname>** subdirectory which uses
under the hood a **sshfs** mountpoint, using **root** to connect to the vm.

By default, we build a cluster of **1** node.

Prerequisites
+++++++++++++++
You need to have installed ``virtualbox``, ``vagrant`` (with ``vagrant-vbguest`` plugin) and ``sshfs``.

On macosx, sshfs is also known as MacFusion.

Please, **read the next chapters** for details on installation and settings of theses elements (you will maybe need to alter some settings for sshfs and fuse, and we'll detail how to install theses various elements).

By default file transferts between host and guest is **really, really slow**.
We have improved performances by some techniques:

    * Increasing the **MTU to 9000** (jumbo frames) on host and guest Ethernet nics
    * Leaving most of files on the guest side, leaving up to you to access the files
      on the guest. We recommend and also integrate this access to be via **sshfs**.
      On previous versions tests were made with NFS, having project files stored on
      the host and shared in the guest. This was too slow for read-heavy services
      like salt and plone, for example, so we finally choose to share files from the
      guest to the host.


Virtualbox (recommended: >=5.0)
++++++++++++++++++++++++++++++++
Install Oracle Virtualbox at at least the **5.0** version and more generally the
most up to date virtualbox release. Check `<https://www.virtualbox.org/>`_ for
details.

**4.3** can also work but is damn slow !

Typically on Debian/Ubuntu::

	wget -q \
        "http://download.virtualbox.org/virtualbox/debian/oracle_vbox.asc" -O-\
        | sudo apt-key add -
	echo \
        "deb http://download.virtualbox.org/virtualbox/debian $(lsb_release -sc) contrib" \
        >/etc/apt/sources.list.d/vbox.list
	apt-get update
	apt-get install virtualbox-5.0

On MacOSX, Install `this DMG from virtualbox.org <http://download.virtualbox.org/virtualbox/5.0.10/VirtualBox-5.0.10-104061-OSX.dmg>`_

Vagrant (>=1.7)
++++++++++++++++
You could make you a supersudoer without password to avoid sudo questions when lauching the VMs (not required)::

    # visudo
    # Allow members of group sudo to execute any command
    %sudo   ALL=(ALL:ALL) NOPASSWD:ALL

For a Debian / Ubuntu deb-like host::

    url="https://releases.hashicorp.com/vagrant/1.8.5/vagrant_1.8.5_x86_64.deb"
    wget "$url" -O $(basename $url) || curl "$url" -o $(basename url)
    sudo dpkg -i $(basename $url)

For macosx, use `<https://releases.hashicorp.com/vagrant/1.7.4/vagrant_1.7.4.dmg>`_

For Fedora, you **must** export the environment variable `VAGRANT_DEFAULT_PROVIDER` and set it to *virtualbox* otherwise, it will assume KVM (via libvirt) as default provider. So for exemple, you can do :

.. code::

  echo "export VAGRANT_DEFAULT_PROVIDER=virtualbox" >> ~/.bashrc
  source ~/.bashrc

**IMPORTANT** install THE VBGUEST PLUGIN, to sync the guest addition packages from your
host virtualbox version::

    vagrant plugin uninstall vagrant-vbguest
    vagrant plugin install vagrant-vbguest

sshfs
++++++
Linux / *BSD
~~~~~~~~~~~~~~
- Install your sshfs distribution package (surely **sshfs**).
- Relog into a new session or reboot
- Ensure that **user_allow_other** is on ``/etc/fuse.conf`` and uncommented out
- next get to next part (ensure your are member of fuse group)

MacOSX
~~~~~~
- Remove old unsupported sshfs:
    - uninstall sshfs & osxfuse from brew if you did installed it
    - uninstall sshfs from MacFusion if any
    - uninstall sshfs from MacFuse if any

- Install **osxfuse** & **sshfs** from `osxfuse <http://osxfuse.github.io/>`_
- Ensure that **user_allow_other** is on ``/etc/fuse.conf`` and uncommented out. Add also "defer_permissions".

Ensure that your user is a fuse member
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Your user needs to be in the fuse group::

    id
    uid=1000(x) gid=1000(x) groupes=1000(x),...,111(fuse)

If fuse is not there::

   sudo gpasswd -a $(whoami) fuse

If you were not in the fuse group, either reconnect your session or reboot your
machine, or use ``newgrp fuse`` in any existing shell.

.. warning::
   On Fedora, there is no group *fuse*. Just be sure that you have read/write
   permissions with :
   
   .. code::
   
   	ll /dev/fuse
   	
   You should got :
   
   .. code::
   
   	crw-rw-rw- 1 root root 10, 229  4 mars  08:26 /dev/fuse

Optimizations (optional)
+++++++++++++++++++++++++
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
-----------------------
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

- Start the VM via ``init`` the first time, this will launch a preconfigured VM after having downloaded it from our Mirrors (sourceforge)::

    ./manage.sh init

- You will certainly need one or to reload to finish the provision steps (normally the first time, the script do it for you) but to do it on your own you could use::

    ./manage.sh reload

Now that vagrant has created a virtualbox vm for you, you should always manipulate this virtualbox VM with ``./manage.sh`` command and use directly ``vagrant`` at last resort.

Please note that when the vm is running, we will try to mount the VM root as
root user with sshfs in the ``./VM/<hostname>`` folder.

To launch a Vagrant command always ``cd`` to the VM base directory::

  cd ~/makina/vms

Starting the VM **ONLY** after the first creation. (if you have not launched first **init**, it will have the glorious effect **rebuild the entire image from scratch**)::

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
You can tweak some settings via a special config file: ``vagrant_config.yml``

  - Read the Vagrantfile top section, containing VM cpu and memory settings and even more.
  - From there, as explained, you should create a .vagrant_config.yml file, to alter what you need.
For exemple, you can clone the **vms** git repository on another place where you can manage another vagrant based virtualbox vm.

Notorious settings are the apt mirror to use at startup, the number of cpus, the
mem to use, etc.

DEVHOST_NUM
~~~~~~~~~~~~
**You will indeed realise that there is a magic DEVHOST_NUM setting (take the last avalaible one as a default).**

You can then this settings, along with the other settings in **vagrant_config.yml** .
By default this file is not yet created and will be created on first usage. But we can enforce it right before the first ``vagrant up``::

    cat > vagrant_config.yml << EOF
    ---
    DEVHOST_NUM: 22
    EOF

This way the second vagrant VM is now using IP: **10.1.22.43** instead of **10.1.42.43** for the private network.
The box hostname will be **devhost22.local** instead of devhost42.local.

Spawning multiple virtualbox inside the same "environment"
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Spawning a cluster based on the **BASE BOX** is easy, you just need to tell how
many machines you want.

For the moment though, the basesetup will be identical on each node.
But after that, you can reconfigure the boxes to do what their respectives roles
bring them to do...
::

    cat > vagrant_config.yml << EOF
    ---
    MACHINES: 3
    EOF

::

  ./manage.sh up

You can then get some infos
::

    ./manage.sh detailed_status [--no-header]

Clone a vm from an existing one
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Take note that it will provision the base vm of the template and not the running VM.
If you want a full clone, use export & import.

Automatic way
**************
To create a new vm from an already existing one is damn easy
::

  cd ~/makina/<VM-TEMPLATE>
  ./manage.sh clonevm /path/to/a/new/vm/directory

Manual way
************
- ending slashes are importants with rsync
::

  cd ~/makina/
  rsync -azv --exclude=VM --exclude="*.tar.bz2" <VM-template>/ <NEW-VM>/
  cd <NEW-VM>
  # the downloaded archive at init time
  ./manage reset && ./manage init ../<VM-TEMPLATE>/<devhost_master*tar.bz2>

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
**THE EXPORT WILL ONLY WORK WITH A ONE NODE SETUP**

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
Base mountpoints and folders inside the VM
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
- **/srv/salt**: Salt state tree
- **/srv/projects**: makina Salt projects installation root
- **/srv/pillar**: Pillar data

Shared from the host:
    - **/vagrant/share**: ``./share`` in the host (where ./manage.sh up has been done)
    - **/vagrant/packer**: ``./packer`` in the host (where ./manage.sh up has been done)
    - **/vagrant/vagrant**: ``./vagrant`` in the host (where ./manage.sh up has been done)

Access the VM files from the host (aka: localedit)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
- To edit or access the files from your HOST, you ll just have to ensure that the **./VM/<hostname>**
  folder is populated. Indeed, it's a **sshfs** share pointing to the ``/`` of the VM (as **root**).

- For example, you can configure **<here>/VM/<hostname>//srv/projects/foo** as the project
  workspace root for your eclipse setup.


Launching the VM should be sufficient to see files inside **./VM/<hostname>**
::

    ./manage.sh up

But in in case VM is empty::
::

    ./manage.sh mount_vm <vm_name>

ssh (git) credential
~~~~~~~~~~~~~~~~~~~~~~
- At each vm access, we copy **vagrant** authorized_keys to **root/.ssh**.
- All of this is managed in **/vagrant/provision_scripts.sh:install_keys**

This allow you from the host:

    - To log as vagrant or root user
    - To mount the guest filesystem as root (used in the core setup)

Troubleshooting
===============
network
---------

If the provision script of the vm halt on file share mounts you will have to check several things:

    * do you have some sort of firewalling preventing connections from your host to the vm? Maybe also apparmor or selinux?
    * did you clone this repository in an encrypted folder (e.g.: home folder on Ubuntu)?
    * try to run the commands but do prior to that::

        export VAGRANT_LOG=INFO

Mac OS
-------
On Mavericks, you may encounter several issues, usually you need at least to reinstall virtualbox:

    * ``There was an error while executing VBoxManage``: https://github.com/mitchellh/vagrant/issues/1809 try to use ``sudo launchctl load /Library/LaunchDaemons/org.virtualbox.startup.plist`` (4.3) and ``sudo /Library/StartupItems/VirtualBox/VirtualBox restart`` (before)
    * ``There was an error executing the following command with VBoxManage: ["hostonlyif", "create"]`` : http://stackoverflow.com/questions/14404777/vagrant-hostonlyif-create-not-working
    * shutdown problems: https://www.virtualbox.org/ticket/12241 you can try ``VBoxManage hostonlyif remove vboxnet0``

Hack
=====
- `<./doc/hack.rst>`_

.. vim:set ts=4 sts=4:
devhost-vagrant-ubuntu-1504-vivid64-lbApL0uKQNmecJrX.tar.bz2 doc LICENSE.txt manage.sh packer README.rst share test.sh vagrant vagrant_config.yml Vagrantfile VM
