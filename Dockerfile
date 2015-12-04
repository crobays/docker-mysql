FROM ubuntu:trusty
ENV HOME /root

MAINTAINER Crobays <crobays@userex.nl>
ENV DOCKER_NAME mysql
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update
RUN apt-get -y dist-upgrade

RUN apt-get -y install mysql-server pwgen

# Remove pre-installed database
RUN rm -rf /var/lib/mysql/*

# Exposed ENV
ENV TIMEZONE=Etc/UTC \
    ENVIRONMENT=prod \
    DB_USER=admin \
    DB_PASS=secret \
    DB_NAME=default \
    SQL_DUMP_FILE=mysql-auto-import.sql \
    DATA_DIR=data

# Add VOLUMEs to allow backup of config and databases
VOLUME  ["/project"]
WORKDIR /project

# MySQL port
EXPOSE 3306

RUN echo '/sbin/my_init' > /root/.bash_history

ADD /conf /conf

RUN mkdir -p /etc/service/mysql && echo "#!/bin/bash\nmysqld_safe" > /etc/service/mysql/run

RUN mkdir /etc/my_init.d
RUN echo "#!/bin/bash\necho \"\$TIMEZONE\" > /etc/timezone && dpkg-reconfigure -f noninteractive tzdata" > /etc/my_init.d/01-timezone.sh
ADD /scripts/mysql-config.sh /etc/my_init.d/02-mysql-config.sh
ADD /scripts/my_init /sbin/my_init

RUN chmod +x /etc/my_init.d/* && chmod +x /etc/service/*/run && chmod +x /sbin/my_init

CMD ["/sbin/my_init"]

# Clean up APT when done.
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# docker build \
#   -t crobays/mysql \
#   /workspace/docker/crobays/mysql && \
# docker run \
# --name mysql \
# -p 3306:3306 \
# -v /workspace/projects/userx/crane-userx-nl:/project \
# -e ENVIRONMENT=dev \
# -e TIMEZONE=Europe/Amsterdam \
# -it --rm \
# crobays/mysql bash

# /etc/my_init.d/01-timezone.sh ;/etc/my_init.d/02-conf-log.sh ;/etc/my_init.d/03-mysql-config.sh

