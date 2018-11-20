#!/bin/sh

set -e

cd /var/www/html/plugins

echo "Installing cilantro-plugins... "
git clone https://github.com/dainst/ojs-cilantro-plugin.git generic/ojs-cilantro-plugin
echo "[ok]\n"
echo "Installing dainst-frontpage-generator-plugin... "
git clone https://github.com/dainst/ojs-dainst-frontpage-generator-plugin.git generic/ojs-dainst-frontpage-generator-plugin
echo "[ok]\n"
echo "Installing dainst-zenonlink-plugin... "
git clone https://github.com/dainst/ojs-dainst-zenonlink-plugin.git pubIds/zenon
echo "[ok]\n"
echo "Installing dainst-epicur-plugin... "
git clone https://github.com/dainst/epicur.git oaiMetadataFormats/epicur
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