#!/usr/bin/env bash
LAUNCH_ARGS="$@"
actions=""
actions_main_usage="usage init ssh up reload destroy down suspend status sync_hosts"
actions_exportimport="export import"
actions_advanced="do_zerofree test install_keys cleanup_keys mount_vm umount_vm release internal_ssh gen_ssh_config"
actions_alias="-h --help --long-help -l "
actions="
    $actions_exportimport
    $actions_main_usage
    $actions_advanced
    $actions_alias
"
# reput on one line
actions=$(echo $actions)

YELLOW="\e[1;33m"
RED="\\033[31m"
CYAN="\\033[36m"
NORMAL="\\033[0m"

if [[ -n $NO_COLORS ]];then
    YELLOW=""
    RED=""
    CYAN=""
    NORMAL=""
fi

log(){
    echo -e "${RED} [manage] ${@}${NORMAL}" 1>&2
}

THIS="$0"
where="${VAGRANT_VM_PATH:-$(dirname "$THIS")}"
cd "${where}" || exit 1
RSYNC=$(which rsync)
VMPATH=$PWD
internal_ssh_config=${VMPATH}/.vagrant/internal-ssh-config
ssh_config=${VMPATH}/.vagrant/ssh-config
VM=${VMPATH}/VM
DEFAULT_DNS_BLOCKFILE="$VM/etc/devhosts"
DEFAULT_HOSTS_FILE="/etc/hosts"
NOINPUT=""
PROJECT_PATH="project/makinacorpus/vms/devhost"
BASE_URL="${DEVHOST_BASE_URL:-"https://downloads.sourceforge.net/${PROJECT_PATH}"}"
SFTP_URL=frs.sourceforge.net:/home/frs/$PROJECT_PATH
PROVISION_WRAPPER="/vagrant/vagrant/provision_script_wrapper.sh"
EXPORT_VAGRANTFILE="Vagrantfile-export"
DEFAULT_NO_SYNC_HOSTS=$NO_SYNC_HOSTS

die() { echo $@ 1>&2; exit -1; }

actions=" $actions "

help_content(){
    echo -e "${CYAN}$@${NORMAL}" 1>&2
}

help_header(){
    action=$1
    shift
    echo -e "   ${RED}$THIS $action${NORMAL} $@" 1>&2
}

usage() {

    for i in $@;do
        case $i in
            --long-help) LONGHELP="1"
                ;;
        esac
    done
    for actions in\
        "$actions_main_usage"\
        "$actions_exportimport"\
        "$actions_advanced";do
        case $actions in
            "$actions_main_usage")
                echo -e "${YELLOW}Main options${NORMAL}"
                ;;
            "$actions_exportimport")
                echo -e "${YELLOW}Export/Import options${NORMAL}"
                ;;
            "$actions_advanced")
                if [[ -z $LONGHELP ]];then
                    actions=""
                else
                    echo -e "${YELLOW}Advanced options${NORMAL}"
                fi
                ;;
        esac
        for i in $actions;do
            buf=""
            addhelp=""
            case $i in
                usage)
                    help_header "" "[-h | --help | --long-help]"
                    help_header $i [--long-help]
                    help_content "      print this help, --long-help print advanced options and additional descriptions"
                    ;;
                init)
                    help_header $i "[URL | FILEPATH]"
                    help_content "      Initialise a new VM from either the specified archive produced by"
                    help_content "      the export command or by default to the last stable release (no arguments to init)"
                    ;;
                sync_hosts)
                    help_header $i "[DEVHOST hosts block file] [/etc/hosts path]"
                    help_content "      Synchronise the devhost $DEFAULT_DNS_BLOCKFILE to the host /etc/hosts"
                    help_content "      It is called automatically upon reload & up, but you can also call it manually"
                    ;;
                status)
                    help_header $i
                    help_content "      Thin wrapper to vagrant status"
                    ;;
                up)
                    help_header $i
                    help_content "      Launch a VM"
                    ;;
                reload)
                    help_header $i
                    help_content "      Restarts a VM"
                    ;;
                destroy)
                    help_header $i
                    help_content "      Destroys a VM without confirmation, this is DESTRUCTIVE"
                    ;;
                down)
                    help_header $i
                    help_content "      Stop a VM"
                    ;;
                export)
                    help_header $i [nozerofree]
                    help_content "      Make an entire snapshot of the current VM to an archive which can be imported"
                    help_content "      elsewhere even on the same box."
                    if [[ -n $LONGHELP ]];then
                        help_content "      nozerofree: do not run zerofree (free VM space and trim virtual hard drive"
                        help_content "                  space to minimal extent) prior to export"
                    fi
                    ;;
                suspend)
                    help_header $i
                    help_content "      Suspend the vm"
                    ;;
                do_zerofree)
                    help_header $i
                    help_content "      run zerofree (free VM space and trim virtual hard drive"
                    help_content "      space to minimal extent) prior to export"
                    ;;
                ssh)
                    help_header $i [args]
                    help_content "      ssh client to the VM"
                    help_content "      args are those of the /bin/ssh command and not those of the vagrant one"
                    if [[ -n $LONGHELP ]];then
                        help_content "      This will use the hostonly adapter by default but can also use the internal"
                        help_content "      (NAT) adapter if the hostonly interface is not correctly configured"
                    fi
                    ;;
                test)
                    help_header $i
                    help_content "      Test to create another vm in another folder -> READ THE CODE, developer only"
                    ;;
                install_keys)
                    help_header $i
                    help_content "      Install the ssh keys from $(whoami) in the guest root and vagrant users"
                    ;;
                cleanup_keys)
                    help_header $i
                    help_content "      Purge any ssh key contained in the VM"
                    ;;
                mount_vm)
                    help_header $i
                    help_content "      Mount the vm filesystem on the host using sshfs"
                    ;;
                umount_vm)
                    help_header $i
                    help_content "      Umount the vm filesystem"
                    ;;
                release)
                    help_header $i
                    help_content "      Release the current vm as the next release on the CDN: $BASE_URL"
                    if [[ -n $LONGHELP ]];then
                        help_content "          - Export the vm to $(get_next_release_name)"
                        help_content "          - Increment .versions/$(get_git_branch $VMPATH).txt"
                        help_content "          - Upload to the CDN"
                    fi
                    ;;
                gen_ssh_config)
                    help_header $i
                    help_content "      Regenerate ssh config files"
                    ;;
                import)
                    help_header $i "[URL | FILEPATH]"
                    help_content "      Import a new VM from either the specified archive produced by"
                    help_content "      the export command or the last stable release (no arguments to init)"
                    ;;
                internal_ssh)
                    help_header $i [args]
                    help_content "      ssh client to the VM using the vagrant internal ssh interface"
                    help_content "      args are those of the /bin/ssh command and not those of the vagrant one"
                    if [[ -n $LONGHELP ]];then
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
    num="$1"
    cat > vagrant_config.rb << EOF
module MyConfig
    DEVHOST_NUM="$num"
    VIRTUALBOX_VM_NAME="Docker DevHost $num Ubuntu ${name}64"
end
EOF
}

status_() {
    vagrant status 2> /dev/null
}

status() {
    status_|egrep "^default    "|grep -v grep|sed -e "s/^default\s*//"|sed -e "s/\s*[(].*//"
}

test() {
    NO_SYNC_HOSTS=1
    where="$(dirname "$THIS")"
    cd "${where}" || exit 1
    local VMPATH=$PWD
    local name=$(grep ' UBUNTU_RELEASE="' Vagrantfile|grep -v grep|sed -e 's/.*="//' -e 's/"//g')
    local dname=$(grep ' DEBIAN_RELEASE="' Vagrantfile|grep -v grep|sed -e 's/.*="//' -e 's/"//g')
    local TESTPATH="${VMPATH}-test"
    sudo rsync -av "${VMPATH}/" "${TESTPATH}/" \
        --exclude=salt/ \
        --exclude=mastersalt --exclude=mastersalt-pillar \
        --exclude=pillar \
        --exclude=projects --exclude=docker/ \
        --exclude=.vagrant --exclude=packer --exclude=vagrant_config.rb
    cd "${TESTPATH}" || exit -1
    git checkout docker
    git checkout packer
    if [[ "$name" == "saucy" ]];then
        num="52"
    elif [[ "$name" == "raring" ]];then
        num="53"
    elif [[ "$name" == "precise" ]];then
        num="55"
    elif [[ "$name" == "wheezy" ]];then
        num="56"
    else
        die "invalid test"
    fi
    if [[ ! -e vagrant_config.rb ]];then
        write_test_config $num
    fi
    if [[ -n "$NOCLEAN" ]];then
        log "Warning, no clean!"
    else
        if [[ -n "$NODESTROY" ]];then
            log "Warning, no destroy!"
        else
            ./manage.sh destroy
        fi
        sudo rm -rf salt projects pillar
    fi
    if [[ ! -e vagrant_config.rb ]];then
        write_test_config $num
    fi
    if [[ -n "$NOCLEAN" ]];then
        ./manage.sh down
    fi
    ./manage.sh up
    NO_SYNC_HOSTS=$DEFAULT_NO_SYNC_HOSTS
    exit $?
}

destroy() {
    cd "${VMPATH}"
    log "Destroy !"
    down
    vagrant destroy -f
}

suspend() {
    cd "${VMPATH}"
    log "Suspend !"
    vagrant suspend
}

internal_ssh() {
    cd "${VMPATH}"
    $(which ssh) -F "$internal_ssh_config" "$(get_ssh_host $internal_ssh_config)" $@
}

ssh_() {
    cd "${VMPATH}"
    $(which ssh) -F "$ssh_config" "$(get_ssh_host $ssh_config)" $@
}

get_devhost_num() {
    local devhost_num=""
    if [[ -n "$(is_wrapper_present)" ]];then
        devhost_num="$(internal_ssh sudo $PROVISION_WRAPPER get_devhost_num)"
    fi
    if [[ -n "$devhost_num" ]];then
        echo "$devhost_num"
    fi
}

is_wrapper_present(){
    local present=""
    if [[ "$(internal_ssh test -e "$PROVISION_WRAPPER";echo $?)" == "0" ]];then
        present="1"
    fi
    echo $present
}

gen_ssh_config() {
    cd "${VMPATH}"
    if [[ ! -d .vagrant ]];then
        mkdir .vagrant
    fi
    vagrant ssh-config 2>/dev/null > "$internal_ssh_config"
    # replace the ip by the hostonly interface one in our ssh wrappers
    local hostip=$(internal_ssh ip addr show dev eth1 2> /dev/null|awk '/inet / {gsub("/.*", "", $2);print $2}'|head -n1)
    local devhost_num="$(get_devhost_num)"
    if [[ -n $devhost_num ]];then
        sed -i "s/Host default/Host devhost${devhost_num}/g" "$internal_ssh_config"
    fi
    cp -f "$internal_ssh_config" "$ssh_config"
    if [[ -z $hostip ]];then
        log "Fallback to internal as we could not detect any ip on eth1"
        ssh_config=$internal_ssh_config
    else
        sed -i "s/HostName.*/HostName $hostip/g" "$ssh_config"
        sed -i "s/Port.*//g" "$ssh_config"
    fi
}
cleanup_keys() {
    ssh_pre_reqs
    if [[ -n "$(is_wrapper_present)" ]];then
        internal_ssh sudo $PROVISION_WRAPPER cleanup_keys
    else
        log "Warning: could not cleanup ssh keys, shared folder mountpoint seems not present"
    fi
}

install_keys() {
    if [[ -n "$(is_wrapper_present)" ]];then
        internal_ssh sudo $PROVISION_WRAPPER install_keys
    else
        log "Warning: could not install ssh keys, shared folder mountpoint seems not present"
    fi
}

ssh_pre_reqs() {
    if [[ "$(status)" != "running" ]];then
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
    umount_vm
}

down() {
    cd "${VMPATH}"
    log "Down !"
    pre_down
    vagrant halt -f
}

maybe_finish_creation() {
    local lret=$1
    shift
    local restart_marker="/tmp/vagrant_provision_needs_restart"
    if [[ "$lret" != "0" ]];then
        for i in $(seq 3);do
            local marker="$(vagrant ssh -c "test -e $restart_marker" &> /dev/null;echo $?)"
            if [[ "$marker" == "0" ]];then
                log "First runs, we issue a scheduled reload after the first up(s)"
                reload $@
                lret="$?"
            elif [[ "$lret" != "0" ]];then
                log "Error in vagrant up/reload"
                exit 1
            else
                break
            fi
        done
    fi
}

get_version_file() {
    local br=$(get_git_branch .)
    echo "$VMPATH/.versions/${br}.txt"
}

get_version() {
    local ver="0"
    local vfile="$(get_version_file)"
    if [[ -e "$vfile" ]];then
        ver="$(cat "$vfile")"
    fi
    echo "$ver"
}

get_next_version() {
    echo "$(($(get_version) +1 ))"
}

get_release_name_() {
    release_suf=$1
    if [[ -n "$release_suf" ]];then
        release_suf="_${release_suf}"
    fi
    echo "$(get_box_name "$VMPATH" ${release_suf})"
}

get_release_name() {
    get_release_name_ "$(get_version)"
}

get_next_release_name() {
    get_release_name_ "$(get_next_version)"
}

get_git_branch() {
    cd $1 &> /dev/null
    local br=$(git branch | grep "*"|grep -v grep)
    echo ${br/* /}
    cd - &> /dev/null
}

release() {
    local rfile="$(get_version_file)"
    local rname="$(get_next_release_name)"
    local rarc="$(get_devhost_archive_name $rname)"
    local rver="$(get_next_version)"
    local nocommit=""
    for i in $@;do
        case $i in
            --no-commit) nocommit=1
                ;;
        esac
    done
    cd "$VMPATH"
    log "Releasing $rname" &&\
        if [[ ! -f "$rarc" ]];then
            export_ "$rname" nozerofree
        fi && \
        log "Running scp \"$rarc\" $SFTP_URL/\"$rarc\"" &&\
        scp "$rarc" $SFTP_URL/"$rarc"
    local lret=$?
    if [[ $lret != 0 ]];then
        log "Error while uploading images"
        exit $lret
    else
        echo "$rver" > "$rfile"
        git add "$rfile"
        git commit -am "RELEASE: $rname" && git push
        log "End of release"
    fi

}

init() {
    cd "$VMPATH"
    local url="${1:-"$BASE_URL/$(get_devhost_archive_name $(get_release_name))"}"
    local status="$(status)"
    if [[ $(status) == "not created" ]];then
        import "$url"
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
    local lsof_pids=""
    if [[ -e "$LSOF" ]];then
        lsof_pids="$($LSOF "$VM" 2> /dev/null|awk '{print $2}')"
    fi
    echo $lsof_pids
}

is_mounted() {
    local mounted=""
    if [[ "$(mount|awk '{print $3}'|egrep "$VM$" |grep -v grep| wc -l)" != "0" ]]\
        || [[ "$(get_sshfs_ps| wc -l)" != "0" ]];then
        mounted="1"
    fi
    echo $mounted
}

get_ssh_host() {
    grep "Host\ " $1 |awk '{print $2}'
}

mount_vm() {
    cd "${VMPATH}"
    # something is wrong with the mountpath, killing it
    test_not_connected="$(LANG=C ls VM 2>&1)"
    if [[ ! -e "$VM/home/vagrant/.ssh" ]]\
        || [[ "$test_not_connected"  == *"is not connected"* ]];then
        umount_vm
    fi
    if [[ ! -e "$VM/home/vagrant/.ssh" ]];then
        if [[ ! -e "$VM" ]];then
            mkdir "$VM"
        fi
        ssh_pre_reqs
        sshhost=$(get_ssh_host $ssh_config)
        log "Mounting $VM -> devhost($sshhost):/"
        sshfs -F "$ssh_config" root@${sshhost}:/ -o nonempty "$VM"
    fi
}

get_pid_line() {
    local pid="$1"
    ps -eo pid,user,comm,args --no-headers|egrep "^\s*${pid}\s"|grep -v grep
}

smartkill_() {
    PIDS=$@
    for pid in $PIDS;do
        while [[ $(get_pid_line $pid|wc -l) != "0" ]];do
            if [[ -z "$NOINPUT" ]] || [[ "$input" == "y" ]];then
                log "Do you really want to kill:"
                log "$(get_pid_line $pid)"
                log "[press y+ENTER, or CONTROL+C to abort]";read input
            fi
            if [[ -n "$NOINPUT" ]] || [[ "$input" == "y" ]];then
                log "killing $pid"
                kill -9 $pid
            fi
        done
    done
}

smartkill() {
    PIDS=""
    PIDS="$PIDS $(get_lsof_pids)"
    PIDS="$PIDS $(get_sshfs_pids)"
    smartkill_ $PIDS
}


do_umount() {
    local args="-f"
    if [[ $(uname) == "Linux" ]];then
        args="$arg -l"
    fi
    for arg in $args;do
        if [[ -n "$(is_mounted)" ]] && [[ -z $noumount ]];then
            sudo umount $arg "$VM" 2>&1
        fi
    done
}

do_fusermount () {
    local lret=$(fusermount -u "$VM" 2>&1)
    # let a little time to fusermount to do his art
    sleep 2
    local noumount=""
    for i in $@;do
        case $i in
            noumount) noumount=1
                ;;
        esac
    done
    if [[ $lret == *"not found"* ]] && [[ -n "$(is_mounted)" ]];then
        if [[ -z $noumount ]];then
            do_umount
        fi
    fi
    if [[ -n "$(is_mounted)" ]] || [[ $lret  == *"Permission denied"* ]];then
        # let a little time to fusermount to do his art
        sleep 2
        sudo fusermount -u "$VM" 2>&1
    fi
    if [[ -z $noumount ]];then
        do_umount
    fi
}

umount_vm() {
    cd "${VMPATH}"
    if [[ -n "$(is_mounted)" ]];then
        log "Umounting of $VM"
        do_fusermount noumount
    fi
    if [[ -n "$(is_mounted)" ]];then
        log "Forcing umounting of $VM"
        smartkill
        do_fusermount
    fi
    if [[ "$?" != 0 ]];then
        log "Can't umount vm"
        exit $?
    fi
}

up() {
    cd "${VMPATH}"
    log "Up !"
    local notrunning=""
    if [[ "$(status)" != "running" ]];then
        notrunning="1"
    fi
    vagrant up $@
    lret=$?
    # be sure of jumbo frames
    if [[ -n $notrunning ]];then
        internal_ssh "sudo ifconfig eth1 mtu 9000"
    fi
    post_up $lret $@
}

post_up() {
    local lret=$1
    shift
    maybe_finish_creation $lret $@
    mount_vm
    sync_hosts
}

reload() {
    cd "${VMPATH}"
    log "Reload!"
    umount_vm
    if [[ "$(status)" != "running" ]];then
        up
    else
        pre_down
        vagrant reload $@
        lret=$?
        post_up $lret $@
    fi
}

generate_packaged_vagrantfile() {
    local packaged_vagrantfile="$EXPORT_VAGRANTFILE-$(gen_uuid)"
    touch $packaged_vagrantfile
    echo $packaged_vagrantfile
}

get_box_name() {
    local path="${1:-"."}"
    local suf="${2:-"-$(gen_uuid)"}"
    if [[ $suf == "nosuf" ]];then
        suf=""
    fi
    local bname="devhost-$(get_git_branch $path)${suf}"
    echo $bname
}

get_vagrant_box_name() {
    echo "${1:-"$(get_box_name $2)"}.box"
}

get_devhost_archive_name() {
    echo "${1:-"$(get_box_name $2)"}.tar.bz2"
}

export_() {
    NO_SYNC_HOSTS=1
    for i in $@;do
        if [[ $i == "nozerofree" ]];then
            local nozerofree=y
        elif [[ $i == "nosed" ]];then
            local nosed=y
        else
            local bname="$i"
        fi
    done
    cd "${VMPATH}"
    export NOCONFIRM=1
    local bname="${bname:-"$(get_box_name)"}"
    local box="$(get_vagrant_box_name $bname)"
    local abox="$(get_devhost_archive_name $bname)"
    local nincludes=""
    local includes=""
    local gtouched=""
    local tar_preopts="cjvf"
    local tar_postopts="--numeric-owner"
    #
    # be sure to package a blank vagrantfile along with the box to not conflict with our Vagrantfile
    # at import time
    #
    local packaged_vagrantfile="$(generate_packaged_vagrantfile)"
    nincludes=""
    for i in .vb_* vagrant_config.rb;do
        if [[ -e "$i" ]];then
            nincludes="$i $nincludes"
        fi
    done
    if [[ $(uname) == "Darwin" ]];then
        tar_postopts=""
    fi
    if [[ $(uname) != "Darwin" ]];then
        tar_preopts="${tar_preopts}p"
    fi
    if [[ -z "$nozerofree" ]];then
        log "Zerofree starting in 20 seconds, you can control C before the next log"
        log "and relaunch with the same cmdline with nozerofree appended: eg ./manage.sh export nozerofree"
        sleep 15
        log "Zerofree starting ! DO NOT INTERRUPT ANYMORE"
        sleep 5
        do_zerofree
    else
        log "Skip zerofree on export"
    fi &&\
    if [[ ! -e "$box" ]];then
        vagrant box remove $bname
        down && up &&\
            if [[ -z $(is_wrapper_present) ]];then \
                log "$PROVISION_WRAPPER is not there in the VM"
                exit -1
            fi &&\
            if [[ -z $nosed ]];then \
                internal_ssh \
                'if [[ -e /etc/udev/rules.d/70-persistent-net.rules ]];then sudo sed -re "s/^SUBSYSTEM/#SUBSYSTEM/g" -i /etc/udev/rules.d/70-persistent-net.rules;fi';\
            fi &&\
            internal_ssh "sudo $PROVISION_WRAPPER mark_export"
            down
            sed -i -e "s/config\.vm\.box\s*=.*/config.vm.box = \"$bname\"/g" Vagrantfile &&\
            gtouched="1" &&\
            log "Be patient, exporting now" &&\
            vagrant package --vagrantfile "$packaged_vagrantfile" --output "$box" 2> /dev/null
            rm -f "$EXPORT_VAGRANTFILE"*
        local lret="$?"
        down
        up --no-provision && internal_ssh "sudo $PROVISION_WRAPPER unmark_exported" && down
        if [[ "$lret" != "0" ]];then
            log "error exporting $box"
            exit 1
        fi
    else
        log "${VMPATH}/$box exists, delete it to redo"
    fi
    # XXX: REALLY IMPORTANT TO NOTE IS THAT THE BOC MUST BE THE FIRST TARED FILE !!!
    if [[ -e "$box" ]] && [[ ! -e "${abox}" ]];then
        log "Be patient, archiving now the whole full box package" &&\
        tar $tar_preopts ${abox} $box $includes $tar_postopts &&\
        rm -f "$box" &&\
        log "Export done of full box: ${VMPATH}/$abox"
    else
        log "${VMPATH}/$abox, delete it to redo"
    fi &&\
    local lret=$?
    # reseting Vagrantfile in any case
    if [[ -n $gtouched ]];then
        git checkout Vagrantfile 2>/dev/null
    fi
    if [[ $lret != 0 ]];then
        log "Error while exporting"
        exit $lret
    else
        log "End of export"
    fi
    NO_SYNC_HOSTS=$DEFAULT_NO_SYNC_HOSTS
}

download() {
    local wget=""
    local url="$1"
    local fname="${2:-${basename $url}}"
    local G_UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.22 (KHTML, like Gecko) Ubuntu Chromium/25.0.1364.160 Chrome/25.0.1364.160 Safari/537.22"
    # freebsd
    if [[ $(uname) == "FreeBSD" ]] && [[ -e $(which fetch 2>&1) ]];then
        $(which fetch) -pra -o $fname $url
    # wget
    elif [[ -e $(which wget) ]];then
        $(which wget) --no-check-certificate -U "${G_UA}" -c -O $fname $url
    # curl
    elif [[ -e $(which curl 2>&1) ]];then
        $(which curl) -A "${G_UA}" --insecure -C - -a -o $fname $url
    fi
    if [[ "$?" != "0" ]];then
        log "Error downloading $url -> $fname"
        exit 1
    fi
}

import() {
    NO_SYNC_HOSTS=1
    cd "${VMPATH}"
    local gtouched=""
    local image="${1:-$(get_devhost_archive_name $(get_release_name))}"
    local tar_preopts="-xjvpf"
    local tar_postopts="--numeric-owner"
    local boxes=" $(vagrant box list 2> /dev/null|awk '{print " " $1 " "}') "
    shift
    local args=${@}
    if [[ "$(status)" != "not created" ]];then
        log "VM already imported,"
        log "   - Run it with: $THIS up"
        log "   - Delete it with: $THIS destroy"
    else
        if [[ "$image" == http* ]];then
            local url="$image"
            image="$(basename $image)"
            if [[ ! -f "$image" ]];then
                download "$url" "$image"
            else
                log "$image already exists, "
                log "   delete this archive, if you want to redownload"
                log "   from $url"
            fi
        fi
        if [[ "$image" == *".tar.bz2" ]] && [[ -e "$image" ]];then
            bname="$(basename "$image" .tar.bz2)"
        else
            log "invalid image file $1 (must be a regular bzip2 tarfile end with .tar.bz2)"
            exit -1
        fi
        local bname="${bname:-$(get_box_name)}"
        local abox="$image"
        log "Getting box name from $image"
        if [[ ! -e "$image" ]];then
            log "Missing file: $image"
            exit -1
        else
            box="$(dd if=$image bs=1024 count=10000 2>/dev/null|tar -tjf - 2>/dev/null)"
        fi
        if [[ $boxes == *" ${bname} "* ]];then
            log "BASE VM already imported, redo base vm import by issuing:"
            log "  vagrant box remove '$bname' && $THIS $LAUNCH_ARGS"
        else
            if [[ ! -e "$box" ]];then
                log "Unarchiving $image"
                # need to sudo to restore sticky GID
                sudo tar $tar_preopts "$image" $tar_postopts
                if [[ $? != 0 ]];then
                    log "Error unarchiving $image"
                fi
                if [[ ! -e "$box" ]];then
                    log "Missing $box"
                    exit -1
                fi
            else
                log "Existing $box, if you want to unarchive again, delete it"
            fi
            log "Importing $box into vagrant bases boxes as '$bname' box"
            vagrant box add -f "$bname" "$box" && rm -f "$box"
            if [[ "$?" != "0" ]];then
                log "Error while importing $box"
                exit $?
            fi
        fi
        log "Initialiasing host from $box" &&\
            sed -i -e "s/config\.vm\.box\s*=.*/config.vm.box = \"$bname\"/g" Vagrantfile &&\
            sed -i -e "/VIRTUALBOX_VM_NAME/d" ./vagrant_config.rb &&\
            sed -i -e "/DEVHOST_NUM/d" ./vagrant_config.rb
        gtouched="1"
        # load initial box image & do initial provisionning
        up && lret="0"
        down
        # reseting Vagrantfile in any case
        if [[ -n $gtouched ]];then
            git checkout Vagrantfile 2>/dev/null
        fi
        if [[ "$lret" != "0" ]];then
            log "Error while importing $box"
            exit $lret
        else
            log "Box $box imported !"
        fi
    fi
    NO_SYNC_HOSTS=$DEFAULT_NO_SYNC_HOSTS
}

sync_hosts() {
    if [[ -n $NO_SYNC_HOSTS ]];then return;fi
    local block="${1:-$DEFAULT_DNS_BLOCKFILE}"
    local hosts="${2:-$DEFAULT_HOSTS_FILE}"
    local lhosts=.vagrant/hosts
    if [[ "$(status)" != "running" ]];then
        up
    fi
    cd "$VMPATH"
    if [[ ! -d .vagrant ]];then mkdir .vagrant;fi
    if [[ ! -e "$block" ]];then die "invalid block file: $block";fi
    if [[ ! -e "$hosts" ]];then die "invalid hosts file: $hosts";fi
    local START=$(cat "$block"|head -n1)
    local END=$(cat "$block"|tail -n1)
    local start_lines=$(grep -- "$START" "$hosts"|wc -l)
    local end_lines=$(grep -- "$END" "$hosts"|wc -l)
    local block_start_lines=$(grep -- "$START" "$block"|wc -l)
    local block_end_lines=$(grep -- "$END" "$block"|wc -l)
    if [[ -z "$START" ]];then
        die "missing start tag"
    fi
    if [[ -z "$END" ]];then
        die "missing end tag"
    fi
    if [[ "$START" != "#-- start devhost"* ]];then
        die "invalid start tag(c): $START"
    fi
    if [[ "$END" != "#-- end devhost"* ]];then
        die "invalid end tag(c): $END"
    fi
    if [[ "$START" == "$END" ]];then
        die "invalid start tag is same as end: $END"
    fi
    if [[ "$start_lines" != "0" ]] || [[ "$end_lines" != "0" ]];then
        if [[ "$start_lines" != "1" ]];then
            die "Weird start/end markers is absent or multiple, balling out (s:$start_lines/$end_lines)"
        fi
        if [[ "$end_lines" != "1" ]];then
            die "Weird start/end markers is absent or multiple, balling out (e:$end_lines/$end_lines)"
        fi
    fi
    if [[ "$block_start_lines" != "0" ]] || [[ "$block_end_lines" != "0" ]];then
        if [[ "$block_start_lines" != "1" ]];then
            die "Weird block_tart/block_end markers is absent or multiple, balling out (s:$block_start_lines/$block_end_lines)"
        fi
        if [[ "$block_end_lines" != "1" ]];then
            die "Weird block_start/block_end markers is absent or multiple, balling out (e:$block_end_lines/$block_end_lines)"
        fi
    fi
    log "Adding $block hosts to $hosts"
    cp "$hosts" "$lhosts"
    if [[ $(grep -- "$START" "$hosts"|wc -l) == "0" ]];then
        # Add block in /etc/hosts
        echo >> "$lhosts"
        cat "$block" >> "$lhosts"
    else
        # replace block in /etc/hosts
        sed  -ne "1,/$START\$/ p" "$hosts"|egrep -v "^$START" > "$lhosts"
        cat "$block"                      >> "$lhosts"
        sed  -ne "/$END\$/,\$ p" "$hosts" |egrep -v "^$END" >> "$lhosts"
    fi
    diff=$(which diff)
    diff -q "$hosts" "$lhosts" &> /dev/null
    if [[ $? != 0 ]];then
        if [[ -z $NOINPUT ]];then
            diff -u "$hosts" "$lhosts"
            log "Replace $hosts by $lhosts?"
            log "[press y+ENTER, or CONTROL+C to abort]";read input
        fi
        if [[ -n "$NOINPUT" ]] || [[ "$input" == "y" ]];then
            log "Replacing $hosts"
            sudo cp -f "$lhosts" "$hosts"
        else
            log "Leaving $hosts as-is"
        fi
    else
        log "$block is already up-to-date"
    fi
    rm -f hosts
}

do_zerofree() {
    log "Zerofreing" &&\
    up &&\
    ssh "sudo /sbin/zerofree.sh" &&\
    log " [*] WM Zerofreed"
}

action="$1"

if [[ -z $MANAGE_AS_FUNCS ]];then
    if [[ -z "$RSYNC" ]];then
        log "Please install rsync"
        exit -1
    fi
    if [[ -z $action ]];then
        action=usage
    fi
    thismatch=$(echo " $actions "|sed -e "s/.* $action .*/match/g")
    if [[ "$thismatch" == "match" ]];then
        shift
        case $action in
            export) action="export_"
                ;;
            usage|-h|--help) action="usage"
                ;;
            -l|--long-help) action="usage";LONGHELP=1
                ;;
        esac
        $action $@
        exit $?
    else
        echo "invalid invocation: $0 $@" 1>&2
        usage $@;exit -1
    fi
    usage $@
    exit 0
fi
# vim:set et sts=4 ts=4 tw=0:
