# -*- mode: ruby -*-
# vim: set ft=ruby ts=2 et sts=2 tw=0 ai:

require 'digest/md5'
require 'etc'
require 'rbconfig'

CWD=File.dirname(__FILE__)
VSETTINGS_N="vagrant_config"
VSETTINGS_P=File.dirname(__FILE__)+"/"+VSETTINGS_N+".rb"
UNAME=`uname`.strip
vagrant_config_lines = []

def eprintf(*args)
  $stdout = STDERR
  printf(*args)
  $stdout = STDOUT
end

# --------------------- CONFIGURATION ZONE ----------------------------------
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
#    BOX_NAME="vivid64"
#    BOX_URI="http://foo/vivid64.img
#    MEMORY="512"
#    CPUS="1"
#    MAX_CPU_USAGE_PERCENT="25"
#    DNS_SERVERS="8.8.8.8"
#    #APT_MIRROR="http://mirror.ovh.net/ftp.ubuntu.com/"
#    #APT_MIRROR="http://ubuntu-archive.mirrors.proxad.net/ubuntu/"
#    #MS_BRANCH="stable"
#    #MS_NODETYPE="vagrantvm"
#    #MS_BOOT_ARGS="-C -MM --mastersalt localhost -b \\${MS_BRANCH} -n \\${MS_NODETYPE} -m devhost\\${DEVHOST_NUM}.local"
# end
# -------------o<---------------

#------------- NETWORKING DETAILS ----------------
# 2 NETWORKS DEFINED, 1 NAT, 1 HOST ONLY
#   The default one is a NAT one, automatically done by vagrant, allows internal->external
#    and some NAT port mappings (by defaut a 2222->22 is managed bu vagrant
#   The private one will let you ref your dev things with a static IP
#    in your /etc/hosts

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

UBUNTU_RELEASE="vivid"

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

# do we launch core salt updates on provision
if defined?(DEVHOST_AUTO_UPDATE)
    vagrant_config_lines << "DEVHOST_AUTO_UPDATE=#{DEVHOST_AUTO_UPDATE}"
else
    DEVHOST_AUTO_UPDATE=true
end

# IP managment
# The box used a default NAT private IP, defined automatically by vagrant and virtualbox
# It also use a private deticated network (automatically created in virtualbox on a vmX network)
# By default the private IP will be 10.1.XX.YY/24. This is used for file share, but, as you will have a fixed
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
consumed_nums = []
devhost_num_def = nil
`VBoxManage list vms|grep -i devhost`.split(/\n/).each do |l|
  n = l.downcase.sub(/.*devhost ([0-9]*) .*/, '\\1')
  if not consumed_nums.include?(n) and not n.empty?
      consumed_nums << n
  end
end
skipped_nums = ["1", "254"]
("1".."254").each do |num|
  if !consumed_nums.include?(num) && !skipped_nums.include?(num)
    devhost_num_def=num
    break
  end
end
if not devhost_num_def
  raise "There is no devhosts numbers left in (#{consumed_nums})"
else
  DEVHOST_NUM_DEF=devhost_num_def
end
if not defined?(DEVHOST_NUM)
    devhost_num=ENV.fetch("MAKINA_DEVHOST_NUM", "").strip()
    if devhost_num.empty?
      devhost_num=DEVHOST_NUM_DEF
    end
    DEVHOST_NUM=devhost_num
end
vagrant_config_lines << "DEVHOST_NUM=\"#{DEVHOST_NUM}\""
BOX_PRIVATE_SUBNET_BASE="10.1." unless defined?(BOX_PRIVATE_SUBNET_BASE)

# Custom dns server
if defined?(DNS_SERVERS)
    vagrant_config_lines << "DNS_SERVER=\"#{DNS_SERVERS}\""
else
    DNS_SERVERS="8.8.8.8"
end

# This is the case on ubuntu <= 13.10
# on ubuntu < 13.04 else the synced folder would not work.
if defined?(AUTO_UPDATE_VBOXGUEST_ADD)
    vagrant_config_lines << "AUTO_UPDATE_VBOXGUEST_ADD=\"#{AUTO_UPDATE_VBOXGUEST_ADD}\""
else
    AUTO_UPDATE_VBOXGUEST_ADD=true
end

# ------------- Mirror to download packages -----------------------
if defined?(APT_MIRROR)
    vagrant_config_lines << "APT_MIRROR=\"#{APT_MIRROR}\""
else
    APT_MIRROR="http://fr.archive.ubuntu.com/ubuntu"
end

#------------ SHARED FOLDERS ----------------------------
# HOST -> VM: Some of host./ subdirectories are mapped to /vagrant/<dir> in the VM
# HOST <- VM: VM /guest is mapped to host ./VM using sshfs
mountpoints = {"./share" => "/vagrant/share",
               "./packer" => "/vagrant/packer",
               "./vagrant" => "/vagrant/vagrant"}

