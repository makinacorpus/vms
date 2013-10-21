#!/usr/bin/env bash
actions="up reload destroy down export import suspend"
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
    vagrant destroy -y
}
suspend() {
    cd $c
    log "Suspend !"
    vagrant suspend
}
down() {
    cd $c
    log "Down !"
    vagrant halt -f
}
up() {
    cd $c
    if [[ "$(not_created)" == "1" ]] || [[ "$1" != "noreload" ]];then
        log "First run, we issue an up & reload first"
        vagrant up
        vagrant reload && no_up=1
    else
        log "Up !"
        vagrant up
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
    log "Exporting to $c/package.tar.bz2"
    up &&\
        vagrant ssh &&\
        sed -ire "s/^SUBSYSTEM/#SUBSYSTEM/g" \
            /etc/udev/rules.d/70-persistent-net.rules &&\
        down &&\
        sed -ire 's/config\.vm\.box\s*=.*/config.vm.box = "devhost"/g' Vagrantfile &&\
        vagrant package --include .vb_* pillar projects salt --vagrantfile Vagrantfile
        #log "package produced in $c/package.box"
        #log "Compressing box and marker files in $c/package.tar.bz2" &&\
        #tar cjvf package.tar.bz2 package.box  &&\
        #rm -vf package.box &&\
        #log "package produced in $c/package.tar.bz2"
    ret=$?
    # reseting Vagrantfile in any case
    git checkout Vagrantfile 2>/dev/null
    if [[ $ret != 0 ]];then
        log "Error while exporting"
        exit $ret
    fi
}
import() {
    cd $c
    log "Importing $c/package.tar.bz2"
    #if [[ ! -e package.tar.bz2 ]];then
    #    log "Missing $c/package.tar.bz2"
    #    exit -1
    #fi
    #if [[ ! -e package.box ]];then
    #    log "Unarchiving package.tar.bz2"
    #    tar xjvf "$c/package.tar.bz2"
    #    if [[ $? != 0 ]];then
    #        log "Error unarchiving package.tar.bz2"
    #    fi
    #    if [[ ! -e package.box ]];then
    #        log "Missing $c/package.box"
    #        exit -1
    #    fi
    #else
    #    log "Existing $c/package.box, if you want to re dearchive, delete it"
    #fi

    log "Importing box" && vagrant box add -f devhost package.box &&\
    log "Initialiasing host from package.box" &&\
    sed -ire 's/config\.vm\.box\s*=.*/config.vm.box = "devhost"/g' \
    Vagrantfile && up noreload && down && git checkout Vagrantfile &&\
    log "Box imported !"
    ret=$?
    # reseting Vagrantfile in any case
    git checkout Vagrantfile 2>/dev/null
    if [[ $ret != 0 ]];then
        log "Error while importing"
        exit $ret
    fi
}
action=$1
test="$(echo "$actions" | sed -re "s/.* $action .*/match/g")"
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
