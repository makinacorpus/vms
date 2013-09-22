#!/usr/bin/env bash
cd $(dirname $0)
dockers="${@:-base ubuntu}"
for d in $dockers;do
    case $d in
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
        docker build $CACHE -rm=true $bargs
        ret=$?
        midf=$PWD/.docker_ubuntuid
        if [[ $1 == "ubuntu" ]];then
                MID=$(docker run -d -privileged makinacorpus/ubuntu /tmp/postinst.sh)
                docker attach $MID
                docker commit $MID makinacorpus/ubuntu
            fi
            echo $MID $midf
            echo $MID>$midf
        fi
        if [[ $ret != 0 ]];then echo "failed $1";exit -1;fi
    else
        echo "$1 not selected to be built ($dockers)"
    fi
}
#maybe_build base
maybe_build ubuntu
# vim:set et sts=4 ts=4 tw=80:
