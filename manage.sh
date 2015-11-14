#!/usr/bin/env bash
LAUNCH_ARGS="${@}"
UNAME="$(uname)"
actions=""
actions_main_usage="usage init ssh up reload destroy down suspend status clonevm remount_vm umount_vm version shutdown poweroff off"
actions_exportimport="export import"
actions_advanced="do_zerofree test install_keys cleanup_keys mount_vm release internal_ssh gen_ssh_config reset is_mounted"
actions_alias="-h --help --long-help -l -v --version"
actions="
    ${actions_exportimport}
    ${actions_main_usage}
    ${actions_advanced}
    ${actions_alias}
"
# reput on one line
actions=$(echo ${actions})

RED="\\e[0;31m"
CYAN="\\e[0;36m"
YELLOW="\\e[0;33m"
YELLOW="\\e[0;33m"
NORMAL="\\e[0;0m"


if [ "x${NO_COLORS}" != "x" ];then
    YELLOW=""
    RED=""
    CYAN=""
    NORMAL=""
fi

log(){
    printf "${RED} [manage] ${@}${NORMAL}\n" 1>&2
}

unactive_echo (){
    if [ "x${MANAGE_DEBUG}" != "x" ];then
        set +x
    fi
    if [ "x${DARWIN_DEBUG}" != "x" ];then
        set +x
    fi
}

active_echo (){
    if [ "x${MANAGE_DEBUG}" != "x" ];then
        set -x
    fi
    if [ "x${DARWIN_DEBUG}" != "x" ];then
        set -x
    fi
}

THIS="${0}"
where="${VAGRANT_VM_PATH:-$(dirname "${THIS}")}"
cd "${where}" || exit 1
MANAGE_DEBUG="${MANAGE_DEBUG}"
if [ "x${DEVHOST_DEBUG}" = "x" ] && [ "x${MANAGE_DEBUG}" != "x" ];then
    DEVHOST_DEBUG=${MANAGE_DEBUG}
fi
RSYNC=$(which rsync)
VMPATH=${PWD}
internal_ssh_config=${VMPATH}/.vagrant/internal-ssh-config
ssh_config=${VMPATH}/.vagrant/ssh-config
VM=${VMPATH}/VM
DEFAULT_DNS_BLOCKFILE="${VM}/etc/devhosts"
DEFAULT_HOSTS_FILE="/etc/hosts"
NO_INPUT=""
PROJECT_PATH="project/makinacorpus/vms/devhost"
BASE_URL="${DEVHOST_BASE_URL:-"https://downloads.sourceforge.net/${PROJECT_PATH}"}"
SFTP_URL=frs.sourceforge.net:/home/frs/${PROJECT_PATH}
PROVISION_WRAPPER="/vagrant/vagrant/provision_script_wrapper.sh"
EXPORT_VAGRANTFILE="Vagrantfile-export"
DEFAULT_NO_SYNC_HOSTS=${NO_SYNC_HOSTS}
SSH_CONFIG_DONE=""
HOSTONLY_SSH_CONFIG_DONE=""
WRAPPER_PRESENT=""
DEVHOST_NUM=""
FUSERMOUNT="fusermount"


die_() {
    ret=${1}
    shift
    printf "${CYAN}${@}${NORMAL}\n" 1>&2
    exit ${ret}
}

die() {
    die_ 1 "${@}"
}

die_in_error_() {
    aret=${1}
    shift
    amsg="${@:-"${ERROR_MSG}"}"
    if [ "x${aret}" != "x0" ];then
        die_ "${aret}" "${amsg}"
    fi
}

die_in_error() {
    die_in_error_ "${?}" "${@}"
}


mac_setup() {
    # add info for sshfs tricks
    if [ "x${UNAME}" = "xDarwin" ];then
        if [ ! -e "$(which sshfs 2>/dev/null)" ];then
            die "Please install sshfs via brew, sudo brew install sshfs"
        fi
        FUSERMOUNT="umount"
    fi
}

actions=" ${actions} "

help_content(){
    printf "${CYAN}${@}${NORMAL}\n" 1>&2
}

help_header(){
    action=${1}
    shift
    printf "   ${RED}${THIS} ${action}${NORMAL} ${@}\n" 1>&2
}

usage() {

    for i in ${@};do
        case ${i} in
            --long-help) LONGHELP="1"
                ;;
        esac
    done
    for actions in\
        "${actions_main_usage}"\
        "${actions_exportimport}"\
        "${actions_advanced}";do
        case ${actions} in
            "${actions_main_usage}")
                printf "${YELLOW}Main options${NORMAL}\n"
                ;;
            "${actions_exportimport}")
                printf "${YELLOW}Export/Import options${NORMAL}\n"
                ;;
            "${actions_advanced}")
                if [ "x${LONGHELP}" = "x" ];then
                    actions=""
                else
                    printf "${YELLOW}Advanced options${NORMAL}\n"
                fi
                ;;
        esac
        for i in ${actions};do
            buf=""
            addhelp=""
            case ${i} in
                usage)
                    help_header "" "[-h | --help | --long-help]"
                    help_header ${i} [--long-help]
                    help_content "      print this help, --long-help print advanced options and additional descriptions"
                    ;;
                init)
                    help_header ${i} "[URL | FILEPATH]"
                    help_content "      Initialise a new VM from either the specified archive produced by"
                    help_content "      the export command or by default to the last stable release (no arguments to init)"
                    ;;
                status)
                    help_header ${i}
                    help_content "      Thin wrapper to vagrant status"
                    ;;
                up)
                    help_header ${i}
                    help_content "      Launch a VM"
                    ;;
                version)
                    help_header ${i}
                    help_content "      Versions info"
                    ;;
                reload)
                    help_header ${i}
                    help_content "      Restarts a VM"
                    ;;
                destroy)
                    help_header ${i}
                    help_content "      Destroys a VM without confirmation, this is DESTRUCTIVE"
                    ;;
                down)
                    help_header ${i}
                    help_content "      Stop a VM"
                    ;;
                export)
                    help_header ${i} [nozerofree]
                    help_content "      Make an entire snapshot of the current VM to an archive which can be imported"
                    help_content "      elsewhere even on the same box."
                    if [ "x${LONGHELP}" != "x" ];then
                        help_content "      nozerofree: do not run zerofree (free VM space and trim virtual hard drive"
                        help_content "                  space to minimal extent) prior to export"
                    fi
                    ;;
                reset)
                    help_header ${i}
                    help_content "      Remove all local files (.vagrant, configs, etc)"
                    ;;
                clonevm)
                    help_header "${i} /path/to/new/vm  [INIT URL]"
                    help_content "      Clone a VM to the desired directory and init it from either the specified URI or the VM base tarball/url"
                    ;;
                suspend)
                    help_header ${i}
                    help_content "      Suspend the vm"
                    ;;
                do_zerofree)
                    help_header ${i}
                    help_content "      run zerofree (free VM space and trim virtual hard drive"
                    help_content "      space to minimal extent) prior to export"
                    ;;
                ssh)
                    help_header ${i} [args]
                    help_content "      ssh client to the VM"
                    help_content "      args are those of the /bin/ssh command and not those of the vagrant one"
                    if [ "x${LONGHELP}" != "x" ];then
                        help_content "      This will use the hostonly adapter by default but can also use the internal"
                        help_content "      (NAT) adapter if the hostonly interface is not correctly configured"
                    fi
                    ;;
                test)
                    help_header ${i}
                    help_content "      Test to create another vm in another folder -> READ THE CODE, developer only"
                    ;;
                install_keys)
                    help_header ${i}
                    help_content "      Install the ssh keys from $(whoami) in the guest root and vagrant users"
                    ;;
                cleanup_keys)
                    help_header ${i}
                    help_content "      Purge any ssh key contained in the VM"
                    ;;
                mount_vm)
                    help_header ${i}
                    help_content "      Mount the vm filesystem on the host using sshfs"
                    ;;
                umount_vm)
                    help_header ${i}
                    help_content "      Umount the vm filesystem"
                    ;;
                remount_vm)
                    help_header ${i}
                    help_content "      Mount or Remount the vm filesystem"
                    ;;
                release)
                    help_header "${i} [--noinput --noclean --nocommit]"
                    help_content "      Release the current vm as the next release on the CDN: ${BASE_URL}"
                    if [ "x${LONGHELP}" != "x" ];then
                        help_content "          - Export the vm to $(get_next_release_name)"
                        help_content "          - Increment .versions/$(get_git_branch ${VMPATH}).txt"
                        help_content "          - Upload to the CDN"
                    fi
                    ;;
                gen_ssh_config)
                    help_header ${i}
                    help_content "      Regenerate ssh config files"
                    ;;
                import)
                    help_header ${i} "[URL | FILEPATH]"
                    help_content "      Import a new VM from either the specified archive produced by"
                    help_content "      the export command or the last stable release (no arguments to init)"
                    ;;
                internal_ssh)
                    help_header ${i} [args]
                    help_content "      ssh client to the VM using the vagrant internal ssh interface"
                    help_content "      args are those of the /bin/ssh command and not those of the vagrant one"
                    if [ "x${LONGHELP}" != "x" ];then
                        help_content "      This will use the hostonly adapter by default but can also use the internal"
                        help_content "      (NAT) adapter if the hostonly interface is not correctly configured"
                    fi
                    ;;
            esac
            echo
        done
        echo
    done
}

gen_uuid() {
    python << EOF
import uuid, base64
u = uuid.uuid4().bytes
u = base64.urlsafe_b64encode(u)
u = u.replace('=', '').replace('_', '').replace('-', '')
print u[:16]
EOF

}

write_test_config() {
    num="${1}"
    cat > vagrant_config.rb << EOF
module MyConfig
    DEVHOST_NUM="${num}"
    VIRTUALBOX_VM_NAME="DevHost ${num} Ubuntu ${name}64"
end
EOF
}

status_() {
    vagrant status 2> /dev/null
}

status() {
    status_\
        | egrep "^default    "\
        | grep -v grep\
        | grep -v provider\
        | grep -i virtualbox\
        | sed -e "s/^default\([ \t]\)*//g"\
        | sed -e "s/\([ ^\t]\)*[(].*//g"\
        | sed -e "s/\([ \t]\)*$//g"\
        | sed -e "s/^\([ \t]\)*//g"

}

vagrant_ssh() {
    if [ "x${SSH_CONFIG_DONE}" = "x" ];then
        if [ "x${@}" != "x" ];then
            vagrant ssh -c "${@}"
        else
            vagrant ssh
        fi
    else
        if [ "x${@}" != "x" ];then
            internal_ssh "${@}"
        else
            internal_ssh
        fi
    fi
}

destroy() {
    cd "${VMPATH}"
    log "Destroy !"
    down
    vagrant destroy -f
    mark_ssh_config_not_done
}

suspend() {
    cd "${VMPATH}"
    log "Suspend !"
    vagrant suspend
}


internal_ssh() {
    cd "${VMPATH}"
    sshhost="$(get_ssh_host "${internal_ssh_config}")"
    if [ ! -e ${internal_ssh_config} ];then
        log " [*] missing ${ssh_config}"
        exit 1
    fi

    if [ "x${sshhost}" != "x" ];then
        active_echo
        $(which ssh) -o ConnectTimeout=2 -F "${internal_ssh_config}" "${sshhost}" ${@}
        unactive_echo
    else
        log "Cant internal ssh, empty host"
        exit 1
    fi
}

ssh_() {
    cd "${VMPATH}"
    sshhost="$(get_ssh_host "${ssh_config}")"
    if [ ! -e ${ssh_config} ];then
        log " [*] missing ${ssh_config}"
        exit 1
    fi
    if [ "x${sshhost}" != "x" ];then
        active_echo
        $(which ssh) -o ConnectTimeout=2 -F "${ssh_config}" "${sshhost}" ${@}
        unactive_echo
    else
        log "Cant ssh, empty host"
        exit 1
    fi
}

set_wrapper_present(){
    if [ "x${WRAPPER_PRESENT}" = "x" ];then
        if [ "x$(vagrant_ssh "test -e \"${PROVISION_WRAPPER}\" &>/dev/null;echo ${?}" 2>/dev/null)" = "x0" ];then
            WRAPPER_PRESENT="1"
        fi
    fi
}

set_devhost_num() {
    if [ "x${DEVHOST_NUM}" = "x" ] && [ "x${WRAPPER_PRESENT}" != "x" ];then
        DEVHOST_NUM="$(vagrant_ssh "sudo ${PROVISION_WRAPPER} get_devhost_num 2>/dev/null" 2>/dev/null)"
    fi
    if [ "x${DEVHOST_NUM}" != "x" ];then
        if [ -e "${internal_ssh_config}" ];then
            sed -i -e "s/Host default/Host devhost${DEVHOST_NUM}/g" "${internal_ssh_config}"
        fi
        if [ -e "${ssh_config}" ];then
            sed -i -e "s/Host default/Host devhost${DEVHOST_NUM}/g" "${ssh_config}"
        fi
    fi
}

mark_ssh_config_not_done() {
    HOSTONLY_SSH_CONFIG_DONE=""
    SSH_CONFIG_DONE=""
    WRAPPER_PRESENT=""
    DEVHOST_NUM=""
}

gen_internal_ssh_config() {
    if [ "x${SSH_CONFIG_DONE}" != "x" ];then return 0;fi
    vagrant ssh-config 2>/dev/null 1>"${internal_ssh_config}"
    if [ ! -f "${internal_ssh_config}" ];then
        log "Cant generate ${internal_ssh_config}"
        exit 1
    else
        SSH_CONFIG_DONE="1"
    fi
}

gen_hostonly_ssh_config() {
    if [ "x${HOSTONLY_SSH_CONFIG_DONE}" != "x" ];then return 0;fi
    # replace the ip by the hostonly interface one in our ssh wrappers
    hostip=$(vagrant_ssh "ip addr show dev eth1 2> /dev/null" 2>/dev/null)
    devhost_num="${DEVHOST_NUM}"
    cp -f "${internal_ssh_config}" "${ssh_config}"
    if [ "x${hostip}" != "x" ];then
        hostip=$(echo "${hostip}"|awk '/inet / {gsub("/.*", "", $2);print $2}'|head -n1)
    fi
    if [ "x${hostip}" = "x" ];then
        log "Fallback to internal as we could not detect any ip on eth1"
        ssh_config=$internal_ssh_config
        HOSTONLY_SSH_CONFIG_DONE=""
    else
        sed -i -e "s/HostName.*/HostName ${hostip}/g" "${ssh_config}"
        sed -i -e "s/Port.*//g" "${ssh_config}"
        HOSTONLY_SSH_CONFIG_DONE="1"
    fi
}

gen_ssh_config() {
    cd "${VMPATH}"
    if [ "x$(status)" != "xrunning" ];then
        log " [*] VM is not running, can't generate ssh configs"
        exit 1
    fi
    if [ ! -d .vagrant ];then
        mkdir .vagrant
    fi
    active_echo
    gen_internal_ssh_config
    set_wrapper_present
    set_devhost_num
    gen_hostonly_ssh_config
    unactive_echo
}

cleanup_keys() {
    active_echo
    ssh_pre_reqs
    if [ "x${WRAPPER_PRESENT}" != "x" ];then
        vagrant_ssh "sudo ${PROVISION_WRAPPER} cleanup_keys" 2>/dev/null
    else
        log "Warning: could not cleanup ssh keys, shared folder mountpoint seems not present"
    fi
    unactive_echo
}

install_keys() {
    active_echo
    gen_ssh_config
    if [ "x${WRAPPER_PRESENT}" != "x" ];then
        vagrant_ssh "sudo ${PROVISION_WRAPPER} install_keys" 2>/dev/null
    else
        log "Warning: could not install ssh keys, shared folder mountpoint seems not present"
    fi
    unactive_echo
}

ssh_pre_reqs() {
    if [ "x$(status)" != "xrunning" ];then
        up
    fi
    gen_ssh_config
    install_keys
}

ssh() {
    mount_vm
    ssh_ $@
}

pre_down() {
    if [ "x$(status)" = "xrunning" ];then
        umount_vm
        vagrant_ssh "sudo sync" 2>/dev/null
    else
        log " [*] pre_down: VM already stopped"
    fi
}

remount_vm() {
    log "Remounting vm"
    umount_vm && mount_vm
}

poweroff() {
    down "${@}"
}

off() {
    down "${@}"
}


shutdown() {
    down "${@}"
}

down() {
    cd "${VMPATH}"
    umount_vm
    log "Down !"
    if [ "x$(status)" = "xrunning" ];then
        pre_down
        vagrant halt -f
        mark_ssh_config_not_done
    else
        log " [*] VM already stopped"
    fi
}

maybe_finish_creation() {
    lret=$1
    shift
    restart_marker="/tmp/vagrant_provision_needs_restart"
    if [ "x${lret}" != "x0" ];then
        for i in $(seq 3);do
            marker="$(vagrant_ssh "test -e ${restart_marker}" &> /dev/null;echo ${?})"
            if [ "x${marker}" = "x0" ];then
                log "First runs, we issue a scheduled reload after the first up(s)"
                reload $@
                lret="${?}"
            elif [ "x${lret}" != "x0" ];then
                log "Error in vagrant up/reload"
                exit 1
            else
                break
            fi
        done
    fi
}

get_version_file() {
    br=$(get_git_branch .)
    echo "${VMPATH}/.versions/${br}.txt"
}

get_version() {
    vfile="$(get_version_file)"
    if [ -e "${vfile}" ];then
        ver="$(cat "${vfile}")"
    fi
    echo "${ver}"
}

get_next_version() {
    echo "$(($(get_version) +1 ))"
}

get_release_name_() {
    release_suf=$1
    if [ "x${release_suf}" != "x" ];then
        release_suf="_${release_suf}"
    fi
    echo "$(get_box_name "${VMPATH}" ${release_suf})"
}

get_release_name() {
    get_release_name_ "$(get_version)"
}

get_next_release_name() {
    get_release_name_ "$(get_next_version)"
}

get_git_branch() {
    cd ${1} &> /dev/null
    br=$(git branch | grep "*"|grep -v grep)
    echo ${br/* /}
    cd - &> /dev/null
}

release() {
    rfile="$(get_version_file)"
    rname="$(get_next_release_name)"
    rarc="$(get_devhost_archive_name ${rname})"
    rver="$(get_next_version)"
    nocommit=""
    for i in ${@};do
        case ${i} in
            --noinput|--no-input) NO_INPUT=1
                ;;
            --nocommit|--no-commit) nocommit=1
                ;;
            --noclean|--no-clean) NO_CLEAN=1
                ;;
        esac
    done
    cd "${VMPATH}"
    OLD_VM_PATH="${VMPATH}"
    RELEASE_PATH="${VMPATH}-release"
    NO_SYNC_HOSTS=1 NO_IMPORT=1 clonevm "${RELEASE_PATH}"
    export VMPATH="${RELEASE_PATH}"
    log "Releasing ${rname}" &&\
        if [ ! -f "${rarc}" ];then
            export_ "${rname}" nozerofree
        fi && \
        log "Running scp \"${rarc}\" ${SFTP_URL}/\"${rarc}\"" &&\
        scp "${rarc}" ${SFTP_URL}/"${rarc}"
    lret=${?}
    if [ "x${lret}" != "x0" ];then
        log "Error while uploading images"
        exit $lret
    else
        cd "${OLD_VM_PATH}" &&\
            echo "${rver}" > "${rfile}" &&\
            git add "${rfile}" &&\
            git commit -am "RELEASE: ${rname}" &&\
            log "You ll need to git push when you ll have test an init" &&\
            log "somewhere and the download works and the sf.net mirrors are well synchron,ized" &&\
            log "URL to test is: $(get_release_url ${rname})" &&\
            log "Automatic commit in 4 hours, or pres CC and issue git push manually" &&\
            sleep "$((4 * 60 * 60))" && git push
        log "End of release"
    fi

}

get_release_url() {
    rname="${1:-$(get_release_name)}"
    echo "${BASE_URL}/$(get_devhost_archive_name ${rname})"
}

init() {
    cd "${VMPATH}"
    url="${1:-"$(get_release_url)"}"
    status="$(status)"
    if [ "x$(status)" = "xnot created" ];then
        import "${url}"
    fi
    up
}

get_sshfs_ps() {
    # be sure to test for the end of the path not to
    # umount near by or in-folder sub-VMs
    ps aux|egrep "sshfs.*${VM}\$"|grep -v grep
}

get_sshfs_pids() {
    get_sshfs_ps|awk '{print $2}'
}

get_lsof_pids() {
    LSOF=$(which lsof)
    lsof_pids=""
    if [ -e "${LSOF}" ];then
        lsof_pids="$(${LSOF} "${VM}" 2> /dev/null|awk '{print $2}')"
    fi
    echo $lsof_pids
}

is_mounted() {
    #set -x
    mounted=""
    if [ "x$(mount|awk '{print $3}'|egrep "${VM}$" |grep -v grep| wc -l|sed -e "s/ //g")" != "x0" ]\
        || [ "x$(get_sshfs_ps| wc -l|sed -e "s/ //g")" != "x0" ];then
        mounted="1"
    fi
    echo ${mounted}
    #set +x
}

get_ssh_host() {
    sshconfig="${1}"
    if [ ! -e "${sshconfig}" ];then
        gen_ssh_config
    fi
    if [ ! -e "${sshconfig}" ];then
        log "Invalid ${sshconfig}, does not exist"
        exit 1
    fi
    grep "Host\ " "${sshconfig}" |awk '{print $2}' 2>/dev/null
}

mount_vm() {
    cd "${VMPATH}"
    active_echo
    # something is wrong with the mountpath, killing it
    test_not_connected="$(LANG=C ls VM 2>&1)"
    if [ ! -e "${VM}/home/vagrant/.ssh" ]\
        || [ "x$(echo "${test_not_connected}"|grep -q "is not connected";echo ${?})" = "x0" ];then
        umount_vm
    fi
    if [ ! -e "${VM}/home/vagrant/.ssh" ];then
        if [ ! -e "${VM}" ];then
            mkdir "${VM}"
        fi
        ssh_pre_reqs
        sshhost=$(get_ssh_host "${ssh_config}")
        if [ "x${sshhost}" != "x" ];then
            log "Mounting devhost(${sshhost}):/ --sshfs--> ${VM}"
            sshopts="transform_symlinks,reconnect,BatchMode=yes"
            if [ "x$(egrep "^user_allow_other" /etc/fuse.conf 2>/dev/null|wc -l|sed -e "s/ //g")" != "0" ];then
                sshopts="${sshopts},allow_other"
            fi
            if [ "x${UNAME}" != "xDarwin" ];then
                sshopts="${sshopts},nonempty"
            fi
            sshfs -F "${ssh_config}" root@${sshhost}:/guest -o ${sshopts} "${VM}"
        else
            log "Cant' mount devhost, empty ssh host"
            exit -1
        fi
    fi
    unactive_echo
}

get_pid_line() {
    pid="${1}"
    ps -eo pid,user,comm,args --no-headers|egrep "^[ \t]*${pid}[ \t]"|grep -v grep
}

smartkill_() {
    PIDS=$@
    for pid in ${PIDS};do
        while [ "x$(get_pid_line ${pid}|wc -l|sed -e "s/ //g")" != "x0" ];do
            if [ "x${NO_INPUT}" = "x" ] || [ "x${input}" = "xy" ];then
                log "Do you really want to kill:"
                log "$(get_pid_line ${pid})"
                log "[press y+ENTER, or CONTROL+C to abort, or ignore to continue]";read input
            fi
            if [ "x${NO_INPUT}" != "x" ] || [ "x${input}" = "xy" ];then
                log "killing ${pid}"
                kill -9 $pid
            fi
            if [ "x${input}" = "xignore" ];then
                log "ignoring ${pid}"
                break
            fi
        done
    done
}

smartkill() {
    PIDS=""
    PIDS="${PIDS} $(get_lsof_pids)"
    PIDS="${PIDS} $(get_sshfs_pids)"
    smartkill_ $PIDS
}


do_umount() {
    args="-f"
    if [ "x${UNAME}" = "xLinux" ];then
        args="${arg} -l"
    fi
    for arg in ${args};do
        if [ "x$(is_mounted)" != "x" ] && [ "x${noumount}" = "x" ];then
            sudo umount ${arg} "${VM}" 2>&1
        fi
    done
}

do_fusermount () {
    fuseropts="-u"
    if [ "x${UNAME}" = "xDarwin" ];then
        fuseropts=""
    fi
    lret=$(${FUSERMOUNT} ${fuseropts} "${VM}" 2>&1)
    # let a little time to fusermount to do his art
    sleep 2
    noumount=""
    for i in ${@};do
        case ${i} in
            noumount) noumount=1
                ;;
        esac
    done
    if [ "x$(echo "${lret}"|grep -q "not found";echo ${?})" = "x0" ] && [ "x$(is_mounted)" != "x" ];then
        if [ "x${noumount}" = "x" ];then
            do_umount
        fi
    fi
    if [ "x$(is_mounted)" != "x" ] || [ "x$(echo ${lret}|grep -q "Permission denied";echo ${?})" = "x0" ];then
        # let a little time to fusermount to do his art
        sleep 2
        sudo ${FUSERMOUNT} ${fuseropts} "${VM}" 2>&1
    fi
    if [ "x${noumount}" = "x" ];then
        do_umount
    fi
}

umount_vm() {
    if [ "x${DARWIN_DEBUG}" != "x" ];then
        set -x
    fi
    cd "${VMPATH}"
    if [ "x$(is_mounted)" != "x" ];then
        log "Umounting of ${VM}"
        do_fusermount noumount
    fi
    if [ "x$(is_mounted)" != "x" ];then
        log "Forcing umounting of ${VM}"
        smartkill
        do_fusermount
    fi
    if [ "x${?}" != "x0" ];then
        log "Can't umount vm"
        exit "${?}"
    fi
    if [ "x${DARWIN_DEBUG}" != "x" ];then
        set +x
    fi
}

up() {
    cd "${VMPATH}"
    log "Up !"
    notrunning=""
    if [ "x$(status)" != "xrunning" ];then
        notrunning="1"
    fi
    vagrant up $@
    lret=${?}
    # be sure of jumbo frames on anything else that macosx
    if [ "x${notrunning}" != "x" ] && [ "x${UNAME}" != "xDarwin" ];then
        vagrant_ssh "sudo ifconfig eth1 mtu 9000" 2>/dev/null
    fi
    post_up ${lret} $@
}

post_up() {
    lret=$1
    shift
    maybe_finish_creation ${lret} $@
    mount_vm
}

reload() {
    cd "${VMPATH}"
    log "Reload!"
    umount_vm
    if [ "x$(status)" != "xrunning" ];then
        mark_ssh_config_not_done
        up
    else
        pre_down
        vagrant reload $@
        lret=${?}
        post_up ${lret} $@
    fi
}

generate_packaged_vagrantfile() {
    packaged_vagrantfile="${EXPORT_VAGRANTFILE}-$(gen_uuid)"
    touch $packaged_vagrantfile
    echo $packaged_vagrantfile
}

get_box_name() {
    path="${1:-"."}"
    suf="${2:-"-$(gen_uuid)"}"
    if [ "x${suf}" = "xnosuf" ];then
        suf=""
    fi
    bname="devhost-$(get_git_branch ${path})${suf}"
    echo $bname
}

get_vagrant_box_name() {
    echo "${1:-"$(get_box_name ${2})"}.box"
}

get_devhost_archive_name() {
    echo "${1:-"$(get_box_name ${2})"}.tar.bz2"
}

export_() {
    NO_SYNC_HOSTS=1
    for i in ${@};do
        if [ "x${i}" = "xnozerofree" ];then
            nozerofree=y
        elif [ "x${i}" = "xnosed" ];then
            nosed=y
        else
            bname="${i}"
        fi
    done
    cd "${VMPATH}"
    export NOCONFIRM=1
    bname="${bname:-"$(get_box_name)"}"
    box="$(get_vagrant_box_name ${bname})"
    abox="$(get_devhost_archive_name ${bname})"
    nincludes=""
    includes=""
    tar_preopts="cjvf"
    tar_postopts="--numeric-owner"
    #
    # be sure to package a blank vagrantfile along with the box to not conflict with our Vagrantfile
    # at import time
    #
    packaged_vagrantfile="$(generate_packaged_vagrantfile)"
    nincludes=""
    for i in .vb_* vagrant_config.rb;do
        if [ -e "${i}" ];then
            nincludes="${i} ${nincludes}"
        fi
    done
    if [ "x${UNAME}" = "xDarwin" ];then
        tar_postopts=""
    fi
    if [ "x${UNAME}" != "xDarwin" ];then
        tar_preopts="${tar_preopts}p"
    fi
    netrules="/etc/udev/rules.d/70-persistent-net.rules"
    if [ "x${nozerofree}" = "x" ];then
        log "Zerofree starting in 20 seconds, you can control C before the next log"
        log "and relaunch with the same cmdline with nozerofree appended: eg ./manage.sh export nozerofree"
        sleep 15
        log "Zerofree starting ! DO NOT INTERRUPT ANYMORE"
        sleep 5
        do_zerofree
    else
        log "Skip zerofree on export"
    fi &&\
    if [ ! -e "${box}" ];then
        vagrant box remove $bname
        down && up && gen_ssh_config &&\
            if [ "x${WRAPPER_PRESENT}" = "x" ];then \
                log "${PROVISION_WRAPPER} is not there in the VM"
                exit -1
            fi &&\
            if [ "x${nosed}" = "x" ];then \
                vagrant_ssh "if [ -d ${netrules} ];then rm -rf ${netrules};touch ${netrules};fi";\
                vagrant_ssh "if [ -e ${netrules} ];then sudo sed -re 's/^SUBSYSTEM/#SUBSYSTEM/g' -i ${netrules};fi";\
            fi &&\
            vagrant_ssh "sudo ${PROVISION_WRAPPER} mark_export" 2>/dev/null
            down
            export DEVHOST_FORCED_BOX_NAME="${bname}" &&\
            log "Be patient, exporting now" &&\
            vagrant package --vagrantfile "${packaged_vagrantfile}" --output "${box}" 2> /dev/null
            rm -f "${EXPORT_VAGRANTFILE}"*
        lret="${?}"
        down
        up --no-provision && vagrant_ssh "sudo ${PROVISION_WRAPPER} unmark_exported" 2>/dev/null && down
        if [ "x${lret}" != "x0" ];then
            log "error exporting ${box}"
            exit 1
        fi
    else
        log "${VMPATH}/${box} exists, delete it to redo"
    fi
    # XXX: REALLY IMPORTANT TO NOTE IS THAT THE BOC MUST BE THE FIRST TARED FILE !!!
    if [ -e "${box}" ] && [ ! -e "${abox}" ];then
        log "Be patient, archiving now the whole full box package" &&\
        tar ${tar_preopts} ${abox} ${box} ${includes} ${tar_postopts} &&\
        rm -f "${box}" &&\
        log "Export done of full box: ${VMPATH}/${abox}"
    else
        log "${VMPATH}/${abox}, delete it to redo"
    fi &&\
    lret=${?}
    if [ "x${lret}" != "x0" ];then
        log "Error while exporting"
        exit $lret
    else
        log "End of export"
    fi
    NO_SYNC_HOSTS=$DEFAULT_NO_SYNC_HOSTS
}

check_tmp_file() {
    fname="${1}"
    res="ok"
    if [ -e ${fname} ];then
        tmpsize=$(dd if=${fname} bs=4046 count=40000 2>/dev/null|wc -c)
        if [ "x${tmpsize}" != "x161840000" ];then
            log "Invalid download, deleting tmp file"
            rm -f "${fname}"
            res=""
        fi
    fi
    echo $res
}

download() {
    active_echo
    wget=""
    url="${1}"
    fname="${2:-${basename ${url}}}"
    # UA do not work in fact, redirect loop and empty file
    G_UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.22 (KHTML, like Gecko) Ubuntu Chromium/25.0.1364.160 Chrome/25.0.1364.160 Safari/537.22"
    # freebsd
    if [ "x${UNAME}" = "xFreeBSD" ] && [ -e "$(which fetch 2>&1)" ];then
        $(which fetch) -pra -o ${fname} $url
    # wget

    elif [ -e "$(which wget)" ];then
        #$(which wget) --no-check-certificate -U "${G_UA}" -c -O ${fname} $url
        $(which wget) --no-check-certificate -c -O ${fname} $url
    # curl
    elif [ -e "$(which curl 2>&1)" ];then
        #$(which curl) -A "${G_UA}" --insecure -C - -a -o ${fname} $url
        $(which curl) --insecure -C - -a -o ${fname} $url
    fi
    if [ "x${?}" != "x0" ];then
        log "Error downloading ${url} -> ${fname}"
        exit 1
    fi
    unactive_echo
}

import() {
    NO_SYNC_HOSTS=1
    cd "${VMPATH}"
    image="${1:-$(get_devhost_archive_name $(get_release_name))}"
    tar_preopts="-xjvpf"
    tar_postopts="--numeric-owner"
    boxes=" $(vagrant box list 2> /dev/null|awk '{print " " $1 " "}') "
    shift
    args=${@}
    if [ "x$(status)" != "xnot created" ];then
        log "VM already imported,"
        log "   - Run it with: ${THIS} up"
        log "   - Delete it with: ${THIS} destroy"
    else
        if [ "x$(echo ${image}|grep -q http;echo ${?})" = "x0" ];then
            url="${image}"
            image="$(basename ${image})"
            do_download=""
            if [ ! -e ${image} ];then
                do_download="1"
            fi
            if [ "x$(check_tmp_file ${image})" = "x" ];then
                do_download="1"
            fi
            if [ "x${do_download}" != "x" ];then
                download "${url}" "${image}"
            else
                log "${image} already exists, "
                log "   delete this archive, if you want to redownload"
                log "   from ${url}"
            fi
        fi
        if [ "x$(echo "${image}"|grep -q ".tar.bz2";echo ${?})" = "x0" ] && [ -e "${image}" ];then
            bname="$(basename "${image}" .tar.bz2)"
        else
            log "invalid image file ${1} (must be a regular bzip2 tarfile end with .tar.bz2)"
            exit -1
        fi
        bname="${bname:-$(get_box_name)}"
        abox="${image}"
        log "Getting box name from ${image}"
        if [ ! -e "${image}" ];then
            log "Missing file: ${image}"
            exit -1
        else
            box="$(dd if=${image} bs=1024 count=10000 2>/dev/null|tar -tjf - 2>/dev/null)"
        fi
        if [ "x$(echo "${boxes}"|grep -q " ${bname} ";echo ${?})" = "x0" ];then
            log "BASE VM already imported, redo base vm import by issuing:"
            log "  vagrant box remove '${bname}' && ${THIS} ${LAUNCH_ARGS}"
        else
            if [ ! -e "${box}" ];then
                log "Unarchiving ${image}"
                # need to sudo to restore sticky GID
                sudo tar ${tar_preopts} "${image}" $tar_postopts
                if [ "x${?}" != "x0" ];then
                    log "Error unarchiving ${image}"
                fi
                if [ ! -e "${box}" ];then
                    log "Missing ${box}"
                    exit -1
                fi
            else
                log "Existing ${box}, if you want to unarchive again, delete it"
            fi
            log "Importing ${box} into vagrant bases boxes as '${bname}' box"
            vagrant box add -f "${bname}" "${box}" && rm -f "${box}"
            if [ "x${?}" != "x0" ];then
                log "Error while importing ${box}"
                exit ${?}
            fi
        fi
        log "Initialiasing host from ${box}" &&\
            export DEVHOST_FORCED_BOX_NAME="${bname}" &&\
            sed -i -e "/VIRTUALBOX_VM_NAME/d" ./vagrant_config.rb &&\
            sed -i -e "/DEVHOST_NUM/d" ./vagrant_config.rb
        # load initial box image & do initial provisionning
        up && lret="0"
        down
        if [ "x${lret}" != "x0" ];then
            log "Error while importing ${box}"
            exit $lret
        else
            log "Box ${box} imported !"
        fi
    fi
}

version() {
    log "VMS"
    git log|head -n1|awk '{print $2}'|sed "s/^/    /g"
    if [ -e VM/src/salt/makina-states ];then
        log "Makina-States"
        cd VM/src/salt/makina-states
        git log|head -n1|awk '{print $2}'|sed "s/^/    /g"
        cd - &> /dev/null
    fi
    log Virtualbox
    VBoxManage --version|sed "s/^/    /g"
    log Vagrant
    vagrant --version|sed "s/^/    /g"
    vagrant plugin list|sed "s/^/    /g"
    log "kernel & sshfs"
    uname -a|sed "s/^/    /g"
    sshfs --version 2>&1|sed "s/^/    /g"

}

reset() {
    if [ -e "${VMPATH}" ];then
        cd "${VMPATH}"
        if [ -e .vagrant ];then
            destroy
        fi
        rm -rvf vagrant_config.rb .vagrant
        log " [*] Reset done"
    else
        log " [*] Reset skipped: ${VMPATH} does not exists"
    fi
}

get_abspath() {
    python -c "import os;print os.path.abspath(os.path.expanduser('${1}'))" 2> /dev/null

}

clonevm() {
    NEWVMPATH="${1}"
    OLDVMPATH="${VMPATH}"
    tarballs="$(ls -1rt *.tar.bz2)"
    tarball="$(ls -1rt devhost*.tar.bz2|head -n1)"
    if [ ! -e ${NEWVMPATH} ];then
        mkdir "${NEWVMPATH}"
    fi
    import_uri="${2}"
    can_continue=""
    active_echo
    log "Syncing in ${NEWVMPATH}"
    if [ -e "${NEWVMPATH}" ];then
        if [ -d "${NEWVMPATH}" ];then
            if [ "x${NO_INPUT}" = "x" ] || [ "x${input}" = "xy" ];then
                log "Do you really want to nuke vm in ${NEWVMPATH} ?"
                log "[press y+ENTER, or CONTROL+C to abort]";read input
            fi
            if [ "x${NO_INPUT}" != "x" ] || [ "x${input}" = "xy" ];then
                cd "${NEWVMPATH}"
                if [ "x${NO_CLEAN}" = "x" ] && [ -f manage.sh ];then
                    ./manage.sh reset
                fi
                can_continue=1
            fi
        fi
    fi
    if [ -e "${NEWVMPATH}" ] && [ "x${can_continue}" = "x" ];then
        log "File already exists, please delete it with rm -rf '${NEWVMPATH}' or choose another path"
        exit 1
    fi
    cd "${OLDVMPATH}"||exit -1
    sudo rsync -av\
        --exclude=VM\
        --exclude="*.tar.bz2"\
        --exclude=.vagrant --exclude=vagrant_config.rb \
        "${OLDVMPATH}/" "${NEWVMPATH}/"
    cd "${NEWVMPATH}"||exit -1
    ID=$(whoami)
    sudo chown -f "${ID}" packer VM docker
    sudo chown -Rf "${ID}" .git vagrant vagrant_config.rb .vagrant
    if [ -f manage.sh ] && [ "x${NO_CLEAN}" = "x" ];then
        log "Wiping in ${NEWVMPATH}"
        ./manage.sh reset
    fi &&\
        log "Cloning in ${NEWVMPATH}" &&\
        for i in ${tarballs};do
            oldp="${OLDVMPATH}/${i}"
            newp="${NEWVMPATH}/${i}"
            lnskip=""
            if [ -e "${oldp}" ] && [ ! -f "${newp}" ];\
            then
                # transform in full path tarballs
                if [ -h "${oldp}" ];then
                    if [ ! -d "${oldp}" ];then
                        cd $(dirname ${oldp})
                        oldp=$(get_abspath "$(readlink ${oldp})")
                        cd - &>/dev/null
                    else
                        lnskip="1"
                    fi
                fi
                if [ "x${lnskip}" = "x" ];then
                    ln -sfv "${oldp}" "${newp}"
                fi
            fi
        done &&\
        ntarball="$(ls -1rt devhost*.tar.bz2|head -n1)" &&\
        if [ ! -e "${ntarball}" ];then ntarball="${import_uri:-$(get_release_url)}";fi &&\
        pb=""
        cd "${NEWVMPATH}" &&\
        if [ "x${NO_IMPORT}" = "x" ];then
            pb="import" &&\
            log "Init in ${VMPATH}" &&\
            ./manage.sh init "${ntarball}"
        else
            pb="init" &&\
            log "UP in ${NEWVMPATH}" &&\
            ./manage.sh reload
        fi
        die_in_error "problem while cloning / ${pb}"
    unactive_echo
}

test() {
    TESTPATH="${VMPATH}-test"
    NO_SYNC_HOSTS=1 NO_INPUT=1 clonevm "${TESTPATH}"
}

do_zerofree() {
    log "Zerofreing" &&\
    up &&\
    ssh "sudo /sbin/zerofree.sh" &&\
    log " [*] WM Zerofreed"
}

action="${1}"

if [ "x${MANAGE_AS_FUNCS}" = "x" ];then
    if [  "x${RSYNC}" = "x" ];then
        log "Please install rsync"
        exit -1
    fi
    mac_setup
    if [ "x${action}" = "x" ];then
        action=usage
    fi
    thismatch=$(echo " ${actions} "|sed -e "s/.* ${action} .*/match/g")
    if [ "x${thismatch}" = "xmatch" ];then
        shift
        case ${action} in
            export) action="export_"
                ;;
            -v|--version) action="version"
                ;;
            usage|-h|--help) action="usage"
                ;;
            -l|--long-help) action="usage";LONGHELP=1
                ;;
        esac
        ${action} $@
        exit ${?}
    else
        echo "invalid invocation: ${0} ${@}" 1>&2
        usage ${@};exit -1
    fi
    usage $@
    exit 0
fi
# vim:set et sts=4 ts=4 tw=0:
