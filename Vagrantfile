# -*- mode: ruby -*-
# vim: set ft=ruby ts=2 et sts=2 tw=0 ai:
#
# !!!!!!!!!!!!!!!!:
# !!! IMPORTANT !!!
# !!!!!!!!!!!!!!!!!
# If you want to improve perfomances specially network related, please read the end of this file
# --------------------- CONFIGURATION ZONE ----------------------------------

require 'digest/md5'
require 'etc'
require 'rbconfig'

UBUNTU_RELEASE="raring"
UBUNTU_LTS_RELEASE="precise"
UBUNTU_NEXT_RELEASE="saucy"
CWD=File.dirname(__FILE__)

# MEMORY SIZE OF THE VM (the more you can, like 1024 or 2048, this is the VM hosting all your projects dockers)
MEMORY="1024"
# Number of available CPU for this VM
CPUS="2"
# LIMIT ON CPU USAGE
MAX_CPU_USAGE_PERCENT="50"
# Use this IP in your /etc/hosts for all names
# That you want to query this BOX with in your browser
# The VirtualBox private network will
# automatically be set to ensure private communications
# between this VM and your host on this IP
# (in VB's preferences network you can see it after first usage)
BOX_PRIVATE_IP="10.0.42.43"
BOX_PRIVATE_GW="10.0.42.1"
# 172.17.0.0 is the default, we use it with the raring image, 172.16.0.0 is enforced on this precise image
DOCKER_NETWORK_IF="docker0"
DOCKER_NETWORK_GATEWAY="172.17.42.1"
DOCKER_NETWORK="172.17.0.0"
DOCKER_NETWORK_MASK="255.255.0.0"
DOCKER_NETWORK_MASK_NUM="16"
# Custom dns server
DNS_SERVER="8.8.8.8"
#BOX_PRIVATE_NETMASK="255.225.255.0"
# md5 based on currentpath
MD5=Digest::MD5.hexdigest(CWD)
printf(" [*] VB MD5: #{MD5}\n")
# Name on your VirtualBox panel
VIRTUALBOX_VM_NAME="Docker DevHost Ubuntu "+UBUNTU_RELEASE+"64 (#{MD5})"
# Name inside the VM (as rendered by hostname command)
VM_HOSTNAME="devhost.local"
# Set this to true ONLY if you have VirtualBox version > 4.2.12
# else the synced folder would not work.
# When activated this would remove warnings about version mismatch of
# VirtualBox Guest additions, but we need at least the 4.2.12 version,
# v 4.2.0 is present in the default precise ubuntu kernel and 4.2.10 on
# raring and we add the 4.2.12 in this script
# even if your host is on a lower version. If you have something greater than
# 4.2.12 set this to true, comment the 4.2.12 install below and install vbguest
# vagrant plugin with this command : "vagrant plugin install vagrant-vbguest"
AUTO_UPDATE_VBOXGUEST_ADD=false
# ----------------- END CONFIGURATION ZONE ----------------------------------

# ------------- BASE IMAGE UBUNTU 13.04 (raring) -----------------------
# You can pre-download this image with
# vagrant box add raring64 http://cloud-images.ubuntu.com/vagrant/raring/current/raring-server-cloudimg-amd64-vagrant-disk1.box
BOX_NAME=ENV['BOX_NAME'] || UBUNTU_RELEASE+"64"
BOX_URI=ENV['BOX_URI'] || "http://cloud-images.ubuntu.com/vagrant/"+UBUNTU_RELEASE+"/current/"+UBUNTU_RELEASE+"-server-cloudimg-amd64-vagrant-disk1.box"


# ------------- Mirror to download packages -----------------------
LOCAL_MIRROR="http://fr.archive.ubuntu.com/ubuntu"
OFFICIAL_MIRROR="http://archive.ubuntu.com/ubuntu"
# let this one to the previous mirror for it to be automaticly replaced
PREVIOUS_LOCAL_MIRROR="http://fr.archive.ubuntu.com/ubuntu"
PREVIOUS_OFFICIAL_MIRROR="http://archive.ubuntu.com/ubuntu"

# -- Other things ----------------------------------------------------------

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

#Vagrant::Config.run do |config|
Vagrant.configure("2") do |config|
  # Setup virtual machine box. This VM configuration code is always executed.
  config.vm.box = BOX_NAME
  config.vm.box_url = BOX_URI
  #config.ssh.username = "ubuntu"
  #config.ssh.username = "vagrant"
  config.vm.host_name = VM_HOSTNAME
  config.vm.provider "virtualbox" do |vb|
      vb.name=VIRTUALBOX_VM_NAME
  end

  # -- VirtualBox Guest Additions ----------
  if Vagrant.has_plugin?('vbguest management')
    config.vbguest.auto_update = AUTO_UPDATE_VBOXGUEST_ADD
  end

  #------------- NETWORKING ----------------
  # 2 NETWORKS DEFINED, 1 NAT, 1 HOST ONLY
  # The default one is a NAT one, automatically done by vagrant, allows internal->external
  #   and some NAT port  mappings (by defaut a 2222->22 is managed bu vagrant
  # The public one is commented by default will give you an easy access to outside
  # The private one will let you ref your dev things with a static IP
  # in your /etc/hosts
  #
  # 1st network is bridging (public DHCP) on eth0 of yout machine
  # If you do not have an eth0 Vagrant will ask you for an interface
  #config.vm.network "public_network", :bridge => 'eth0'
  #config.vm.network "private_network", ip: BOX_PRIVATE_IP, netmask: BOX_PRIVATE_NETMASK
  config.vm.network "private_network", ip: BOX_PRIVATE_IP
  # NAT PORTS, if you want...
  #config.vm.network "forwarded_port", guest: 80, host: 8080
  #config.vm.network "forwarded_port", guest: 22, host: 2222

  #------------ SHARED FOLDERS ----------------------------
  # The current directory is mapped to the /srv of the mounted host
  # In this /srv we'll find the salt-stack things and projects
  # we use NFS to avoid speed penalities on VirtualBox (between *10 and *100)
  # and the "sendfile" bugs with nginx and apache
  #config.vm.synced_folder ".", "/srv/",owner: "vagrant", group: "vagrant"
  # be careful, we neded to ALLOW ROOT OWNERSHIP on this /srv directory, so "no_root_squash" option
  config.vm.synced_folder ".", "/srv/", nfs: true, linux__nfs_options: ["rw", "no_root_squash", "no_subtree_check"]
  #disabling default vagrant mount on /vagrant as we mount it on /srv
  config.vm.synced_folder ".", "/vagrant", disabled: true
  # dev: mount of etc, so we can alter current host /etc/hosts fromm the guest (insecure by defintion)
  config.vm.synced_folder "/etc", "/mnt/parent_etc", id: 'parent-etc', nfs: true

  #------------- PROVISIONING ------------------------------
  # We push all the code in a script which manages the versioning of
  # provisioning.
  # Since vagrant 1.3.0 provisioning is run only on the first "up"
  # or when --provision is used. But we need to run this script
  # on each up/reload, so that at least this script can handle the
  # launch of daemons which depends on NFS /srv mount which is done quite
  # late by vagrant and cannot be done on upstart. So first let's remove
  # the one-time provisioning marker

  # vagrant 1.3 HACK: provision is now run only at first boot, we want to run it every time
  if File.exist?("#{CWD}/.vagrant/machines/default/virtualbox/action_provision")
    # hack: remove this "provision-is-done" marker
    File.delete("#{CWD}/.vagrant/machines/default/virtualbox/action_provision")
  end

  # To manage edition rights sync between the VM and the local host
  # we need to ensure the current user is member of a salt-admin-vm group (gid: 65753) and
  # that this group exists
  newgid = 65753 # the most important
  newgroup = 'salt-admin-vm'
  user = Etc.getlogin

  # detect current host OS

  def os
    @os ||= (
      host_os = RbConfig::CONFIG['host_os']
      case host_os
      when /darwin|mac os/
        :macosx
      when /linux/
        :linux
      when /solaris|bsd/
        :unix
      else
        raise Error::WebDriverError, "Non supported os: #{host_os.inspect}"
      end
    )
  end

  #printf(" [*] Checking if local group %s exists\n", newgroup )
  # also search for a possible custom name
  found = false
  Etc.group {|g|
    if g.gid == newgid
      found = true
      newgroup = g.name
      break
    end
  }
  if !found
    printf(" [*] local group %s does not exists, creating it\n", newgroup)
    if os == :linux or os == :unix
      # Unix
      `sudo groupadd -g #{newgid} #{newgroup}`
    else
      # Mac
      `sudo dscl . -create /groups/#{newgroup} gid #{newgid}`
    end
  end
  #  printf(" [*] Checking if current user %s is member of group %s\n", user, newgroup)
  # loop on members of newgid to find our user
  found = false
  Etc.getgrgid(newgid).mem.each { |u|
    if u == user
      found = true
      break
    end
  }
  if !found
    printf(" [*] User %s is not member of group %s, adding him\n", user, newgroup)
    if os == :linux or os == :unix
      # Nunux
      `sudo gpasswd -a #{user} #{newgroup}`
    else
      #Mac
      `sudo dseditgroup -o edit -t user -a #{user} #{newgroup}`
    end
  end

  printf(" [*] checking local routes to %s/%s via %s. If sudo password is requested then it means we need to alter local host routing...\n",DOCKER_NETWORK,DOCKER_NETWORK_MASK_NUM,BOX_PRIVATE_IP)
  `ip route show|grep "#{DOCKER_NETWORK}/#{DOCKER_NETWORK_MASK_NUM}"|grep "#{BOX_PRIVATE_IP}";if [ "\\$?" != "0" ];then sudo ip route replace #{BOX_PRIVATE_IP} via #{BOX_PRIVATE_GW}; sudo ip route replace #{DOCKER_NETWORK}/#{DOCKER_NETWORK_MASK_NUM} via #{BOX_PRIVATE_IP}; fi;`
  printf(" [*] local routes ok, check it on your guest host with 'ip route show'\n\n")

  # Now generate the provision script, put it inside /root VM's directory and launch it
  # provision script has been moved to a bash script as it growned too much see ./provision_script.sh
  # the only thing we cant move is to test for NFS to be there as the shared file system relies on it
  pkg_cmd = [
      %{cat > /root/provision_nfs.sh  << EOF
#!/usr/bin/env bash
MARKERS="/srv/root/vagrant/markers"
die_if_error() { if [[ "\\$?" != "0" ]];then output "There were errors";exit 1;fi; };
if [[ ! -f /srv/Vagrantfile ]];then
    output() { echo "\\$@" >&2; };
    if [ ! -d "/srv" ]; then mkdir /srv;fi;
    if [ ! -f \\$MARKERS/provision_step_nfs_done ];then
      if [[ ! -e \\$MARKERS ]];then
        mkdir -pv "\\$MARKERS"
      fi
      output " [*] Installing nfs tools on guest for next reboot, please wait..."
      apt-get update -qq
      apt-get install nfs-common portmap
      if [ "0" == "$?" ];then touch \\$MARKERS/provision_step_nfs_done; fi;
    fi
    output " [*] ERROR: You do not have /srv/Vagrantfile, this means vagrant did not mount the vagrant directory in /srv, this VM wont be able to do anything usefull. Fix it and launch 'vagrant reload'!"
    exit 1
fi
EOF},
    %{cat > /root/vagrant_provision_settings.sh  << EOF
DNS_SERVER="#{DNS_SERVER}"
PREVIOUS_OFFICIAL_MIRROR="#{PREVIOUS_OFFICIAL_MIRROR}"
PREVIOUS_LOCAL_MIRROR="#{PREVIOUS_LOCAL_MIRROR}"
OFFICIAL_MIRROR="#{OFFICIAL_MIRROR}"
LOCAL_MIRROR="#{LOCAL_MIRROR}"
UBUNTU_RELEASE="#{UBUNTU_RELEASE}"
UBUNTU_NEXT_RELEASE="#{UBUNTU_NEXT_RELEASE}"
DOCKER_NETWORK_IF="#{DOCKER_NETWORK_IF}"
DOCKER_NETWORK_GATEWAY="#{DOCKER_NETWORK_GATEWAY}"
DOCKER_NETWORK="#{DOCKER_NETWORK}"
DOCKER_NETWORK_MASK="#{DOCKER_NETWORK_MASK}"
DOCKER_NETWORK_MASK_NUM="#{DOCKER_NETWORK_MASK_NUM}"
VB_MD5="#{MD5}"
EOF},
      "chmod 700 /root/provision_nfs.sh /srv/vagrant/provision_script.sh /root/provision_docker_bridge.sh;",
      "/root/provision_nfs.sh;",
      "/root/provision_docker_bridge.sh;",
      "/srv/vagrant/provision_script.sh",
  ]
  config.vm.provision :shell, :inline => pkg_cmd.join("\n")
end

# Providers were added on Vagrant >= 1.1.0
Vagrant::VERSION >= "1.1.0" and Vagrant.configure("2") do |config|
  config.vm.provider :virtualbox do |vb|
    vb.customize ["modifyvm", :id, "--ioapic", "on"]
    vb.customize ["modifyvm", :id, "--memory", MEMORY]
    vb.customize ["modifyvm", :id, "--cpus", CPUS]
    vb.customize ["modifyvm", :id, "--cpuexecutioncap", MAX_CPU_USAGE_PERCENT]
  end
end

# NOTE: right know you need to use a very uptodate kernel not to suffer from big slowness on ubuntu
# To improve performance of virtualisation, you need a kernel > 3.10
# and the last virtualbox stuff
# Idea is to backport the official next-ubuntu kernel (Codename: saucy)
#
# install a recent kernel & last virtualbox (saucy backports):
#   ./backport-pkgs.sh
#
# If you use nvidia drivers, you need nvidia>325 to run on kernel 3.10+:
#  sudo add-apt-repository ppa:xorg-edgers/ppa
#  sudo add-apt-repository ppa:bumblebee/stable
#  sudo apt-get update
#  sudo apt-get purge nvidia-304 nvidia-settings-304
#  apt-get install nvidia-325 nvidia-settings-325
#  # If you have optimus based chipset you will need to upgrade your bumblebee setup:
#    sudo apt-get install bumblebee bumblebee-nvidia primus primus-libs-ia32:i386 virtualgl
#  # Then, edit in /etc/bumblebee/bumblebee.conf
#    KernelDriver=nvidia_325
#    LibraryPath=/usr/lib/nvidia-325/:/usr/lib32/nvidia-325:/usr/lib/nvidia-current:/usr/lib32/nvidia-current
#    XorgModulePath=/usr/lib/nvidia-325/xorg,/usr/lib/nvidia-current/xorg,/usr/lib/xorg/modules
#  # You can then use nvidia settings as usual:
#    optirun nvidia-settings -c :8
#
#  # finally remove this edge repo:
#    sudo add-apt-repository --remove ppa:xorg-edgers:ppa
