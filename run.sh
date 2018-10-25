#!/bin/sh
dockerid=diotough
name=ojs3-dainst
version=0.6
mysqlvolume=ojs3db
appvolume=ojs3app
filesvolume=ojs3files
containername=ojs3
sslmap=8888
httpmap=8080

while getopts d:n:v:m:a:f:c:s:h: o
do  case "$o" in
    d)    dockerid="$OPTARG";;
    n)    name="$OPTARG";;
    v)    version="$OPTARG";;
    m)    mysqlvolume="$OPTARG";;
    a)    appvolume="$OPTARG";;
    f)    filesvolume="$OPTARG";;
    c)    containername="$OPTARG";;
    s)    sslmap="$OPTARG";;
    h)    httpmap="$OPTARG";;
    [?])  print >&2 "Usage: $0 [-d DockerID] [-n name] [-v version] [-m mysql volume] [-a app volume] [-f files volume] [-c container name] [-s ssl port mapping] [-h http port mapping]"
          exit 1;;
    esac
done

docker container run --detach --mount source=${filesvolume},target=/var/www/ojsfiles --mount source=${ojs3app},target=/var/www/html --mount source=${mysqlvolume},target=/var/lib/mysql --publish ${httpmap}:80 --publish ${sslmap}:443 --name ${containername} ${dockerid}/${name}:${version}