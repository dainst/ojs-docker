FROM debian:9.5-slim

LABEL maintainer="Deutsches Archäologisches Institut: dev@dainst.org"
LABEL "author"="Dennis Twardy: kontakt@dennistwardy.com"
LABEL version="1.0"
LABEL description="DAI specific OJS3 Docker container with DAI specific plugins"
LABEL "license"="GNU GPL 3"

ENV DEBIAN_FRONTEND noninteractive
ENV OJS_PORT="8000"


# Installing software packages
RUN apt-get update && apt-get install -y \
    apt-transport-https \
    bash-completion \
    ca-certificates \
    curl \
    dirmngr \
    gnupg2 \
    openssl \
    software-properties-common \
    wget \
    apache2

# Adding MariaDB repo and installing MariaDB 10.3
RUN apt-key adv --no-tty --recv-keys --keyserver keyserver.ubuntu.com 0xF1656F24C74CD1D8
RUN add-apt-repository 'deb [arch=amd64,i386,ppc64el] http://mirrors.dotsrc.org/mariadb/repo/10.3/debian stretch main'
RUN apt-get update && apt-get install -y mariadb-server

# Adding repo and installing PHP7.2 packages 
RUN wget -q -O- https://packages.sury.org/php/apt.gpg | apt-key add -
RUN echo "deb https://packages.sury.org/php/ stretch main" | tee /etc/apt/sources.list.d/php.list
RUN apt-get update && apt-get install -y \
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

WORKDIR /tmp

# Update apt caches and install essentials
RUN apt-get update && apt-get -y install \
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
    && apt-get -y install \
    nodejs
RUN curl -sS https://getcomposer.org/installer -o composer-setup.php \
    && php composer-setup.php --install-dir=/usr/local/bin --filename=composer

# Configure Apache
# Adding configuration files
COPY conf/php.ini /etc/php/7.2/apache2/
COPY conf/php.ini /etc/php/7.2/cli/
COPY conf/ojs-apache.conf /etc/apache2/conf-available
COPY conf/ojs-ssl-site.conf /etc/apache2/sites-available
COPY conf/ojs-site.conf /etc/apache2/sites-available
COPY conf/.htpasswd /etc/apache2/

# Ports
RUN sed -i "s/^Listen 80.*\$/Listen $OJS_PORT/" /etc/apache2/ports.conf
RUN sed -i "s/^<VirtualHost \*:80>.*\$/<VirtualHost \*:$OJS_PORT>/" /etc/apache2/sites-available/ojs-site.conf

# Adding SSL keys and set access rights them
COPY ssl/apache.crt /etc/apache2/ssl
COPY ssl/apache.key /etc/apache2/ssl
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
COPY scripts/ojsInstall.exp /root/ojsInstall.exp
RUN chmod +x /root/ojsInstall.exp

# Entrypoint
COPY ./docker-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["docker-entrypoint.sh"]

EXPOSE $OJS_PORT 443 3306 33060

#CMD ["mysqld"]
