#!/usr/bin/env bash

# This script is ubuntu specific for the moment.
# Script is supposed to be run on development VMs (Virtualbox)
# This will install correctly NFS client, salt, makina-states, docker & virtualbox extensions
#
# Beware on raring and saucy baremetal vms, this script is not safe
# as it backport a lot of saucy packages, see ../backport-pgks.sh
# for backporting things on a bare metal machine
#
# In there we have only core configuration (network, ssh access, salt init)
# The rest is done salt side, see makina-states.nodetypes.vagrantvm
#
#

YELLOW='\e[1;33m'
RED="\\033[31m"
CYAN="\\033[36m"
NORMAL="\\033[0m"
if [[ -n $NO_COLORS ]];then
    YELLOW=""
    RED=""
    CYAN=""
    NORMAL=""
fi
DEBUG=${BOOT_SALT_DEBUG:-}
output() { echo -e "${YELLOW}$@${NORMAL}" >&2; }
log() { output "$@"; }
die_if_error() { if [[ "$?" != "0" ]];then output "There were errors";exit 1;fi; }

detect_os() {
    # make as a function to be copy/pasted as-is in multiple scripts
    IS_UBUNTU=""
    IS_DEBIAN=""
    IS_DEBIAN_LIKE=""
    if [[ -e $CONF_ROOT/lsb-release ]];then
        . $CONF_ROOT/lsb-release
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
        if [[ "$DISTRIB_ID" == "Ubuntu" ]];then
            IS_UBUNTU="y"
        fi
    fi
    if [[ -e "$CONF_ROOT/os-release" ]];then
        OS_RELEASE_ID=$(egrep ^ID= $CONF_ROOT/os-release|sed -re "s/ID=//g")
        OS_RELEASE_NAME=$(egrep ^NAME= $CONF_ROOT/os-release|sed -re "s/NAME=""//g")
        OS_RELEASE_VERSION=$(egrep ^VERSION= $CONF_ROOT/os-release|sed -re "s/VERSION=/""/g")
        OS_RELEASE_PRETTY_NAME=$(egrep ^PRETTY_NAME= $CONF_ROOT/os-release|sed -re "s/PRETTY_NAME=""//g")

    fi
    if [[ -e $CONF_ROOT/debian_version ]] && [[ "$OS_RELEASE_ID" == "debian" ]] && [[ "$DISTRIB_ID" != "Ubuntu" ]];then
        IS_DEBIAN="y"
        SALT_BOOT_OS="debian"
        DISTRIB_CODENAME="$(echo $OS_RELEASE_PRETTY_NAME |sed -re "s/.*\((.*)\).*/\1/g")"
    fi
    if [[ -n "$IS_UBUNTU" ]];then
        SALT_BOOT_OS="ubuntu"
        DISTRIB_NEXT_RELEASE="saucy"
        DISTRIB_BACKPORT="$DISTRIB_NEXT_RELEASE"
    elif [[ -n "$IS_DEBIAN" ]];then
        if [[ "$DISTRIB_CODENAME"  == "wheezy" ]];then
            DISTRIB_NEXT_RELEASE="jessie"
        elif [[ "$DISTRIB_CODENAME"  == "squeeze" ]];then
            DISTRIB_NEXT_RELEASE="wheezy"
        fi
        DISTRIB_BACKPORT="wheezy-backports"
    fi
    if [[ -n "$IS_UBUNTU" ]] || [[ -n "$IS_DEBIAN" ]];then
        IS_DEBIAN_LIKE="y"
    fi
}

set_vars() {
    ROOT="/"
    CONF_ROOT="${CONF_ROOT:-"${ROOT}etc"}"
    PREFIX="${PREFIX:-"${ROOT}srv"}"
    SALT_ROOT="${SALT_ROOT:-"$PREFIX/salt"}"
    MASTERSALT_ROOT="${MASTERSALT_ROOT:-"$PREFIX/mastersalt"}"
    # source a maybe existing settings file
    SETTINGS="${SETTINGS:-"${ROOT}root/vagrant/provision_settings.sh"}"
    if [[ -f "$SETTINGS" ]];then
        output " [*] Loading custom settings in $SETTINGS"
        . "$SETTINGS"
    fi
    MS="$SALT_ROOT/makina-states"
    MMS="$MASTERSALT_ROOT/makina-states"
    VPREFIX="${PREFIX:-"$PREFIX/vagrant"}"
    VBOX_ADD_VER="4.2.16"

    # Markers must not be on a shared folder for a new VM to be reprovisionned correctly
    VENV_PATH="${ROOT}salt-venv"
    MARKERS="${MARKERS:-"${ROOT}root/vagrant/markers"}"
    DNS_SERVER="${DNS_SERVER:-"8.8.8.8"}"
    PREVIOUS_OFFICIAL_MIRROR="${PREVIOUS_OFFICIAL_MIRROR:-"http://archive.ubuntu.com/ubuntu"}"
    PREVIOUS_LOCAL_MIRROR="${PREVIOUS_LOCAL_MIRROR:-"http://fr.archive.ubuntu.com/ubuntu"}"
    OFFICIAL_MIRROR="${OFFICIAL_MIRROR:-"http://archive.ubuntu.com/ubuntu"}"
    LOCAL_MIRROR="${LOCAL_MIRROR:-"http://fr.archive.ubuntu.com/ubuntu"}"
    UBUNTU_RELEASE="${UBUNTU_RELEASE:-"raring"}"
    UBUNTU_NEXT_RELEASE="${UBUNTU_NEXT_RELEASE:-"saucy"}"
    DOCKER_DISABLED="${DOCKER_DISABLED:-no}"
    if [[ "$DOCKER_DISABLED" != "yes" ]];then
        DOCKER_DISABLED=""
    fi
    DOCKER_NETWORK_HOST_IF="${DOCKER_NETWORK_HOST_IF:-eth0}"
    DOCKER_NETWORK_IF="${DOCKER_NETWORK_IF:-docker0}"
    DOCKER_NETWORK_GATEWAY="${DOCKER_NETWORK_GATEWAY:-"172.17.42.1"}"
    DOCKER_NETWORK="${DOCKER_NETWORK:-"172.17.0.0"}"
    DOCKER_NETWORK_MASK="${DOCKER_NETWORK_MASK:-"255.255.0.0"}"
    DOCKER_NETWORK_MASK_NUM="${DOCKER_NETWORK_MASK_NUM:-"16"}"
    restart_marker=/tmp/vagrant_provision_needs_restart

    # disable some useless and harmfull services
    CHRONO="$(date "+%F_%H-%M-%S")"

    detect_os

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
    export_marker="$MARKERS/exported"
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
    bootsalt_marker="$MARKERS/salt_bootstrap_done"
}

