#!/usr/bin/env bash
dockers="${@:-base upstart}"
for d in $dockers;do
    case $d in
        *upstart*)
            do_dockers="$do_dockers upstart"
            ;;
        *base*)
            do_dockers="$do_dockers base"
            ;;
    esac 
done
maybe_build() {
    if [[ $do_dockers == *$1* ]];then
        echo build $1
        docker build -t makinacorpus/$1 $1
    else
        echo "$1 not selected to be built ($dockers)"
    fi
    if [[ $? != 0 ]];then echo "failed $1";exit -1;fi
}
maybe_build base
maybe_build upstart
# vim:set et sts=4 ts=4 tw=80:
