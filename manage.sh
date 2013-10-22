#!/usr/bin/env bash
actions="up reload destroy down export export_nude import import_nude suspend do_zerofree ssh"
a_eximmodes="full nude"
RED="\\033[31m"
CYAN="\\033[36m"
NORMAL="\\033[0m"
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
die() { echo $@; exit -1; }
actions=" $actions "
actions_main_usage="$actions"
usage() {
    for i in $actions_main_usage;do
        echo "$0 $i"
    done
}
destroy() {
    cd $c
    vagrant halt -f
    vagrant destroy -f
}
suspend() {
    cd $c
    log "Suspend !"
    vagrant suspend
}
ssh() {
    cd $c
    exec vagrant ssh $@
}
down() {
    cd $c
    log "Down !"
    vagrant halt -f
}
up() {
    cd $c
    local noreload=""
    if [[ "$1" == "noreload" ]];then
        noreload=y
    fi
    not_created="$(not_created)"
    log "Up !"
    vagrant up
    if [[ "$not_created" == "1" ]];then
        if [[ -z $noreload ]];then
            log "First run, we issue a reload after the first up"
            vagrant reload
        fi
    fi
}
not_created() {
    cd $c
    vagrant status|grep "not created (virtualbox)" 2>/dev/null|wc -l
}
reload() {
    cd $c
    log "Reload!"
    vagrant reload
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
                up noreload &&\
                vagrant ssh \
                   -c 'sudo sed -ire "s/^SUBSYSTEM/#SUBSYSTEM/g" /etc/udev/rules.d/70-persistent-net.rules';\
            fi &&\
            down;\
            sed -ie 's/config\.vm\.box\s*=.*/config.vm.box = "devhost"/g' Vagrantfile &&\
            log "Be patient, exporting now the full box" &&\
            vagrant package --vagrantfile Vagrantfile --output package-full.box
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
            vagran package --vagrantfile Vagrantfile --output package-nude.box
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
    Vagrantfile;gtouched="1" && up noreload && down
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
    up noreload      &&\
    vagrant ssh -c "sudo /root/vagrant/zerofree.sh" &&\
    log " [*] WM Zerofreed"
}
action=$1
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
