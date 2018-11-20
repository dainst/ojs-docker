#!/bin/sh
dockerid=dainst
name=ojs3
version=1.0
adminPassword=password
adminMail="dummy@address.local"
mysqlUser=ojs
mysqlPassword=ojs
mysqlDBName=ojs

while getopts "i:n:v:a:m:u:p:d:" o
do  case "$o" in
    i)    dockerid="$OPTARG";;
    n)    name="$OPTARG";;
    v)    version="$OPTARG";;
    a)    adminPassword="$OPTARG";;
    m)    adminMail="$OPTARG";;
    u)    mysqlUser="$OPTARG";;
    p)    mysqlPassword="$OPTARG";;
    d)    mysqlDBName="$OPTARG";;
    [?])  print >&2 "Usage: $0 [-d DockerID] [-n name] [-v version]"
          exit 1;;
    esac
done

docker image build --build-arg b_ADMIN_PASSWORD=${adminPassword} --build-arg b_ADMIN_EMAIL=${adminMail} --build-arg b_MYSQL_USER=mysqlUser --build-arg B_MYSQL_PASSWORD=mysqlPassword --build-arg B_MYSQL_DB=mysqlDBName --tag ${dockerid}/${name}:${version} .