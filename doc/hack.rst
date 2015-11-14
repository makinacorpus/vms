HACK
======

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


Git merge From branch a to branch b
------------------------------------
Some weird changes can happen in Vagrant file

Say that you want to put master commits in debian (vagrant-debian-7-wheezy64) branch::

    git merge --no-commit --no-ff -e origin/master

Verify and discard or merge any changes to Vagrantfile::

    git diff --cached Vagrantfile

Discard::

    git show origin/vagrant-debian-7-wheezy64>Vagrantfile
    git add Vagrantfile

2 ways merge::

    git show origin/master>Vagrantfile.a
    git show origin/vagrant-debian-7-wheezy64>Vagrantfile
    vimdiff Vagrantfile.a Vagrantfile
    git add Vagrantfile

commit && push the result::

    git commit && push
 
