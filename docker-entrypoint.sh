#!/bin/bash

while ! mysqladmin ping -h"$MYSQL_HOST" --silent; do
    echo "Waiting for database connection..."
    sleep 1
done

file_env() {
	local var="$1"
	local fileVar="${var}_FILE"
	local def="${2:-}"
	if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
		echo >&2 "error: both $var and $fileVar are set (but are exclusive)"
		exit 1
	fi
	local val="$def"
	if [ "${!var:-}" ]; then
		val="${!var}"
	elif [ "${!fileVar:-}" ]; then
		val="$(< "${!fileVar}")"
	fi
	export "$var"="$val"
	unset "$fileVar"
}

envs=(
		ADMIN_USER
		ADMIN_PASSWORD
		ADMIN_EMAIL
		MYSQL_USER
		MYSQL_PASSWORD
		MYSQL_DATABASE
		MYSQL_HOST
	)

for e in "${envs[@]}"; do
		file_env "$e"
		if [ -z "$haveConfig" ] && [ -n "${!e}" ]; then
			haveConfig=1
		fi
	done


if [ ! -f /var/www/html/config.inc.php ]; then
    echo "config.inc.php does not exist. starting installation ..."

    cp /var/www/html/config.TEMPLATE.inc.php /var/www/html/config.inc.php
    expect /root/ojsInstall.exp ${ADMIN_USER} ${ADMIN_PASSWORD} ${ADMIN_EMAIL} ${MYSQL_USER} ${MYSQL_PASSWORD} ${MYSQL_DATABASE} ${MYSQL_HOST}

    php /var/www/ojsconfig/ojs3.php --journal.theme=ojs-dainst-theme --theme=ojs-dainst-theme --journal.plugins=themes/ojs-dainst-theme

    sed -i 's/allowProtocolRelative = false/allowProtocolRelative = true/' /var/www/html/lib/pkp/classes/core/PKPRequest.inc.php

    cd /var/www/

    chgrp -f -R www-data html/plugins && \
    chmod -R 771 html/plugins && \
    chmod g+s html/plugins

    chgrp -f -R www-data html/cache && \
    chmod -R 771 html/cache && \
    chmod g+s html/cache

    chgrp -f -R www-data html/public && \
    chmod -R 771 html/public && \
    chmod g+s html/public

    chgrp -f -R www-data ojsfiles && \
    chmod -R 771 ojsfiles && \
    chmod g+s ojsfiles
fi

apachectl -DFOREGROUND
