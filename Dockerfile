FROM php:7.3-apache

LABEL maintainer="Deutsches Archäologisches Institut: dev@dainst.org"
LABEL author="Dennis Twardy: kontakt@dennistwardy.com"
LABEL version="1.0"
LABEL description="DAI specific OJS3 Docker container with DAI specific plugins"
LABEL license="GNU GPL 3"

ENV DEBIAN_FRONTEND noninteractive
ENV OJS_PORT="8000"

RUN apt-get update && apt-get -y install \
    default-mysql-client \
    git \
    expect \
    libbz2-dev \
    libcurl3-dev \
    libicu-dev \
    libedit-dev \
    libxml2-dev \
    zlib1g-dev \
    libzip-dev

RUN docker-php-ext-install \
    bcmath \
    bz2 \
    curl \
    dba \
    intl \
    json \
    mbstring \
    mysqli \
    readline \
    xml \
    zip

WORKDIR /tmp

RUN curl -sL https://deb.nodesource.com/setup_10.x | bash - \
    && apt-get -y install \
    nodejs
RUN curl -sS https://getcomposer.org/installer -o composer-setup.php \
    && php composer-setup.php --install-dir=/usr/local/bin --filename=composer

# Use the default production configuration
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

# Add OJS installation scripts and change permissions
COPY scripts/ojsInstall.exp /root/ojsInstall.exp
RUN chmod +x /root/ojsInstall.exp

### Install OJS ###
RUN mkdir -p /var/www/ojsfiles
WORKDIR /var/www/html

ARG OJS_BRANCH
RUN git clone https://github.com/pkp/ojs.git -b ${OJS_BRANCH} .
RUN git submodule update --init --recursive

# php modules
RUN composer install -v -d lib/pkp --no-dev
RUN composer install -v -d plugins/paymethod/paypal --no-dev
RUN composer install -v -d plugins/generic/citationStyleLanguage --no-dev

# js modules
RUN npm install -y
RUN npm run build

# initial file rights
WORKDIR /var
RUN chgrp -f -R www-data www && \
    chmod -R 771 www && \
    chmod g+s www

WORKDIR /var/www/html/plugins/importexport
RUN git clone https://github.com/pkp/quickSubmit -b v1.0.4-1

RUN a2enmod rewrite

COPY conf/config.TEMPLATE.inc.php  /var/www/html/config.TEMPLATE.inc.php
ARG MYSQL_PASSWORD
RUN sed -i "s|password = ojs|password = $MYSQL_PASSWORD|g" /var/www/html/config.TEMPLATE.inc.php 

COPY ./docker-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["docker-entrypoint.sh"]

EXPOSE 80
