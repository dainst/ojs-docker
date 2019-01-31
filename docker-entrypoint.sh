#!/bin/bash
set -eo pipefail

# usage: file_env VAR [DEFAULT]
#    ie: file_env 'XYZ_DB_PASSWORD' 'example'
# (will allow for "$XYZ_DB_PASSWORD_FILE" to fill in the value of
#  "$XYZ_DB_PASSWORD" from a file, especially for Docker's secrets feature)
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
    MYSQL_DB
)

for e in "${envs[@]}"; do
    file_env "$e"
done

service mysql start

if  [ "${MYSQL_USER}" != "$(sh -c "echo \"SELECT User from mysql.user;\" | mysql -u root" | grep ${MYSQL_USER})" ]; then
    echo "User ${MYSQL_USER} not found. Creating new user... "
    sh -c "echo \"CREATE USER '${MYSQL_USER}'@'localhost' IDENTIFIED BY '${MYSQL_PASSWORD}';\" | mysql -u root"
    sh -c "echo \"UPDATE mysql.user SET plugin = 'mysql_native_password' WHERE User='${MYSQL_USER}'; FLUSH PRIVILEGES;\" | mysql -u root"
    echo "[ok]\n"
else
    echo "using existing MySQL User ${MYSQL_USER}...\n"
fi

if  [ "${MYSQL_USER}" != "$(sh -c "echo \"SHOW DATABASES;\" | mysql -u root" | grep ${MYSQL_DB})" ]; then
    echo "Database ${MYSQL_DB} not found. Creating database... "
    sh -c "echo \"CREATE DATABASE ${MYSQL_DB};\" | mysql -u root"
    sh -c "echo \"GRANT ALL PRIVILEGES on ${MYSQL_DB}.* TO '${MYSQL_USER}'@'localhost'; FLUSH PRIVILEGES;\" | mysql -u root"
    echo "[ok]\n"
else
    echo "using existing MySQL database ${MYSQL_DB}...\n"
fi

if [ ! -e /var/www/html/config.TEMPLATE.inc.php ]; then
    echo "No existing OJS installation found.\n"

    echo "Creating ojsfiles folder in /var/www... "
    mkdir -p /var/www/ojsfiles
    echo "[ok]\n"

    cd /var/www/html

    if [ -e index.html ]; then
        echo "Non ojs-related index.html found. Removing... "
        rm index.html
        echo "[ok]\n"
    fi

    echo "Initializing git empty git repository... "
    git init
    echo "[ok]\n"
    echo "Fetching branch ${OJS_BRANCH} of OJS from github... "
    git remote add -t ${OJS_BRANCH} origin https://github.com/pkp/ojs.git
    git fetch origin --depth 1 ${OJS_BRANCH}
    git checkout --track origin/${OJS_BRANCH}
    echo "[ok]\n"
    echo "Updating submodules... "
    git submodule update --init --recursive
    echo "[ok]\n"

    echo "Installing dependencies with Composer... "
    composer install -v -d lib/pkp --no-dev
    composer install -v -d plugins/paymethod/paypal --no-dev
    composer install -v -d plugins/generic/citationStyleLanguage --no-dev
    echo "[ok]\n"

    echo "Installing dependencies with npm... "
    npm install -y
    npm run build
    echo "[ok]\n"

    echo "Creating config.inc.php"
    cp config.TEMPLATE.inc.php config.inc.php
    echo "[ok]\n"

    echo "Updating permissions... "
    cd /var
    chgrp -f -R www-data www
    chmod -R 771 www
    chmod g+s www
    setfacl -Rm o::x,d:o::x www
    setfacl -Rm g::rwx,d:g::rwx www
    echo "[ok]\n"

else
    echo "Existing config.TEMPLATE.inc.php found. Assuming OJS installation already exists...\n"
fi


if { [ -e /var/www/html/config.inc.php ] && [ "installed = On" != "$(cat /var/www/html/config.inc.php | grep "installed = On")" ] ;} ; then
    cd /var/www
    echo "Starting OJS install script... \n"
    expect /root/ojsInstall.exp ${ADMIN_USER} ${ADMIN_PASSWORD} ${ADMIN_EMAIL} ${MYSQL_USER} ${MYSQL_PASSWORD} ${MYSQL_DB}
    echo "OJS install script done... [ok]\n"

    echo "Installing DAI OJS configure tool...\n"
    echo "Fetching code..."
    git clone https://github.com/dainst/ojs-config-tool ojsconfig
    echo "[ok]\n"
    echo "Installing PKP Texture plugin... \n"
    echo "Fetching code... "
    cd html/plugins
    git clone --single-branch -b ${OJS_BRANCH} https://github.com/asmecher/texture generic/texture
    echo "[ok]\n"
    echo "Updating submodules... "
    git submodule update --init --recursive
    echo "[ok]\n"
    echo "Updating permissions... "
    chgrp -f -R www-data generic/texture
    chmod -R 771 generic/texture
    chmod g+s generic/texture
    setfacl -Rm o::x,d:o::x generic/texture
    setfacl -Rm g::rwx,d:g::rwx generic/texture
    echo "[ok]\n"
    echo "Running DAI OJS configure tool...\n"
    php /var/www/ojsconfig/ojs3.php
else
    echo "OJS is already setup and configured... \n"
fi

#if [ ! -d "/var/www/html/plugins/generic/ojs-cilantro-plugin" ]; then
if [ ! -d "/var/www/html/plugins/oaiMetadataFormats/epicur" ]; then
    echo "Starting install script for DAI Plugins... \n"

    cd /var/www/html/plugins

    # plugins are not ready for ojs3
    echo "Installing cilantro-plugins... "
    git clone -b ojs3 https://github.com/dainst/ojs-cilantro-plugin.git generic/ojs-cilantro-plugin
    echo "[ok]\n"

    #echo "Installing dainst-zenonlink-plugin... "
    #git clone https://github.com/dainst/ojs-dainst-zenonlink-plugin.git pubIds/zenon
    #echo "[ok]\n"

    echo "Installing dainst-epicur-plugin... "
    git clone -b ojs3 https://github.com/dainst/epicur.git oaiMetadataFormats/epicur
    echo "[ok]\n"

    echo "Updating dependencies... "
    git submodule update --init --recursive
    echo "[ok]\n"

    echo "Updating permissions... "
    cd /var/www/html/
    chgrp -f -R www-data plugins
    chmod -R 771 plugins
    chmod g+s plugins
    setfacl -Rm o::x,d:o::x plugins
    setfacl -Rm g::rwx,d:g::rwx plugins
    echo "[ok]\n"

    echo "Creating temporary folder and adding it to config.inc.php... "
    mkdir /var/www/tmp
    echo "[dainst]\ntmpPath = /var/www/tmp" >> /var/www/html/config.inc.php
    echo "[ok]\n"
    echo "Updating permissions... "
    cd /var/www
    chgrp -f -R www-data tmp
    chmod -R 771 tmp
    chmod g+s tmp
    setfacl -Rm o::x,d:o::x tmp
    setfacl -Rm g::rwx,d:g::rwx tmp
    echo "[ok]\n"

    echo "Finished install script for DAI Plugins... [ok]\n"
fi

sed -i 's/allowProtocolRelative = false/allowProtocolRelative = true/' /var/www/html/lib/pkp/classes/core/PKPRequest.inc.php
#echo "base_url[index] = http://192.168.178.39/ojs/index.php/test" | tee -a /var/www/html/config.inc.php

apachectl -DFOREGROUND
