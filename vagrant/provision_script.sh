#!/usr/bin/env bash
#
# This script is ubuntu specific for the moment.
# Script is supposed to be run on development VMs (Virtualbox)
# This will install correctly NFS client, salt, makina-states, docker & virtualbox extensions
#
# Beware on raring and saucy baremetal vms, this script is not safe
# as it backport a lot of saucy packages, see ../backport-pgks.sh
# for backporting things on a bare metal machine
#
YELLOW='\e[1;33m'
RED="\\033[31m"
CYAN="\\033[36m"
NORMAL="\\033[0m"
DEBUG=${BOOT_SALT_DEBUG:-}

if [[ -e /etc/lsb-release ]];then
    . /etc/lsb-release
fi

output() { echo -e "${YELLOW}$@${NORMAL}" >&2; }
die_if_error() {
    if [[ "$?" != "0" ]];then
        output "There were errors"
        exit 1
    fi
}

output " [*] STARTING MAKINA VAGRANT PROVISION SCRIPT: $0"
output " [*] You can safely relaunch this script from within the vm"

# source a maybe existing settings file
SETTINGS="${SETTINGS:-"/root/vagrant_provision_settings.sh"}"
if [ -f $SETTINGS ];then
    output " [*] Loading custom settings in $SETTINGS"
    . $SETTINGS
fi
PREFIX="${PREFIX:-"/srv"}"
VPREFIX="${PREFIX:-"$PREFIX/vagrant"}"
export SALT_BOOT='server'
BOOT_GRAIN="makina.bootstrap.$SALT_BOOT"

# Markers must not be on a shared folder for a new VM to be reprovisionned correctly
VENV_PATH="/salt-venv"
MARKERS="${MARKERS:-"/root/vagrant/markers"}"
DNS_SERVER="${DNS_SERVER:-"8.8.8.8"}"
PREVIOUS_OFFICIAL_MIRROR="${PREVIOUS_OFFICIAL_MIRROR:-"http://archive.ubuntu.com/ubuntu"}"
PREVIOUS_LOCAL_MIRROR="${PREVIOUS_LOCAL_MIRROR:-"http://fr.archive.ubuntu.com/ubuntu"}"
OFFICIAL_MIRROR="${OFFICIAL_MIRROR:-"http://archive.ubuntu.com/ubuntu"}"
LOCAL_MIRROR="${LOCAL_MIRROR:-"http://fr.archive.ubuntu.com/ubuntu"}"
UBUNTU_RELEASE="${UBUNTU_RELEASE:-"raring"}"
UBUNTU_NEXT_RELEASE="${UBUNTU_NEXT_RELEASE:-"saucy"}"
DOCKER_NETWORK_HOST_IF="${DOCKER_NETWORK_HOST_IF:-eth0}"
DOCKER_NETWORK_IF="${DOCKER_NETWORK_IF:-docker0}"
DOCKER_NETWORK_GATEWAY="${DOCKER_NETWORK_GATEWAY:-"172.17.42.1"}"
DOCKER_NETWORK="${DOCKER_NETWORK:-"172.17.0.0"}"
DOCKER_NETWORK_MASK="${DOCKER_NETWORK_MASK:-"255.255.0.0"}"
DOCKER_NETWORK_MASK_NUM="${DOCKER_NETWORK_MASK_NUM:-"16"}"

# disable some useless and harmfull services
PLYMOUTH_SERVICES=$(find /etc/init -name 'plymouth*'|grep -v override|sed -re "s:/etc/init/(.*)\.conf:\1:g")
UPSTART_DISABLED_SERVICES="$PLYMOUTH_SERVICES"
CHRONO="$(date "+%F_%H-%M-%S")"

# order is important
LXC_PKGS="lxc apparmor apparmor-profiles"
KERNEL_PKGS="linux-source linux-image-generic linux-headers-generic linux-image-extra-virtual"
VB_PKGS="virtualbox virtualbox-dkms virtualbox-source virtualbox-qt"
VB_PKGS="$VB_PKGS virtualbox-guest-additions-iso virtualbox-guest-dkms virtualbox-guest-source"
VB_PKGS="$VB_PKGS virtualbox-guest-utils virtualbox-guest-x11 virtualbox-guest-dkms"
kernel_marker="$MARKERS/provision_step_kernel${UBUNTU_NEXT_RELEASE}_done"
lxc_marker="$MARKERS/vbox_lxc_from_${UBUNTU_NEXT_RELEASE}.ok"
vbox_marker="$MARKERS/vbox_vbox_from_${UBUNTU_NEXT_RELEASE}.ok"
mirror_marker="$MARKERS/vbox_pkg_2_init_repos_${OFFICIAL_MIRROR//\//-}_${LOCAL_MIRROR//\//-}_${PREVIOUS_LOCAL_MIRROR//\//-}"
NEED_RESTART=""
export DEBIAN_FRONTEND="noninteractive"
# escape to 5 "antislash"
# http://www./#foo -> http:\/\/www\./\#foo
RE_PREVIOUS_OFFICIAL_MIRROR="$(echo "${PREVIOUS_OFFICIAL_MIRROR}" | sed -re "s/([.#/])/\\\\\1/g")"
RE_PREVIOUS_LOCAL_MIRROR="$(echo "${PREVIOUS_LOCAL_MIRROR}"       | sed -re "s/([.#/])/\\\\\1/g")"
RE_OFFICIAL_MIRROR="$(echo "${OFFICIAL_MIRROR}"                   | sed -re "s/([.#/])/\\\\\1/g")"
RE_LOCAL_MIRROR="$(echo "${LOCAL_MIRROR}"                         | sed -re "s/([.#/])/\\\\\1/g")"
RE_UBUNTU_RELEASE="$(echo "${UBUNTU_RELEASE}"                     | sed -re "s/([.#/])/\\\\\1/g")"
src_l="/etc/apt/sources.list"

ready_to_run() {
    output " [*] VM is now ready for 'vagrant ssh' or other usages..."
    output " ------------------------------- [ OK] -----------------------------------------"
    output " 'You can upgrade all your projects with \"salt '*' state.highstate\""
    output " 'You can upgrade the base salt infrastructure with \"salt '*' state.sls setup\""
    output " 'Stop vm with 'vagrant [-f] halt', connect it with 'vagrant ssh'"
}

deactivate_ifup_debugging() {
    if [[ -f /root/ifup ]];then
        cp /root/ifup /sbin/ifup
        rm -rf /ifup.debug /root/ifup
    fi
}

activate_ifup_debugging() {
    if [[ ! -f /root/ifup ]];then
        cp /sbin/ifup /root/ifup
        cat > /sbin/ifup<<EOF
#!/usr/bin/env bash
echo \$(date) \$0 \$@>>/ifup.debug
/root/ifup \$@
ret=\$?
echo \$(date) \$0 \$@ END >>/ifup.debug
exit \$ret
EOF
        chmod +x /sbin/ifup
    fi
}

write_zerofree() {
    cat > /root/zerofree.sh << EOF
#!/usr/bin/env bash
echo " [*] Zerofreeing"
apt-get install -y --force-yes zerofree
echo s > /proc/sysrq-trigger
echo s > /proc/sysrq-trigger
echo u > /proc/sysrq-trigger
mount -o remount,ro /
zerofree -v /dev/sda1
mount -o remount,rw /
EOF
    chmod +x /root/zerofree.sh
}
write_zerofree


get_grain() { salt-call --local grains.get $1 --out=raw 2>/dev/null ; }

initialize_devel_salt_grains() {
    grain=makina.devhost
    output " [*] Testing salt grain '$grain'"
    if [[ "$(get_grain $grain)" != *"True"* ]];then
        output " [*] Setting salt grain $grain=true to mark this host as a dev host for salt-stack"
        salt-call --local grains.setval $grain true
        # sync grains right now, do not wait for reboot
        salt-call saltutil.sync_grains
    else
        output " [*] Grain '$grain' already set"
    fi
}

open_routes() {
    output " [*] allow routing of traffic coming from dev host going to docker net"
    sysctl -w net.ipv4.ip_forward=1
    sysctl -w net.ipv4.conf.all.rp_filter=0
    sysctl -w net.ipv4.conf.all.log_martians=1
}

backport_saucy() {
    if [[ ! -e "$lxc_marker" ]];then
        output " [*] Backporting Saucy LXC packages: adding repository"
        sed -re "s/(precise|${UBUNTU_RELEASE})/${UBUNTU_NEXT_RELEASE}/g" -i "${src_l}" && \
        apt-get update -qq && \
        output " [*] Backporting Saucy LXC packages:"
        output " [*]   ${LXC_PKGS}"
        apt-get install -y --force-yes ${LXC_PKGS}
        die_if_error
        output " [*] cleanup of apt, removing backports from sources"
        sed -re "s/${UBUNTU_NEXT_RELEASE}/${UBUNTU_RELEASE}/g" -i "${src_l}" && apt-get update -qq
        die_if_error
        touch "$lxc_marker"
        NEED_RESTART="1"
    fi

    if [[ ! -e "$vbox_marker" ]];then
        output " [*] Backporting Saucy Virtualbox packages:"
        output " [*]   $VB_PKGS"
        sed -re "s/(precise|${UBUNTU_RELEASE})/${UBUNTU_NEXT_RELEASE}/g" -i ${src_l} &&\
        apt-get update -qq && apt-get install -y --force-yes $VB_PKGS
        die_if_error
        output " [*] Backporting Saucy Virtualbox packages: cleanup repository"
        sed -re "s/${UBUNTU_NEXT_RELEASE}/${UBUNTU_RELEASE}/g" -i ${src_l} && apt-get update -qq
        die_if_error
        touch "$vbox_marker"
        NEED_RESTART="1"
    fi

    if [[ ! -e "${kernel_marker}" ]]; then
        output " [*] Backporting Saucy kernel ($KERNEL_PKGS)"
        sed -re "s/(precise|${UBUNTU_RELEASE})/${UBUNTU_NEXT_RELEASE}/g" -i ${src_l} &&\
        apt-get update -qq && apt-get install -y --force-yes $KERNEL_PKGS
        die_if_error
        sed -re "s/${UBUNTU_NEXT_RELEASE}/${UBUNTU_RELEASE}/g" -i ${src_l} && apt-get update -qq
        die_if_error
        touch "$kernel_marker"
        NEED_RESTART="1"
    fi

    if [[ ! -e "${kernel_marker}" ]]; then
        output " [*] Backporting Saucy kernel ($KERNEL_PKGS)"
        sed -re "s/(precise|${UBUNTU_RELEASE})/${UBUNTU_NEXT_RELEASE}/g" -i ${src_l} &&\
        apt-get update -qq && apt-get install -y --force-yes $KERNEL_PKGS
        die_if_error
        sed -re "s/${UBUNTU_NEXT_RELEASE}/${UBUNTU_RELEASE}/g" -i ${src_l} && apt-get update -qq
        die_if_error
        touch "$kernel_marker"
        NEED_RESTART="1"
    fi
}

output " [*] Temporary DNs overrides in /etc/resolv.conf : ${DNS_SERVER}, 8.8.8.8 & 4.4.4.4"
# DNS TMP OVERRIDE
cat > /etc/resolv.conf << DNSEOF
nameserver ${DNS_SERVER}
nameserver 8.8.8.8
nameserver 4.4.4.4
DNSEOF

# cleanup old failed provisions
if [[ "$(grep "$UBUNTU_NEXT_RELEASE" ${src_l} | wc -l)" != "0" ]];then
    output " [*] Deactivating next-release($UBUNTU_NEXT_RELEASE) repos"
    sed -re "s/$UBUNTU_NEXT_RELEASE/$UBUNTU_RELEASE/g" -i ${src_l}
    apt-get update -qq
fi

# Create basic directories
for p in "$PREFIX" "$MARKERS";do
    if [[ ! -e $p ]];then
        mkdir -pv "$p"
    fi
done

# Create the docker0 bridge before docker does it to hard-fcode
# the docker network address
if_file="/etc/network/interfaces.${DOCKER_NETWORK_IF}"
if_conf="$if_file.conf "
NETWORK_RESTART=""

#activate_ifup_debugging

if [[ "$(egrep "^source.*docker0" /etc/network/interfaces  |wc -l)" == "0" ]];then
    apt-get install -y --force-yes bridge-utils
    echo>>/etc/network/interfaces
    touch $if_conf
    echo "# configure dockers">>/etc/network/interfaces
    echo "source $if_conf">>/etc/network/interfaces
    echo>>/etc/network/interfaces
    NETWORK_RESTART="1"
fi

# we control activation of main interface in docker conf
# comment it in main file
sed -re "s/^#*(.*${DOCKER_NETWORK_HOST_IF})/#\1/g" -i /etc/network/interfaces

# configure bridge
cat > $if_file.up <<EOF
#!/usr/bin/env bash
iptables -t nat -A POSTROUTING -s ${DOCKER_NETWORK}/$DOCKER_NETWORK_MASK_NUM ! -d ${DOCKER_NETWORK}/$DOCKER_NETWORK_MASK_NUM -o $DOCKER_NETWORK_HOST_IF -j MASQUERADE
EOF

cat > $if_file.down << EOF
#!/usr/bin/env bash
iptables -t nat -D POSTROUTING -s ${DOCKER_NETWORK}/$DOCKER_NETWORK_MASK_NUM ! -d ${DOCKER_NETWORK}/$DOCKER_NETWORK_MASK_NUM -o $DOCKER_NETWORK_HOST_IF -j MASQUERADE || true
EOF

chmod +x "/etc/network/interfaces.${DOCKER_NETWORK_IF}."{up,down}
    cat > $if_conf << EOF
# for this to work, we need  ${DOCKER_NETWORK_HOST_IF} to be wired
# we force so with a pre-up call
auto ${DOCKER_NETWORK_HOST_IF}
iface ${DOCKER_NETWORK_HOST_IF} inet dhcp
    post-up ifup ${DOCKER_NETWORK_IF}

auto ${DOCKER_NETWORK_IF}
iface ${DOCKER_NETWORK_IF} inet static
    address ${DOCKER_NETWORK_GATEWAY}
    netmask ${DOCKER_NETWORK_MASK}
    bridge_ports none
    bridge_stp off
    bridge_fd 0
    pre-up $if_file.up
    post-down $if_file.down

EOF

if [[ "$(md5sum $if_conf 2>/dev/null)" != "$(md5sum $if_conf.new 2>/dev/null)" ]];then
    cp -f $if_conf.new $if_conf
    NETWORK_RESTART="1"
fi

if [[ -n "$NETWORK_RESTART" ]];then
    output " [*] Init docker(${DOCKER_NETWORK_IF}) network bridge to fix docker network class"
    service networking restart
fi

# be sure to have routes forwarded on a network restart or at boot time
# on a vagrant reload
open_routes

if [[ "$DISTRIB_CODENAME" == "lucid" ]]\
    || [[ "$DISTRIB_CODENAME" == "maverick" ]]\
    || [[ "$DISTRIB_CODENAME" == "natty" ]]\
    || [[ "$DISTRIB_CODENAME" == "oneiric" ]]\
    || [[ "$DISTRIB_CODENAME" == "precise" ]]\
    || [[ "$DISTRIB_CODENAME" == "quantal" ]]\
    ;then
    EARLY_UBUNTU=y
    BEFORE_RARING=y
fi

if [[ "$DISTRIB_CODENAME" == "raring" ]] || [[ -n "$EARLY_UBUNTU" ]];then
    BEFORE_SAUCY=y
fi

for service in $UPSTART_DISABLED_SERVICES;do
    sf=/etc/init/$service.override
    if [[ "$(cat $sf 2>/dev/null)" != "manual" ]];then
        output " [*] Disable $service upstart service"
        echo "manual" > "$sf"
        service $service stop
        if [[ -n "$BEFORE_SAUCY" ]];then
            NEED_RESTART="1"
        fi
    fi
done

if [ ! -e "$mirror_marker" ];then
    if [ ! -e "$MARKERS/vbox_pkg_1_initial_update" ];then
        # generate a proper commented /etc/apt/source.list
        output " [*] Initial upgrade with cloud-init"
        if [[ -n $EARLY_UBUNTU ]];then
            apt-get install -y --force-yes cloud-init
            cloud-init start
        fi
        /usr/bin/cloud-init init
        /usr/bin/cloud-init modules --mode=config
        /usr/bin/cloud-init modules --mode=final
        cp "${src_l}" "${src_l}.${CHRONO}.sav" || die_if_error
        touch "$MARKERS/vbox_pkg_1_initial_update"
    fi
    output " [*] Activating some Ubuntu repository and mirrors"
    sed -re "s/(.*deb(-src)?\s+)(${RE_PREVIOUS_OFFICIAL_MIRROR}|${RE_PREVIOUS_LOCAL_MIRROR}|${RE_OFFICIAL_MIRROR})(.*)/\1${RE_LOCAL_MIRROR}\4/g" -i ${src_l}
    sed -re "s/^(#|\s)*(deb(-src)?\s+[^ ]+\s+(precise|raring|${UBUNTU_NEXT_RELEASE}|${UBUNTU_RELEASE})(-(updates|backports|security))?)\s+(.*)/\2 \7/g" -i ${src_l}
    for rel in $UBUNTU_RELEASE ${UBUNTU_RELEASE}-updates;do
        for i in partner restricted universe multiverse main;do
            ADD_DEB=1
            ADD_DEBSRC=1
            if [[ "$i" == "partner" ]];then
                ADD_DEBSRC=""
                if [[ "$rel" != "$UBUNTU_RELEASE" ]];then
                    ADD_DEB=""
                fi
            fi
            if [[ ! "$(egrep "^deb\s+.*\s${rel}\s*$i" ${src_l}|wc -l)" == "0" ]];then
                ADD_DEB=""
            fi
            if [[ ! "$(egrep "^deb-src\s+.*\s${rel}\s*$i" ${src_l}|wc -l)" == "0" ]];then
                ADD_DEBSRC=""
            fi
            if [[ -n "$ADD_DEB" ]];then
                output " [*] Adding ${i}@${rel} to repos"
                echo "deb ${LOCAL_MIRROR} ${rel} $i" >> ${src_l}
            fi
            if [[ -n "$ADD_DEBSRC" ]];then
                output " [*] Adding ${i}(src)@${rel} to repos"
                echo "deb-src ${LOCAL_MIRROR} ${rel} $i" >> ${src_l}
            fi
        done
    done
    apt-get update -qq
    die_if_error
    touch "$mirror_marker"
fi

if [ ! -e "$MARKERS/vbox_init_global_upgrade" ];then
    output " [*] Upgrading base image (apt-get upgrade & dist-upgrade)"
    apt-get update -qq && apt-get upgrade -y && apt-get dist-upgrade -y
    die_if_error
    touch "$MARKERS/vbox_init_global_upgrade"
fi

use_backports=""
if [[ -n "$BEFORE_SAUCY" ]];then
    backport_saucy
    use_backports="y"
fi

if [[ -n "$NEED_RESTART" ]];then
    output " [*] The first time, you need to reload the new kernel and reprovision the box."
    output " [*] For that, issue now 'vagrant reload'"
    exit -1
fi

if [[ -n "$use_backports" ]] &&  [[ ! -e "$kernel_marker" ]];then
    output " [*] The first time, you need to reload the new kernel and reprovision."
    output " [*] For that, issue now 'vagrant reload'"
    exit -1
fi
if [ ! -e $MARKERS/provision_step_nfs_done ]; then
  output " [*] Install nfs support on guest"
  apt-get install -q -y --force-yes nfs-common portmap || die_if_error
  touch $MARKERS/provision_step_nfs_done
fi
if [ ! -e $MARKERS/provision_step_lxc_done ]; then
  output " [*] Install lxc-docker support"
  # Add lxc-docker package
  wget -c -q -O - https://get.docker.io/gpg | apt-key add -
  echo deb http://get.docker.io/ubuntu docker main > ${src_l}.d/docker.list
  output " [*] Install lxc-docker support: refresh packages list"
  apt-get update -qq || die_if_error
  output " [*] Install lxc-docker support: install lxc-docker package"
  apt-get install -q -y --force-yes lxc-docker || die_if_error
  # autorestart dockers on boot
  killall -9 docker
  service docker stop
  sed -re "s/docker -d/docker -r -d/g" -e /etc/init/docker.conf
  service docker start
  die_if_error
  touch $MARKERS/provision_step_lxc_done
  # since apparmor backport, seem we have not to reboot anymore
  # NEED_RESTART="1"
fi
if [ ! -e $MARKERS/provision_step_lang_done ]; then
  output " [*] Fix French language"
  apt-get install -q -y --force-yes language-pack-fr
  echo>/etc/locale.gen
  echo "en_US.UTF-8 UTF-8">>/etc/locale.gen
  echo "en_US ISO-8859-1">>/etc/locale.gen
  echo "de_DE.UTF-8 UTF-8">>/etc/locale.gen
  echo "de_DE ISO-8859-1">>/etc/locale.gen
  echo "de_DE@euro ISO-8859-15">>/etc/locale.gen
  echo "fr_FR.UTF-8 UTF-8">>/etc/locale.gen
  echo "fr_FR ISO-8859-1">>/etc/locale.gen
  echo "fr_FR@euro ISO-8859-15">>/etc/locale.gen
  echo 'LANG="fr_FR.utf8"'>/etc/default/locale
  echo "export LANG=\${LANG:-fr_FR.UTF-8}">>/etc/profile.d/0_lang.sh
  /usr/sbin/locale-gen || die_if_error
  update-locale LANG=fr_FR.utf8 || die_if_error
  if [ "0" == "$?" ];then touch $MARKERS/provision_step_lang_done; fi;
fi
if [[ ! -e $MARKERS/salt_bootstrap_done ]];then
  output " [ * ] Bootstrap Salt-Stack env..."
  if [ -e /src/salt/makina-states/src/salt ];then
    sed -re "s/filemode = true/filemode = false/g" -i /src/salt/makina-states/src/*/.git/config
  fi
  ms_updated=""
  if [[ -e /srv/salt/makina-states/.git ]];then
      output " [ * ] Bootstrap mode update in makina-states.."
      cd /srv/salt/makina-states
      git pull && ms_updated="1"
  fi
  if [[ -z $ms_updated ]];then
      output " [ * ] Running makina-states bootstrap directly from github"
      wget http://raw.github.com/makinacorpus/makina-states/master/_scripts/boot-salt.sh -O - | bash
  else
      output " [ * ] Running makina-states bootstrap"
      /srv/salt/makina-states/_scripts/boot-salt.sh
  fi
  die_if_error
  . /etc/profile
  touch $MARKERS/salt_bootstrap_done
fi
# migrate existing vms, be sure to have everywhere the same setup
NEED_REDO=""
EDITOR_GID="$(salt-call --local pillar.get salt.filesystem.gid 65753|grep -v 'local:'|sed -re 's/\s//g')"
EDITOR_GROUP="$(salt-call --local pillar.get salt.filesystem.group editor|grep -v 'local:'|sed -re 's/\s//g')"
oldg=$(getent group "$EDITOR_GID"|awk -F: '{print $1}')
if [[ "$oldg" != "$EDITOR_GROUP" ]];then
    output " [*] Changing Editor Group from '$oldg' to '$EDITOR_GROUP'"
    groupmod "$oldg" -n "$EDITOR_GROUP"
    NEED_REDO="y"
fi
if [[ -e /srv/salt-venv ]];then
    rm -rf /srv/salt-venv
    NEED_REDO="y"
fi
if [[ ! -e $VENV_PATH ]];then
    NEED_REDO="y"
fi
if [[ ! -e /srv/salt/setup.sls ]] || [[ ! -e /srv/salt/top.sls ]];then
    NEED_REDO="y"
fi
initialize_devel_salt_grains
vm_boot_mode=$(get_grain $BOOT_GRAIN)
if [[ $(egrep -- "- makina-states\.dev\s*" /srv/salt/top.sls|wc -l) == "0" ]];then
    output " [*] Old installation detected for makina-stes.dev top file"
    NEED_REDO=1
fi
if [[ "$vm_boot_mode" != *"True"* ]];then
    output " [*] Old installation detected for boot grain, updating salt"
    NEED_REDO=1
fi
if [[ -n "$NEED_REDO" ]];then
    output " [*] Updating code"
    cd /srv/salt/makina-states
    git pull origin master
    cd /srv/salt/makina-states/src/salt
    git pull origin develop
    output " [*] Running salt state setup"
    /srv/salt/makina-states/_scripts/boot-salt.sh
fi

if [[ -n "$NEED_RESTART" ]];then
    output "You need to reboot, issue 'vagrant reload'"
    exit $NEED_RESTART
fi

#deactivate_ifup_debugging
cleanup_space() {
    output " [*] Cleaning vm to reduce disk space usage"
    output " [*] Cleaning apt"
    apt-get clean -y
    apt-get autoclean -y
    # cleanup archives to preserve vm SPACE
    if [[ $(find /var/cache/apt/archives/ -name *deb|wc -l) != "0" ]];then
        rm -rf /var/cache/apt/archives/*deb
    fi
}

cleanup_space

# Always start salt and docker AFTER /srv has been mounted on the VM
output " [*] Manage Basic daemons using /srv"
output " [*] /srv is mounted quite late so we must start some daemons later"

# kill salt that may be running
ps aux|egrep "salt-(master|minion|syndic)"|awk '{print $2}'|xargs kill -9 &> /dev/null
service salt-master start
#rm -rf /etc/salt/pki/minion/minion_master.pub

service salt-minion start
service docker stop
service docker start

open_routes

ready_to_run
# vim:set et sts=4 ts=4 tw=0:
