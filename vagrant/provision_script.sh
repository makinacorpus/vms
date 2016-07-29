#!/usr/bin/env bash
# This script is ubuntu specific for the moment.
# Script is supposed to be run on development VMs (Virtualbox)
# This will install correctly NFS client, salt, makina-states, docker & virtualbox extensions
# In there we have only core configuration (network, ssh access, salt init)
# The rest is done salt side, see makina-states.nodetypes.vagrantvm

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
DEBUG=${BOOT_SALT_DEBUG:-${DEBUG}}
red_output() { echo -e "${RED}$@${NORMAL}" >&2; }
output() { echo -e "${YELLOW}$@${NORMAL}" >&2; }
log() { output "$@"; }

ERROR_MSG="There were errors"

deactivate_debug() {
    if [ "x${DEBUG}" != "x" ];then set +x;fi
}

activate_debug() {
    if [ "x${DEBUG}" != "x" ];then set -x;fi
}

die_() {
    ret=$1
    shift
    echo -e "${CYAN}${@}${NORMAL}" 1>&2
    exit $ret
}

die() {
    die_ 1 $@
}

die_in_error_() {
    local ret=$1
    shift
    local msg="${@:-"$ERROR_MSG"}"
    if [[ "$ret" != "0" ]];then
        die_ "$ret" "$msg"
    fi
}

die_in_error() {
    die_in_error_ "${?}" "$@"
}

detect_os() {
    # make as a function to be copy/pasted as-is in multiple scripts
    IS_UBUNTU=""
    IS_DEBIAN=""
    IS_DEBIAN_LIKE=""
    if [[ -e $CONF_ROOT/lsb-release ]];then
        . $CONF_ROOT/lsb-release
        if [ "x$DISTRIB_ID" = "xUbuntu" ];then
            ret=${?}
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
    if [[ -n "${IS_UBUNTU}" ]];then
        SALT_BOOT_OS="ubuntu"
    fi
    if [[ -n "${IS_UBUNTU}" ]] || [[ -n "$IS_DEBIAN" ]];then
        IS_DEBIAN_LIKE="y"
    fi
}

set_vars() {
    NOT_EXPORTED="^(proc|sys|dev|lost+found|guest|vmlinu.*)\$"
    VM_EXPORT_MOUNTPOINT="/guest"
    MS_BRANCH="${MS_BRANCH:-master}"
    MS_NODETYPE="${MS_NODETYPE:-vagrantvm}"
    ROOT="/"
    CONF_ROOT="${CONF_ROOT:-"${ROOT}etc"}"
    PREFIX="${PREFIX:-"${ROOT}srv"}"
    # source a maybe existing settings file
    SETTINGS="${SETTINGS:-"${ROOT}root/vagrant/provision_settings_${DEVHOST_MACHINE}.sh"}"
    if [ "x${WANT_SETTINGS}" != "x" ] && [ ! -f "$SETTINGS" ];then
        echo "settings not found: ${SETTINGS}"
        exit 1
    fi
    if [ -f "$SETTINGS" ];then
        output " [*] Loading custom settings in ${SETTINGS}"
        . "$SETTINGS"
    fi
    MS_BOOT_ARGS="${MS_BOOT_ARGS:-"-C -M -MM --mastersalt localhost -b ${MS_BRANCH} -n ${MS_NODETYPE} -m devhost${DEVHOST_NUM}.local"}"
    # Markers must not be on a shared folder for a new VM to be reprovisionned correctly
    MARKERS="${MARKERS:-"${ROOT}root/vagrant/markers"}"
    DNS_SERVERS="${DNS_SERVERS:-"8.8.8.8 4.4.4.4"}"
    APT_MIRROR="${APT_MIRROR:-"http://fr.archive.ubuntu.com/ubuntu"}"
    restart_marker=/tmp/vagrant_provision_needs_restart
    # disable some useless and harmfull services
    detect_os
    # order is important
    export_marker="$MARKERS/exported"
    NEED_RESTART=""
    export DEBIAN_FRONTEND="noninteractive"
    bootsalt_marker="$MARKERS/salt_bootstrap_done"
}

ready_to_run() {
    output " [*] VM is now ready for './manage.sh ssh' or other usages..."
    output " ------------------------------- [ OK] -----------------------------------------"
    output " Once connected as root in the vm with \"./manage.sh ssh\" and \"sudo su -\""
    output "   * You can run one specific state with \"(master)salt-call [-l all] state.sls name-of-state\""
    output " If you want to share this wm, use ./manage.sh export | import"
    output " Stop vm with './manage.sh down', connect it with './manage.sh ssh'"
}

is_mounted() {
    local mounted=""
    local mp="$1"
    if [[ "$(mount|awk '{print $3}'|egrep "$mp$"|wc -l)" != "0" ]];then
        mounted="1"
    fi
    echo $mounted
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
ret=\${?}
echo \$(date) \$0 \$@ END >>/ifup.debug
exit \$ret
EOF
        chmod +x /sbin/ifup
    fi
}

get_grain() {
    /srv/makina-states/_scripts/salt-call grains.get $1 --out=raw 2>/dev/null
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
         if [ "x$(is_apt_installed $i)"  != "xyes" ];then
             to_install="$to_install $i"
         fi
    done
    if [[ -n "$to_install" ]];then
        output " [*] Installing $to_install"
        apt-get install -y --force-yes $to_install
    fi
}

open_routes() {
    output " [*] allow routing of traffic coming from dev host going to docker net"
    sysctl -w net.ipv4.ip_forward=1
    sysctl -w net.ipv4.conf.all.rp_filter=0
    sysctl -w net.ipv4.conf.all.log_martians=1
}

cleanup_restart_marker() {
    if [ -e "${restart_marker}" ];then
        output " [*] Removing restart marker"
        rm -f "${restart_marker}"
    fi
}

configure_dns() {
    NSADD="${DNS_SERVERS} 8.8.8.8 4.4.4.4"
    if [ "x${IS_UBUNTU}" != "x" ];then NSADD="127.0.0.1 ${NSADD}";fi
    output " [*] Temporary DNS overrides in /etc/resolv.conf : ${NSADD}"
    ensure_localhost_in_hosts
    for resolv in /etc/resolv.conf /etc/resolvconf/resolv.conf.d/head;do
        if [ -e $resolv ];then
            echo > ${resolv}
            for i in ${NSADD};do
                if grep -vq ${i} ${resolv};then
                    echo "nameserver ${i}" >> ${resolv};
                fi
            done
        fi
    done
    if [ -e /etc/resolvconf/resolv.conf.d/head ];then
        service resolvconf restart
        /bin/true
    fi
}

initial_upgrade() {
    initial_upgrade_marker="$MARKERS/vbox_init_global_upgrade"
    local force_apt_update=""
    if [ -e "$export_marker" ] && [ $DEVHOST_AUTO_UPDATE != "false" ];then
        force_apt_update="1"
    fi
    if [ ! -e "${initial_upgrade_marker}" ] || [ "x${force_apt_update}" != "x" ];then
        output " [*] Upgrading base image"
        if [ "x${IS_DEBIAN_LIKE}" != "x" ];then
            output " [*] apt-get upgrade & dist-upgrade"
            cn=$(lsb_release -sc)
            if [ "${IS_UBUNTU}" != "x" ];then
                cat > /etc/apt/sources.list << EOF
deb     http://archive.ubuntu.com/ubuntu/ ${cn} main restricted universe multiverse
deb-src http://archive.ubuntu.com/ubuntu/ ${cn} main restricted universe multiverse
deb     http://archive.ubuntu.com/ubuntu/ ${cn}-proposed main restricted universe multiverse
deb-src http://archive.ubuntu.com/ubuntu/ ${cn}-proposed main restricted universe multiverse
deb     http://archive.ubuntu.com/ubuntu/ ${cn}-updates main restricted universe multiverse
deb-src http://archive.ubuntu.com/ubuntu/ ${cn}-updates main restricted universe multiverse
deb     http://archive.ubuntu.com/ubuntu/ ${cn}-security main restricted universe multiverse
deb-src http://archive.ubuntu.com/ubuntu/ ${cn}-security main restricted universe multiverse
deb     http://archive.ubuntu.com/ubuntu/ ${cn}-backports main restricted universe multiverse
deb-src http://archive.ubuntu.com/ubuntu/ ${cn}-backports main restricted universe multiverse
deb     http://archive.canonical.com/ubuntu ${cn} partner
deb-src http://archive.canonical.com/ubuntu ${cn} partner
EOF
            fi &&\
            if [ "x${APT_MIRROR}" != "x" ];then
                sed -i -re\
                    "s#^(deb(-src)?)[ \s]+http://[^\.]*\.?archives?.ubuntu[^ \s]+(\s.*)#\1 ${APT_MIRROR} \3#g"\
                    /etc/apt/sources.list
                apt-get update
            fi\
                && apt-get update -qq -y \
                && lazy_apt_get_install git git-core bridge-utils \
                && install_needing_reboot
        fi
        die_in_error
        touch "${initial_upgrade_marker}"
    fi
}

create_base_dirs() {
    # Create basic directories
    for p in "$PREFIX" "$MARKERS";do
        if [ ! -e ${p} ];then
            mkdir -pv "${p}"
        fi
    done
}

check_restart() {
    if [ -e $restart_marker ];then
        output " [*] A restart trigger to finish to provision the box has been detected."
        output " [*] For that, issue now '$0 reload'"
        exit 1
    fi
}

install_needing_reboot() {
    install_needing_reboot_marker="$MARKERS/vbox_needing_reboot_done"
    if [ ! -e "${install_needing_reboot_marker}" ];then
        if [  "x${IS_UBUNTU}" != "x" ];then
            output " [*] Installing linux-image-extra-virtual for AUFS support" \
                && lazy_apt_get_install linux-image-extra-virtual
            die_in_error "kernel install failed"
            output " [*] Initial dist-upgrade" \
                && apt-get dist-upgrade -y --force-yes
            die_in_error "dist-upgrade install failed"
            output " [*] Installing latest system-d related packages" \
                && apt-get install -t $(lsb_release -sc)-proposed \
                systemd libpam-systemd libsystemd0 systemd-sysv policykit-1
            die_in_error "systemd install failed"
            touch "${install_needing_reboot_marker}"
        fi
        if [ -e "${install_needing_reboot_marker}" ];then
            touch "${restart_marker}"
        fi
    fi
    check_restart
}

set_v1() {
    output " [*] Using makina-states v1"
    bootsalt="${bootsalt_v1}"
    MS_BOOT_ARGS="${MS_BOOT_ARGS_V1}"
}

run_boot_salt() {
    bootsalt_v1="/srv/salt/makina-states/_scripts/boot-salt.sh"
    bootsalt="/srv/makina-states/_scripts/boot-salt.sh"
    if [ ! -e ${bootsalt} ] && [ -e ${bootsalt_v1} ];then
        set_v1
    fi
    if [ "x${MS_BRANCH}" = "xstable" ];then
        set_v1
    fi
    if [ "x${bootsalt_v1}" != "x${bootsalt}" ]; then
        if ! echo $MS_BOOT_ARGS | grep -q -- "--highstates";then
            output " [*] Appending --highstates to bootsalt args"
            MS_BOOT_ARGS="${MS_BOOT_ARGS} --highstates"
        fi
    fi
    local ret="0"
    if [ ! -e "$bootsalt_marker" ];then
        boot_word="Bootstrap"
    else
        boot_word="Refresh"
        MS_BOOT_ARGS="-S ${MS_BOOT_ARGS}"
    fi
    if [ ! -e "${bootsalt}" ];then
        output " [*] Running makina-states bootstrap directly from github"
        wget "http://raw.github.com/makinacorpus/makina-states/${MS_BRANCH}/_scripts/boot-salt.sh" -O "/tmp/boot-salt.sh"
        bootsalt="/tmp/boot-salt.sh"
    fi
    bootsalt="/vagrant/vagrant/boot-salt.sh"
    chmod u+x "${bootsalt}"
    if [ ! -e "${bootsalt_marker}" ];then
        activate_debug
        output " [*] $boot_word makina-states..."
        output " -> "${bootsalt}" ${MS_BOOT_ARGS}"
        LANG=C LC_ALL=C "${bootsalt}" ${MS_BOOT_ARGS} && touch "${bootsalt_marker}"
        ret=${?}
        deactivate_debug
    fi
    die_in_error_ ${ret} "Bootsalt failed"
    . /etc/profile
}

test_online() {
    ping -W 10 -c 1 8.8.8.8 &> /dev/null
    echo ${?}
}


fix_salt() {
    fix_salt_marker="$MARKERS/fix_salt_done"
    if [ ! -e "${fix_salt_marker}" ];then
        ls -d /salt-venv/*/src/salt 2>/dev/null | while read d;do
            log " [*] Reset salt repo: ${d}"
            cd "${d}"
            git reset --hard
        done
        touch "${fix_salt_marker}"
    fi
}

install_or_refresh_makina_states() {
    # upgrade salt only if online
    if [ "x$(test_online)" = "x0" ];then
        run_boot_salt
        die_in_error
    else
        if [ ! -e "$bootsalt_marker" ];then
            output " [*] Warning, we are not online, and thus boot-salt can't be runned"
            exit -1
        else
            output " [*] Warning, we are not online, not refreshing makina-states!"
        fi
    fi
}

fix_apt()   {
    apt-get -f install -y --force-yes
}

cleanup_space() {
    sync
    if [ "x${IS_DEBIAN_LIKE}" = "x" ];then
        # dropeed by makina-states.nodetypes.vagrantvm
        /sbin/system-cleanup.sh
    fi
}

base_packages_sanitization() {
    if [ "x${IS_DEBIAN_LIKE}" != "x" ];then fix_apt;fi
    initial_upgrade
}

disable_base_box_services() {
    disable_base_box_services_marker="$MARKERS/disabled_base_box_services"
    if [ ! -e "${disable_base_box_services_marker}" ];then
        for i in puppet chef-client;do
            if [ "x$i" = "xchef-client" ];then
                ps aux|grep -- "$i"|awk '{print $2}'|xargs kill -9
            fi
            if which systemctl >/dev/null 2>&1;then
                systemctl stop ${i}    >/dev/null 2>&1
                systemctl disable ${i} >/dev/null 2>&1
            fi
            if [ -f /etc/init.d/$i ];then
                output " [*] Disabling $i"
                service $i stop
                update-rc.d -f $i remove
                # seems that some package updates are re-enabling it
                # enforce inactivation
                echo "START=no" > /etc/default/$i
            fi
        done
        touch "${disable_base_box_services_marker}"
    fi
}

cleanup_misc() {
    rm -vf /etc/devhosts
    for user_home in $(awk -F: '{if ($6!="") print $1 ":" $6}' /etc/passwd);do
        user="$(echo $user_home|awk -F: '{print $1}')"
        home="$(echo $user_home|awk -F: '{print $2}')"
        if [ -e "$home/.bash_history" ];then
            rm -vf $home/.bash_history
        fi
    done
}

mark_export() {
    output " [*] Cleaning and marking vm as exported"
    reset_git_configs
    cleanup_misc
    touch  "${export_marker}"
}

mark_exported() {
    mark_export "$@"
}

unmark_exported() {
    output " [*] Cleaning and unmarking vm as exported"
    rm -f  "$export_marker"
}

kill_pids(){
    for i in ${@};do
        if [ "x${i}" != "x" ];then
            kill -9 $i
        fi
    done
}

reset_hostname() {
    if [ "x$DEVHOST_HOSTNAME" != "x" ];then
        local fqdn="$DEVHOST_HOSTNAME"
        local dn="$(echo "$DEVHOST_HOSTNAME"|awk -F\. '{print $1}')"
        if [ "x$(hostname)" != "x$dn" ];then
            output " [*] Reseting hostname: $dn"
            hostname "$dn"
        fi
        if [ "x$(cat /etc/hostname &> /dev/null)" != "x$dn" ];then
            output " [*] Reseting /etc/hostname: $dn"
            echo "$dn">/etc/hostname
        fi
        if [ "x$(egrep "127\\..*$hostname" /etc/hosts 2> /dev/null|wc -l)" = "x0" ];\
        then
            output " [*] Reset hostname to /etc/hosts"
            cp -f /etc/hosts /etc/hosts.bak
            echo "127.0.0.1 $dn $fqdn">/etc/hosts
            cat /etc/hosts.bak>>/etc/hosts
            ensure_localhost_in_hosts
            echo "127.0.0.1 $dn $fqdn">>/etc/hosts
            rm -f /etc/hosts.bak
        fi

        if [ -e /etc/init/nscd.conf ] || [ -e /etc/init.d/nscd ];then
            service nscd restart
        fi
    fi
}

ensure_localhost_in_hosts() {
    if [ "x$(egrep "127\\..*localhost" /etc/hosts 2> /dev/null|wc -l)" = "x0" ];then
        echo "127.0.0.1 localhost" >> /etc/hosts
    fi
}

create_vm_mountpoint() {
    activate_debug
    if [ ! -e "${VM_EXPORT_MOUNTPOINT}" ];then mkdir "${VM_EXPORT_MOUNTPOINT}";fi
    cd /
    ls -d * | grep -v "${VM_EXPORT_MOUNTPOINT}" | while read mountpoint;do
        dest="$VM_EXPORT_MOUNTPOINT/${mountpoint}"
        if [  "x$(is_mounted "$dest")" != "x" ];then
            log "Already mounted point: ${mountpoint}"
        else
            if echo "${mountpoint}" | egrep -vq "${NOT_EXPORTED}";then
                if [ -d "${mountpoint}" ];then
                    if [ ! -d "$dest" ];then
                        mkdir -pv "${dest}"
                    fi
                elif [ -e "${mountpoint}" ];then
                    touch "${dest}"
                fi
                if [ "x$(is_mounted "${dest}")" = "x" ];then
                    log "Bind-Mounting /${mountpoint} -> ${dest}"
                    mount -o bind,rw,exec "${mountpoint}" "${dest}"
                    # is a symlink on debian, to /proc/mounts
                    if [ -h /etc/mtab ] &&\
                        ! readlink -f /etc/mtab | grep -q proc;then
                        cat /proc/mounts>/etc/mtab
                    fi
                else
                    if [ "x${DEBUG}" != "x" ];then
                        log "Skipping ${mountpoint}, not exported (not a dir/file)"
                    fi
                fi
            else
                if [ "x${DEBUG}" != "x" ];then
                    log "Skipping ${mountpoint}, not exported"
                fi
            fi
        fi
    done
    deactivate_debug
}

umount_guest_mountpoint(){
    local hdone="0"
    mount|grep ${VM_EXPORT_MOUNTPOINT}|awk '{print $3}'|while read i;do
        umount -f "${i}" 2>&1 | grep -v "not mounted"
        if [ "x${?}" = "x0" ];then
            log "Umounted point: ${i}"
        fi
        hdone="1"
    done
    # is a symlink on debian, to /proc/mounts
    if [ "x${hdone}" != "x" ] && [ "x$(readlink "${mountpoint}/etc/mtab")" != "x/proc/mounts" ];then
        cat /proc/mounts>/etc/mtab
    fi
}

unmark_bootsalt_done() {
    rm -vf "${bootsalt_marker}"
}

handle_export() {
    if [ -e "${export_marker}" ];then
        output " [*] VM export detected, resetting some stuff"
        activate_debug
        # reset salt minion id and perms
        for i in mastersalt salt;do
            for j in minion master;do
                service "${i}-${j}" stop &> /dev/null
                kill_pids $(ps aux|grep "${i}-${j}"|awk '{print $2}') &> /dev/null
                rm -rfv /var/cache/${i}-{j}
                mkdir -p /var/cache/${i}-${j}
            done
        done
        reset_git_configs
        # remove vagrant conf as it can contain doublons on first load
        output " [*] Reset network interface file"
        sed -ne "/VAGRANT-BEGIN/,\$!p" /etc/network/interfaces > /etc/network/interfaces.buf
        if [ "x$(grep lo /etc/network/interfaces|grep -v grep|wc -l)" != "x0" ];then
            cp -f /etc/network/interfaces.buf /etc/network/interfaces
            rm -f /etc/network/interfaces.buf
        fi
        unmark_exported
        deactivate_debug
    fi
}

reset_git_configs() {
    find / -type d -name .git -not \( -path guest -prune \)|while read dotgit; do
        cd "${dotgit}" &> /dev/null &&\
        output " [*] Resetting ${dotgit}" &&\
        for i in user.email user.name;do git config --local --unset ${i};done &&\
        cd - &> /dev/null
    done
}

sync_ssh() {
    if [ ! -e /root/.ssh ];then mkdir /root/.ssh;fi
    if [ -e /home/vagrant ]; then
        user=vagrant
    else
        user=ubuntu
    fi
    rsync -a /home/$user/.ssh/authorized* /root/.ssh/
    chown -Rf root:root /root/.ssh/
}

get_devhost_num() {
    echo ${DEVHOST_NUM}
}

if [ "x${VAGRANT_PROVISION_AS_FUNCS}" = "x" ];then
    output " [*] STARTING MAKINA VAGRANT PROVISION SCRIPT: ${0}"
    output " [*] You can safely relaunch this script from within the vm"
    set_vars
    reset_hostname
    sync_ssh
    handle_export
    create_base_dirs
    disable_base_box_services
    cleanup_restart_marker
    configure_dns
    base_packages_sanitization
    install_or_refresh_makina_states
    fix_salt
    open_routes
    cleanup_space
    check_restart
    umount_guest_mountpoint
    create_vm_mountpoint
    ready_to_run
    sync
fi
# vim:set et sts=4 ts=4 tw=0:
