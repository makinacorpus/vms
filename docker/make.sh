#!/usr/bin/env bash
actions="rm_all build_docker fix_perms restart_dockers init_src"
u=""
if [[ "$(whoami)" != "root" ]];then
    u=$(whoami)
fi
g=editor
c=$(dirname $0)
cd $c
c=$PWD
die() { echo $@; exit -1; }
build_docker() {
    init_src
    cd $0/docker || die "docker src not there"
    if [ ! -f /usr/bin/docker.ubundu ];then
        sudo cp /usr/bin/docker /usr/bin/docker.ubundu
    fi
    for binary in lxc-start docker;do
        if [ ! -f /usr/bin/${binary} ];then
            sudo cp -v /usr/bin/${binary} /usr/bin/${binary}.ubuntu
        fi
    done
    sudo service docker stop
    sudo rm -rf /var/run/docker.sock
    sudo rm -f  /usr/bin/docker
    sudo ln -sf /usr/bin/docker.ubundu /usr/bin/docker
    sudo service docker start
    sleep 2
    sudo /usr/bin/docker run -lxc-conf=lxc.aa_profile=unconfined -privileged -v `pwd`:/go/src/github.com/dotcloud/docker docker hack/make.sh binary
    bin="$(ls -r1t $PWD/bundles/*/binary/docker-*|tail -n1)"
    sudo service docker stop
    sudo rm -rf /var/run/docker.sock
    sudo ln -fs  $bin /usr/bin/docker
    sudo service docker start
}
init_src() {
    if [ ! -d lxc ];then
        git clone https://github.com/lxc/lxc.git
    fi
    if [ ! -d docker ];then
        git clone https://github.com/dotcloud/docker.git
    fi
    cd $c/lxc && git pull
    cd $c/docker && git remote add k https://github.com/kiorky/docker.git
    cd $c/docker && git pull
    sed -re "s/filemode.*/filemode=false/g" -i $c/*/.git/config
    sudo fix_perms
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
