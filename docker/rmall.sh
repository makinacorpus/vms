#!/usr/bin/env bash
for j in $(docker ps -a |awk '{print $1}'|grep -v ID);do 
    echo $j
    docker stop -t=1  $j
    docker rm  $j
done
docker images -a|egrep  '<none>.*<none>'|awk '{print $3}'|xargs docker rmi
service docker restart
# vim:set et sts=4 ts=4 tw=80:
