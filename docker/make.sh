#!/usr/bin/env bash
#
# not really safe to use on a real system, you may better run that on a vm
# was tested with the vagrantfile of this repository
#
# This script has 2 main functions:
#    - build an environment with lxc & docker from development packages
#    - build makina corpus base docker images
#
#
# There are some helpers to manage dockers (like rm_all which wipe out this host docker images and containers)
#

actions="rm_all build_docker fix_perms restart_dockers init_src build_lxc make_image usage images"
actions=" $actions "
actions_main_usage="$actions"
UBUNTU_SAUCY_IMG="http://cloud-images.ubuntu.com/releases/saucy/release/ubuntu-13.10-server-cloudimg-amd64-root.tar.gz"
UBUNTU_RARING_IMG="http://cloud-images.ubuntu.com/releases/raring/release/ubuntu-13.04-server-cloudimg-amd64-root.tar.gz"
UBUNTU_PRECISE_IMG="http://cloud-images.ubuntu.com/releases/12.04.3/release/ubuntu-12.04-server-cloudimg-amd64-root.tar.gz"
lxc_bins="lxc-stop lxc-start lxc-info lxc-attach lxc-kill lxc-restart lxc-execute"
CURRENT_UBUNTU="saucy"
CURRENT_URL="$UBUNTU_SAUCY_IMG"
c=$(dirname $0)
cd $c
c=$PWD
markers=$c/.done
RED="\\033[31m"
CYAN="\\033[36m"
NORMAL="\\033[0m"
YELLOW='\e[1;33m'

help() { usage; }

log(){ echo -e "${YELLOW} [docker make] ${@}${NORMAL}"; }

warn(){ echo -e "${CYAN} [docker make] ${@}${NORMAL}"; }

die() { echo -e "${RED}${@}${NORMAL}"; exit -1; }

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
    if [[ $(docker images|awk '{print $1}'|egrep '^docker$'|wc -l) == "0" ]];then
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

fix_perms() {
    u="";g="editor"
    if [[ "$(whoami)" != "root" ]];then u="$(whoami)";fi
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

cook() {
    func=$1
    mk="$markers/.cook_${PWD//\//_}_${@//\//_}"
    mk="${mk// /_}"
    if [[ ! -f $mk ]] || [[ -n $COOK_FORCE ]] ;then
        "$@"
        if [[ $? == 0 ]];then
            if [[ ! -d $markers ]];then mkdir $markers;fi
            touch "$mk"
        else
            die "stopped due to error ($@ in $PWD)"
        fi
    else
        shift
        warn "Already done $func ($@) in $PWD (delete '$mk' to redo)"
    fi
}

tar_image() {
    w=$PWD
    src="$1";tar="${2:-${1}.tar.gz}";
    echo "Tarballing $src to $tar"
    cd $src && tar czfp "$tar" . --numeric-owner
    cd $w
}

make_image_from_path() {
    src="$1";tag="$2"
    log "Building docker $tag from path: $src"
    tar_image $src ${src}.tar.gz
    make_image_from_tarball ${src}.tar.gz $c/$tag
}

make_image_from_deboostrap() {
    debootstrap="$1";tag="$2";dst="$c/$tag/deboostrap"
    if [[ -e $debootstrap ]];then chmod +x $debootstrap;fi
    log "Using $debootstrap for building $tag"
    cook $debootstrap -p $dst
    make_image_from_path $dst $c/$tag
}

import_image() {
    log "Importing tarball in docker: $1 > $2"
    cat "$1" | docker import - "$2"
}

make_image_from_tarball() {
    tag="$2";tar="$1"
    log "Building docker from tarball: $tar"
    cook import_image $tar ${tag}_base
    log "Building docker image $c/$tag from imported tarball"
    cook docker build -t="${tag}" $c/$tag
}

make_image_from_remote_tarball() {
    tag="$2";url="$1";fic="$c/$(basename $url)"
    log "Building $tag from remote tarball: $url"
    wget -c $url
    make_image_from_tarball $fic $tag
}

make_image_generic() {
    cook docker build -rm=true -t="$1" "$1"
}

ubuntu_dockerfile() {
    sed -re "s|^FROM.*|FROM ${tag}_base|g" $c/$tag/Dockerfile.in > $c/$tag/Dockerfile
}

make_image_with_postinst() {
    tag="$1";postinst="${2:-/etc/docker-postinst.sh}"
    log "Building image $tag with postinst: $postinst"
    docker build -rm=true -t ${tag}_tmp ${tag}
    if [[ $ret != 0 ]];then log "failed tmp build $tag";exit -1;fi
    MID=$(docker run -d -privileged ${tag}_tmp)
    LID=$(docker inspect $MID|grep ID|awk '{print $2}'|sed -re 's/\"//g' -e 's/\,//g')
    log "Running $postinst from $MID( $LID )"
    lxc-attach -n $LID -- $postinst
    log "Commiting result from $MID to $tag"
    docker commit $MID $tag
    log "Cleaning image ${tag}_tmp"
    docker rmi ${tag}_tmp
}

make_image_ubuntu_salt() {
    make_image ubuntu
    cook make_image_with_postinst makinacorpus/salt
}

make_image_ubuntu_mastersalt() {
    make_image ubuntu
    cook make_image_with_postinst makinacorpus/mastersalt
}

make_image_ubuntu_upstart() {
    make_image ubuntu
    cook make_image_generic makinacorpus/ubuntu_upstart
}

make_image_ubuntu_deboostrap() {
    tag="makinacorpus/ubuntu_deboostrap"
    ubuntu_dockerfile $tag
    make_image_from_deboostrap $c/lxc-ubuntu $tag
}

make_image_debian() {
    make_image_from_deboostrap $c/lxc-debian makinacorpus/debian
}

make_image_ubuntu_saucy() {
    tag="makinacorpus/ubuntu_saucy"
    ubuntu_dockerfile $tag
    make_image_from_remote_tarball $UBUNTU_SAUCY_IMG $tag
}

make_image_ubuntu() {
    ctag="makinacorpus/ubuntu_${CURRENT_UBUNTU}"
    btag="${ctag}_base"
    ctar="$c/$(basename $CURRENT_URL)"
    make_image_ubuntu_$CURRENT_UBUNTU || die "building current ubuntu failed"
    # get image id of current image
    bid=$(docker images|egrep "^${btag}\s*"|awk '{print $3}')
    tag=makinacorpus/ubuntu
    if [[ -n $bid ]];then
        log "Tagging $bid as $tag"
        docker tag $bid $tag
    else
        die "cant get bid"
    fi
}

make_image_ubuntu_raring() {
    tag="makinacorpus/ubuntu_raring"
    ubuntu_dockerfile $tag
    make_image_from_remote_tarball $UBUNTU_RARING_IMG $tag
}

make_image_ubuntu_precise() {
    tag="makinacorpus/ubuntu_precise"
    ubuntu_dockerfile $tag
    make_image_from_remote_tarball $UBUNTU_PRECICE_IMG $tag
}

images() {
    make_image ubuntu
    make_image ubuntu_saucy
    make_image ubuntu_raring
    make_image ubuntu_salt
    make_image ubuntu_mastersalt
    make_image debian

}

make_image() {
    cook make_image_$@
}

usage() {
    cd $c
    log "make_image [ $(echo $(ls makinacorpus/* -d)|sed -re "s/ / | /g" -e "s/makinacorpus\///g") ]"
    for i in $actions_main_usage;do
        if [[ "$i" != "make_image" ]];then
            log "$0 $i"
        fi
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

