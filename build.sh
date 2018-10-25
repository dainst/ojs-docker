#!/bin/sh
dockerid=diotough
name=ojs3-dainst
version=1.0

while getopts d:n:v: o
do  case "$o" in
    d)    dockerid="$OPTARG";;
    n)    name="$OPTARG";;
    v)    version="$OPTARG";;
    [?])  print >&2 "Usage: $0 [-d DockerID] [-n name] [-v version]"
          exit 1;;
    esac
done

docker image build --tag ${dockerid}/${name}:${version} .