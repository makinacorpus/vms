#!/usr/bin/env bash
#
# not really safe to use on a real system, you may better run that on a vm
# was tested with the vagrantfile of this repository
#
actions="rm_all build_docker fix_perms restart_dockers init_src build_lxc"
u=""
if [[ "$(whoami)" != "root" ]];then
    u=$(whoami)
fi
g=editor
lxc_bins="lxc-stop lxc-start lxc-attach lxc-kill lxc-restart lxc-execute"
c=$(dirname $0)
cd $c
c=$PWD
RED="\\033[31m"
CYAN="\\033[36m"
NORMAL="\\033[0m"
YELLOW='\e[1;33m'
lazy_apt_get_install() {
    to_install=""
    for i in $@;do
         if [[ $(dpkg-query -s $i 2>/dev/null|egrep "^Status:"|grep installed|wc -l)  == "0" ]];then
             to_install="$to_install $i"
         fi
    done
    if [[ -n "$to_install" ]];then
        log " [*] Installing $to_install"
        sudo apt-get install -y --force-yes $to_install
    fi
}
log(){ echo -e "${RED} [docker make] ${@}${NORMAL}"; }
warn(){ echo -e "${YELLOW} [docker make] ${@}${NORMAL}"; }
die() { echo -e "${CYAN}$@${NOMAL}"; exit -1; }
build_lxc() {
    log "Bootstrapping sources"
    init_src
    save_bins
    cd $c/lxc || die "docker src not there"
    lazy_apt_get_install autopoint
    sudo apt-get build-dep -y --force-yes lxc
    ./autogen.sh -ifv && ./configure --with-distro=ubuntu --prefix=/lxc/ && make && sudo make install &&\
        for i in $lxc_bins;do sudo ln -svf /lxc/bin/$i /usr/bin/$i;done
    post_build $@
}
save_bins() {
    for binary in $lxc_bins docker ;do
        mybin="$(which $binary)"
        if [ ! -f "${mybin}.ubuntu" ] && [ -f "${mybin}" ];then
            warn "Saving $binary in ${mybin}.ubuntu"
            sudo cp "${mybin}" "${mybin}.ubuntu"
        fi
    done
}
post_build() {
    for i in $@;do
        if [[ $i == "fix_perms" ]];then
            fix_perms
        fi
    done
}
build_docker() {
    nopull="nopull"
    for i in $@;do
        if [[ $i == "pull" ]];then
            nopull="pull"
        fi
    done
    log "Bootstrapping sources"
    init_src $nopull
    cd $c/docker || die "docker src not there"
    save_bins
    sudo service docker stop
    sudo rm -rf /var/run/docker.sock
    sudo rm -f  /usr/bin/docker
    sudo ln -sf /usr/bin/docker.ubuntu /usr/bin/docker
    sudo service docker start
    sleep 2
    cd $c/docker || die "docker src not there"
    if [[ $(docker images|awk '{print $2}'|egrep '^docker$'|wc -l) == "0" ]];then
        docker build -t docker .
        if [[ $? != 0 ]];then
            die "Docker build-init failed"
        fi
    fi
    sudo /usr/bin/docker run -lxc-conf=lxc.aa_profile=unconfined -privileged -v `pwd`:/go/src/github.com/dotcloud/docker docker hack/make.sh binary
    bin="$(ls -r1t $PWD/bundles/*/binary/docker-*|tail -n1)"
    sudo service docker stop
    sudo rm -rf /var/run/docker.sock
    sudo ln -fs  $bin /usr/bin/docker
    sudo service docker start
    post_build $@
}
init_src() {
    log "Getting sources"
    if [ ! -d lxc ];then
        warn "Getting lxc"
        git clone https://github.com/lxc/lxc.git
    fi
    if [ ! -d docker ];then
        warn "Getting docker"
        git clone https://github.com/dotcloud/docker.git
    fi
    nopull="nopull"
    for i in $@;do
        if [[ $i == "pull" ]];then
            nopull="pull"
        fi
    done
    if [[ $nopull != "nopull" ]];then
        warn "Upgrading lxc"
        cd $c/lxc && git pull
        warn "Upgrading sources"
        cd $c/docker && git remote add k https://github.com/kiorky/docker.git
        warn "Upgrading docker"
        cd $c/docker && git pull
    fi
    sed -re "s/filemode.*/filemode=false/g" -i $c/*/.git/config
}
restart_dockers() {
    case $1 in
        debian)
            image="makinacorpus/debian"
            args="-p 4122:22"
            ;;
        ubuntu)
            image="makinacorpus/ubuntu"
            args="-p 4022:22 -p 4023:2222"
            ;;
        *)
            image="makinacorpus/ubuntu"
            args=""
            ;;
    esac
    shift
    for j in kill rm ;do
        docker $j $(docker ps -a |awk '{print $1}')
    done
    if [[ -z $NODAEMON ]];then
        args="-d $args"
    fi
    sleep 2
    docker run $args $image $@
}
rm_all() {
    for j in $(docker ps -a |awk '{print $1}'|grep -v ID);do
        echo $j
        docker stop -t=1  $j
        docker rm  $j
    done
    docker images -a|egrep  '<none>.*<none>'|awk '{print $3}'|xargs docker rmi
    service docker restart
}
actions=" $actions "
actions_main_usage="$actions"
fix_perms() {
    fics=""
    fics="$fics $(find $c/docker $c/lxc -maxdepth 0 -type f -print)"
    fics="$fics $(find $c/docker -type f -print)"
    directories=""
    directories="$directories $(find $c/docker $c/lxc -type d -print)"
    directories="$directories $c/.."
    directories="$directories $(find $c/debian -type d -print|egrep -v "/debian/(debootstrap|cache)")"
    directories="$directories $(find $c/ubuntu-debootstrap -type d -print|egrep -v "/ubuntu-debootstrap/(debootstrap|cache)")"
    sudo chmod g-s $directories
    sudo chmod g+rwx $fics $directories
    sudo chown $u:$g $fics $directories
    sudo chmod g+s $directories
}
usage() {
    for i in $actions_main_usage;do
        echo "$0 $i"
    done
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
