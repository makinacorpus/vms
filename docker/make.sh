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

actions="usage fix_perms"
actions="$actions cleanup_docker cleanup_containers cleanup_images"
actions="$actions restart_dockers rm_all cleanup_docker dattach"
actions="$actions make_image make_images"
actions="$actions init_src"
actions="$actions inst install_lxc install_docker"
actions="$actions teardown teardown_lxc teardown_docker"
actions=" $actions "
actions="${actions//  / }"
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

if [[ -f /etc/lsb-release ]];then
    . /etc/lsb-release
fi

help() { usage; }

log(){ echo -e "${YELLOW} [docker make] ${@}${NORMAL}" >&2; }

warn(){ echo -e "${CYAN} [docker make] ${@}${NORMAL}" >&2; }

die() { echo -e "${RED}${@}${NORMAL}" >&2; exit -1; }

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

teardown_() {
    for binary in $@;do
        mybin="$(which $binary)"
        if [ -f "${mybin}.ubuntu" ];then
            warn "Saving${mybin}.ubuntu in $binary"
            sudo cp -f "${mybin}.ubuntu" "${mybin}"
            if [[ "$?" == "0" ]];then
                rm -f "${mybin}.ubuntu"
            fi
        fi
    done
}

inst() {
    if [[ $DISTRIB_CODENAME == "saucy" ]] || [[ $DISTRIB_CODENAME == "trusty" ]];then
        install_lxc
    fi
    install_docker
}

teardown_docker() {
    log "Disabling docker dev binaries"
    teardown_ $lxc_bins
}

teardown_lxc() {
    log "Disabling lxc dev binaries"
    teardown_ docker
}

teardown() {
    teardown_lxc
    teardown_docker
}


save_() {
    for binary in $@;do
        mybin="$(which $binary)"
        if [ ! -f "${mybin}.ubuntu" ] && [ -f "${mybin}" ];then
            warn "Saving $binary in ${mybin}.ubuntu"
            sudo cp "${mybin}" "${mybin}.ubuntu"
        fi
    done
}
save_docker() {
    save_ docker
}

save_lxc() {
    save_ $lxc_bins
}


install_lxc() {
    log "Bootstrapping sources"
    init_src
    save_lxc
    cd $c/lxc || die "docker src not there"
    lazy_apt_get_install autopoint
    sudo apt-get build-dep -y --force-yes lxc
    ./autogen.sh -ifv && ./configure --with-distro=ubuntu --prefix=/lxc/ && make && sudo make install &&\
        for i in $lxc_bins;do sudo ln -svf /lxc/bin/$i /usr/bin/$i;done
    post_build $@
}

post_build() {
    for i in $@;do
        if [[ $i == "fix_perms" ]];then
            fix_perms
        fi
    done
}

install_docker() {
    nopull="nopull"
    for i in $@;do
        if [[ $i == "pull" ]];then
            nopull="pull"
        fi
    done
    log "Bootstrapping sources"
    init_src $nopull
    cd $c/docker || die "docker src not there"
    save_docker
    sudo service docker stop
    sudo rm -rf /var/run/docker.sock
    sudo rm -f /usr/bin/docker
    sudo cp -f /usr/bin/docker.ubuntu /usr/bin/docker
    sudo service docker start
    sleep 2
    cd $c/docker || die "docker src not there"
    chrono=$(date +"%Y%m%d%H%M%S")
    old="$PWD/bundles/old/$chrono"
    if [[ ! -d "$old" ]];then
        mkdir -pv "$old"
    fi
    mv -vf $PWD/bundles/* $old/
    if [[ $(docker images|awk '{print $1}'|egrep '^docker$'|wc -l) == "0" ]];then
        sudo docker build -t docker .
        if [[ $? != 0 ]];then
            die "Docker build-init failed"
        fi
    fi
    log "Building docker"
    sudo /usr/bin/docker run -lxc-conf=lxc.aa_profile=unconfined -privileged -v `pwd`:/go/src/github.com/dotcloud/docker docker hack/make.sh binary
    bin="$(find $PWD/bundles|grep -v "old"|grep "docker-"|xargs ls -r1t|tail -n1)"
    echo $bin
    sudo service docker stop
    sudo rm -rf /var/run/docker.sock
    log "Linking docker"
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
        d_origin="o"
        d_branch="master"
        warn "Upgrading sources"
        cd $c/docker && git remote add o https://github.com:makinacorpus/docker.git
        cd $c/docker && git remote add k https://github.com/kiorky/docker.git
        warn "Upgrading lxc"
        cd $c/lxc && git pull
        warn "Upgrading docker"
        cd $c/docker && git pull $d_origin $d_branch
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

cleanup_images() {
    docker images -a|egrep  '<none>.*<none>'|awk '{print $3}'|xargs docker rmi
}

cleanup_containers() {
    for j in $(docker ps -a|grep Exit|awk '{print $1}'|grep -v ID);do
        echo $j
        docker stop -t=1  $j
        docker rm  $j
    done
}

cleanup_docker() {
    cleanup_images
    cleanup_containers
    service docker restart
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
    log "Tarballing $src to $tar"
    cd $src && tar czfp "$tar" . --numeric-owner
    cd $w
}

make_image_from_path() {
    src="$1";tag="$2"
    log "Building docker $tag from path: $src"
    tar_image $src ${src}.tar.gz
    make_image_from_tarball ${src}.tar.gz $tag
}

make_image_from_deboostrap() {
    debootstrap="$1";tag="$2";dst="$c/$tag/deboostrap"
    iid="$(get_iid $tag)"
    if [[ -n $iid ]];then
        log "Already built image '$tag' from deboostrap: $debootstrap ($iid)"
    else
        if [[ -e $debootstrap ]];then chmod +x $debootstrap;fi
        log "Build image '$tag' from deboostrap: $debootstrap"
        cook $debootstrap -p $dst
        make_image_from_path $dst $tag
    fi
}

import_image() {
    log "Importing tarball in docker: $1 > $2"
    cat "$1" | docker import - "$2"
}

make_image_from_tarball() {
    tag="$2";tar="$1";iid="$(get_iid $tag)"
    if [[ -n "$iid" ]];then
        log "Already built '$tag' from tarball: $tar ($iid)"
    else
        log "Building docker from tarball: $tar"
        import_image $tar ${tag}_base
        log "Building docker image $c/$tag from imported tarball"
        docker build -t="${tag}" $c/$tag
    fi
}

make_image_from_remote_tarball() {
    tag="$2";url="$1";tar="$c/$(basename $url)"
    log "Building $tag from remote tarball: $url"
    wget -c $url
    make_image_from_tarball $tar $tag
}

make_image_generic() {
    iid="$(get_iid $1)"
    if [[ -n $iid ]];then
        docker build -rm=true -t="$1" "$1"
    else
        log "Already Builded generic image $1 (tag: $iid)"
    fi
}

ubuntu_dockerfile() {
    sed -re "s|^FROM.*|FROM ${tag}_base|g" $c/$tag/Dockerfile.in > $c/$tag/Dockerfile
}

get_iid() {
    docker images|egrep "^$1 "|awk '{print $3}'
}

make_image_with_postinst() {
    tag="$1";postinst="${2:-/etc/docker-postinst.sh}"
    iid="$(get_iid $tag)"
    if [[ -n "$iid" ]];then
        log "Already Builded image $tag with postinst: $postinst (tag: $iid)"
    else
        log "Building image $tag with postinst: $postinst"
        docker build -rm=true -t ${tag}_tmp $c/${tag}
        ret="$?"
        if [[ "$ret" != "0" ]];then die "failed tmp build $tag";fi
        MID=$(docker run -d -privileged ${tag}_tmp)
        if [[ "$?" != "0" ]];then die "failed run tmp build $tag";fi
        LID=$(docker inspect $MID|grep ID|awk '{print $2}'|sed -re 's/\"//g' -e 's/\,//g')
        log "Running $postinst from $MID( $LID )"
        lxc-attach -n $LID -- $postinst
        if [[ "$ret" != "0" ]];then die "failed postinst: $postinst";fi
        log "Commiting result from $MID to $tag"
        docker commit $MID $tag
        log "Cleaning image ${tag}_tmp"
        docker rmi ${tag}_tmp
    fi
}

make_image_ubuntu_salt() {
    make_image ubuntu
    make_image_with_postinst makinacorpus/ubuntu_salt
}

make_image_ubuntu_mastersalt() {
    make_image ubuntu
    make_image_with_postinst makinacorpus/ubuntu_mastersalt
}

make_image_ubuntu_upstart() {
    make_image ubuntu
    make_image_generic makinacorpus/ubuntu_upstart
}

make_image_ubuntu_deboostrap() {
    tag="makinacorpus/ubuntu_deboostrap"
    ubuntu_dockerfile $tag
    make_image_from_deboostrap $c/lxc-ubuntu $tag
}

make_image_debian() {
    make_image_from_deboostrap $c/lxc-debian makinacorpus/debian
}

make_image_debian_salt() {
    make_image_from_deboostrap $c/lxc-debian makinacorpus/debian_salt
}

make_image_debian() {
    make_image_from_deboostrap $c/lxc-debian makinacorpus/debian_mastersalt
}

dattach() {
    did="$1";lid="$(docker inspect $did|grep ID|sed -re 's/.* "//g' -e 's/".*//g')"
    shift
    cmd="$@"
    if [[ -z "$cmd" ]];then cmd=bash;fi
    log "Executing lxc-attach -n $lid -- $cmd"
    lxc-attach -n $lid -- $cmd
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
    bid=$(docker images|egrep "^${ctag} "|awk '{print $3}')
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

make_images() {
    make_image ubuntu_saucy
    make_image ubuntu
    #make_image ubuntu_raring
    make_image ubuntu_salt
    make_image ubuntu_mastersalt
    #make_image debian
    #make_image debian_salt
    #make_image debian_mastersalt
}

make_image() {
    make_image_$@
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

