#!/bin/sh

while getopts b:a:m:u:p:n: o
do  case "$o" in
    b)    ojsBranch="$OPTARG";;
    a)    adminPwd="$OPTARG";;
    m)    adminMail="$OPTARG";;
    u)    dbUser="$OPTARG";;
    p)    dbPassword="$OPTARG";;
    n)    dbName="$OPTARG";;
    [?])  print >&2 "Usage: $0 [-b ojsBranch] [-a adminPassword] [-m adminMail] [-u dbUser] [-p dbPassword] [-n dbName]"
          exit 1;;
    esac
done

service mysql start
sh /root/ojsInit.sh -b ${ojsBranch} -a ${adminPwd} -m ${adminMail} -u ${dbUser} -p ${dbPassword} -n ${dbName}
apachectl -DFOREGROUND
