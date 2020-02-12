#!/bin/bash

while ! mysqladmin ping -h"$MYSQL_HOST" --silent; do
    echo "Waiting for database connection..."
    sleep 5
done

if [ ! -f /var/www/html/config.inc.php ]; then
    echo "config.inc.php does not exist. starting installation ..."
    
    cd /var/www/html

    # js modules
    npm install -y
    npm run build

    # php modules
    composer install -v -d lib/pkp --no-dev
    composer install -v -d plugins/paymethod/paypal --no-dev
    composer install -v -d plugins/generic/citationStyleLanguage --no-dev

    # configuration
    cp /tmp/config.TEMPLATE.inc.php /var/www/html/config.inc.php
	sed -i 's/allowProtocolRelative = false/allowProtocolRelative = true/' /var/www/html/lib/pkp/classes/core/PKPRequest.inc.php
fi

apachectl -DFOREGROUND
