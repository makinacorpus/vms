#!/usr/bin/env bash
for j in $(docker ps -a |awk '{print $1}');do 
    echo $j
    docker stop -t=1  $j
    docker rm  $j
done
service docker restart
# vim:set et sts=4 ts=4 tw=80:
