#!/usr/bin/env bash

#
# Base docker container images generator
#
# CALL with:
#
# ./make.sh minimal ubuntu
# ./make.sh salt -> salt + minion
# ./make.sh mastersalt -> salt + minion + mastersalt minion
#
cd $(dirname $0)
dockers="${@:-base ubuntu salt}"
for d in $dockers;do
    case $d in
        mastersalt)
            do_dockers="$do_dockers salt"
            ;;
        salt)
            do_dockers="$do_dockers mastersalt"
            ;;
        *ubuntu*)
            do_dockers="$do_dockers ubuntu"
            ;;
        *base*)
            do_dockers="$do_dockers base"
            ;;
    esac
done
maybe_build() {
    if [[ $do_dockers == *$1* ]];then
        echo "---> Building $1"
        CACHE=${DOCK_CACHE:-}
        bargs="-t makinacorpus/ubuntu"
        case $d in
            *base*)
                bargs="$bargs/$d"
                ;;
        esac
        bargs="$bargs $1"
        midf=$PWD/.docker_ubuntu_${1}_id
        if [[ $1 == *salt* ]];then
            echo docker build -t makinacorpus/ubuntu_tmp ${1}
            docker build -t makinacorpus/ubuntu_tmp ${1}
            MID=$(docker run -d -privileged makinacorpus/ubuntu_tmp)
            LID=$(docker inspect $MID|grep ID|awk '{print $2}'|sed -re 's/\"//g' -e 's/\,//g')
            lxc-attach -n $LID -- /tmp/postinst.sh
            docker commit $MID makinacorpus/ubuntu_${1}
            echo $MID $midf
            echo $MID>$midf
            docker rmi makinacorpus/ubuntu_tmp
        else
            docker build $CACHE -rm=true $bargs
            ret=$?
            if [[ $ret != 0 ]];then echo "failed $1";exit -1;fi
        fi
    else
        echo "$1 not selected to be built ($dockers)"
    fi
}
#maybe_build base
maybe_build ubuntu
maybe_build salt
#maybe_build mastersalt
# vim:set et sts=4 ts=4 tw=80:
