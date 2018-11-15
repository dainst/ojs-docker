# ojs3_dainst-docker

## Description

This repository offers a fully dockerized version of https://pkp.sfu.ca/ OJS 3 in addition to a set of DAI specific plugins. The repository offers easy to use shell scripts to help with handling Docker. By default all data will be encapsuled in Docker Volumes and can therefore be used in multiple instances of the container. OJS3 code will be fetched via github during first start of the build image.

**This may take a couple of minutes on first startup.**

After the first startup, any container using the prepared volumes will start within seconds.

## Versions

The image is based on the official **debian:9.5-slim** image. **PHP 7.2** is manually installed via the official repositories. **MariaDB 10.3** is being installed via official repositories. **Apache 2.4.25** is being installed via the official repositories. **OJS 3.1.1** is tested and verified to run and is being cloned from the official https://github.com/pkp/ojs repository.

## Configuration

Configuration files can be found in the _conf folder_. The image is setup to expose Port 443 for https communication. HTTPS is only available if the _ojs-ssl-site.conf_ configuration file is setup. **Remember** to replace apache.crt and apache.key files in _ssl folder_ with individually generated files matching your domain!

For further configuration of apache2 in general use _ojs-apache.conf_. _ojs-site.conf_ and _ojs-ssl-site.conf_ configure the site configurations. _php.ini_ is being copied into the image during build. Adjust configuration as needed.

## Logging

## Usage

Available scripts are _cbuild.sh_, _crun.sh_, _cstart.sh_ and _cstop.sh_. All scripts use **/bin/sh** and are therefore compatible with all POSIX-compatible OS.

### cbuild

`sh cbuild.sh [-d dockerID] [-n name] [-v version]`

**Description**
Builds the image from Dockerfile. If no parameters are given, default values are being used.

**Defaults:**

- dockerID: _dainst_
- name: _ojs3_
- version: _1.0_

### crun

`sh crun.sh [-d DockerID] [-n name] [-v version] [-m mysql volume] [-a app volume] [-f files volume] [-c container name] [-s ssl port mapping] [-h http port mapping] [-aP adminPassword] [-aM adminMail] [-dU mysqlUser] [-dP mysqlPassword] [-dN mysqlDBName]`

**Description**
Runs the container based on the built image. If no parameters are given, default values are being used. It is **highly advised** to specify a different password! Adjust port mappings as suited.

**Defaults:**

- dockerID: _dainst_
- name: _ojs3_
- version: _1.0_
- mysql volume: _ojsdb_
- app volume: _ojsapp_
- files volume: _ojsfiles_
- container name: _ojs3_
- ssl port mapping: _8888_
- http port mapping: _8080_
- adminPassword:
- adminMail:
- mysqlUser:
- mysqlPassword:
- mysqlDBName:

### cstart

`sh cstart.sh [-c container name]`

**Description**
Starts the existing container. If no parameter is specified, default value is being used.

**Defaults:**

- container name: _ojs3_

### cstop

`sh cstop.sh [-c container name]`

**Description**
Stops the container if neccessary. If no parameter is specified, default value is being used.

**Defaults:**

- container name: _ojs3_
