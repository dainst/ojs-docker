FROM php:7.3-apache

LABEL maintainer="Deutsches Archäologisches Institut: dev@dainst.org"
LABEL author="Dennis Twardy: kontakt@dennistwardy.com"
LABEL author="Simon Hohl: simon.hohl@dainst.de"
LABEL version="1.0"
LABEL description="DAI specific OJS3 Docker container with DAI specific plugins"
LABEL license="GNU GPL 3"

ENV DEBIAN_FRONTEND noninteractive

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
    xml \
    zip

RUN pecl install xdebug-2.8.1 \
    && docker-php-ext-enable xdebug

WORKDIR /tmp

RUN curl -sL https://deb.nodesource.com/setup_10.x | bash - \
    && apt-get -y install \
    nodejs
RUN curl -sS https://getcomposer.org/installer -o composer-setup.php \
    && php composer-setup.php --install-dir=/usr/local/bin --filename=composer --1

COPY php.ini "$PHP_INI_DIR/php.ini"
COPY apache.conf /etc/apache2/sites-available/000-default.conf

# initial file rights
WORKDIR /var
RUN chgrp -f -R www-data www && \
    chmod -R 771 www && \
    chmod g+s www

RUN a2enmod rewrite

RUN mkdir -p /data/files

RUN chown -R www-data:www-data /data

COPY ./docker-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["docker-entrypoint.sh"]

EXPOSE 80
