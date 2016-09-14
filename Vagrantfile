# -*- mode: ruby -*-
# vim: set ft=ruby ts=2 et sts=2 tw=0 ai:
require 'yaml'
require 'digest/md5'
require 'etc'
# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"
CWD = File.dirname(__FILE__)
SCWD = CWD.gsub(/\//, '_').slice(1..-1)
if File.exists? "#{CWD}/vagrant_config.rb"
    raise "Migrate your vagrant_config.rb to vagrant_config.yml (same variables but in yaml format)"
end

def eprintf(*args)
  $stdout = STDERR
  printf(*args)
  $stdout = STDOUT
end

class Hash
  def setdefault(key, value)
    if self[key].nil?
      self[key] = value
    else
      self[key]
    end
  end
end

# --------------------- CONFIGURATION ZONE ----------------------------------
# If you want to alter any configuration setting, put theses settings in a ./vagrant_config.yml file
# This file would contain a combinaison of those settings
# The most importants are:
#    DEVHOST_NUM (network subnet related, default: lower available)
# -------------o<---------------
# ---
# CPUS: 1
# MEMORY: 512
# DEVHOST_NUM: 3
# MACHINES: "1" # number of machines to spawn
# BOX_URI: "http://foo/vivid64.img
# MAX_CPU_USAGE_PERCENT: 25
# DNS_SERVERS: "8.8.8.8"
# BOX: "vivid64"
# BOX: "devhost-vagrant-ubuntu-1504-vivid64_2"
# APT_MIRROR: "http://mirror.ovh.net/ftp.ubuntu.com/"
# APT_MIRROR: "http://ubuntu-archive.mirrors.proxad.net/ubuntu/"
# MS_BRANCH: "stable"
# HAS_NFS: false
# MS_NODETYPE: "vagrantvm"
# MS_BOOT_ARGS: |
#               -C -MM --mastersalt localhost -b \\${MS_BRANCH} -n \\${MS_NODETYPE} -m devhost\\${DEVHOST_NUM}.local
# -------------o<---------------
#------------- NETWORKING DETAILS ----------------
# 2 NETWORKS DEFINED, 1 NAT, 1 HOST ONLY
#   The default one is a NAT one, automatically done by vagrant, allows internal->external
#    and some NAT port mappings (by defaut a 2222->22 is managed bu vagrant
#   The private one will let you ref your dev things with a static IP in your /etc/hosts

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
def get_uuid(machine)
    uuid_file = "#{CWD}/.vagrant/machines/#{machine}/virtualbox/id"
    uuid = nil
    if File.exist?(uuid_file)
        uuid = File.read(uuid_file).strip()
    end
    uuid
end

cfg = Hash.new
# Number of machines to spawn
cfg['DEVHOST_NUM'] = nil
cfg['UNAME'] = `uname`.strip
# Number of machines to spawn
cfg['MACHINES'] = 1
# Per Machine resources quotas
cfg['MEMORY'] = 1024
cfg['CPUS'] = 2
cfg['MAX_CPU_USAGE_PERCENT'] = 50
cfg['HAS_NFS'] = false
# network & misc devhost settings
cfg['DEVHOST_AUTO_UPDATE'] = true
cfg['AUTO_UPDATE_VBOXGUEST_ADD'] = true
cfg['DNS_SERVERS'] = '8.8.8.8'
# OS
cfg['OS'] = 'Ubuntu'
cfg['OS_RELEASE'] = 'vivid'
cfg['APT_MIRROR'] = 'http://fr.archive.ubuntu.com/ubuntu'
cfg['APT_PROXY'] = ''
# MAKINA STATES CONFIGURATION
cfg['MS_BRANCH'] = 'v2'
cfg['MS_NODETYPE'] = 'vagrantvm'
cfg['MS_BOOT_ARGS'] = "-C -b \\${MS_BRANCH} -n \\${MS_NODETYPE} -m devhost\\${DEVHOST_FQDN}"
cfg['MS_BOOT_ARGS_V1'] = "-MM --mastersalt localhost #{cfg['MS_BOOT_ARGS']}"

# load settings from a local file in case
localcfg = Hash.new
VSETTINGS_Y = "#{CWD}/vagrant_config.yml"
if File.exist?(VSETTINGS_Y)
  localcfg = YAML.load_file(VSETTINGS_Y)
  if ! localcfg then localcfg = Hash.new end
end
cfg = cfg.merge(localcfg)

# Can be overidden by env. (used by manage.sh import/export)
cfg.each_pair { |i, val| cfg[i] = ENV.fetch("DEVHOST_#{i}", val) }
['BOX', 'BOX_URI', 'BOX_PRIVATE_SUBNET_BASE', 'BOX_PRIVATE_SUBNET'].each do |i|
    val = ENV.fetch("DEVHOST_#{i}", nil)
    if val != nil then cfg[i] = val end
end

# IP managment
# The box used a default NAT private IP, defined automatically by vagrant and virtualbox
# It also use a private deticated network (automatically created in virtualbox on a vmX network)
# By default the private IP will be 10.1.XX.YY/24. This is used for file share, but, as you will have a fixed
# IP for this VM it could be used in your /etc/host file to reference any name on this vm
# (the default devhostYY.local or devhotsXX.local entry is managed by salt).
# If you have several VMs you may need to alter at least the DEVHOST_NUM to obtain a different IP network
# Be sure to have only one unique subnet per devhost per physical host
if not cfg['DEVHOST_NUM']
    consumed_nums = []
    skipped_nums = ["1", "254"]
    `VBoxManage list vms|grep -i devhost`.split(/\n/).each do |l|
      n = l.downcase.sub(/.*devhost ([0-9]*) .*/, '\\1')
      if not consumed_nums.include?(n) and not n.empty?
          consumed_nums << n
      end
    end
    ("1".."254").each do |num|
      if !consumed_nums.include?(num) && !skipped_nums.include?(num)
        cfg['DEVHOST_NUM'] = num
        break
      end
    end
    if not cfg['DEVHOST_NUM']
      raise "There is no devhosts numbers left in (#{consumed_nums})"
    end
end
localcfg['DEVHOST_NUM'] = cfg['DEVHOST_NUM']

# NETWORK
cfg.setdefault('BOX_PRIVATE_SUBNET_BASE', "10.1.")
cfg.setdefault('BOX_PRIVATE_SUBNET', "#{cfg['BOX_PRIVATE_SUBNET_BASE']}#{cfg['DEVHOST_NUM']}")

# BOX SELECTION
cfg.setdefault('BOX', "#{cfg['OS_RELEASE']}64")
cfg.setdefault('BOX_URI',
               "http://cloud-images.ubuntu.com/vagrant/"\
               "#{cfg['OS_RELEASE']}/current/#{cfg['OS_RELEASE']}-server-cloudimg-amd64-vagrant-disk1.box")

# save back config to yaml (mainly for persiting devhost_num)
File.open("#{VSETTINGS_Y}", 'w') {|f| f.write localcfg.to_yaml }

#------------ SHARED FOLDERS ----------------------------
mountpoints = {"./share" => "/vagrant/share", "./packer" => "/vagrant/packer", "./vagrant" => "/vagrant/vagrant"}

#------------ Computed variables ------------------------
cfg['VIRTUALBOX_BASE_VM_NAME'] = "DevHost #{cfg['DEVHOST_NUM']} #{cfg['OS']} #{cfg['OS_RELEASE']}64"
cfg['VM_HOST'] = "devhost#{cfg['DEVHOST_NUM']}"
cfg['MTU_SET'] = if os == :macosx then "/bin/true" else "ifconfig eth1 mtu 9000" end

Vagrant.configure("2") do |config|
  if Vagrant.has_plugin?('vbguest management')
    if cfg['HAS_NFS']
        config.vbguest.auto_update = false
        config.vbguest.auto_reboot = false
        config.vbguest.no_install = true
    else
        config.vbguest.auto_update = cfg['AUTO_UPDATE_VBOXGUEST_ADD']
        config.vbguest.auto_reboot = true
        config.vbguest.no_install = false
    end
  end
  mountpoints.each do |mountpoint, target|
    shared_folder_args = {create: true}
    if cfg['HAS_NFS']
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
  (1..cfg['MACHINES'].to_i).each do |machine_num|
     hostname = "#{cfg['VM_HOST']}-#{machine_num}"
     machine = hostname
     config.vm.define  machine do |sub|
       box_private_ip = cfg['BOX_PRIVATE_SUBNET']+".#{machine_num + 1}"
       fqdn = "#{machine}.local"
       virtualbox_vm_name = "#{cfg['VIRTUALBOX_BASE_VM_NAME']} #{machine_num} (#{SCWD})"
       sub.vm.box = cfg['BOX']
       sub.vm.box_url = cfg['BOX_URI']
       # do not use vagrant hostname plugin, it's evil
       # https://github.com/mitchellh/vagrant/blob/master/plugins/guests/debian/cap/change_host_name.rb#L22-L23
       #if machine_num > 1
       #    sub.vm.host_name = fqdn
       #else
       #    sub.vm.host_name = fqdn
       #end
       sub.vm.provider "virtualbox" do |vb|
           vb.name = "#{virtualbox_vm_name}"
       end
       sub.vm.network "private_network", ip: box_private_ip, adapter: 2
       # vagrant 1.3 HACK: provision is now run only at first boot, we want to run it every time
       if File.exist?("#{CWD}/.vagrant/machines/#{machine}/virtualbox/action_provision")
         File.delete("#{CWD}/.vagrant/machines/#{machine}/virtualbox/action_provision")
       end
       provision_scripts = [
         # FOR NFS ENABLE JUMBO FRAMES, OTHER PART IN ON THE VAGRANTFILE
         # FOR HOST ONLY INTERFACE VBOXNET
         cfg['MTU_SET'],
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
    #{cfg['MTU_SET']}
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
         %{cat > /root/vagrant/provision_settings_#{machine}.sh  << EOF
export DEVHOST_NUM="#{cfg['DEVHOST_NUM']}"
export DEVHOST_MACHINE="#{machine}"
export DEVHOST_BASE_NAME="#{cfg['VIRTUALBOX_BASE_VM_NAME']}"
export DEVHOST_HOSTNAME="#{hostname}"
export DEVHOST_FQDN="#{fqdn}"
export DEVHOST_MACHINE_NUM="#{machine_num}"
export DEVHOST_IP="#{box_private_ip}"
export DEVHOST_VB_NAME="#{virtualbox_vm_name}"
export DNS_SERVERS="#{cfg['DNS_SERVERS']}"
export APT_MIRROR="#{cfg['APT_MIRROR']}"
export APT_PROXY="#{cfg['APT_PROXY']}"
export HAS_NFS="#{cfg['HAS_NFS']}"
export DEVHOST_AUTO_UPDATE="#{cfg['DEVHOST_AUTO_UPDATE']}"
export DEVHOST_HOST_OS="#{cfg['UNAME']}"
export MS_BRANCH="#{cfg['MS_BRANCH']}"
export MS_NODETYPE="#{cfg['MS_NODETYPE']}"
export MS_BOOT_ARGS="#{cfg['MS_BOOT_ARGS']}"
export MS_BOOT_ARGS_v1="#{cfg['MS_BOOT_ARGS']}"
EOF},
         "chmod 700 /root/vagrant/provision_*.sh",
         "rm -f /tmp/vagrant_provision_needs_restart",
         "/root/vagrant/provision_net.sh;",
         "/root/vagrant/provision_nfs.sh;",
         "export WANT_SETTINGS='1' " \
         " && . /root/vagrant/provision_settings_#{machine}.sh " \
         " && /vagrant/vagrant/provision_script.sh"]
       sub.vm.provision :shell, :inline => provision_scripts.join("\n")
    end
  end
end

Vagrant.configure("2") do |config|
  config.vm.provider :virtualbox do |vb|
    vb.customize ["modifyvm", :id, "--ioapic", "on"]
    vb.customize ["modifyvm", :id, "--memory", cfg['MEMORY']]
    vb.customize ["modifyvm", :id, "--cpus", cfg['CPUS']]
    vb.customize ["modifyvm", :id, "--cpuexecutioncap", cfg['MAX_CPU_USAGE_PERCENT']]
    vb.customize ["modifyvm", :id, "--nicpromisc2", "allow-all"]
    (1..cfg['MACHINES'].to_i).each do |machine_num|
       machine = "#{cfg['VM_HOST']}_#{machine_num}"
       uuid = get_uuid machine
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
end