ready_to_run() {
    output " [*] VM is now ready for './manage.sh ssh' or other usages..."
    output " ------------------------------- [ OK] -----------------------------------------"
    output " Once connected as root in the vm with \"./manage.sh ssh\" and \"sudo su -\""
    output "   * You can upgrade all your projects with \"salt-call [-l all] state.highstate\""
    output "   * You can run one specific state with \"salt-call [-l all] state.sls name-of-state\""
    output " If you want to share this wm, use ./manage.sh export | import"
    output " Stop vm with './manage.sh down', connect it with './manage.sh ssh'"
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

delete_old_stuff() {
    # delete old generated scripts
    for old in /root/provision_nfs.sh \
        /root/vagrant_provision_settings.sh;do
        if [[ -e "$old" ]];then
            rm -f "$old"
        fi
    done
    if [[ -e /srv/salt-venv ]];then
        rm -rf /srv/salt-venv
    fi
}

get_grain() {
    salt-call --local grains.get $1 --out=raw 2>/dev/null
}

is_apt_installed() {
    if [[ $(dpkg-query -s $@ 2>/dev/null|egrep "^Status:"|grep installed|wc -l)  == "0" ]];then
        echo "no"
    else
        echo "yes"
    fi
}

lazy_apt_get_install() {
    to_install=""
    for i in $@;do
         if [[ $(is_apt_installed $i)  != "yes" ]];then
             to_install="$to_install $i"
         fi
    done
    if [[ -n "$to_install" ]];then
        output " [*] Installing $to_install"
        apt-get install -y --force-yes $to_install
    fi
}

salt_set_grain() {
    grain=$1
    val=$2
    output " [*] Testing salt grain '$grain'='$val'"
    if [[ "$(get_grain $grain)" != *"$val"* ]];then
        output " [*] Setting salt grain $grain=$val to mark this host as a dev host for salt-stack"
        salt-call --local grains.setval $grain $val
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

backport_for_raring() {
    if [[ ! -e "$vbox_marker" ]];then
        output " [*] Installing  $VB_PKGS"
        apt-get install -y --force-yes $VB_PKGS
        die_if_error
        touch "$vbox_marker" "$restart_marker"
    fi
    if [[ ! -e "${kernel_marker}" ]];then
        output " [*] Updating kernel"
        apt-get update -qq apt-get install -y --force-yes linux-image &&\
        touch "$kernel_marker" && touch "$restart_marker"
    fi
}


backport_for_precise() {
    output " [*] Backporting LTS Hardware Enablement Stack kernel"
    if [[ ! -e $kernel_marker ]];then
        lazy_apt_get_install\
            dkms\
            linux-image-generic-lts-raring build-essential\
            xserver-xorg xserver-xorg-core \
            linux-headers-generic-lts-raring\
            && touch "$kernel_marker"
        touch $restart_marker
    fi
    if [[ ! -f /root/vagrant/vboxguest${VBOX_ADD_VER}.ok ]]; then
        output " [*] Enforce VBoxGuestAdditions ${VBOX_ADD_VER}..."
        cd /tmp
        output " [*] Downloading virtualbox additionsi iso" &&\
            wget -qc http://dlc.sun.com.edgesuite.net/virtualbox/${VBOX_ADD_VER}/VBoxGuestAdditions_${VBOX_ADD_VER}.iso &&\
            output " [*] mounting them" &&\
            if [[ "$(mount|grep VBoxGuest|wc -l)" == "0" ]];then
                mount -o loop,ro /tmp/VBoxGuestAdditions_${VBOX_ADD_VER}.iso /mnt
            fi &&\
            lazy_apt_get_install&&\
            output " [*] installing them" &&\
            echo yes | /mnt/VBoxLinuxAdditions.run ;/bin/true
            output " [*] unmounting them" &&\
            touch /root/vagrant/vboxguest${VBOX_ADD_VER}.ok
            touch $restart_marker
    else
        if [[ -f /tmp/VBoxGuestAdditions_${VBOX_ADD_VER}.iso ]];then
            output " [*] Removing old additions iso"
            rm -f /tmp/VBoxGuestAdditions_${VBOX_ADD_VER}.iso
        fi
    fi
}

cleanup_restart_marker() {
    if [[ -e "$restart_marker" ]];then
        output " [*] Removing restart marker"
        rm -f "$restart_marker"
    fi
}

configure_network() {
    output " [*] Temporary DNs overrides in /etc/resolv.conf : ${DNS_SERVER}, 8.8.8.8 & 4.4.4.4"
    if [[ "$(egrep "\s+localhost" /etc/hosts|wc -l)" == "0" ]];then
        # add localhost if missing
        sed "/127.0.0.1/ {
a 127.0.0.1 localhost
}" -i /etc/hosts
    fi
    # DNS TMP OVERRIDE
    cat > /etc/resolv.conf << DNSEOF
nameserver ${DNS_SERVER}
nameserver 8.8.8.8
nameserver 4.4.4.4
DNSEOF
}

configure_docker_network() {
    # Create the docker0 bridge before docker does it to hard-fcode
    # the docker network address
    if_file="/etc/network/interfaces.${DOCKER_NETWORK_IF}"
    if_conf="$if_file.conf "
    NETWORK_RESTART=""
    #activate_ifup_debugging
    lazy_apt_get_install git git-core bridge-utils

    if [[ "$(egrep "^source.*docker0" /etc/network/interfaces|wc -l)" == "0" ]];then
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
}

initial_upgrade() {
    marker="$MARKERS/vbox_init_global_upgrade"
    if [[ ! -e "$marker" ]] || [[ $DEVHOST_AUTO_UPDATE != "false" ]];then
        output " [*] Upgrading base image"
        if [[ -n "$IS_DEBIAN_LIKE" ]];then
            output " [*] apt-get upgrade & dist-upgrade"
            apt-get update -qq &&\
                install_backports &&\
                apt-get upgrade -y &&\
                apt-get dist-upgrade -y --force-yes
        fi
        die_if_error
        touch "$marker"
    fi
}

create_base_dirs() {
    # Create basic directories
    for p in "$PREFIX" "$MARKERS";do
        if [[ ! -e $p ]];then
            mkdir -pv "$p"
        fi
    done
    ## disabled as now this part is NFS shared whereas
    ## salt & projects parts are not
    ## # initial sync which will be done by unison later
    ## rsync -Aazv /nfs-srv/ /srv/\
    ##     --exclude=docker/ubuntu-*-server-cloudimg-amd64-root*\
    ##     --exclude=docker/cache/*\
    ##     --exclude=docker/*/*/deboostrap*\
    ##     --exclude=packer/*cache/*
}

check_restart() {
    if [[ -e $restart_marker ]];then
        output " [*] A restart trigger to finish to provision the box has been detected."
        output " [*] For that, issue now '$0 reload'"
        exit 1
    fi
}

install_backports() {
    if [[ -n "$IS_UBUNTU" ]];then
        if [[ "$DISTRIB_CODENAME" == "raring" ]]\
            || [[ "$DISTRIB_CODENAME" == "precise" ]];then
            backport_for_${DISTRIB_CODENAME}
        fi
        if [[ -z "$BEFORE_RARING" ]];then
            if [[ "$(is_apt_installed linux-image-extra-virtual)" != "yes" ]];then
                output " [*] Installing linux-image-extra-virtual for AUFS support"
                lazy_apt_get_install linux-image-extra-virtual
                touch $restart_marker
            fi
        fi
        check_restart
    fi
}

run_boot_salt() {
    bootsalt="$MS/_scripts/boot-salt.sh"
    boot_args="-C -M -n vagrantvm"
    if [[ ! -e "$bootsalt_marker" ]];then
        boot_word="Bootstrap"
    else
        boot_word="Refresh"
        boot_args="-S $boot_args"
    fi
    output " [*] $boot_word makina-states..."
    if [[ ! -e "$bootsalt" ]];then
        output " [*] Running makina-states bootstrap directly from github"
        wget "http://raw.github.com/makinacorpus/makina-states/master/_scripts/boot-salt.sh" -O "/tmp/boot-salt.sh"
        bootsalt="/tmp/boot-salt.sh"
    fi
    chmod u+x "$bootsalt"
    # no confirm / saltmaster / nodetype: vagrantvm
    #
    # for now we disable automatic updates when we have done at least one salt deployment
    #
    if [[ ! -e "$bootsalt_marker" ]];then
        "$bootsalt" $boot_args && touch "$bootsalt_marker"
    fi
    die_if_error
    . /etc/profile
}

test_online() {
    ping -W 10 -c 1 8.8.8.8 &> /dev/null
    echo $?
}

install_or_refresh_makina_states() {
    if [ -e $MS/src/salt ];then
          sed -re "s/filemode = true/filemode = false/g" -i $MS/src/*/.git/config
    fi
    # upgrade salt only if online
    if [[ $(test_online) == "0" ]];then
        run_boot_salt
    else
        if [[ ! -e "$bootsalt_marker" ]];then
            output " [*] Warning, we are not online, and thus boot-salt can't be runned"
            exit -1
        else
            output " [*] Warning, we are not online, not refreshing makina-states!"
        fi
    fi
}

old_editor_group_stuff() {
    if [[ -e "$(which salt-call 2> /dev/null)" ]];then
        EDITOR_GID="$(salt-call --local pillar.get salt.filesystem.gid 65753|grep -v 'local:'|sed -re 's/\s//g')"
        EDITOR_GROUP="$(salt-call --local pillar.get salt.filesystem.group editor|grep -v 'local:'|sed -re 's/\s//g')"
    fi
    oldg=$(getent group "$EDITOR_GID"|awk -F: '{print $1}')
    if [[ "$oldg" != "$EDITOR_GROUP" ]];then
        output " [*] Changing Editor Group from '$oldg' to '$EDITOR_GROUP'"
        groupmod "$oldg" -n "$EDITOR_GROUP"
    fi
}

fix_apt()   {
    apt-get -f install -y --force-yes
}

cleanup_space() {
    sync
    if [[ -n "$IS_DEBIAN_LIKE" ]];then
        # dropeed by makina-states.nodetypes.vagrantvm
        /sbin/system-cleanup.sh
    fi
}

base_packages_sanitization() {
    if [[ -n "$IS_DEBIAN_LIKE" ]];then
        fix_apt
    fi
    initial_upgrade
}

disable_base_box_services() {
    marker="$MARKERS/disabled_base_box_services"
    if [[ ! -e "$marker" ]];then
        for i in puppet chef-client;do
            if [[ "$i" == "chef-client" ]];then
                ps aux|grep -- "$i"|awk '{print $2}'|xargs kill -9
            fi
            if [[ -f /etc/init.d/$i ]];then
                output " [*] Disabling $i"
                service $i stop
                update-rc.d -f $i remove
                # seems that some package updates are re-enabling it
                # enforce inactivation
                echo "START=no" > /etc/default/$i
            fi
        done
        touch "$marker"
    fi
}

migrate_old_stuff() {
    # migrate old settings location
    if [[ ! -e /root/vagrant/provision_settings.sh ]];then
        cp -f /root/vagrant_provision_settings.sh /root/vagrant/provision_settings.sh
    fi
    delete_old_stuff
    # no more vms with that old stuff
    # old_editor_group_stuff
}

cleanup_keys() {
    lazy_apt_get_install rsync
    for user_home in $(awk -F: '{if ($6!="") print $1 ":" $6}' /etc/passwd);do
        user="$(echo $user_home|awk -F: '{print $1}')"
        home="$(echo $user_home|awk -F: '{print $2}')"
        sshf="$home/.ssh"
        if [[ -e "$sshf" ]];then
            for i in $(ls $sshf);do
                fulli="$sshf/$i"
                cleanup=y
                # only keep authorized* files
                case $i in
                    author*) cleanup="";
                        ;;
                esac
                if [[ -n $cleanup ]];then
                    rm -fvr "$fulli"
                fi
            done
        fi
    done
}

install_keys() {
    lazy_apt_get_install rsync
    users="vagrant root"
    for user in $users;do
        home=$(awk -F: -v v="$user" '{if ($1==v && $6!="") print $6}' /etc/passwd)
        if [[ -e "$home" ]];then
            rsync\
                -a\
                --exclude=authorized_keys* \
                /mnt/parent_ssh/ "$home/.ssh/"
            for i in /home/vagrant/.ssh/author*;do
                dest=$home/.ssh/$(basename $i)
                if [[ "$i" != "$dest" ]];then
                    cp -rf "$i" "$dest"
                fi
            done
            chmod -Rf 700 "$home/.ssh"
            chown -Rf $user "$home/.ssh"
        fi
    done
}

cleanup_salt() {
    output " [*] Resetting all salt configuration information"
    rm -rvf /var/cache/salt/* /var/cache/mastersalt/* 2> /dev/null
    rm -rvf /var/log/salt/* /var/log/mastersalt/* 2> /dev/null
    rm -vf /srv/*pillar/{mastersalt,salt}.sls
    rm -vf /etc/*salt/minion_id "$bootsalt_marker"
    find /etc/*salt/pki -type f -delete
    if [[ -e /srv/pillar/top.sls ]];then
        sed -re /"\s*- salt/ d" -i /srv/pillar/top.sls
    fi
    if [[ -e /srv/mastersalt-pillar/top.sls ]];then
        sed -re /"\s*- mastersalt/ d" -i /srv/mastersalt-pillar/top.sls
    fi
}

mark_export() {
    output " [*] Cleaning and marking vm as exported"
    cleanup_keys
    cleanup_misc
    # cleanup_salt
    touch  "$export_marker"
}

unmark_exported() {
    output " [*] Cleaning and unmarking vm as exported"
    rm -f  "$export_marker"
}

kill_pids(){
    for i in $@;do
        if [[ -n $i ]];then
            kill -9 $i
        fi
    done
}

cleanup_misc() {
    rm -vf /etc/devhosts
    for user_home in $(awk -F: '{if ($6!="") print $1 ":" $6}' /etc/passwd);do
        user="$(echo $user_home|awk -F: '{print $1}')"
        home="$(echo $user_home|awk -F: '{print $2}')"
        if [[ -e "$home/.bash_history" ]];then
            rm -vf $home/.bash_history
        fi
    done
}

reset_hostname() {
    if [[ -n "$DEVHOST_HOSTNAME" ]];then
        local fqdn="$DEVHOST_HOSTNAME"
        local dn="$(echo "$DEVHOST_HOSTNAME"|awk -F\. '{print $1}')"
        if [[ "$(hostname)" != "$dn" ]];then
            output " [*] Reseting hostname: $dn"
            hostname "$dn"
        fi
        if [[ "$(cat /etc/hostname &> /dev/null)" != "$dn" ]];then
            output " [*] Reseting /etc/hostname: $dn"
            echo "$dn">/etc/hostname
        fi
        if [[ "$(egrep "127\\..*$hostname" /etc/hosts 2> /dev/null)" != "$dn" ]];\
        then
            output " [*] Reset hostname to /etc/hosts"
            cp -f /etc/hosts /etc/hosts.bak
            echo "127.0.0.1 $dn $fqdn">/etc/hosts
            cat /etc/hosts.bak>>/etc/hosts
            echo "127.0.0.1 $dn $fqdn">>/etc/hosts
            rm -f /etc/hosts.bak
        fi
        if [[ -e /etc/init/nscd.conf ]] || [[ -e /etc/init.d/nscd ]];then
            service nscd restart
        fi
    fi
}

detected_old_changesets() {
    # bugged releases, list here old makinastates git commit ids to mark as to
    # upgrade on import
    echo "723f485750bff7f34835755030b790f046859fc5"
}

git_changeset() {
    # current working directory git commit id
    git log|head -n1|awk '{print $2}'
}


handle_export() {
    if [[ -e "$export_marker" ]];then
        output " [*] VM export detected, resetting some stuff"
        # reset salt minion id and perms
        for i in mastersalt salt;do
            for j in minion master syndic;do
                service "${i}-${j}" stop &> /dev/null
                kill_pids $(ps aux|grep "${i}-${j}"|awk '{print $2}') &> /dev/null
            done
        done
        cleanup_misc
        cleanup_salt
        # no auto update unless configured
        if [[ $DEVHOST_AUTO_UPDATE != "false" ]];then
            export SALT_BOOT_SKIP_CHECKOUTS=""
            export SALT_BOOT_SKIP_HIGHSTATES=""
        else
            export SALT_BOOT_SKIP_CHECKOUTS=1
            export SALT_BOOT_SKIP_HIGHSTATES=1

        fi
        # remove vagrant conf as it can contain doublons on first load
        output " [*] Reset network interface file"
        sed -ne "/VAGRANT-BEGIN/,\$!p" /etc/network/interfaces > /etc/network/interfaces.buf
        if [[ "$(grep lo /etc/network/interfaces|grep -v grep|wc -l)" != "0" ]];then
            cp -f /etc/network/interfaces.buf /etc/network/interfaces
            rm -f /etc/network/interfaces.buf
        fi
        # on import, check that the bundled makina-states is not marked as
        # to be upgraded, and in case upgrade it
        if [[ $(test_online) == "0" ]];then
            for i in /srv/{salt,mastersalt}/makina-states;do
                if [[ -e "$i" ]];then
                    cd "$i"
                    if [[ $(detected_old_changesets) == *"$(git_changeset)"* ]];then
                        output " [*] Upgrade makina-states detected, going to pull the master"
                        git fetch origin
                        git reset --hard origin/master
                    fi
                    cd - &>/dev/null
                fi
            done
        else
            output " [*] Warning, cant update makina-states, offline"
        fi
        unmark_exported
    fi
}

get_devhost_num() {
    echo $DEVHOST_NUM
}

if [[ -z $VAGRANT_PROVISION_AS_FUNCS ]];then
    output " [*] STARTING MAKINA VAGRANT PROVISION SCRIPT: $0"
    output " [*] You can safely relaunch this script from within the vm"
    set_vars
    reset_hostname
    #
    install_keys
    handle_export
    create_base_dirs
    disable_base_box_services
    cleanup_restart_marker
    migrate_old_stuff
    configure_network
    base_packages_sanitization
    install_or_refresh_makina_states
    open_routes
    cleanup_space
    check_restart
    ready_to_run
    sync
fi
# vim:set et sts=4 ts=4 tw=0:
