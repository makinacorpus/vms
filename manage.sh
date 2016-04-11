#!/usr/bin/env bash
LAUNCH_ARGS="${@}"
UNAME="$(uname)"
actions=""
actions_main_usage="usage init ssh up reload env destroy down suspend status clonevm remount_vm umount_vm version shutdown poweroff off"
actions_exportimport="export import"
actions_advanced="do_zerofree test install_keys mount_vm release internal_ssh gen_ssh_configs reset detailed_status"
actions_internal="ssh__ long_status all_running_hosts all_hosts first_running_host get_devhost_num is_mounted first_host raw_internal_ssh raw_ssh vagrant_ssh"
actions_alias="-h --help --long-help -l -v --version"
actions="
    ${actions_exportimport}
    ${actions_main_usage}
    ${actions_advanced}
    ${actions_internal}
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
DEVHOST_NUM=""
FUSERMOUNT="fusermount"
TAR_FORMAT="${TAR_FORMAT:-bz2}"

get_tar_knob() {
    if echo "${@}" | egrep -q '.(xz|lzma)$';then
        echo "J"
    elif echo "${@}" | egrep -q '.(gz|gzip)$';then
        echo "z"
    elif echo "${@}" | egrep -q '.(bz2|bzip2)$';then
        echo "j"
    else
        echo ""
    fi
}

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
                    help_header ${i} "[URL | FILEPATH | VAGRANT_BOX_NAME] [VAGRANT_BOX_NAME]"
                    help_content "      Initialise a new VM from either a vagrant cached vm, the specified archive produced by"
                    help_content "      the export command or by default to the last stable release (no arguments to init)"
                    help_content "      If vagrant box name is provided, pay attention that it won't reimport an already existing box into vagrant cache vms"
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
                mount_vm)
                    help_header ${i}
                    help_content "      Mount the vm filesystem on the host using sshfs"
                    ;;
                umount_vm)
                    help_header ${i}
                    help_content "      Umount the vm filesystem"
                    ;;

                env)
                    help_header ${i}
                    help_content "      Get MISC variables to be used in shell (DOCKER_HOST, DEVHOST_IP, etc)"
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
                gen_ssh_configs)
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

status_() {
    vagrant status 2> /dev/null
}

long_status() {
    status_\
        | grep -i "(virtualbox)"\
        | grep -v grep\
        | grep -v provider\
        | grep -i virtualbox\
        | sed -e "s/\([ ^\t]\)*[(].*//g"\
        | sed -e "s/\([ \t]\)*$//g"\
        | sed -e "s/^\([ \t]\)*//g" | while read hostline;do
        if [ "x${@}" != "x" ];then
            for h in ${@};do
                host=$(echo ${hostline}|awk '{print $1}')
                hstatus=$(echo ${hostline}|awk '{print $2}')
                if [ "x${host}" = "x${h}" ];then echo "${h} ${hstatus}";fi
            done
        else
            echo "${hostline}"
        fi
    done
}

detailed_status() {
    echo "host                      status      ip_local"
    echo "--------------------------------------------------------"
    while read -u 3 l;do
        local sshhost="$(echo ${l}|awk '{print $1}')"
        local hstatus="$(echo ${l}|sed -e "s/[^ ]\+ \+//")"
        local add=""
        if [ "x${hstatus}" = "xrunning" ];then
            add="${add}     ip_local:$(get_host_ip)"
        fi
        echo "${l}${add}"
    done 3< <(long_status ${@})
}

status() {
    long_status ${@} | sed -e "s/[^ ]* *//" | uniq
}

is_running() {
    local i=""
    for i in $(default_to_all_hosts $@);do
        if status $i | grep -vq running;then
            return 1
        fi
    done
    return 0
}

all_hosts() {
    long_status $@ | awk '{print $1}'
}

first_host() {
    if [ "x${FIRST_HOST}" = "x" ];then
        FIRST_HOST=$(all_hosts| head -n 1)
    fi
    echo ${FIRST_HOST}
}

all_running_hosts() {
    long_status $@ | grep running | awk '{print $1}'
}

first_running_host() {
    all_running_hosts $@ | head -n 1
}

default_to_first_host() {
    if [ "x${1}" = "x" ];then
        echo $(first_host)
    else
        echo "${1}"
    fi
}

default_to_all_hosts() {
    if [ "x${1}" = "x" ];then
        echo $(all_hosts)
    else
        echo "${1}"
    fi
}

destroy() {
    cd "${VMPATH}"
    local u=""
    for i in $(default_to_all_hosts $@);do
        log "Destroy $i !"
        down $i
        vagrant destroy -f $i
        if [ -d .vagrant/machines/$i ];then rm -rf .vagrant/machines/$i;fi
        mark_ssh_config_not_done $i
    done
}

suspend() {
    cd "${VMPATH}"
    local u=""
    for i in $(default_to_all_hosts $@);do
        log "Suspend $i !"
        vagrant suspend $i
    done
}

set_wrapper_present(){
    local sshhost="$(default_to_first_host ${1:-${sshhost}})"
    local slug="${sshhost//-/}"
    eval local stest="\$WRAPPER_PRESENT_${slug}"
    if [ "x${stest}" = "x" ];then
        if [ "x$(sshuser=vagrant sshhost=$sshhost \
                  raw_internal_ssh_ \
                    sudo test -e "${PROVISION_WRAPPER}";echo ${?})" = "x0" ];then
            eval WRAPPER_PRESENT_${slug}="1"
        fi
    fi
}

set_devhost_num() {
    if [ "x${DEVHOST_NUM}" = "x" ];then
        DEVHOST_NUM="$(echo -e ${@:-$(long_status)}|head -n1|awk -F'devhost' '{print $2}'|awk -F- '{print $1}')"
    fi
}

get_devhost_num() {
    if [ "x${DEVHOST_NUM}" = "x" ];then set_devhost_num;fi
    echo "${DEVHOST_NUM}"
}

mark_ssh_config_not_done() {
    eval HOSTONLY_SSH_CP_CONFIG_DONE_${@//-/}=""
    eval HOSTONLY_SSH_CONFIG_DONE_${@//-/}=""
    eval SSH_CONFIG_DONE_${@//-/}=""
    eval WRAPPER_PRESENT_${@//-}=""
    DEVHOST_NUM=""
}

raw_ssh_() {
    local sshhost="$(default_to_first_host ${sshhost})"
    local sshuser="${sshuser:-root}"
    ssh -o ConnectTimeout=2 -F "${ssh_config}-${sshhost}" ${sshuser}@${sshhost} "${@}"
}


raw_internal_ssh_() {
    local sshhost="$(default_to_first_host ${sshhost})"
    local sshuser="${sshuser:-root}"
    ssh -o ConnectTimeout=2 -F "${internal_ssh_config}-${sshhost}" ${sshuser}@${sshhost} "${@}"
}

gen_internal_ssh_config() {
    local sshhost="$(default_to_first_host $1)"
    local slug="${sshhost//-/}"
    # if config is present and usable, use it
    eval local stest="\$SSH_CONFIG_DONE_${slug}"
    if [ "x${stest}" = "x" ] && [ -e "${internal_ssh_config}-${sshhost}" ];then
        raw_internal_ssh_ true 2>/dev/null && eval SSH_CONFIG_DONE_${slug}="1"
    fi
    eval stest="\$SSH_CONFIG_DONE_${slug}"
    if [ "x${stest}" = "x" ];then
        local vsshconfig=$(vagrant ssh-config $sshhost 2>/dev/null)
        if [ "x${vsshconfig}" != "x" ];then
            echo -e "${vsshconfig}">"${internal_ssh_config}-${sshhost}"
        fi
        if [ ! -f "${internal_ssh_config}-${sshhost}" ];then
            log "$sshhost: Cant generate ${internal_ssh_config}-${sshhost}"
            return 1
        else
            eval SSH_CONFIG_DONE_${slug}="1"
        fi
    fi
}

get_host_ip() {
    local sshhost="$(default_to_first_host ${1:-${sshhost}})"
    hostip=$(sshuser=root sshhost=$sshhost raw_internal_ssh_ ip addr show dev eth1)
    if [ "x${hostip}" != "x" ];then
        hostip=$(echo "${hostip}"|awk '/inet / {gsub("/.*", "", $2);print $2}'|head -n1)
    fi
    echo "${hostip}"
}

gen_hostonly_ssh_config() {
    local sshhost="$(default_to_first_host ${1:-${sshhost}})"
    local slug="${sshhost//-/}"
    eval local stest="\$HOSTONLY_SSH_CONFIG_DONE_${slug}"
    if [ "x${stest}" = "x" ] \
        && [ -e "${ssh_config}-${sshhost}" ] \
        && ! grep -q 127.0.0.1 "${ssh_config}-${sshhost}"; then
        raw_ssh_ true 2>/dev/null && eval HOSTONLY_SSH_CONFIG_DONE_${slug}="1"
    fi
    eval local stest="\$HOSTONLY_SSH_CONFIG_DONE_${slug}"
    if [ "x${stest}" = "x" ];then
        gen_internal_ssh_config ${sshhost}
        eval local scptest="\$HOSTONLY_SSH_CP_CONFIG_DONE_${slug}"
        if [ "x${scptest}" = "x" ];then
            cp -f "${internal_ssh_config}-${sshhost}" "${ssh_config}-${sshhost}"
            eval HOSTONLY_SSH_CP_CONFIG_DONE_${slug}=-1
        fi
        hostip=$(get_host_ip $sshhost)
        if [ "x${hostip}" != "x" ];then
            sed -i -e "/Host ${sshhost}/, /Host / s/HostName.*/HostName ${hostip}/g" "${ssh_config}-${sshhost}"
            sed -i -e "/Port.*/d" "${ssh_config}-${sshhost}"
            eval HOSTONLY_SSH_CONFIG_DONE_${slug}=1
        else
            log "${sshhost}: Fallback to internal as we could not detect any ip on eth1"
        fi
    fi
}

raw_ssh() {
    local sshhost="$(default_to_first_host ${sshhost})"
    gen_hostonly_ssh_config $sshhost
    raw_ssh_ "${@}"
}

raw_internal_ssh() {
    local sshhost="$(default_to_first_host ${sshhost})"
    gen_internal_ssh_config $sshhost
    raw_internal_ssh_ "${@}"
}

gen_ssh_configs() {
    cd "${VMPATH}"
    local allhosts=$(default_to_all_hosts $@)
    if [ ! -d .vagrant ];then mkdir .vagrant;fi
    local i=""
    active_echo
    set_devhost_num ${@}  # optim, we get devnum for guessed host
    for i in $allhosts;do
        gen_internal_ssh_config $i
        set_wrapper_present $i
        gen_hostonly_ssh_config $i
    done
    unactive_echo
}

install_keys() {
    active_echo
    local i=""
    for i in $(default_to_all_hosts $@);do
        gen_ssh_configs $i
        if set_wrapper_present $i;then
            sshuser=vagrant sshhost=${i} raw_internal_ssh_ sudo ${PROVISION_WRAPPER} sync_ssh 2>/dev/null
        else
            log "Warning: $i: could not install ssh keys, shared folder mountpoint seems not present"
        fi
    done
    unactive_echo
}

ssh_pre_reqs() {
    local u=""
    for i in $(default_to_all_hosts $@);do
        gen_ssh_configs $i
        if ! is_running $i;then up $i;fi
        install_keys $i
    done
}

ssh_() {
    cd "${VMPATH}"
    local sshhost="${sshhost:-}" allhosts="$(all_hosts)"
    if [ "x${1}" != "x" ] && [ "x${sshhost}" = "x" ];then
        if echo "$allhosts" | sed -e "s/\(^\|$\)/ /g" | grep -q " ${1} ";then
            sshhost="${1}"
            shift
        fi
    fi
    if [ "x${sshhost}" = "x" ];then
        sshhost="$(default_to_first_host ${allhosts})"
    fi
    if [ "x${sshhost}" != "x" ];then
        active_echo
        local sconfig="" sconfigt=""
        gen_ssh_configs $sshhost
        local func=""
        for func in raw_ssh raw_internal_ssh;do
            if ${func} true;then break;fi
            func=""
        done
        if [ "x${func}" = "x" ];then
            log "Cant ssh, unreachable: $i (tried: ${ssh_config}-${sshhost} ${internal_ssh_config}-${sshhost})"
            log " [*] is VM $sshhost is not running"
            log   "   You should start via ./manage.sh up $sshhost, or ./manage.sh init $sshhost first"
            return 1
        fi
        ${func} "${@}"
        unactive_echo
    else
        log "Cant ssh, empty host $i"
        return 1
    fi
}

pre_down() {
    local u=""
    for i in $(default_to_all_hosts $@);do
        if [ "x$(status)" = "xrunning" ];then
            umount_vm $i
            sshuser=vagrant sshhost=$i raw_internal_ssh_ sudo sync 2>/dev/null
        else
            log " [*] pre_down: VM already stopped $i"
        fi
    done
}

remount_vm() {
    local i=""
    for i in $(default_to_all_hosts $@);do
        log "Remounting vm $i"
        umount_vm $i && mount_vm $i
    done
}

poweroff() {
    down ${@}
}

off() {
    down ${@}
}


shutdown() {
    down ${@}
}

down() {
    cd "${VMPATH}"
    local i=""
    for i in $(default_to_all_hosts $@);do
        umount_vm $i
        log "Down $i !"
        if is_running $i;then
            pre_down $i
            vagrant halt -f $i
            mark_ssh_config_not_done $i
        else
            log " [*] VM already stopped $i"
        fi
    done
}

maybe_finish_creation() {
    lret=$1
    shift
    restart_marker="/tmp/vagrant_provision_needs_restart"
    local i=""
    for i in $(default_to_all_hosts $@);do
        if [ "x${lret}" != "x0" ];then
            for i in $(seq 3);do
                marker="$(sshuser=vagrant sshhost=$i raw_internal_ssh_ \
                    sudo test -e ${restart_marker} &> /dev/null;echo ${?})"
                if [ "x${marker}" = "x0" ];then
                    log "$i: First runs, we issue a scheduled reload after the first up(s)"
                    reload ${i}
                    lret="${?}"
                elif [ "x${lret}" != "x0" ];then
                    log "$i: Error in vagrant up/reload"
                    return 1
                else
                    break
                fi
            done
        fi
    done
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
    local sshhost="$(default_to_first_host ${sshhost})"
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
    NO_IMPORT=1 clonevm "${RELEASE_PATH}"
    export VMPATH="${RELEASE_PATH}"
    log "Releasing ${rname}" &&\
        if [ ! -f "${rarc}" ];then
            sshhost=${sshhost} export_ "${rname}" zerofree
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
            log "somewhere and the download works and the sf.net mirrors are well synchronized" &&\
            log "URL to test is: $(get_release_url ${rname})" &&\
            log "Automatic commit in 30mins, or pres CC and issue git push manually" &&\
            sleep "$((30 * 60))" && git push
        log "End of release"
    fi

}

init() {
    cd "${VMPATH}"
    status="$(status)"
    if status | grep -q "not created";then import "${@}";fi
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
    mounted=""
    if [ "x$(mount|awk '{print $3}'|egrep "${VM}/${1}$" |grep -v grep| wc -l|sed -e "s/ //g")" != "x0" ]\
        || [ "x$(get_sshfs_ps| wc -l|sed -e "s/ //g")" != "x0" ];then
        mounted="1"
    fi
    echo ${mounted}
    #set +x
}

mount_vm() {
    cd "${VMPATH}"
    active_echo
    hosts="${@}"
    if [ "x${hosts}" = "x" ];then hosts=$(all_hosts);fi
    local host=""
    local sshhost=""
    for host in ${hosts};do
        local sshhost="${host}"
        # something is wrong with the mountpath, killing it
        test_not_connected="$(LANG=C ls VM/${host} 2>&1)"
        if [ ! -e "${VM}/${host}/home/vagrant/.ssh" ]\
            || [ "x$(echo "${test_not_connected}"|grep -q "is not connected";echo ${?})" = "x0" ];then
            umount_vm ${host}
        fi
        if [ ! -e "${VM}/${host}/home/vagrant/.ssh" ];then
            if [ ! -e "${VM}/${host}" ];then mkdir -p "${VM}/${host}";fi
            ssh_pre_reqs $@
            if [ "x${sshhost}" != "x" ];then
                log "Mounting devhost(${sshhost}):/ --sshfs--> ${VM}/${host}"
                sshopts="transform_symlinks,reconnect,BatchMode=yes"
                if [ "x$(egrep "^user_allow_other" /etc/fuse.conf 2>/dev/null|wc -l|sed -e "s/ //g")" != "0" ];then
                    sshopts="${sshopts},allow_other"
                fi
                if [ "x${UNAME}" != "xDarwin" ];then sshopts="${sshopts},nonempty";fi
                if [ "x${UNAME}" = "xDarwin" ];then sshopts="${sshopts},defer_permissions";fi
                mountpoint="/guest"
                if ssh -F "${ssh_config}-${sshhost}" "${sshhost}"  test ! -e /guest;then
                    if ssh -F "${ssh_config}-${sshhost}" "${sshhost}" sudo ${PROVISION_WRAPPER} create_vm_mountpoint;then
                        if ssh -F "${ssh_config}-${sshhost}" "${sshhost}" test ! -e /guest/bin;then
                            log "${sshhost}: /guest does not exists, fallback to /"
                            mountpoint="/"
                        fi
                    else
                        log "${sshhost}: /guest populator does not exists, fallback to /"
                        mountpoint="/"
                    fi
                fi
                sshfs -F "${ssh_config}-${sshhost}" root@${sshhost}:"${mountpoint}" -o ${sshopts} "${VM}/${host}"
            else
                log "${sshhost}: Cant' mount sshfs, empty ssh host"
                return -1
            fi
        fi
    done
    unactive_echo
}

get_pid_line() {
    pid="${1}"
    ps -eo pid,user,comm,args --no-headers|egrep "^[ \t]*${pid}[ \t]"|grep -v grep
}

smartkill_() {
    PIDS=${@}
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
    hosts="${@}"
    if [ "x${hosts}" = "x" ];then hosts=$(all_hosts);fi
    local host=""
    for host in ${hosts};do
        PIDS=""
        PIDS="${PIDS} $(get_lsof_pids ${host})"
        PIDS="${PIDS} $(get_sshfs_pids ${host})"
        smartkill_ ${PIDS}
    done
}


do_umount() {
    hosts="${@}"
    if [ "x${hosts}" = "x" ];then hosts=$(all_hosts);fi
    local host=""
    for host in ${hosts};do
        args="-f"
        if [ "x${UNAME}" = "xLinux" ];then
            args="${arg} -l"
        fi
        for arg in ${args};do
            if [ "x$(is_mounted ${host})" != "x" ] && [ "x${noumount}" = "x" ];then
                sudo umount ${arg} "${VM}/${host}" 2>&1
            fi
        done
    done
}

do_fusermount () {
    noumount=""
    local u=""
    for i in ${@};do
        case ${i} in
            noumount) noumount=1;shift;
                ;;
        esac
    done
    hosts="${@}"
    if [ "x${hosts}" = "x" ];then hosts=$(all_hosts);fi
    local host=""
    for host in ${hosts};do
        fuseropts="-u"
        if [ "x${UNAME}" = "xDarwin" ];then
            fuseropts=""
        fi
        lret=$(${FUSERMOUNT} ${fuseropts} "${VM}/${host}" 2>&1)
        # let a little time to fusermount to do his art
        sleep 2
        if [ "x$(echo "${lret}"|grep -q "not found";echo ${?})" = "x0" ] && [ "x$(is_mounted ${host})" != "x" ];then
            if [ "x${noumount}" = "x" ];then
                do_umount ${host}
            fi
        fi
        if [ "x$(is_mounted ${host})" != "x" ] || [ "x$(echo ${lret}|grep -q "Permission denied";echo ${?})" = "x0" ];then
            # let a little time to fusermount to do his art
            sleep 2
            sudo ${FUSERMOUNT} ${fuseropts} "${VM}/${host}" 2>&1
        fi
        if [ "x${noumount}" = "x" ];then
            do_umount ${host}
        fi
    done
}

umount_vm() {
    hosts="${@}"
    if [ "x${hosts}" = "x" ];then hosts=$(all_hosts);fi
    if [ "x${DARWIN_DEBUG}" != "x" ];then set -x;fi
    cd "${VMPATH}"
    local host=""
    for host in ${hosts};do
        if [ "x$(is_mounted ${host})" != "x" ];then
            log "Umounting of ${VM}/${host}"
            do_fusermount noumount "${host}"
        fi
        if [ "x$(is_mounted ${host})" != "x" ];then
            log "Forcing umounting of ${VM}/${host}"
            smartkill "${host}"
            do_fusermount "${host}"
        fi
        if [ "x${?}" != "x0" ];then
            log "Can't umount vm: ${host}"
            exit "${?}"
        fi
    done
    if [ "x${DARWIN_DEBUG}" != "x" ];then set +x;fi
}

up() {
    cd "${VMPATH}"
    local i=""
    for i in $(default_to_all_hosts $@);do
        log "Up $i !"
        notrunning=""
        if ! is_running $i; then
            notrunning="1"
        fi
        if [ ! -d share ];then mkdir share;fi
        vagrant up ${i}
        lret=${?}
        # be sure of jumbo frames on anything else that macosx
        if [ "x${notrunning}" != "x" ] && [ "x${UNAME}" != "xDarwin" ];then
            sshuser=vagrant sshhost=$i raw_internal_ssh_ sudo ifconfig eth1 mtu 9000 2>/dev/null
        fi
        post_up ${lret} ${i}
    done
}

post_up() {
    lret=$1
    shift
    local i=""
    for i in $(default_to_all_hosts $@);do
        maybe_finish_creation ${lret} ${i}
        mount_vm $i
    done
}

reload() {
    cd "${VMPATH}"
    local i=""
    for i in $(default_to_all_hosts $@);do
        log "Reload $i !"
        umount_vm $i
        if ! is_running $i;then
            mark_ssh_config_not_done $i
            up $i
        else
            pre_down $i
            vagrant reload ${i}
            lret=${?}
            post_up ${lret} ${i}
        fi
    done
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
    echo "${1:-"$(get_box_name ${2})"}.tar.${TAR_FORMAT}"
}

get_release_url() {
    rname="${1:-$(get_release_name)}"
    echo "${BASE_URL}/$(get_devhost_archive_name ${rname})"
}

export_() {
    local sshhost="$(default_to_first_host ${sshhost})"
    zerofree=""
    nozerofree=""
    for i in ${@};do
        if [ "x${i}" = "xzerofree" ];then
            zerofree=y
        elif [ "x${i}" = "xnozerofree" ];then
            nozerofree=y
        elif [ "x${i}" = "xnosed" ];then
            nosed=y
        else
            bname="${i}"
        fi
    done
    cd "${VMPATH}"
    export NOCONFIRM=1
    local sshhost=$(first_host)
    bname="${bname:-"$(get_box_name)"}"
    box="$(get_vagrant_box_name ${bname})"
    abox="$(get_devhost_archive_name ${bname})"
    nincludes=""
    includes=""
    tar_k=$(get_tar_knob "${abox}")
    tar_preopts="c${tar_k}vf"
    tar_postopts="--numeric-owner"
    #
    # be sure to package a blank vagrantfile along with the box to not conflict with our Vagrantfile
    # at import time
    #
    packaged_vagrantfile="$(generate_packaged_vagrantfile)"
    nincludes=""
    for i in .vb_* vagrant_config.yml;do
        if [ -e "${i}" ];then
            nincludes="${i} ${nincludes}"
        fi
    done
    if [ "x${UNAME}" = "xDarwin" ];then tar_postopts="";fi
    if [ "x${UNAME}" != "xDarwin" ];then tar_preopts="${tar_preopts}p";fi
    if [ "x${tar_k}" = "xJ" ];then
        export XZ_OPT="${VMS_XZ_OPT:-${XZ_OPT:-"-9e"}}"
        log "using VMS_XZ_OPTS: ${XZ_OPT}"
    fi
    netrules="/etc/udev/rules.d/70-persistent-net.rules"
    # XXX: REALLY IMPORTANT TO NOTE IS THAT THE BOC MUST BE THE FIRST TARED FILE !!!
    if [ "x${nozerofree}" = "x" ] && [ "x${zerofree}" = "x" ];then
        log "Zerofree will starting in 10 seconds, in the mean time you can interrupt the process with control-C"
        log "and relaunch with the same cmdline with nozerofree appended: eg ./manage.sh export nozerofree"
        sleep 10
        zerofree=y
    fi
    if [ "x${zerofree}" != "x" ];then
        do_zerofree $sshhost
    else
        log "$sshhost: Skip zerofree on export"
    fi
    if [ ! -e "${box}" ];then
        vagrant box remove ${bname}
        down $sshhost && up $sshhost && gen_ssh_configs $sshhost
        if [ "x${?}" = "x" ];then
            log "Can't provision VM $sshhost"
            return -1
        fi
        set_wrapper_present $sshhost
        if [ "x${?}" = "x" ];then
            log "${PROVISION_WRAPPER} is not there in the VM $sshhost"
            return -1
        fi
        if [ "x${nosed}" = "x" ];then
            sshuser=vagrant sshhost=$sshhost raw_internal_ssh_ \
                "bash -c \"if sudo test -d ${netrules};then sudo rm -rf ${netrules};sudo mkdir ${netrules};fi\""
            sshuser=vagrant sshhost=$sshhost raw_internal_ssh_ \
                "bash -c \"if sudo test -e ${netrules};then sudo sed -re 's/^SUBSYSTEM/#SUBSYSTEM/g' -i ${netrules};fi\""
        fi
        sshuser=vagrant sshhost=$sshhost raw_internal_ssh_ \
          sudo ${PROVISION_WRAPPER} mark_export 2>/dev/null &&\
            down $sshhost &&\
            export DEVHOST_BOX="${bname}" &&\
            log "Be patient, exporting now $sshhost" &&\
            vagrant package --vagrantfile "${packaged_vagrantfile}" --output "${box}" $sshhost 2> /dev/null &&\
            rm -f "${EXPORT_VAGRANTFILE}"*  &&\
            if [ -e "${box}" ] && [ ! -e "${abox}" ];then
                log "Be patient, archiving now the whole full box package for $sshhost" &&\
                    tar ${tar_preopts} ${abox} ${box} ${includes} ${tar_postopts} &&\
                    rm -f "${box}" &&\
                    log "$sshhost: Export done of full box: ${VMPATH}/${abox}"
            else
                log "${VMPATH}/${abox}, delete it to redo"
            fi
            down $sshhost && up $sshhost --no-provision &&\
              sshuser=vagrant sshhost=$sshhost raw_internal_ssh_ \
                sudo ${PROVISION_WRAPPER} unmark_exported 2>/dev/null && down
        else
        log "$sshhost: ${VMPATH}/${box} exists, delete it to redo"
    fi
}

check_tmp_file() {
    fname="${1}"
    res="ok"
    if [ -e ${fname} ];then
        tmpsize=$(dd if=${fname} bs=4046 count=40000 2>/dev/null|wc -c | sed -e 's/^[[:space:]]*//')
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
    fname="${2:-$(basename ${url})}"
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
        return 1
    fi
    unactive_echo
}

get_vagrant_boxes() {
    vagrant box list 2> /dev/null|awk '{print " " $1 " "}'
}

import() {
    cd "${VMPATH}"
    url=""
    sshurl=""
    image="${1:-$(get_release_url $(get_release_name))}"
    bname="$(echo "${bname:-${2:-$(basename "${image}")}}" | sed "s/\.tar.*//g")"
    box="$(get_vagrant_box_name ${bname})"
    tar_k="$(get_tar_knob ${image})"
    tar_preopts="-x${tar_k}vpf"
    tar_postopts="--numeric-owner"
    if [ "x$(echo ${image}|grep -q http;echo ${?})" = "x0" ];then
        url="${image}"
        log "using HTTP: ${url}"
        image="$(basename ${image})"
    elif [ "x$(echo ${image}|grep -q :;echo ${?})" = "x0" ];then
        sshurl="${image}"
        log "using RSYNC(ssh): ${sshurl}"
        image="$(basename $(echo "${image}"|sed "s/.*://g"))"
    fi
    # test if vm has already been imported
    if [ "x$(status)" != "xnot created" ];then
        log "VM already imported,"
        log "   - Run it with: ${THIS} up"
        log "   - Delete it with: ${THIS} destroy"
        exit 0
    fi
    if [ "x$(echo " $(get_vagrant_boxes) "|grep -q " ${bname} ";echo ${?})" = "x0" ];then
        log "BASE VM already imported, redo base vm import by issuing:"
        log "  vagrant box remove '${bname}' && ${THIS} ${LAUNCH_ARGS}"
    else
        if [ ! -e "${box}" ];then
            do_download=""
            if [ ! -e "${image}" ];then
                if  [ "x${url}" != "x" ];then do_download="1";fi
                if  [ "x${sshurl}" != "x" ];then do_download="1";fi
            else
                if [ "x$(check_tmp_file ${image})" = "x" ];then do_download="1";fi
            fi
            if [ "x${do_download}" != "x" ];then
                if [ "x${url}" != "x" ];then
                    download "${url}" "${image}"
                elif [ "x${sshurl}" != "x" ];then
                    rsync -azvP "${sshurl}" "${image}"
                    die_in_error "scp failed: ${sshurl} -> ${image}"
                fi
            elif [ "x${url}" != "x" ] || [ "x${sshurl}" != "x" ];then
                log "${image} already exists, "
                log "   delete this archive, if you want to redownload"
                log "   from ${url}"
            fi
            if [ ! -e "${image}" ];then
                log "Missing image file: ${image}"
                return -1
            else
                log "Getting box name from ${image}"
                box="$(dd if=${image} bs=1024 count=10000 2>/dev/null|tar -t${tar_k}f - 2>/dev/null)"
            fi
            if [ ! -e "${box}" ];then
                log "Unarchiving ${image}"
                tar ${tar_preopts} "${image}" $tar_postopts
                if [ "x${?}" != "x0" ];then
                    log "Error unarchiving ${image}"
                    return 1
                fi
            else
                log "Existing ${box}, if you want to unarchive from image file again, delete it"
            fi
        fi
        if [ ! -e "${box}" ];then
            log "Missing ${box}"
            return -1
        fi
        log "Importing ${box} into vagrant bases boxes as '${bname}' box"
        vagrant box add -f "${bname}" "${box}" && rm -f "${box}"
        if [ "x${?}" != "x0" ];then
            log "Error while importing ${bname} (from: ${box})"
            exit ${?}
        fi
    fi
    # load initial box image & do initial provisionning
    log "Initialiasing from BASEBOX: ${bname}"
    export DEVHOST_BOX="${bname}"
    if [ ! -e ./vagrant_config.yml ];then
        echo "---">./vagrant_config.yml
    fi &&\
        sed -i -e "/VIRTUALBOX_VM_NAME/d" ./vagrant_config.yml &&\
        sed -i -e "/SSH_INSERT_KEY/d" ./vagrant_config.yml &&\
        sed -i -e "/DEVHOST_NUM/d" ./vagrant_config.yml
    uplret=1
    for i in $(default_to_all_hosts);do
        up $i && uplret=${?}
        down $i
        if [ "x${uplret}" != "x0" ];then
            log "$i: Error while importing ${bname}"
            exit $uplret
        else
            log "$i: Box ${bname} imported !"
        fi
    done
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
        if [ -e .vagrant ];then destroy;fi
        if [ -e vagrant_config.yml ];then rm -vf vagrant_config.yml;fi
        if [ -e vagrant_config.rb ];then rm -vf vagrant_config.rb;fi
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
    tarballs="$(ls -1rt *.tar.{bz2,gz,xz} 2>/dev/null)"
    tarball="$(ls -1rt devhost*.tar.{bz2,gz,xz} 2>/dev/null|head -n1)"
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
        return 1
    fi
    cd "${OLDVMPATH}"||return -1
    sudo rsync -av\
        --exclude=VM\
        --exclude="*.tar.bz2"\
        --exclude="*.tar.xz"\
        --exclude="*.tar.gz"\
        --exclude=.vagrant --exclude=vagrant_config.rb --exclude=vagrant_config.yml \
        "${OLDVMPATH}/" "${NEWVMPATH}/"
    cd "${NEWVMPATH}"||return -1
    ID=$(whoami)
    sudo chown -f "${ID}" packer VM docker
    sudo chown -Rf "${ID}" .git vagrant vagrant_config.rb vagrant_config.yml .vagrant
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
        ntarball="$(ls -1rt devhost*.tar.{gz,bz2,xz} 2>/dev/null|head -n1)" &&\
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
    NO_INPUT=1 clonevm "${TESTPATH}"
}

do_zerofree() {
    local sshhost="$(default_to_first_host ${1:-$sshhost})"
    log "Zerofree starting for $sshhost ! DO NOT INTERRUPT ANYMORE"\
        && up ${sshhost}\
        && sshuser=vagrant raw_internal_ssh_ sudo /sbin/zerofree.sh\
        && log " [*] VM Zerofreed: $sshhost"
}

env_() {
    local sshhost="$(default_to_first_host ${sshhost})"
    if [ "x$(status ${sshhost})" != "xrunning" ];then
        echo "# VM IS NOT RUNNING: $sshhost"
    else
        gen_ssh_configs ${sshhost}
        ip=$(sshhost="${sshhost}" get_host_ip)
        echo export DOCKER_HOST=\"tcp://${ip}\"
        echo export DEVHOST_IP=\"${ip}\"
        echo export DEVHOST_NUM=\"$(sshhost="${sshhost}" get_devhost_num)\"
    fi
}

action="${1}"

if [ "x${MANAGE_AS_FUNCS}" = "x" ];then
    if [  "x${RSYNC}" = "x" ];then
        log "Please install rsync"
        return -1
    fi
    mac_setup
    if [ "x${action}" = "x" ];then
        action=usage
    fi
    thismatch=$(echo " ${actions} "|sed -e "s/.* ${action} .*/match/g")
    if [ "x${thismatch}" = "xmatch" ];then
        shift
        case ${action} in
            env|export|ssh) action="${action}_"
                ;;
            -v|--version) action="version"
                ;;
            usage|-h|--help) action="usage"
                ;;
            -l|--long-help) action="usage";LONGHELP=1
                ;;
        esac
        ${action} ${@}
        exit ${?}
    else
        echo "invalid invocation: ${0} ${@}" 1>&2
        usage ${@};exit -1
    fi
    usage ${@}
    exit 0
fi
# vim:set et sts=4 ts=4 tw=0:
