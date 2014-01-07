# -*- mode: ruby -*-
# vim: set ft=ruby ts=2 et sts=2 tw=0 ai:
#
# !!!!!!!!!!!!!!!!:
# !!! IMPORTANT !!!
# !!!!!!!!!!!!!!!!!
# If you want to improve perfomances specially network related, please read the end of this file

require 'digest/md5'
require 'etc'
require 'rbconfig'

CWD=File.dirname(__FILE__)
VSETTINGS_N="vagrant_config"
VSETTINGS_P=File.dirname(__FILE__)+"/"+VSETTINGS_N+".rb"
vagrant_config_lines = []

def eprintf(*args)
  $stdout = STDERR
  printf(*args)
  $stdout = STDOUT
end


# --------------------- CONFIGURATION ZONE ----------------------------------
#
# If you want to alter any configuration setting, put theses settings in a ./vagrant_config.rb file
# This way you will be able to "git up" the project more easily and get this Vagrantfile updated
#
# This file would contain a combinaison of those settings
#
# The most importants are:
#    DEVHOST_NUM (network subnet related)
#    VIRTUALBOX_VM_NAME (name of the virtualbox vm)
#
# -------------o<---------------
# module MyConfig
#    DEVHOST_NUM="3"
#    VIRTUALBOX_VM_NAME="Super devhost Vm"
#    BOX_NAME="saucy64"
#    BOX_URI="http://foo/saucy64.img
#    MEMORY="512"
#    CPUS="1"
#    MAX_CPU_USAGE_PERCENT="25"
#    DNS_SERVER="8.8.8.8"
# end
# -------------o<---------------


# Check entries in the configuration zone for variables available.
# --- Start Load optional config file ---------------
def get_uuid
    uuid_file = "#{CWD}/.vagrant/machines/default/virtualbox/id"
    uuid = nil
    if File.exist?(uuid_file)
        uuid = File.read(uuid_file).strip()
    end
    uuid
end
begin
  require_relative VSETTINGS_N
  include MyConfig
rescue LoadError
end
# --- End Load optional config file -----------------

if defined?(UBUNTU_RELEASE)
    vagrant_config_lines << "UBUNTU_RELEASE=\"#{UBUNTU_RELEASE}\""
else
    UBUNTU_RELEASE="saucy"
end
if defined?(UBUNTU_LTS_RELEASE)
    vagrant_config_lines << "UBUNTU_LTS_RELEASE=\"#{UBUNTU_LTS_RELEASE}\""
else
    UBUNTU_LTS_RELEASE="precise"
end
if defined?(UBUNTU_NEXT_RELEASE)
    vagrant_config_lines << "UBUNTU_NEXT_RELEASE=\"#{UBUNTU_NEXT_RELEASE}\""
else
    UBUNTU_NEXT_RELEASE="trusty"
end

# MEMORY SIZE OF THE VM (the more you can, like 1024 or 2048, this is the VM hosting all your projects dockers)
if defined?(MEMORY)
    vagrant_config_lines << "MEMORY=\"#{MEMORY}\""
else
    MEMORY="1024"
end
if defined?(CPUS)
    vagrant_config_lines << "CPUS=\"#{CPUS}\""
else
    CPUS="2"
end
# Number of available CPU for this VM
# LIMIT ON CPU USAGE
if defined?(MAX_CPU_USAGE_PERCENT)
    vagrant_config_lines << "MAX_CPU_USAGE_PERCENT=\"#{MAX_CPU_USAGE_PERCENT}\""
else
    MAX_CPU_USAGE_PERCENT="50"
end

# IP managment
# The box used a default NAT private IP, defined automatically by vagrant and virtualbox
# It also use a private deticated network (automatically created in virtualbox on a vmX network)
# By default the private IP will be 10.1.XX.YY/24. This is used for NFS shre, but, as you will have a fixed
# IP for this VM it could be used in your /etc/host file to reference any name on this vm
# (the default devhostYY.local or devhotsXX.local entry is managed by salt).
# If you have several VMs you may need to alter at least the MAKINA_DEVHOST_NUM to obtain a different
# IP network and docker IP network on this VM
#
# You can change the subnet used via the MAKINA_DEVHOST_NUM
# EG: export MAKINA_DEVHOST_NUM=44 will give an ip of 10.1.XX.YY for this host
# This setting is saved upon reboots, you need to set it only once.
# (be careful with env variable if you run several vms)
# You could also set it in the ./vagrant_config.rb to get it fixed at any time
# and specified for each vm
#
# Be sure to have only one unique subnet per devhost per physical host
#
VBOX_SUBNET_FILE=File.dirname(__FILE__) + "/.vb_subnet"
DEVHOST_NUM_DEF="42"
if not defined?(DEVHOST_NUM)
    devhost_num=ENV.fetch("MAKINA_DEVHOST_NUM", "").strip()
    if devhost_num.empty? and File.exist?(VBOX_SUBNET_FILE)
        devhost_num=File.open(VBOX_SUBNET_FILE, 'r').read().strip()
    end
    if devhost_num.empty?
      devhost_num=DEVHOST_NUM_DEF
    end
    DEVHOST_NUM=devhost_num
end
vagrant_config_lines << "DEVHOST_NUM=\"#{DEVHOST_NUM}\""
BOX_PRIVATE_SUBNET_BASE="10.1." unless defined?(BOX_PRIVATE_SUBNET_BASE)
DOCKER_NETWORK_BASE="172.31." unless defined?(DOCKER_NETWORK_BASE)

# Custom dns server
if defined?(DNS_SERVER)
    vagrant_config_lines << "DNS_SERVER=\"#{DNS_SERVER}\""
else
    DNS_SERVER="8.8.8.8"
end

# This is the case on ubuntu <= 13.10
# on ubuntu < 13.04 else the synced folder would not work.
if defined?(AUTO_UPDATE_VBOXGUEST_ADD)
    vagrant_config_lines << "AUTO_UPDATE_VBOXGUEST_ADD=\"#{AUTO_UPDATE_VBOXGUEST_ADD}\""
else
    AUTO_UPDATE_VBOXGUEST_ADD=false
end

# ------------- Mirror to download packages -----------------------
if defined?(LOCAL_MIRROR)
    vagrant_config_lines << "LOCAL_MIRROR=\"#{LOCAL_MIRROR}\""
else
    LOCAL_MIRROR="http://fr.archive.ubuntu.com/ubuntu"
end
if defined?(OFFICIAL_MIRROR)
    vagrant_config_lines << "OFFICIAL_MIRROR=\"#{OFFICIAL_MIRROR}\""
else
    OFFICIAL_MIRROR="http://archive.ubuntu.com/ubuntu"
end
# let this one to the previous mirror for it to be automaticly replaced
if defined?(PREVIOUS_LOCAL_MIRROR)
    vagrant_config_lines << "PREVIOUS_LOCAL_MIRROR=\"#{PREVIOUS_LOCAL_MIRROR}\""
else
    PREVIOUS_LOCAL_MIRROR="http://fr.archive.ubuntu.com/ubuntu"
end
if defined?(PREVIOUS_OFFICIAL_MIRROR)
    vagrant_config_lines << "PREVIOUS_OFFICIAL_MIRROR=\"#{PREVIOUS_OFFICIAL_MIRROR}\""
else
    PREVIOUS_OFFICIAL_MIRROR="http://us.archive.ubuntu.com/ubuntu"
end

# ----------------- END CONFIGURATION ZONE ----------------------------------

# ------ Init based on configuration values ---------------------------------
# Chances are you do not want to alter that.

BOX_PRIVATE_SUBNET=BOX_PRIVATE_SUBNET_BASE+DEVHOST_NUM
BOX_PRIVATE_IP=BOX_PRIVATE_SUBNET+".43" # so 10.1.XX.YY by default
BOX_PRIVATE_GW=BOX_PRIVATE_SUBNET+".1"
# To enable dockers to be interlinked between multiple virtuabox,
# we also setup a specific docker network subnet per virtualbox host
DOCKER_NETWORK_IF="docker0"
DOCKER_NETWORK_HOST_IF="eth0"
DOCKER_NETWORK_SUBNET=DOCKER_NETWORK_BASE+DEVHOST_NUM # so 172.31.xx.0 by default
DOCKER_NETWORK=DOCKER_NETWORK_SUBNET+".0"
DOCKER_NETWORK_GATEWAY=DOCKER_NETWORK_SUBNET+".254"
DOCKER_NETWORK_MASK="255.255.255.0"
DOCKER_NETWORK_MASK_NUM="24"

# md5 based on currentpath
# Name on your VirtualBox panel
VIRTUALBOX_BASE_VM_NAME="Docker DevHost "+DEVHOST_NUM+" Ubuntu "+UBUNTU_RELEASE+"64"
VBOX_NAME_FILE=File.dirname(__FILE__) + "/.vb_name"
if not defined?(VIRTUALBOX_VM_NAME)
    # old system file support
    if not File.exist?(VBOX_NAME_FILE)
        MD5=Digest::MD5.hexdigest(CWD)
        VIRTUALBOX_VM_NAME="#{VIRTUALBOX_BASE_VM_NAME} (#{MD5})"
    else
        md5_fo = File.open(VBOX_NAME_FILE, 'r')
        VIRTUALBOX_VM_NAME=md5_fo.read().strip()
    end
end
vagrant_config_lines << "VIRTUALBOX_VM_NAME=\"#{VIRTUALBOX_VM_NAME}\""
eprintf(" [*] VB NAME: '#{VIRTUALBOX_VM_NAME}'\n")
eprintf(" [*] VB IP: #{BOX_PRIVATE_IP}\n")
eprintf(" [*] VB MEMORY|CPUS|MAX_CPU_USAGE_PERCENT: #{MEMORY}MB | #{CPUS} | #{MAX_CPU_USAGE_PERCENT}%\n")
eprintf(" [*] To have multiple hosts, you can change the third bits of IP (default: #{DEVHOST_NUM_DEF}) via the MAKINA_DEVHOST_NUM env variable)\n")
eprintf(" [*] if you want to share this wm, dont forget to have ./vagrant_config.rb along\n")
eprintf(" [*] if you want to share this wm, use manage.sh export | import\n")
# Name inside the VM (as rendered by hostname command)
VM_HOSTNAME="devhost"+DEVHOST_NUM+".local" # so devhostxx.local by default


# ------------- BASE IMAGE UBUNTU  -----------------------
# You can pre-download this image with
# vagrant box add precise64 http://cloud-images.ubuntu.com/precise/precise/current/precise-server-cloudimg-amd64-vagrant-disk1.box

if defined?(BOX_NAME)
    vagrant_config_lines << "BOX_NAME=\"#{BOX_NAME}\""
else
    BOX_NAME=UBUNTU_RELEASE+"64"
end
if defined?(BOX_URI)
    vagrant_config_lines << "BOX_URI=\"#{BOX_URI}\""
else
    BOX_URI="http://cloud-images.ubuntu.com/vagrant/"+UBUNTU_RELEASE+"/current/"+UBUNTU_RELEASE+"-server-cloudimg-amd64-vagrant-disk1.box"
end

# -- Other things ----------------------------------------------------------

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

#Vagrant::Config.run do |config|
Vagrant.configure("2") do |config|
  # Setup virtual machine box. This VM configuration code is always executed.
  config.vm.box = BOX_NAME
  config.vm.box_url = BOX_URI
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
  #
  mountpoints = {
      "./" => "/vagrant",
      "/etc" => "/mnt/parent_etc",
      File.expand_path('~') => "/mnt/parent_home"
  }
  mountpoints.each do |mountpoint, target|
      config.vm.synced_folder(
          mountpoint, target,
          nfs: true,
          nfs_udp: false,
          linux__nfs_options: ["rw", "no_root_squash", "no_subtree_check",],
          bsd__nfs_options: ["maproot=root:wheel", "alldirs"],
          mount_options: [
              "vers=3","rw","noatime", "nodiratime",
              "udp", "rsize=32768", "wsize=32768",
          ],
      )
  end
  # config.vm.synced_folder ".", "/vagrant", disabled: true
  # dev: mount of etc, so we can alter current host /etc/hosts from the guest (insecure by definition)
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
  # we need to ensure the current user is member of a group editor (gid: 65753) and
  # that this group exists
  newgid = 65753 # the most important
  newgroup = 'editor'
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

  #eprintf(" [*] Checking if local group %s exists\n", newgroup )
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
    eprintf(" [*] local group %s does not exists, creating it\n", newgroup)
    if os == :linux or os == :unix
      # Unix
      `sudo groupadd -g #{newgid} #{newgroup}`
    else
      # Mac
      `sudo dscl . -create /groups/#{newgroup} gid #{newgid}`
    end
  end
  #  eprintf(" [*] Checking if current user %s is member of group %s\n", user, newgroup)
  # loop on members of newgid to find our user
  found = false
  Etc.getgrgid(newgid).mem.each { |u|
    if u == user
      found = true
      break
    end
  }
  if !found
    eprintf(" [*] User %s is not member of group %s, adding him\n", user, newgroup)
    if os == :linux or os == :unix
      # Nunux
      `sudo gpasswd -a #{user} #{newgroup}`
    else
      #Mac
      `sudo dseditgroup -o edit -t user -a #{user} #{newgroup}`
    end
  end

  eprintf(" [*] checking local routes to %s/%s via %s. If sudo password is requested then it means we need to alter local host routing...\n",DOCKER_NETWORK,DOCKER_NETWORK_MASK_NUM,BOX_PRIVATE_IP)
  if os == :linux or os == :unix
    # Nunux
    `if ip route show|grep "#{DOCKER_NETWORK}/#{DOCKER_NETWORK_MASK_NUM}"|grep -q "#{BOX_PRIVATE_IP}";then echo "routes ok"; else sudo ip route replace #{BOX_PRIVATE_IP} via #{BOX_PRIVATE_GW}; sudo ip route replace #{DOCKER_NETWORK}/#{DOCKER_NETWORK_MASK_NUM} via #{BOX_PRIVATE_IP}; fi;`
  else
    #Mac
    `if netstat -rn|grep "#{DOCKER_NETWORK_SUBNET}/#{DOCKER_NETWORK_MASK}"|grep -q "#{BOX_PRIVATE_IP}";then echo "routes ok"; else sudo route -n add -host #{BOX_PRIVATE_IP} #{BOX_PRIVATE_GW};sudo route -n add -net #{DOCKER_NETWORK_SUBNET}/#{DOCKER_NETWORK_MASK_NUM} #{BOX_PRIVATE_IP};fi;`
  end
  eprintf(" [*] local routes ok, check it on your guest host with 'ip route show'\n")

# SAVING CUSTOM CONFIGURATION TO A FILE (AND ONLY CUSTOMIZED ONE)
vagrant_config = ""
vagrant_config_lines_s = ""
["", "module MyConfig"].each{ |s| vagrant_config += s + "\n" }
vagrant_config_lines.each{ |s| vagrant_config_lines_s += "    "+ s + "\n" }
vagrant_config += vagrant_config_lines_s
["end", ""].each{ |s| vagrant_config += s + "\n" }
eprintf(" [*] Saving vagrant settings:\n#{vagrant_config_lines_s}")
vsettings_f=File.open(VSETTINGS_P, "w")
vsettings_f.write(vagrant_config)
vsettings_f.close()

# Now generate the provision script, put it inside /root VM's directory and launch it
# provision script has been moved to a bash script as it growned too much see ./provision_script.sh
# the only thing we cant move is to test for NFS to be there as the shared file system relies on it
pkg_cmd = [
    # FOR NFS ENABLE JUMBO FRAMES, OTHER PART IN ON THE VAGRANTFILE
    # FOR HOST ONLY INTERFACE VBOXNET
    "ifconfig eth1 mtu 9000",
    "if [ ! -d /root/vagrant ];then mkdir /root/vagrant;fi;",
    %{cat > /root/vagrant/provision_nfs.sh  << EOF
#!/usr/bin/env bash
MARKERS="/root/vagrant/markers"
die_if_error() { if [[ "\\$?" != "0" ]];then output "There were errors";exit 1;fi; };
if [[ ! -e /vagrant/Vagrantfile ]];then
    output() { echo "\\$@" >&2; };
    if [ ! -f \\$MARKERS/provision_step_nfs_done ];then
      if [[ ! -e \\$MARKERS ]];then
        mkdir -pv "\\$MARKERS"
      fi
      output " [*] Installing nfs tools on guest for next reboot, please wait..."
      apt-get update -qq
      apt-get install -y --force-yes nfs-common portmap
      if [ "0" == "$?" ];then touch \\$MARKERS/provision_step_nfs_done; fi;
    fi
    output " [*] ERROR: You do not have /vagrant/vagrant/Vagrantfile, this means vagrant did not mount the vagrant directory in /srv, this VM wont be able to do anything usefull. Fix it and launch './manage.sh reload'!"
    exit 1
fi
EOF},
    %{cat > /root/vagrant/provision_settings.sh  << EOF
DNS_SERVER="#{DNS_SERVER}"
PREVIOUS_OFFICIAL_MIRROR="#{PREVIOUS_OFFICIAL_MIRROR}"
PREVIOUS_LOCAL_MIRROR="#{PREVIOUS_LOCAL_MIRROR}"
OFFICIAL_MIRROR="#{OFFICIAL_MIRROR}"
LOCAL_MIRROR="#{LOCAL_MIRROR}"
UBUNTU_RELEASE="#{UBUNTU_RELEASE}"
UBUNTU_NEXT_RELEASE="#{UBUNTU_NEXT_RELEASE}"
DOCKER_NETWORK_HOST_IF="#{DOCKER_NETWORK_HOST_IF}"
DOCKER_NETWORK_IF="#{DOCKER_NETWORK_IF}"
DOCKER_NETWORK_BASE="#{DOCKER_NETWORK_IF}"
DOCKER_NETWORK_SUBNET="#{DOCKER_NETWORK_SUBNET}"
DOCKER_NETWORK_GATEWAY="#{DOCKER_NETWORK_GATEWAY}"
DOCKER_NETWORK="#{DOCKER_NETWORK}"
DOCKER_NETWORK_MASK="#{DOCKER_NETWORK_MASK}"
DOCKER_NETWORK_MASK_NUM="#{DOCKER_NETWORK_MASK_NUM}"
VB_NAME="#{VIRTUALBOX_VM_NAME}"
EOF},
      "chmod 700 /root/vagrant/provision_nfs.sh /vagrant/vagrant/provision_script.sh;",
      "/root/vagrant/provision_nfs.sh;",
      "/vagrant/vagrant/provision_script.sh",
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
    vb.customize ["modifyvm", :id, "--nicpromisc2", "allow-all"]
    #uuid = 'b71e292b-87e5-4ec8-8ecb-337b9482676f'
    uuid = get_uuid
    if uuid != nil
      interface_hostonly = `VBoxManage showvminfo #{uuid} --machinereadable|grep -i hostonlyadapter|sed 's/.*="//'|sed 's/"//'`.strip()
      if interface_hostonly.start_with?("vboxnet")
        mtu = `sudo ifconfig #{interface_hostonly}|grep -i mtu|sed -e "s/.*MTU:*//g"|awk '{print $1}'`.strip()
        if (mtu != "9000")
          eprintf("Configuring jumbo frame on #{interface_hostonly}\n")
          `sudo ifconfig #{interface_hostonly} mtu 9000`
        end
      end
    end
  end
end