# ------ Init based on configuration values ---------------------------------
# Chances are you do not want to alter that.
BOX_PRIVATE_SUBNET=BOX_PRIVATE_SUBNET_BASE+DEVHOST_NUM
BOX_PRIVATE_IP=BOX_PRIVATE_SUBNET+".43" # so 10.1.XX.YY by default
BOX_PRIVATE_GW=BOX_PRIVATE_SUBNET+".1"
# md5 based on currentpath
# Name on your VirtualBox panel
VIRTUALBOX_BASE_VM_NAME="DevHost "+DEVHOST_NUM+" Ubuntu "+UBUNTU_RELEASE+"64"
VBOX_NAME_FILE=File.dirname(__FILE__) + "/.vb_name"
MD5=Digest::MD5.hexdigest(CWD)
#VIRTUALBOX_VM_NAME="#{VIRTUALBOX_BASE_VM_NAME} (#{MD5})"
# as we have now mecanisms to select a new devnum, force the facct that we cant have more that one
# vm with the same devnum
SCWD = CWD.gsub(/\//, '_').slice(1..-1)
VIRTUALBOX_VM_NAME="#{VIRTUALBOX_BASE_VM_NAME} (#{SCWD})"
eprintf(" [*] VB NAME: '#{VIRTUALBOX_VM_NAME}'\n")
eprintf(" [*] VB IP: #{BOX_PRIVATE_IP}\n")
eprintf(" [*] VB MEMORY|CPUS|MAX_CPU_USAGE_PERCENT: #{MEMORY}MB | #{CPUS} | #{MAX_CPU_USAGE_PERCENT}%\n")
VM_HOSTNAME="devhost"+DEVHOST_NUM+".local" # so devhostxx.local by default

# ------------- MAKINA STATES CONFIGURATION -----------------------
if defined?(MS_BRANCH)
    vagrant_config_lines << "MS_BRANCH=\"#{MS_BRANCH}\""
else
    MS_BRANCH="stable"
end
if defined?(MS_NODETYPE)
    vagrant_config_lines << "MS_NODETYPE=\"#{MS_NODETYPE}\""
else
    MS_NODETYPE="vagrantvm"
end
if defined?(MS_BOOT_ARGS)
    vagrant_config_lines << "MS_BOOT_ARGS=\"#{MS_BOOT_ARGS}\""
else
    MS_BOOT_ARGS="-C -MM --mastersalt localhost -b \\${MS_BRANCH} -n \\${MS_NODETYPE} -m devhost\\${DEVHOST_NUM}.local"
end

# ------------- BASE IMAGE UBUNTU  -----------------------
if defined?(BOX_NAME)
    vagrant_config_lines << "BOX_NAME=\"#{BOX_NAME}\""
else
    BOX_NAME=UBUNTU_RELEASE+"64"
end
# Can be overidden by env. (used by manage.sh import/export)
REAL_BOX_NAME = ENV.fetch("DEVHOST_FORCED_BOX_NAME", BOX_NAME).strip()
if defined?(BOX_URI)
    vagrant_config_lines << "BOX_URI=\"#{BOX_URI}\""
else
    BOX_URI="http://cloud-images.ubuntu.com/vagrant/"+UBUNTU_RELEASE+"/current/"+UBUNTU_RELEASE+"-server-cloudimg-amd64-vagrant-disk1.box"
end

# -- Other things ----------------------------------------------------------
# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"
# we do not use nfs anymore, but rely on sshfs
if defined?(DEVHOST_HAS_NFS)
    vagrant_config_lines << "DEVHOST_HAS_NFS=#{DEVHOST_HAS_NFS}"
else
    DEVHOST_HAS_NFS=false
end
if ! defined?(SSH_INSERT_KEY)
    SSH_INSERT_KEY=true
end
vagrant_config_lines << "SSH_INSERT_KEY=#{SSH_INSERT_KEY}"

# SAVING CUSTOM CONFIGURATION TO A FILE (AND ONLY CUSTOMIZED variables will be written)
vagrant_config = ""
vagrant_config_lines_s = ""
["# do not write comments, they will be lost",
 "module MyConfig"].each{ |s| vagrant_config += s + "\n" }
vagrant_config_lines.each{ |s| vagrant_config_lines_s += "    "+ s + "\n" }
vagrant_config += vagrant_config_lines_s
["end", ""].each{ |s| vagrant_config += s + "\n" }
vsettings_f=File.open(VSETTINGS_P, "w")
vsettings_f.write(vagrant_config)
vsettings_f.close()

mtu_set = "ifconfig eth1 mtu 9000"
if os == :macosx
    mtu_set="/bin/true"
end


# the provision script
pkg_cmd = [
    # FOR NFS ENABLE JUMBO FRAMES, OTHER PART IN ON THE VAGRANTFILE
    # FOR HOST ONLY INTERFACE VBOXNET
    mtu_set,
    "if [ ! -d /root/vagrant ];then mkdir /root/vagrant;fi;",
    %{cat > /root/vagrant/provision_net.sh  << EOF
#!/usr/bin/env bash
# be sure to have the configured ip in config rather that prior to import one
interface="eth1"
hostip=\\$(ip addr show dev \\$interface 2> /dev/null|awk '/inet / {gsub("/.*", "", \\$2);print \\$2}'|head -n1)
configured_hostip=\\$( cat /etc/network/interfaces|grep \\$interface -A3|grep address|awk '{print \\$2}')
if [ "x\\$hostip" != "x\\$configured_hostip" ];then
    ifdown \\$interface &> /dev/null
    ifup \\$interface
    #{mtu_set}
fi
EOF},
    %{cat > /root/vagrant/provision_nfs.sh  << EOF
#!/usr/bin/env bash
MARKERS="/root/vagrant/markers"
die_if_error() { if [ "x\\$?" != "x0" ];then output "There were errors";exit 1;fi; };
output() { echo "\\$@" >&2; };
if [ ! -f \\$MARKERS/provision_step_nfs_done ];then
    if [[ ! -e \\$MARKERS ]];then
      mkdir -pv "\\$MARKERS"
    fi
    output " [*] Installing nfs tools on guest for next reboot, please wait..."
    apt-get update -qq
    apt-get install -y --force-yes nfs-common portmap
    if [ "x0" = "x${?}" ];then
        touch \\$MARKERS/provision_step_nfs_done
    fi
fi
if [ ! -e "/vagrant/vagrant/provision_script.sh" ];then
    output " [*] ERROR: You do not have /vagrant/vagrant/provision_script.sh,"
    output " [*] ERROR: this means vagrant did not mount the vagrant directory in /srv,"
    output " [*] ERROR: Fix it and launch './manage.sh reload'!"
    exit 1
fi
EOF},
    %{cat > /root/vagrant/provision_settings.sh  << EOF
DEVHOST_HAS_NFS="#{DEVHOST_HAS_NFS}"
DEVHOST_AUTO_UPDATE="#{DEVHOST_AUTO_UPDATE}"
DNS_SERVERS="#{DNS_SERVERS}"
DEVHOST_NUM="#{DEVHOST_NUM}"
DEVHOST_HOSTNAME="#{VM_HOSTNAME}"
APT_MIRROR="#{APT_MIRROR}"
ZHOST_OS="#{UNAME}"
VB_NAME="#{VIRTUALBOX_VM_NAME}"
MS_BRANCH="#{MS_BRANCH}"
MS_NODETYPE="#{MS_NODETYPE}"
MS_BOOT_ARGS="#{MS_BOOT_ARGS}"
EOF},
      "chmod 700 /root/vagrant/provision_*.sh",
      "rm -f /tmp/vagrant_provision_needs_restart",
      "/root/vagrant/provision_net.sh;",
      "/root/vagrant/provision_nfs.sh;",
      "/vagrant/vagrant/provision_script.sh",
]

Vagrant.configure("2") do |config|
  if Vagrant.has_plugin?('vbguest management')
    if DEVHOST_HAS_NFS
        config.vbguest.auto_update = false
        config.vbguest.auto_reboot = false
        config.vbguest.no_install = true
    else
        config.vbguest.auto_update = AUTO_UPDATE_VBOXGUEST_ADD
        config.vbguest.auto_reboot = true
        config.vbguest.no_install = false
    end
  end
  config.vm.box = REAL_BOX_NAME
  config.vm.box_url = BOX_URI
  config.vm.host_name = VM_HOSTNAME
  config.vm.provider "virtualbox" do |vb|
        vb.name="#{VIRTUALBOX_VM_NAME}"
  end
  config.vm.network "private_network", ip: BOX_PRIVATE_IP, adapter: 2
  mountpoints.each do |mountpoint, target|
      shared_folder_args = {create: true}
      if DEVHOST_HAS_NFS
          shared_folder_args.update({
              :nfs => true,
              :nfs_udp => false,
              :linux__nfs_options => ["rw", "no_root_squash", "no_subtree_check",],
              :bsd__nfs_options => ["maproot=root:wheel", "alldirs"],
              :mount_options => ["vers=3", "rw","noatime", "nodiratime",
                                 "udp", "rsize=32768", "wsize=32768"]})
      end
      config.vm.synced_folder(mountpoint, target, shared_folder_args)
  end
  # disable default /vagrant shared folder
  config.vm.synced_folder ".", "/vagrant", disabled: true
  # vagrant 1.3 HACK: provision is now run only at first boot, we want to run it every time
  if File.exist?("#{CWD}/.vagrant/machines/default/virtualbox/action_provision")
    File.delete("#{CWD}/.vagrant/machines/default/virtualbox/action_provision")
  end
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
    uuid = get_uuid
    if uuid != nil
      interface_hostonly = `VBoxManage showvminfo #{uuid} --machinereadable|grep -i hostonlyadapter2|sed 's/.*="//'|sed 's/"//'`.strip()
      if interface_hostonly.start_with?("vboxnet")
        mtu = `sudo ifconfig #{interface_hostonly}|grep -i mtu|sed -e "s/.*MTU:*//g"|awk '{print $1}'`.strip()
        if (mtu != "9000")
          if os != :macosx
              eprintf("Configuring jumbo frame on #{interface_hostonly}\n")
          # not supported on darwin AT THE MOMENT
          #  `sudo networksetup -setMTU #{interface_hostonly} 9000`
          #else
            `sudo ifconfig #{interface_hostonly} mtu 9000`
          end
        end
      end
    end
  end
end
