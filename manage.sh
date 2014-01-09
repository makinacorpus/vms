#!/usr/bin/env bash
actions="init status up reload destroy down export suspend do_zerofree ssh test install_keys cleanup_keys mount_vm umount_vm release import"

RED="\\033[31m"
CYAN="\\033[36m"
NORMAL="\\033[0m"

if [[ -n $NO_COLORS ]];then
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
NOINPUT=""
PROJECT_PATH="project/makinacorpus/vms/devhost"
BASE_URL="${DEVHOST_BASE_URL:-"http://downloads.sourceforge.net/${PROJECT_PATH}"}"
SFTP_URL=frs.sourceforge.net:/home/frs/$PROJECT_PATH
PROVISION_WRAPPER="/vagrant/vagrant/provision_script_wrapper.sh"

die() { echo $@ 1>&2; exit -1; }

actions=" $actions "

actions_main_usage="$actions"

usage() {
    for i in $actions_main_usage;do
        echo "$THIS $i" 1>&2
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
    status_|egrep "^default    "|sed -e "s/^default\s*//"|sed -e "s/\s*[(].*//"
}

test() {
    where="$(dirname "$THIS")"
    cd "${where}" || exit 1
    local VMPATH=$PWD
    local name=$(grep ' UBUNTU_RELEASE="' Vagrantfile|sed -e 's/.*="//' -e 's/"//g')
    local dname=$(grep ' DEBIAN_RELEASE="' Vagrantfile|sed -e 's/.*="//' -e 's/"//g')
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
    exit $?
}

destroy() {
    cd "${VMPATH}"
    log "Destroy !"
    vagrant halt -f
    vagrant destroy -f
}

suspend() {
    cd "${VMPATH}"
    log "Suspend !"
    vagrant suspend
}

gen_ssh_config() {
    cd "${VMPATH}"
    if [[ ! -d .vagrant ]];then
        mkdir .vagrant
    fi
    vagrant ssh-config 2>/dev/null > "$internal_ssh_config"
    # replace the ip by the hostonly interface one in our ssh wrappers
    local hostip=$(internal_ssh_ ip addr show dev eth1 2> /dev/null|awk '/inet / {gsub("/.*", "", $2);print $2}'|head -n1)
    cp -f "$internal_ssh_config" "$ssh_config"
    sed -i "s/HostName.*/HostName $hostip/g" "$ssh_config"
    sed -i "s/Port.*//g" "$ssh_config"
}

internal_ssh_() {
    cd "${VMPATH}"
    $(which ssh) -F "$internal_ssh_config" default $@
}

ssh_() {
    cd "${VMPATH}"
    $(which ssh) -F "$ssh_config" default $@
}

cleanup_keys() {
    ssh_pre_reqs
    internal_ssh_ sudo $PROVISION_WRAPPER cleanup_keys
}

install_keys() {
    internal_ssh_ sudo $PROVISION_WRAPPER install_keys
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

down() {
    cd "${VMPATH}"
    log "Down !"
    umount_vm
    vagrant halt -f
}

maybe_finish_creation() {
    local lret=$?
    local restart_marker="/tmp/vagrant_provision_needs_restart"
    if [[ "$lret" != "0" ]] || [[ "$marker" == "0" ]];then
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
    echo "version_${br}.txt"
}
get_version() {
    release_suf="$(if [[ -f "$(get_version_file)" ]];then cat version.txt;else echo "0"; fi)"
}


get_next_version() {
    release_suf="$(if [[ -f "$(get_version_file)" ]];then cat version.txt;else echo "0"; fi)"
    echo "$(($(get_version) +1 ))"
}

get_release_name_() {
    release_suf=$1
    if [[ -n "$release_suf" ]];then
        release_suf="_${release_suf}"
    fi
    echo "$(get_box_name)${release_suf}.tar.bz2"
}

get_release_name() {
    get_release_name_ "$(get_version)"
}

get_next_release_name() {
    get_release_name_ "$(get_next_version)"
}

get_git_branch() {
    cd $1 &> /dev/null
    local br=$(git branch | grep "*")
    echo ${br/* /}
    cd - &> /dev/null
}

release() {
    local rfile="$(get_version_file)"
    local rname="$(get_next_release_name)"
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
        export_ "$rname" nozerofree && \
        scp "$rname.tar.bz2" $SFTP_URL/"$rname.tar.bz2"
    local lret=$?
    if [[ $lret != 0 ]];then
        log "Error while uploading images"
        exit $lret
    else
        echo $rev > "$rfile"
        git add "$rfile"
        git commit -am "RELEASE: $rname" && git push
        log "End of release"
    fi

}

init() {
    cd "$VMPATH"
    local branch="$(get_git_branch .)"
    local status="$(status)"
    local url="$BASE_URL/$(get_release_name)"
    if [[ $(status) == "not created" ]];then
        import "$url"
    fi
    up
}

get_sshfs_pids() {
    ps aux|egrep "sshfs.*$VM"|grep -v grep|awk '{print $2}'
}


is_mounted() {
    local mounted=""
    if [[ "$(mount|awk '{print $3}'|egrep "$VM$" | wc -l)" != "0" ]]\
        || [[ "$(ps aux|egrep "sshfs.*$VM"| wc -l)" != "0" ]];then
        mounted="1"
    fi
    echo $mounted
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
        if [[ ! -e "$VM" ]];then
            mkdir "$VM"
        fi
        log "Mounting $VM -> devhost:/"
        sshfs -F $ssh_config root@default:/ -o nonempty "$VM"
    fi
}

get_pid_line() {
    local pid="$1"
    ps -eo pid,user,comm,args --no-headers|egrep "^\s*${pid}\s"
}

smartkill() {
    for pid in $PIDS;do
        while [[ $(get_pid_line $pid|wc -l) != "0" ]];do
            if [[ -z "$NOINPUT" ]] || [[ "$input" == "y" ]];then
                log "Do you really want to kill:"
                log "$(get_pid_line $pid)"
                log "[press y nthen enter control C to abort]";read input
            fi
            if [[ -n "$NOINPUT" ]] || [[ "$input" == "y" ]];then
                log "killing $pid"
                kill -9 $pid
            fi
        done
    done
}

do_fusermount () {
    local lret=$(fusermount -u "$VM" 2>&1)
    if [[ $lret  == *"not found"* ]];then
        if [[ "$(mount|awk '{print $3}'|grep $VM|wc -l)" != 0 ]];then
            sudo umount -f "$VM" 2>&1
        fi
    fi
    if [[ $lret  == *"Permission denied"* ]];then
        sudo fusermount -u "$VM" 2>&1
    fi
}

umount_vm() {
    cd "${VMPATH}"
    if [[ -n "$(is_mounted)" ]];then
        log "Umounting of $VM"
        do_fusermount
    fi
    if [[ -n "$(is_mounted)" ]];then
        log "forcing umounting of $VM"
        PIDS="$(get_sshfs_pids)"
        smartkill $PIDS
        PIDS="$(get_sshfs_pids)"
        smartkill $PIDS
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
    vagrant up $@
    maybe_finish_creation $@
    mount_vm
}

reload() {
    cd "${VMPATH}"
    log "Reload!"
    umount_vm
    if [[ "$(status)" != "running" ]];then
        up
    else
        down
        vagrant reload $@
    fi
    maybe_finish_creation $@
    mount_vm
}
generate_packaged_vagrantfile() {
    local packaged_vagrantfile="Vagrantfile-$(gen_uuid)"
    touch $packaged_vagrantfile
    echo $packaged_vagrantfile
}

export_() {
    cd "${VMPATH}"
    export NOCONFIRM=1
    local bname="$(get_box_name)-$(gen_uuid)"
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
    for i in $@;do
        if [[ $i == "nozerofree" ]];then
            nozerofree=y
        elif [[ $i == "nosed" ]];then
            nosed=y
        else
            bname="$1"
        fi
    done
    local box="${bname}.box"
    local abox="${bname}.tar.bz2"
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
    if [[ ! -f "$box" ]];then
        vagrant box remove $bname
        down && up &&\
            if [[ -z $nosed ]];then \
                vagrant ssh \
                -c 'if [[ -e /etc/udev/rules.d/70-persistent-net.rules ]];then sudo sed -re "s/^SUBSYSTEM/#SUBSYSTEM/g" -i /etc/udev/rules.d/70-persistent-net.rules;fi';\
            fi &&\
            vagrant ssh -c "sudo $PROVISION_WRAPPER mark_export" &&\
            down
            sed -i -e "s/config\.vm\.box\s*=.*/config.vm.box = \"$bname\"/g" Vagrantfile &&\
            gtouched="1" &&\
            log "Be patient, exporting now" &&\
            vagrant package --vagrantfile "$packaged_vagrantfile" --output "$box" 2> /dev/null
            rm -f "$packaged_vagrantfile"
        local lret="$?"
        down
        vagrant up --no-provision && install_keys && vagrant ssh -c "sudo $PROVISION_WRAPPER unmark_exported" && down
        if [[ "$lret" != "0" ]];then
            log "error exporting $box"
            exit 1
        fi
    else
        log "${VMPATH}/$box exists, delete it to redo"
    fi
    # XXX: REALLY IMPORTANT TO NOTE IS THAT THE BOC MUST BE THE FIRST TARED FILE !!!
    if [[ -f "$box" ]] && [[ ! -f "${abox}" ]];then
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
}

download() {
    local wget=""
    local url="$1"
    local fname="${2:-${basename url}}"
    # freebsd
    if [[ $(uname) == "FreeBSD" ]];then
        if [[ -f $(which fetch 2>&1) ]];then
            wget="$(which fetch) -pra -o"
        fi
    #another macosx hack
    elif [[ -f $(which wget) ]];then
        wget="$(which wget) --no-check-certificate  -c -O"
    elif [[ -f $(which curl 2>&1) ]];then
        wget="$(which curl) --insecure -C - -a -o"
    fi
    $wget "$fname" "$url"
    if [[ "$?" != "0" ]];then
        log "Error downloading $url -> $fname"
        exit 1
    fi
}

get_box_name() {
    local path="${1:-"."}"
    local bname="devhost-$(get_git_branch $path)"
    echo $bname
}

import() {
    cd "${VMPATH}"
    local box=""
    local gtouched=""
    local bname="$(get_box_name)"
    local abox="${bname}.tar.bz2"
    local image="${1:-"$abox"}"
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
            download "$url" "$image"
        fi
        if [[ "$image" == *".tar.bz2" ]] && [[ -e "$image" ]];then
            bname="$(basename "$image" .tar.bz2)"
        else
            log "invalid image file $1 (must be a regular bzip2 tarfile end with .tar.bz2)"
            exit -1
        fi
        log "Getting box name from $image"
        if [[ ! -e "$image" ]];then
            log "Missing file: $image"
            exit -1
        else
            box="$(dd if=$image bs=1024 count=10000 2>/dev/null|tar -tjf - 2>/dev/null)"
        fi
        if [[ $boxes == *" ${bname} "* ]];then
            log "BASE VM already imported, redo base vm import by issuing:"
            log "  vagrant box remove '$bname' && $THIS init"
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
}

do_zerofree() {
    log "Zerofreing" &&\
    up &&\
    ssh "sudo /sbin/zerofree.sh" &&\
    log " [*] WM Zerofreed"
}

action=$1

if [[ -z $MANAGE_AS_FUNCS ]];then
    if [[ -z "$RSYNC" ]];then
        log "Please install rsync"
        exit -1
    fi
    test="$(echo "$actions" | sed -e "s/.* $action .*/match/g")"
    if [[ "$test" == "match" ]];then
        shift
        if [[ $action == 'export' ]];then
            action="export_"
        fi
        $action $@
        exit $?
    else
        echo "invalid invocation: $0 $@" 1>&2
        usage;exit -1
    fi
    usage
    exit 0
fi
# vim:set et sts=4 ts=4 tw=0:
