#!/bin/sh

service mysql start
sh /root/ojsInit.sh
apachectl -DFOREGROUND