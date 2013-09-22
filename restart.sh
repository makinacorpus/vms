#!/usr/bin/env bash
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
    echo docker $j $(docker ps -a|grep $image |awk '{print $1}')
done
if [[ -z $NODAEMON ]];then
    args="-d $args"
fi
echo docker run $args $image $@
# vim:set et sts=4 ts=4 tw=80:
