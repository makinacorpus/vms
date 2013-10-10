#!/usr/bin/env bash
for j in $(docker ps -a |awk '{print $1}');do 
    for i in kill rm;do docker $i $j;
    done;
done
service docker restart
# vim:set et sts=4 ts=4 tw=80:
