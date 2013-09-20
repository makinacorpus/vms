#!/usr/bin/env bash
cd $(dirname $0)
W=$PWD
MARKERS=$W/.done
cook() {
    func=$1
    mk="$MARKERS/.cook_${PWD//\//_}_${@//\//_}"
    if [[ ! -f $mk ]];then
        "$@"
        if [[ $? == 0 ]];then
            if [[ ! -d $MARKERS ]];then mkdir $MARKERS;fi
            touch "$mk"
        else
            echo "stopped due to error ($@ in $PWD)"
            exit -1
        fi
    else
        shift
        echo "Already done $func ($@) in $PWD ($mk)"
    fi
}
tar_() {
    pushd deboostrap &&\
    tar cjvf ../debian-base.tgz .&&\
    popd
}
cook ./lxc-debian -p $W/deboostrap
#cook tar_
# vim:set et sts=4 ts=4 tw=80:
