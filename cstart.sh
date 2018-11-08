#!/bin/sh
containername=ojs3

while getopts c: o
do  case "$o" in
    c)    containername="$OPTARG";;
    [?])  print >&2 "Usage: $0 [-c container name]"
          exit 1;;
    esac
done

docker container start ${containername}