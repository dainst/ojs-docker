#!/bin/sh

set -e

adminUser=admin

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

if  [ "${dbUser}" != "$(sh -c "echo \"SELECT User from mysql.user;\" | mysql -u root" | grep ${dbUser})" ]; then
    echo "User ${dbUser} not found. Creating new user... "
    sh -c "echo \"CREATE USER '${dbUser}'@'localhost' IDENTIFIED BY '${dbPassword}';\" | mysql -u root"
    sh -c "echo \"UPDATE mysql.user SET plugin = 'mysql_native_password' WHERE User='${dbUser}'; FLUSH PRIVILEGES;\" | mysql -u root"
    echo "[ok]\n"
else
    echo "using existing MySQL User ${dbUser}...\n"
fi

if  [ "${dbUser}" != "$(sh -c "echo \"SHOW DATABASES;\" | mysql -u root" | grep ${dbName})" ]; then
    echo "Database ${dbName} not found. Creating database... "
    sh -c "echo \"CREATE DATABASE ${dbName};\" | mysql -u root"
    sh -c "echo \"GRANT ALL PRIVILEGES on ${dbName}.* TO '${dbUser}'@'localhost'; FLUSH PRIVILEGES;\" | mysql -u root"
    echo "[ok]\n"
else
    echo "using existing MySQL database ${dbName}...\n"
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
    echo "Fetching branch ${ojsBranch} of OJS from github... "
    git remote add -t ${ojsBranch} origin https://github.com/pkp/ojs.git
    git fetch origin --depth 1 ${ojsBranch}
    git checkout --track origin/${ojsBranch}
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
    expect /root/ojsInstall.exp ${adminUser} ${adminPwd} ${adminMail} ${dbUser} ${dbPassword} ${dbName}
    echo "OJS install script done... [ok]\n"

    echo "Installing DAI OJS configure tool...\n"
    echo "Fetching code..."
    git clone https://github.com/dainst/ojs-config-tool ojsconfig
    echo "[ok]\n"
    echo "Installing PKP Texture plugin... \n"
    echo "Fetching code... "
    cd html/plugins
    git clone --single-branch -b ${ojsBranch} https://github.com/asmecher/texture generic/texture
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

if [ ! -d "/var/www/html/plugins/generic/ojs-cilantro-plugin" ]; then
    echo "Starting install script for DAI Plugins... \n"
    sh /root/dainstInit.sh
    echo "Finished install script for DAI Plugins... [ok]\n"
fi