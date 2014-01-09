#!/usr/bin/env bash
actions="init status up reload destroy down export suspend do_zerofree ssh test install_keys cleanup_keys mount_vm umount_vm"
import_export_modes="full nude"
RED="\\033[31m"
CYAN="\\033[36m"
NORMAL="\\033[0m"
RSYNC=$(which rsync)

log(){
    echo -e "${RED} [manage] ${@}${NORMAL}"
}


where="$(dirname "$0")"
cd "${where}" || exit 1
VMPATH=$PWD
internal_ssh_config=${VMPATH}/.vagrant/internal-ssh-config
ssh_config=${VMPATH}/.vagrant/ssh-config
VM=${VMPATH}/VM
NOINPUT=""
BASE_URL="http://downloads.sourceforge.net/project/makinacorpus/vms"
BOX=package.box
ABOX=$BOX.tar.tbz2

die() { echo $@; exit -1; }

actions=" $actions "

actions_main_usage="$actions"

usage() {
    for i in $actions_main_usage;do
        echo "$0 $i"
    done
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
    where="$(dirname "$0")"
    cd "${where}" || exit 1
    VMPATH=$PWD
    name=$(grep ' UBUNTU_RELEASE="' Vagrantfile|sed -e 's/.*="//' -e 's/"//g')
    dname=$(grep ' DEBIAN_RELEASE="' Vagrantfile|sed -e 's/.*="//' -e 's/"//g')
    echo $name
    TESTPATH="${VMPATH}-test"
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
    hostip=$(vagrant ssh -c "ip addr show dev eth1" 2> /dev/null|awk '/inet / {gsub("/.*", "", $2);print $2}'|head -n1)
    cp -f "$internal_ssh_config" "$ssh_config"
    sed -i "s/HostName.*/HostName $hostip/g" "$ssh_config"
    sed -i "s/Port.*//g" "$ssh_config"
}

ssh_() {
    cd "${VMPATH}"
    $(which ssh) -F "$ssh_config" default $@
}

cleanup_keys() {
    ssh_pre_reqs
    ssh_ sudo /vagrant/vagrant/cleanup_keys.sh
}

install_keys() {
    ssh_ sudo /vagrant/vagrant/install_keys.sh
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
    ret=$?
    restart_marker="/tmp/vagrant_provision_needs_restart"
    if [[ "$ret" != "0" ]] || [[ "$marker" == "0" ]];then
        for i in $(seq 3);do
            marker="$(vagrant ssh -c "test -e $restart_marker" &> /dev/null;echo $?)"
            if [[ "$marker" == "0" ]];then
                log "First runs, we issue a scheduled reload after the first up(s)"
                vagrant reload
                ret="$?"
            elif [[ "$ret" != "0" ]];then
                log "Error in vagrant up/reload"
                exit 1
            else
                break
            fi
        done
    fi
}

git_branch() {
    cd $1 &> /dev/null
    br=`git branch | grep "*"`
    echo ${br/* /}
    cd - &> /dev/null
}

init() {
    cd "$VMPATH"
    branch="$(git_branch .)"
    status="$(status)"
    if [[ $(status) == "not created" ]];then
        url="$BASE_URL/$branch/$ABOX"
        import "$url"
    fi
    up
}

mount_vm() {
    if [[ ! -e "$VM/home/vagrant/.ssh" ]];then
        ssh_pre_reqs
        cd "${VMPATH}"
        if [[ ! -e "$VM" ]];then
            mkdir "$VM"
        fi
        sshfs -F $ssh_config root@default:/ -o nonempty "$VM"
    fi
}

get_pid_line() {
    pid="$1"
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

umount_vm() {
    cd "${VMPATH}"
    if [[ ! -e "$VM" ]];then
        mkdir "$VM"
    fi
    if [[ "$(mount|awk '{print $3}'|egrep "$VM$" | wc -l)" != "0" ]];then
        fusermount -u "$VM"
    fi
    if [[ "$(mount|awk '{print $3}'|egrep "$VM$" | wc -l)" != "0" ]];then
        log "forcing umounting of $VM"
        PIDS="$(ps aux|grep "$VM"|grep sshfs|awk '{print $2}')"
        smartkill $PIDS
        PIDS="$(lsof 2> /dev/null|grep -- "$VM"|awk '{print $2}')"
        smartkill $PIDS
        fusermount -u "$VM"
    fi
}

up() {
    cd "${VMPATH}"
    log "Up !"
    vagrant up
    maybe_finish_creation
    mount_vm
}

reload() {
    cd "${VMPATH}"
    log "Reload!"
    umount_vm
    if [[ "$(status)" != "running" ]];then
        vagrant up
    else
        vagrant reload
    fi
    maybe_finish_creation
    mount_vm
}

clean_buf_vm() {
    vagrant box remove devhost
}

export() {
    cd "${VMPATH}"
    local nincludes=""
    local includes=""
    local gtouched=""
    for i in $@;do
        if [[ $i == "nozerofree" ]];then
            nozerofree=y
        fi
        if [[ $i == "nosed" ]];then
            nosed=y
        fi
    done
    nincludes=""
    for i in .vb_* vagrant_config.rb;do
        if [[ -e "$i" ]];then
            nincludes="$i $nincludes"
        fi
    done
    tar_preopts="cjvf"
    tar_postopts="--numeric-owner"
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
    if [[ ! -f $BOX ]];then
        if [[ -z $nosed ]];then \
            up &&\
            vagrant ssh \
               -c 'sudo sed -re "s/^SUBSYSTEM/#SUBSYSTEM/g" -i /etc/udev/rules.d/70-persistent-net.rules';\
        fi &&\
        down;\
        sed -i -e 's/config\.vm\.box\s*=.*/config.vm.box = "devhost"/g' Vagrantfile &&\
        gtouched="1" &&\
        clean_buf_vm
        log "Be patient, exporting now" &&\
        ssh sudo /vagrant/vagrant/exported.sh &&\
        vagrant package --vagrantfile Vagrantfile --output $BOX 2> /dev/null
        ret="$?"
        install_keys
        if [[ "$ret" != "0" ]];then
            log "error exporting $BOX"
            exit 1
        fi
    else
        log "${VMPATH}/$BOX exists, delete it to redo"
    fi
    # XXX: REALLY IMPORTANT TO NOTE IS THAT THE BOC MUST BE THE FIRST TARED FILE !!!
    if [[ -f "$BOX" ]] && [[ ! -f "${ABOX}" ]];then
        log "Be patient, archiving now the whole full box package" &&\
        tar $tar_preopts ${ABOX} $BOX  $includes $tar_postopts &&\
        rm -f "$BOX" &&\
        log "Export done of full box: ${VMPATH}/$ABOX"
    else
        log "${VMPATH}/$ABOX, delete it to redo"
    fi &&\
    ret=$?
    # reseting Vagrantfile in any case
    if [[ -n $gtouched ]];then
        git checkout Vagrantfile 2>/dev/null
    fi
    if [[ $ret != 0 ]];then
        log "Error while exporting"
        exit $ret
    else
        log "End of export"
    fi
}

download() {
    url="$1"
    fname="${2:-${basename url}}"
    # freebsd
    if [[ $(uname) == "FreeBSD" ]];then
        if [[ -f $(which fetch 2>&1) ]];then
            wget="$(which fetch) -pra -o"
        fi
    #another macosx hack
    elif [[ -f $(which wget) ]];then
        wget="$(which wget) --no-check-certificate  -c -O"
    elif [[ -f $(which curl 2>&1) ]];then
        wget="$(which curl) -C - -a -o"
    fi
    $wget "$fname" "$url"
    if [[ "$?" != "0" ]];then
        log "Error downloading $url -> $fname"
        exit 1
    fi
}


import() {
    cd "${VMPATH}"
    local gtouched=""
    mode=""
    image=$1
    shift
    args=${@}
    if [[ "$image" == http* ]];then
        arc="$(basename $image)"
        download "$image" "$arc"
    elif [[ -e "$image" ]];then
        arc="$image"
    elif [[ -e "$ABOX" ]];then
        arc="$ABOX"
    else
        log "invalid image file $1"
        exit -1
    fi
    log "Getting box name from $arc (takes a while)"
    box="$(dd if=package.box.tar.tbz2 bs=1024 count=10000 2>/dev/null|tar -tjf - 2>/dev/null)"
    tar_preopts="-xjvpf"
    tar_postopts="--numeric-owner"
    if [[ ! -e "$arc" ]];then
        log "Missing $arc"
        exit -1
    fi
    if [[ ! -e "$box" ]];then
        log "Unarchiving $arc"
        # need to sudo to restore sticky GID
        sudo tar $tar_preopts "$arc" $tar_postopts
        if [[ $? != 0 ]];then
            log "Error unarchiving $arc"
        fi
    else
        log "Existing $box, if you want to unarchive again, delete it"
    fi
    if [[ ! -e "$box" ]];then
        log "Missing $box"
        exit -1
    fi
    sed -i -e "/VIRTUALBOX_VM_NAME/d" ./vagrant_config.rb &&\
    sed -i -e "/DEVHOST_NUM/d" ./vagrant_config.rb &&\
    clean_buf_vm
    log "Importing $box (mode: $mode) into vagrant bases boxes as 'devhost' box" &&\
    vagrant box add -f devhost "$box" &&\
    log "Initialiasing host from $box" &&\
    sed -i -e 's/config\.vm\.box\s*=.*/config.vm.box = "devhost"/g' \
    Vagrantfile;gtouched="1" && rm -f "$box" && up;down
    ret=$?
    # reseting Vagrantfile in any case
    if [[ -n $gtouched ]];then
        git checkout Vagrantfile 2>/dev/null
    fi
    if [[ $ret != 0 ]];then
        log "Error while importing $box"
        exit $ret
    else
        log "Box $box imported !"
    fi
}

do_zerofree() {
    log "Zerofreing" &&\
    up &&\
    ssh "sudo /sbin/zerofree.sh" &&\
    log " [*] WM Zerofreed"
}

action=$1
if [[ -z "$RSYNC" ]];then
    log "Please install rsync"
    exit -1
fi
test="$(echo "$actions" | sed -e "s/.* $action .*/match/g")"
if [[ "$test" == "match" ]];then
    shift
    $action $@
    exit $?
else
    echo "invalid invocation: $0 $@"
    usage;exit -1
fi
usage
exit 0
# vim:set et sts=4 ts=4 tw=0:
