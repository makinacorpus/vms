#!/usr/bin/env bash
actions="status up reload destroy down export export_nude import import_nude suspend do_zerofree ssh test install_keys cleanup_keys mount_vm umount_vm"
a_eximmodes="full nude"
RED="\\033[31m"
CYAN="\\033[36m"
NORMAL="\\033[0m"
RSYNC=$(which rsync)

log(){
    echo -e "${RED} [manage] ${@}${NORMAL}"
}

u=""
if [[ "$(whoami)" != "root" ]];then
    u=$(whoami)
fi
g=editor
c=$(dirname $0)
cd $c
c=$PWD
internal_ssh_config=$c/.vagrant/internal-ssh-config
ssh_config=$c/.vagrant/ssh-config
VM=$c/VM

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
    status_|egrep "^default"|awk '{print $2}'
}

test() {
    cd $(dirname $0)
    c=$PWD
    name=$(grep ' UBUNTU_RELEASE="' Vagrantfile|sed -e 's/.*="//' -e 's/"//g')
    dname=$(grep ' DEBIAN_RELEASE="' Vagrantfile|sed -e 's/.*="//' -e 's/"//g')
    echo $name
    d="$c-test"
    sudo rsync -av $c/ $d/ \
        --exclude=salt/ \
        --exclude=mastersalt --exclude=mastersalt-pillar \
        --exclude=pillar \
        --exclude=projects --exclude=docker/ \
        --exclude=.vagrant --exclude=packer --exclude=vagrant_config.rb
    cd ${d} || exit -1
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
    cd $c
    log "Destroy !"
    vagrant halt -f
    vagrant destroy -f
}

suspend() {
    cd $c
    log "Suspend !"
    vagrant suspend
}

gen_ssh_config() {
    cd $c
    if [[ ! -d .vagrant ]];then
        mkdir .vagrant
    fi
    vagrant ssh-config 2>/dev/null > "$internal_ssh_config"
    # replace the ip by the hostonly interface one in our ssh wrappers
    hostip=$(vagrant ssh -c "ip addr show dev eth1" 2> /dev/null|awk '/inet / {gsub("/.*", "", $2);print $2}')
    cp -f "$internal_ssh_config" "$ssh_config"
    sed -i "s/HostName.*/HostName $hostip/g" "$ssh_config"
    sed -i "s/Port.*//g" "$ssh_config"
}

ssh_() {
    cd $c
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
    cd $c
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

mount_vm() {
    if [[ ! -e "$VM/home/vagrant/.ssh" ]];then
        ssh_pre_reqs
        cd $c
        if [[ ! -e "$VM" ]];then
            mkdir "$VM"
        fi
        sshfs -F $ssh_config root@default:/ -o nonempty "$VM"
    fi
}

umount_vm() {
    cd $c
    if [[ ! -e "$VM" ]];then
        mkdir "$VM"
    fi
    if [[ "$(mount|awk '{print $3}'|egrep "$VM$" | wc -l)" != "0" ]];then
        fusermount -u "$VM"
    fi
    if [[ "$(mount|awk '{print $3}'|egrep "$VM$" | wc -l)" != "0" ]];then
        log "forcing umounting of $VM"
        ps aux|grep "$VM"|grep sshfs|awk '{print $2}'|xargs kill -9
        lsof 2> /dev/null|grep -- "$VM"|awk '{print $2}'|xargs kill -9
        fusermount -u "$VM"
    fi
}

up() {
    cd $c
    log "Up !"
    vagrant up
    maybe_finish_creation
    mount_vm
}

reload() {
    cd $c
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

export() {
    cd $c
    local nincludes=""
    local includes=""
    local gtouched=""
    mode="full"
    for i in $@;do
        if [[ $i == "nude" ]];then
            mode="nude"
        fi
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
    # we use to have salt on a shared folder
    # this is not the case anymore, so the folling loop is just a NOOP
    includes="$nincludes"
    for i in pillar projects salt;do
        if [[ -e $i ]];then
            includes="$i $includes"
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
    if [[ "$mode" == "full" ]];then \
        if [[ ! -f package-full.box ]];then
            if [[ -z $nosed ]];then \
                up &&\
                vagrant ssh \
                   -c 'sudo sed -ire "s/^SUBSYSTEM/#SUBSYSTEM/g" /etc/udev/rules.d/70-persistent-net.rules';\
            fi &&\
            down;\
            sed -ie 's/config\.vm\.box\s*=.*/config.vm.box = "devhost"/g' Vagrantfile &&\
            log "Be patient, exporting now the full box" &&\
            cleanup_keys &&\
            vagrant package --vagrantfile Vagrantfile --output package-full.box &&\
            install_keys
        else
            log "$c/package-full.box exists, delete it to redo"
        fi\
    fi &&\
    gtouched="1" &&\
    if [[ "$mode" == "full" ]];then \
        if [[ ! -f package-full.tar.bz2 ]];then
            log "Be patient, archiving now the whole full box package" &&\
            tar $tar_preopts package-full.tar.bz2 package-full.box $includes $tar_postopts &&\
            log "Export done of full box: $c/package-full.tar.bz2"
        else
            log "$c/package-full.tar.bz2 exists, delete it to redo"
        fi \
    fi &&\
    if [[ "$mode" == "nude" ]];then \
        if [[ ! -f package-nude.box ]];then
            log "Be patient, exporting now the nude box" &&\
            sed -ie 's/config\.vm\.box\s*=.*/config.vm.box = "devhost"/g' Vagrantfile &&\
            cleanup_keys &&\
            vagran package --vagrantfile Vagrantfile --output package-nude.box &&\
            install_keys
        else
            log "$c/package-nude.box exists, delete it to redo"
        fi &&\
        if [[ ! -f package-nude.tar.bz2 ]];then
            log "Be patient, archiving now the whole nude box package" &&\
            tar $tar_preopts package-nude.tar.bz2 package-nude.box $nincludes $tar_postopts  &&\
            log "Export done of nude box: $c/package-nude.tar.bz2"
        else
            log "$c/package-nude.tar.bz2 exists, delete it to redo"
        fi
    fi
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

export_nude() {
    export nude
}

import_nude() {
    import nude
}

import() {
    cd $c
    local gtouched=""
    mode=""
    args=${@}
    for amode in $a_eximmodes;do
        for arg in $args;do
            if [[ "$amode" == "$arg" ]] && [[ -z $mode ]];then
                mode=$arg
            fi
        done
    done
    if [[ -z $mode ]];then
        for i in $a_eximmodes;do
            if [[ -e package-$i.tar.bz2 ]];then
                mode=$i
                log "No specified mode, defaulting to $mode"
                break
            fi
        done
    fi
    if [[ -z $mode ]];then
        log "No import archive found"
        exit -1
    fi
    box="$c/package-$mode.box"
    arc="$c/package-$mode.tar.bz2"
    tar_preopts="-xjvpf"
    tar_postopts="--numeric-owner"
    #if [[ $(uname) == "Darwin" ]];then
    #    tar_postopts=""
    #fi
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
        if [[ ! -e "$box" ]];then
            log "Missing $box"
            exit -1
        fi
    else
        log "Existing $box, if you want to unarchive again, delete it"
    fi
    if [[ -f "./vagrant_config.rb" ]];then
        EXPORTED_VM="$(ruby  -e 'require File.expand_path("./vagrant_config.rb");include MyConfig;printf("%s", VIRTUALBOX_VM_NAME)' 2>/dev/null)"
    fi
    if [[ $(VBoxManage list vms|grep "\"$EXPORTED_VM\""|wc -l) != "0" ]];then
        log "This virtualbox already exists, please rename or delete it"
        VBoxManage list vms|grep "\"$EXPORTED_VM\""
        uid=$(VBoxManage list vms|grep "\"$EXPORTED_VM\""|awk -F'{' '{print $2}'|sed -e 's/}//g')
        log "You can try VBoxManage modifyvm $uid --name \"sav_$EXPORTED_VM\""
    fi
    log "Importing $box (mode: $mode) into vagrant bases boxes as 'devhost' box" &&\
    vagrant box add -f devhost "$box" &&\
    log "Initialiasing host from $box" &&\
    sed -ie 's/config\.vm\.box\s*=.*/config.vm.box = "devhost"/g' \
    Vagrantfile;gtouched="1" && up && down
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
    vagrant ssh -c "sudo /root/vagrant/zerofree.sh" &&\
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
