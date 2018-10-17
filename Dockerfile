FROM php:7.2.11-apache-stretch

LABEL maintainer="Deutsches Archäologisches Institut: dev@dainst.org"
LABEL "author"="Dennis Twardy: kontakt@dennistwardy.com"
LABEL version="0.3"
LABEL description="DAI specific OJS3 Docker container with DAI specific plugins"
LABEL "license"="GNU GPL 3"

EXPOSE 80 433
USER root

ENV ADMIN_USER=admin
ENV ADMIN_PASSWORD="password"
ENV ADMIN_EMAIL="dummy@address.local"
ENV MYSQL_PASSWORD="ojs"
ENV MYSQL_DB="ojs"
ENV OJS_VERSION="ojs-stable-3_1_1"
ENV COMPOSER_ALLOW_SUPERUSER=1

WORKDIR ~

# PHP settings
RUN echo "error_reporting=E_ALL & ~E_WARNING & ~E_NOTICE & ~E_STRICT & ~E_DEPRECATED"  >> /usr/local/etc/php/php.ini
RUN echo "date.timezone = Europe/Berlin"  >> /usr/local/etc/php/php.ini

# Update system and install essentials
RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get -y upgrade \
  &&  apt-get -y install git mysql-server nano curl cron supervisor unzip build-essential libssl-dev gnupg
RUN curl -sS https://getcomposer.org/installer -o composer-setup.php \
  && php composer-setup.php --install-dir=/usr/local/bin --filename=composer
RUN curl -sL https://deb.nodesource.com/setup_10.x | bash -
RUN apt-get -y install nodejs

# Setup and run MySQL
RUN echo "mysql.default_socket=/var/run/mysqld/mysqld.sock" >> /usr/local/etc/php/php.ini
RUN find /var/lib/mysql -type f -exec touch {} \; \
  && service mysql start \
  && sh -c "echo \"CREATE DATABASE ${MYSQL_DB};\" | mysql" \ 
  && mysqladmin -u root password ${MYSQL_PASSWORD}

# configure git
RUN git config --global url.https://.insteadOf git://
RUN git config --global advice.detachedHead false

# Set working directory and create files folder
WORKDIR /var/www/html
RUN mkdir -p /ojsfiles

# Get OJS3 code and prepare it
RUN git clone --depth 1 --single-branch --branch $OJS_VERSION https://github.com/pkp/ojs.git ojs
WORKDIR /var/www/html/ojs
RUN git submodule update --init --recursive >/dev/null
RUN composer update -d lib/pkp --no-dev \
  && composer install -d plugins/paymethod/paypal --no-dev \
  & composer install -d plugins/generic/citationStyleLanguage --no-dev
RUN npm install -y \
  && npm run build
RUN chmod -R 777 /var/www/html/ojs/cache \
  && chmod -R 777 /var/www/html/ojs/public
RUN cp config.TEMPLATE.inc.php config.inc.php

# Install DAI Plugins
WORKDIR /var/www/html/ojs/plugins
RUN git clone https://github.com/dainst/ojs-cilantro-plugin.git generic/ojs-cilantro-plugin
RUN git clone https://github.com/dainst/ojs-dainst-frontpage-generator-plugin.git generic/ojs-dainst-frontpage-generator-plugin
RUN git clone https://github.com/dainst/ojs-dainst-zenonlink-plugin.git pubIds/zenon
RUN git clone https://github.com/dainst/epicur.git oaiMetadataFormats/epicur
RUN git submodule update --init --recursive

# startup script
RUN echo "#!/bin/bash\nfind /var/lib/mysql -type f -exec touch {} \;\nservice mysql start\napachectl -DFOREGROUND" >> /root/startup.sh  \
  && chmod a+x /root/startup.sh
ENTRYPOINT ["/root/startup.sh"]