
#!/usr/bin/env bash
cd $(dirname $0)
W=$PWD
MARKERS=$W/.done
tar=$W/ubuntu-base.tar.gz
cook() {
    func=$1
    mk="$MARKERS/.cook_${PWD//\//_}_${@//\//_}"
    if [[ ! -f $mk ]] || [[ -n $COOK_FORCE ]] ;then
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
    echo Tarballing
    cd deboostrap &&\
    tar cjf $tar .&&\
    cd $W
}
import_() {
    cat $tar | docker import - makinacorpus/ubuntu_deboostrap/base
}
cook ./lxc-ubuntu -p $W/deboostrap
cook tar_
cook import_
docker build -t="makinacorpus/ubuntu_deboostrap:latest" ubuntu
# vim:set et sts=4 ts=4 tw=80:
