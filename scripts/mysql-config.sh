#!/bin/bash
set -e
[ $DEBUG ] && set -x

DB_NAME=${DATABASE:-$DB_NAME}
DB_USER=${USER:-$DB_USER}
DB_PASS=${PASS:-$DB_PASS}
mkdir -p /etc/mysql/conf.d

if [ "${DATA_DIR:0:1}" != "/" ]
then
    DATA_DIR="/project/$DATA_DIR"
fi
mkdir -p "$DATA_DIR"

MYSQL_DIR="$DATA_DIR/mysql"

if [ -f "/project/mysql.cnf" ];then
    cp -f "/project/mysql.cnf" /etc/mysql/conf.d/my.cnf
else
    echo "[mysqld]" > /etc/mysql/conf.d/my.cnf
    echo "bind-address=0.0.0.0" >> /etc/mysql/conf.d/my.cnf
    echo "user=mysql" >> /etc/mysql/conf.d/my.cnf
    if [ "$MYSQL_DIR" != "/var/lib/mysql" ];then
        echo "datadir=$MYSQL_DIR" >> /etc/mysql/conf.d/my.cnf
    fi
fi

cat /etc/mysql/conf.d/my.cnf

charset="/conf/mysqld-charset.cnf"
if [ -f "/project/mysqld-charset.cnf" ];then
    charset="/project/mysqld-charset.cnf"
fi
cp -f "$charset" /etc/mysql/mysqld_charset.cnf
mkdir -p /var/log/mysql

USERMAP_ORIG_UID=$(id -u mysql)
USERMAP_ORIG_GID=$(id -g mysql)
USERMAP_GID=${USERMAP_GID:-${USERMAP_UID:-$USERMAP_ORIG_GID}}
USERMAP_UID=${USERMAP_UID:-$USERMAP_ORIG_UID}
if [[ ${USERMAP_UID} != ${USERMAP_ORIG_UID} ]] || [[ ${USERMAP_GID} != ${USERMAP_ORIG_GID} ]]; then
    echo "Adapting uid and gid for mysql:mysql to $USERMAP_UID:$USERMAP_GID"
    sed -i -e "s/mysql:x:[0-9]*:/mysql:x:${USERMAP_GID}:/" /etc/group
    sed -i -e "s/:${USERMAP_ORIG_UID}:${USERMAP_ORIG_GID}:/:${USERMAP_UID}:${USERMAP_GID}:/" /etc/passwd
fi

chown -R mysql:mysql /etc/mysql
chown -R mysql:mysql $DATA_DIR || echo "Could not chown $DATA_DIR"
chmod -R 0700 $DATA_DIR || echo "Could not chmod $DATA_DIR"

mkdir -p /var/log/mysql
chown -R mysql:mysql /var/log/mysql || echo "Could not chown /var/log/mysql"
chmod -R 1775 /var/log/mysql || echo "Could not chmod /var/log/mysql"

mkdir -p /var/run/mysqld
chown -R mysql:mysql /var/run/mysqld || echo "Could not chown /var/run/mysqld"
chmod -R 0755 /var/run/mysqld || echo "Could not chmod /var/run/mysqld/*"
chmod g+s /var/run/mysqld || echo "Could not chmod /var/run/mysqld"

if [ ! -d $MYSQL_DIR ];then
    echo "=> An empty or uninitialized MySQL volume is detected in $MYSQL_DIR"
    echo "=> Configuring MySQL ..."
    mysql_install_db
    echo "=> Done!"
    # chown root:root $DATA_DIR
    # Bind to 127.0.0.1 else the outside world thinks it's ready
    sudo -Hu mysql /usr/bin/mysqld_safe --bind-address=127.0.0.1 --skip-syslog > /dev/null 2>&1 &

    # Time out in 1 minute
    LOOP_LIMIT=13
    for (( i=0 ; ; i++ )); do
        if [ ${i} -eq ${LOOP_LIMIT} ]; then
            echo "Time out. Error log is shown as below:"
            tail -n 100 ${LOG}
            exit 1
        fi
        echo "=> Waiting for confirmation of MySQL service startup, trying ${i}/${LOOP_LIMIT} ..."
        sleep 5
        sudo -Hu mysql mysql -uroot -e "status" > /dev/null 2>&1 && break
    done
    echo "=> Creating MySQL user $DB_USER with password: ${DB_PASS:0:8}..."
    sudo -Hu mysql mysql -uroot -e "CREATE USER '$DB_USER'@'%' IDENTIFIED BY '$DB_PASS'"
    sudo -Hu mysql mysql -uroot -e "GRANT ALL PRIVILEGES ON *.* TO '${DB_USER}'@'%' WITH GRANT OPTION"

    echo "=> Done!"

    echo "========================================================================"
    echo "You can now connect to this MySQL Server using:"
    echo ""
    echo "    mysql -u$DB_USER -p${DB_PASS:0:8}... -h<host> -P<port>"
    echo ""
    echo "MySQL user 'root' has no password but only allows local connections"
    echo "========================================================================"

    sudo -Hu mysql mysqladmin -uroot shutdown

    # Bind to 127.0.0.1 else the outside world thinks it's ready
    sudo -Hu mysql /usr/bin/mysqld_safe --bind-address=127.0.0.1 --skip-syslog > /dev/null 2>&1 &

    echo "=> Creating database $DB_NAME"
    RET=1
    while [[ RET -ne 0 ]]
    do
        sleep 5
        sudo -Hu mysql mysql -uroot -e "CREATE DATABASE \`$DB_NAME\`"
        RET=$?
    done

    sudo -Hu mysql mysqladmin -uroot shutdown

    echo "=> Done!"

    if [ $SQL_DUMP_FILE ]
    then
        if [ "${SQL_DUMP_FILE:0:1}" != "/" ]
        then
            SQL_DUMP_FILE="/project/$SQL_DUMP_FILE"
        fi

        if [ -f "$SQL_DUMP_FILE" ]
        then
            echo "=> Starting MySQL Server"
            # Bind to 127.0.0.1 else the outside world thinks it's ready
            /usr/bin/mysqld_safe --bind-address=127.0.0.1 --skip-syslog > /dev/null 2>&1 &
            sleep 5
            echo "   Started with PID $!"

            echo "=> Importing SQL file $SQL_DUMP_FILE. Get coffee, this can take a while..."
            sudo -Hu mysql mysql -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" < "$SQL_DUMP_FILE"
            echo "=> Stopping MySQL Server"
            sudo -Hu mysql mysqladmin -u"$DB_USER" -p"$DB_PASS" shutdown

            echo "=> Done!"
        else
            echo "=> ERROR: Import file not found: $SQL_DUMP_FILE"
        fi
    else
        echo "=> No file given to import"
    fi
else
    echo "=> Using an existing volume of MySQL"
fi

sleep 1