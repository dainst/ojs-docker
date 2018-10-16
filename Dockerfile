FROM php:7.2.11-apache-stretch

LABEL maintainer="Deutsches Archäologisches Institut: dev@dainst.org"
LABEL "author"="Dennis Twardy: kontakt@dennistwardy.com"
LABEL version="0.2"
LABEL description="DAI specific OJS3 Docker container with DAI specific plugins"

EXPOSE 80 433
USER root

ENV ADMIN_USER=admin
ENV ADMIN_PASSWORD="dummy@address.local"
ENV MYSQL_PASSWORD="ojs"
ENV MYSQL_DB="ojs"
ENV OJS_VERSION="ojs-stable-3_1_1"
ENV COMPOSER_ALLOW_SUPERUSER=1

# PHP settings
RUN echo "error_reporting=E_ALL & ~E_WARNING & ~E_NOTICE & ~E_STRICT & ~E_DEPRECATED"  >> /usr/local/etc/php/php.ini
RUN echo "date.timezone = Europe/Berlin"  >> /usr/local/etc/php/php.ini

# Update system and install essentials
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y upgrade 
RUN apt-get -y install git mysql-server nano curl cron supervisor unzip build-essential libssl-dev gnupg
RUN curl -sS https://getcomposer.org/installer | php
RUN curl -sL https://deb.nodesource.com/setup_10.x | bash -
RUN apt-get -y install nodejs

# Setup and run MySQL
#RUN docker-php-ext-install -j$(nproc) mysql && echo "mysql.default_socket=/run/mysqld/mysqld.sock" >> /usr/local/etc/php/php.ini
RUN echo "mysql.default_socket=/run/mysqld/mysqld.sock" >> /usr/local/etc/php/php.ini
RUN mkdir /run/mysqld
RUN find /var/lib/mysql -type f -exec touch {} \; && service mysql start
RUN sh -c "echo \"CREATE DATABASE ${MYSQL_DB};\" | mysql" && mysqladmin -u root password ${MYSQL_PASSWORD}

# configure git
RUN git config --global url.https://.insteadOf git://
RUN git config --global advice.detachedHead false

# Set working directory and create files folder
WORKDIR /var/www/html
RUN mkdir -p /var/www/html/files

# Get OJS3 code and prepare it
RUN git clone --depth 1 --single-branch --branch $OJS_VERSION https://github.com/pkp/ojs.git public
WORKDIR /var/www/html/public
RUN git submodule update --init --recursive >/dev/null

WORKDIR /var/www/html
RUN composer update -d public/lib/pkp --no-dev && composer install -d public/plugins/paymentmethod/paypal --no-dev && composer install -d public/plugins/generic/citationStyleLanguage --no-dev
WORKDIR /var/www/html/public
RUN npm install -y && npm run build
RUN cp config.TEMPLATE.inc.php config.inc.php
