# ojs3_dainst-docker

## Description

This repository offers a fully dockerized version of [PKP's](https://pkp.sfu.ca/) OJS 3 in addition to a set of DAI specific plugins. The repository offers easy to use shell scripts to help with handling Docker. By default all data will be encapsuled in Docker Volumes and can therefore be used in multiple instances of the container. OJS3 code will be fetched via github during first start of the build image.

**This may take a couple of minutes on first startup.**

After the first startup, any container using the prepared volumes will start within seconds.

## Versions

The image is based on the official **debian:9.5-slim** image.
The following packages are installed via official repositories:
- PHP 7.2
- MariaDB 10.3
- Apache 2.4.25

**OJS 3.1.1** is tested and verified to run and is being cloned from the official [OJS](https://github.com/pkp/ojs) repository.

## Configuration

Configuration files can be found in the _conf folder_. The image is setup to expose Port 443 for https communication. HTTPS is only available if the _ojs-ssl-site.conf_ configuration file is setup. **Remember** to replace apache.crt and apache.key files in _ssl folder_ with individually generated files matching your domain!

For further configuration of apache2 in general use _ojs-apache.conf_. _ojs-site.conf_ and _ojs-ssl-site.conf_ configure the site configurations. _php.ini_ is being copied into the image during build. Adjust configuration as needed.

## Logging

All logs by default routed to _/dev/stdout_ and _/dev/stderr_. To inspect live use `docker logs -f [container name]`. The run script _crun.sh_ set the container to use Docker's _json-file_ logging driver. Logging driver is setup to cycle through 3 files of each up to 10MB. Use appropriate tools like [jq](https://stedolan.github.io/jq/) to inspect json logs in terminal. Log files are by default saved in _/var/lib/docker/containers/[container id]/[container id]-json.log_. Older logs are enumerated with a suffix: _-json.log.1_ and _-json.log.2_. For an easy, human readable printout with jq use: `cat *-json.log | jq '.'`.

**Note:** Depending on your system you might need root rights to open the folder and/or read/cat the logs.

## Usage

Managing the image is done by docker-compose.

Build the image with
    docker-compose build

Start the container with
    docker-compose up

Stop the container by terminating the process (ctrl+C) or using
    docker-compose stop

## License

Licensed under GPL-3.0. For further information see LICENSE.
