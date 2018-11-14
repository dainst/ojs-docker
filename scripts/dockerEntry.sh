#!/bin/sh
#find /var/lib/mysql -type f -exec touch {};
service mysql start
apachectl -DFOREGROUND