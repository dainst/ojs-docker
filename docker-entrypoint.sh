#!/bin/bash

while ! mysqladmin ping -h"$MYSQL_HOST" --silent; do
    echo "Waiting for database connection..."
    sleep 1
done

if [ ! -f /var/www/html/config.inc.php ]; then
    echo "config.inc.php does not exist. starting installation ..."

    cp /var/www/html/config.TEMPLATE.inc.php /var/www/html/config.inc.php
	sed -i 's/allowProtocolRelative = false/allowProtocolRelative = true/' /var/www/html/lib/pkp/classes/core/PKPRequest.inc.php
fi

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

apachectl -DFOREGROUND
