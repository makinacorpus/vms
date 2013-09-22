#!/usr/bin/env bash
cd $(dirname $0)
dockers="${@:-base latest}"
for d in $dockers;do
    case $d in
        *latest*)
            do_dockers="$do_dockers latest"
            ;;
        *base*)
            do_dockers="$do_dockers base"
            ;;
    esac
done
maybe_build() {
    if [[ $do_dockers == *$1* ]];then
        echo build $1
        CACHE=${DOCK_CACHE:-}
        case $d in
            *latest*)
                bargs="-t makinacorpus/ubuntu/"
                ;;
            *base*)
                bargs="-t makinacorpus/ubuntu"
        esac
        bargs="$bargs $1"
        echo docker build $CACHE -rm=true $bargs
        ret=$?
        if [[ $ret != 0 ]];then echo "failed $1";exit -1;fi
    else
        echo "$1 not selected to be built ($dockers)"
    fi
}
maybe_build base
maybe_build latest
# vim:set et sts=4 ts=4 tw=80:
