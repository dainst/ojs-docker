FROM php:7.2.11-apache-stretch

LABEL maintainer="Deutsches Archäologisches Institut: dev@dainst.org"
LABEL "author"="Dennis Twardy: kontakt@dennistwardy.com"
LABEL version="0.5"
LABEL description="DAI specific OJS3 Docker container with DAI specific plugins"
LABEL "license"="GNU GPL 3"

EXPOSE 80 443
USER root

ENV ADMIN_USER=admin
ENV ADMIN_PASSWORD="password"
ENV ADMIN_EMAIL="dummy@address.local"
ENV MYSQL_USER="ojs"
ENV MYSQL_PASSWORD="ojs"
ENV MYSQL_DB="ojs"
ENV OJS_BRANCH="ojs-stable-3_1_1"
ENV COMPOSER_ALLOW_SUPERUSER=1

WORKDIR /tmp

# Adding configuration files
ADD php.ini /usr/local/etc/php/
ADD ojs-apache.conf /etc/apache2/conf-available
ADD ojs-ssl-site.conf /etc/apache2/sites-available
ADD ojs-site.conf /etc/apache2/sites-available

# Adding SSL keys and protect them
ADD apache.crt /etc/apache2/ssl
ADD apache.key /etc/apache2/ssl
RUN chmod 600 -R /etc/apache2/ssl

# Update system and install essentials
RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get -y install \
  acl \
  build-essential \
  curl \
  cron \
  git \
  gnupg \
  libssl-dev \
  mysql-server \ 
  nano \
  openssl \
  supervisor \
  unzip \
  && curl -sL https://deb.nodesource.com/setup_10.x | bash - \
  && apt-get -y install \
  nodejs

RUN curl -sS https://getcomposer.org/installer -o composer-setup.php \
  && php composer-setup.php --install-dir=/usr/local/bin --filename=composer

# Setup and run MySQL
RUN echo "mysql.default_socket=/var/run/mysqld/mysqld.sock" >> /usr/local/etc/php/php.ini
RUN find /var/lib/mysql -type f -exec touch {} \; \
  && service mysql start \
  && sh -c "echo \"CREATE USER '${MYSQL_USER}'@'localhost' IDENTIFIED BY '${MYSQL_PASSWORD}';\" | mysql -u root" \
  && sh -c "echo \"CREATE DATABASE ${MYSQL_DB};\" | mysql" \ 
  && sh -c "echo \"GRANT ALL PRIVILEGES on ${MYSQL_DB}.* TO '${MYSQL_USER}'@'localhost'; FLUSH PRIVILEGES;\" | mysql" 

# Configure Apache
RUN a2enconf ojs-apache \
  && a2enmod ssl \
  && a2ensite ojs-site \
  && a2ensite ojs-ssl-site

# configure git
RUN git config --global url.https://.insteadOf git://
RUN git config --global advice.detachedHead false

# create files folder
RUN mkdir -p /var/www/ojsfiles

# Get OJS3 code and prepare it
WORKDIR /var/www/html
RUN git init \
  && git remote add -t $OJS_BRANCH origin https://github.com/pkp/ojs.git \
  && git fetch origin $OJS_BRANCH \
  && git checkout --track origin/$OJS_BRANCH
RUN git submodule update --init --recursive >/dev/null
RUN composer update -d lib/pkp --no-dev \
  && composer install -d plugins/paymethod/paypal --no-dev \
  && composer install -d plugins/generic/citationStyleLanguage --no-dev
RUN npm install -y \
  && npm run build
RUN cp config.TEMPLATE.inc.php config.inc.php

# Install DAI Plugins
WORKDIR /var/www/html/plugins
RUN git clone https://github.com/dainst/ojs-cilantro-plugin.git generic/ojs-cilantro-plugin
RUN git clone https://github.com/dainst/ojs-dainst-frontpage-generator-plugin.git generic/ojs-dainst-frontpage-generator-plugin
RUN git clone https://github.com/dainst/ojs-dainst-zenonlink-plugin.git pubIds/zenon
RUN git clone https://github.com/dainst/epicur.git oaiMetadataFormats/epicur
RUN git submodule update --init --recursive

WORKDIR /var/www
RUN chgrp -f -R www-data html \
  && chmod -R 771 html \
  && chmod g+s html \
  && setfacl -Rm o::x,d:o::x html \
  && setfacl -Rm g::rwx,d:g::rwx html

# startup script
RUN echo "#!/bin/bash\nfind /var/lib/mysql -type f -exec touch {} \;\nservice mysql start\napachectl -DFOREGROUND" >> /root/startup.sh  \
  && chmod a+x /root/startup.sh
ENTRYPOINT ["/root/startup.sh"]