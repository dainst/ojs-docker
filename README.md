# ojs3-docker

## Description

This repository offers a fully dockerized version of [PKP's](https://pkp.sfu.ca/) OJS 3 in addition to a set of DAI specific plugins. The repository offers easy to use shell scripts to help with handling Docker. By default all data will be encapsuled in Docker Volumes and can therefore be used in multiple instances of the container. OJS3 code will be fetched via github when building the image.

**This may take a couple of minutes on first startup.**

After the first startup, any container using the prepared volumes will start within seconds.

## Versions

The image is based on the official **php:7.3-apache** image.

The stack defined in the docker-compose file also adds a database container
based on the latest version of the official mariadb image.

**OJS 3.1.1** is tested and verified to run and is being cloned from the official [OJS](https://github.com/pkp/ojs) repository.

## Configuration

Configuration files can be found in the _conf folder_.

## Usage

Managing the image is done by docker-compose.

Build the image with

    docker-compose build

Start the container with

    docker-compose up

Stop the container by terminating the process (ctrl+C) or using

    docker-compose stop

Publish the image on dockerhub

    docker-compose publish

## License

Licensed under GPL-3.0. For further information see LICENSE.
