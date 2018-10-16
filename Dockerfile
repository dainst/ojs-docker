FROM php:7.2.11-stretch

LABEL maintainer="Deutsches Archäologisches Institut: dev@dainst.org"
LABEL "author"="Dennis Twardy: kontakt@dennistwardy.com"
LABEL version="0.1"
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
RUN apt-get -y install git mysql-server nano curl nodejs dcron supervisor

# Set working directory
WORKDIR /var/www/html

# Get OJS3 code
RUN git clone -b ${OJS_VERSION} https://github.com/pkp/ojs.git public
