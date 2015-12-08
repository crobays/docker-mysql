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
    USERMAP_UID=501 \
    USERMAP_GID=501 \
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

CMD ["/sbin/my_init"]

# Clean up APT when done.
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN echo '/sbin/my_init' > /root/.bash_history

RUN mkdir -p /etc/service/mysql && echo "#!/bin/bash\nmysqld_safe --skip-syslog" > /etc/service/mysql/run

RUN mkdir /etc/my_init.d
ADD /conf /conf
ADD /scripts/my_init /sbin/my_init
RUN echo "#!/bin/bash\necho \"\$TIMEZONE\" > /etc/timezone && dpkg-reconfigure -f noninteractive tzdata" > /etc/my_init.d/01-timezone.sh
ADD /scripts/mysql-config.sh /etc/my_init.d/02-mysql-config.sh
RUN chmod +x /etc/my_init.d/* && chmod +x /etc/service/*/run && chmod +x /sbin/my_init
