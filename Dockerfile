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

# Configure PHP to work with MySQL
RUN echo "mysql.default_socket=./run/mysqld/mysqld.sock" >> /etc/php/7.2/apache2/php.ini \
    && echo "mysql.default_socket=./run/mysqld/mysqld.sock" >> /etc/php/7.2/cli/php.ini

# configure git
RUN git config --global url.https://.insteadOf git://
RUN git config --global advice.detachedHead false

# Adding OJS installation scripts and changing permissions
ADD scripts/dockerEntry.sh /root/dockerEntry.sh
ADD scripts/ojsInstall.exp /root/ojsInstall.exp
ADD scripts/ojsInit.sh /root/ojsInit.sh
ADD scripts/dainstInit.sh /root/dainstInit.sh
RUN chmod +x /root/ojsInstall.exp \
    && chmod +x /root/ojsInit.sh \
    && chmod +x /root/dainstInit.sh \
    && chmod +x /root/dockerEntry.sh

# Entrypoint
ENTRYPOINT ["/root/dockerEntry.sh"]