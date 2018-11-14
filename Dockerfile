FROM debian:9.5-slim
# FROM debian:9.5

LABEL maintainer="Deutsches Archäologisches Institut: dev@dainst.org"
LABEL "author"="Dennis Twardy: kontakt@dennistwardy.com"
LABEL version="0.5"
LABEL description="DAI specific OJS3 Docker container with DAI specific plugins"
LABEL "license"="GNU GPL 3"

EXPOSE 80 443
USER root

ENV ADMIN_USER="admin"
ENV ADMIN_PASSWORD="password"
ENV ADMIN_EMAIL="dummy@address.local"
ENV MYSQL_USER="ojs"
ENV MYSQL_PASSWORD="ojs"
ENV MYSQL_DB="ojs"
ENV OJS_BRANCH="ojs-stable-3_1_1"
ENV COMPOSER_ALLOW_SUPERUSER=1

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    apt-transport-https \
    bash-completion \
    ca-certificates \
    curl \
    dirmngr \
    gnupg2 \
    openssl \
    software-properties-common \
    wget  

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    apache2 
RUN /etc/init.d/apache2 start \
    && service apache2 status

RUN apt-key adv --no-tty --recv-keys --keyserver keyserver.ubuntu.com 0xF1656F24C74CD1D8
RUN add-apt-repository 'deb [arch=amd64,i386,ppc64el] http://mirrors.dotsrc.org/mariadb/repo/10.3/debian stretch main'
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    mariadb-server
RUN service mysql start \
    && service mysql status

# Install PHP7.2 packages and restart Apache
RUN wget -q -O- https://packages.sury.org/php/apt.gpg | apt-key add -
RUN echo "deb https://packages.sury.org/php/ stretch main" | tee /etc/apt/sources.list.d/php.list
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    libapache2-mod-php \
    php7.2 \
    php7.2-bcmath \
    php7.2-bz2 \
    php7.2-cgi \
    php7.2-cli \
    php7.2-common \
    php7.2-curl \
    php7.2-dba \
    php7.2-intl \
    php7.2-json \
    php7.2-mbstring \
    php7.2-mysql \
    php7.2-readline \
    php7.2-xml \
    php7.2-zip
RUN /etc/init.d/apache2 restart

WORKDIR /tmp

# Adding configuration files
ADD conf/php.ini /usr/local/etc/php/
ADD conf/ojs-apache.conf /etc/apache2/conf-available
ADD conf/ojs-ssl-site.conf /etc/apache2/sites-available
ADD conf/ojs-site.conf /etc/apache2/sites-available

# Adding SSL keys and protect them
ADD ssl/apache.crt /etc/apache2/ssl
ADD ssl/apache.key /etc/apache2/ssl
RUN chmod 600 -R /etc/apache2/ssl

# Update system and install essentials
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get -y install \
    acl \
    build-essential \
    cron \
    exiftool \
    expect \
    git \
    imagemagick \
    libssl-dev \ 
    nano \
    pdftk \
    supervisor \
    unzip 

RUN curl -sL https://deb.nodesource.com/setup_10.x | bash - \
    && DEBIAN_FRONTEND=noninteractiv apt-get -y install \
    nodejs

RUN curl -sS https://getcomposer.org/installer -o composer-setup.php \
    && php composer-setup.php --install-dir=/usr/local/bin --filename=composer

# Configure Apache
RUN a2enconf ojs-apache \
    && a2enmod rewrite \
    && a2ensite ojs-site 
RUN echo "#!/bin/sh\nif [ -s /etc/apache2/sites-available/ojs-ssl-site.conf ]; then\na2enmod ssl\na2ensite ojs-ssl-site.conf\nfi"

# configure git
RUN git config --global url.https://.insteadOf git://
RUN git config --global advice.detachedHead false

# create files folder
RUN mkdir -p /var/www/ojsfiles

# Get OJS3 code and prepare it
WORKDIR /var/www/html
RUN git init \
    && git remote add -t $OJS_BRANCH origin https://github.com/pkp/ojs.git \
    && git fetch origin --depth 1 $OJS_BRANCH \
    && git checkout --track origin/$OJS_BRANCH
RUN git submodule update --init --recursive >/dev/null
RUN composer install -v -d lib/pkp --no-dev \
    && composer install -v -d plugins/paymethod/paypal --no-dev \
    && composer install -v -d plugins/generic/citationStyleLanguage --no-dev
RUN npm install -y \
    && npm run build
RUN cp config.TEMPLATE.inc.php config.inc.php

# Fix access rights, set ACL and make everything accessible for www-data group
WORKDIR /var/www
RUN chgrp -f -R www-data html \
    && chmod -R 771 html \
    && chmod g+s html \
    && setfacl -Rm o::x,d:o::x html \
    && setfacl -Rm g::rwx,d:g::rwx html \
    && chgrp -f -R www-data ojsfiles \
    && chmod -R 771 ojsfiles \
    && chmod g+s ojsfiles \
    && setfacl -Rm o::x,d:o::x ojsfiles \
    && setfacl -Rm g::rwx,d:g::rwx ojsfiles

RUN echo "mysql.default_socket=./run/mysqld/mysqld.sock" >> /etc/php/7.2/apache2/php.ini \
    && echo "mysql.default_socket=./run/mysqld/mysqld.sock" >> /etc/php/7.2/cli/php.ini
RUN /etc/init.d/mysql start \
    && service mysql status \
    && sh -c "echo \"CREATE USER '${MYSQL_USER}'@'localhost' IDENTIFIED BY '${MYSQL_PASSWORD}';\" | mysql -u root" \
    && sh -c "echo \"UPDATE mysql.user SET plugin = 'mysql_native_password' WHERE User='${MYSQL_USER}'; FLUSH PRIVILEGES;\" | mysql -u root" \
    && sh -c "echo \"CREATE DATABASE ${MYSQL_DB};\" | mysql -u root" \ 
    && sh -c "echo \"GRANT ALL PRIVILEGES on ${MYSQL_DB}.* TO '${MYSQL_USER}'@'localhost'; FLUSH PRIVILEGES;\" | mysql -u root"

# Run OJS Installation Script
ADD scripts/ojsInstall.exp /tmp/ojsInstall.exp
RUN chmod +x /tmp/ojsInstall.exp
RUN /etc/init.d/mysql start \
    && expect /tmp/ojsInstall.exp

# Install DAI Plugin
WORKDIR /var/www/html/plugins
RUN git clone https://github.com/dainst/ojs-cilantro-plugin.git generic/ojs-cilantro-plugin
RUN git clone https://github.com/dainst/ojs-dainst-frontpage-generator-plugin.git generic/ojs-dainst-frontpage-generator-plugin
RUN git clone https://github.com/dainst/ojs-dainst-zenonlink-plugin.git pubIds/zenon
RUN git clone https://github.com/dainst/epicur.git oaiMetadataFormats/epicur
RUN git submodule update --init --recursive
RUN mkdir /var/www/tmp \
    && chgrp -f -R www-data /var/www/tmp \
    && chmod -R 771 /var/www/tmp \
    && chmod g+s /var/www/tmp \
    && setfacl -Rm o::x,d:o::x /var/www/tmp \
    && setfacl -Rm g::rwx,d:g::rwx /var/www/tmp
RUN echo "[dainst]\ntmpPath = /var/www/tmp" >> /var/www/html/config.inc.php

# startup script
ADD scripts/dockerEntry.sh /root/startup.sh
RUN chmod a+x /root/startup.sh
ENTRYPOINT ["/root/startup.sh"]