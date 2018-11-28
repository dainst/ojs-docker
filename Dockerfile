FROM debian:9.5-slim

LABEL maintainer="Deutsches Archäologisches Institut: dev@dainst.org"
LABEL "author"="Dennis Twardy: kontakt@dennistwardy.com"
LABEL version="1.0"
LABEL description="DAI specific OJS3 Docker container with DAI specific plugins"
LABEL "license"="GNU GPL 3"

EXPOSE 8000 443
USER root

# Setting default values for buildtime arguments
ARG b_ADMIN_USER="admin"
ARG b_ADMIN_PASSWORD="password"
ARG b_ADMIN_EMAIL="dummy@address.local"
ARG b_MYSQL_USER="ojs"
ARG b_MYSQL_PASSWORD="ojs"
ARG b_MYSQL_DB="ojs"
ARG b_OJS_BRANCH="ojs-stable-3_1_1"

# Sett environment variables to buildtime arguments by default
ENV ADMIN_USER=$b_ADMIN_USER
ENV ADMIN_PASSWORD=$b_ADMIN_PASSWORD
ENV ADMIN_EMAIL=$b_ADMIN_EMAIL
ENV MYSQL_USER=$b_MYSQL_USER
ENV MYSQL_PASSWORD=$b_MYSQL_PASSWORD
ENV MYSQL_DB=$b_MYSQL_DB
ENV OJS_BRANCH=$b_OJS_BRANCH
ENV COMPOSER_ALLOW_SUPERUSER=1

# Installing software packages
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

# Installing Apache2 and starting the service for test purposes    
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    apache2 
RUN /etc/init.d/apache2 start \
    && service apache2 status

# Adding MariaDB repo and installing MariaDB 10.3
RUN apt-key adv --no-tty --recv-keys --keyserver keyserver.ubuntu.com 0xF1656F24C74CD1D8
RUN add-apt-repository 'deb [arch=amd64,i386,ppc64el] http://mirrors.dotsrc.org/mariadb/repo/10.3/debian stretch main'
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    mariadb-server
RUN service mysql start \
    && service mysql status

# Adding repo and installing PHP7.2 packages 
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

# Update apt caches and install essentials
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
# Adding configuration files
ADD conf/php.ini /etc/php/7.2/apache2/
ADD conf/php.ini /etc/php/7.2/cli/
ADD conf/ojs-apache.conf /etc/apache2/conf-available
ADD conf/ojs-ssl-site.conf /etc/apache2/sites-available
ADD conf/ojs-site.conf /etc/apache2/sites-available

# Adding SSL keys and set access rights them
ADD ssl/apache.crt /etc/apache2/ssl
ADD ssl/apache.key /etc/apache2/ssl
RUN chmod 600 -R /etc/apache2/ssl 

RUN a2ensite ojs-site \
    && a2dissite 000-default \
    && a2enmod rewrite
RUN echo "#!/bin/sh\nif [ -s /etc/apache2/sites-available/ojs-ssl-site.conf ]; then\na2enmod ssl\na2ensite ojs-ssl-site.conf\nfi"
RUN ln -sf /dev/stdout /var/log/apache2/access.log \
    && ln -sf /dev/stderr /var/log/apache2/error.log

# configure git for Entrypoint script
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
ENTRYPOINT exec /root/dockerEntry.sh -b ${OJS_BRANCH} -a ${ADMIN_PASSWORD} -m ${ADMIN_EMAIL} -u ${MYSQL_USER} -p ${MYSQL_PASSWORD} -n ${MYSQL_DB}