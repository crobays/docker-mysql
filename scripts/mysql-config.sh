#!/bin/bash

mkdir -p /etc/mysql/conf.d

if [ "${SQL_DATA_DIR:0:1}" != "/" ]
then
    SQL_DATA_DIR="/project/$SQL_DATA_DIR"
fi

if [ -f "/project/mysql.cnf" ]
then
    cp -f "/project/mysql.cnf" /etc/mysql/conf.d/my.cnf
else
    echo "[mysqld]" > /etc/mysql/conf.d/my.cnf
    echo "bind-address=0.0.0.0" >> /etc/mysql/conf.d/my.cnf
    if [ "$SQL_DATA_DIR" != "/var/lib/mysql" ]
    then
        echo "user=root" >> /etc/mysql/conf.d/my.cnf
        echo "datadir=$SQL_DATA_DIR" >> /etc/mysql/conf.d/my.cnf
    fi
fi
VOLUME_HOME="$SQL_DATA_DIR"
cat /etc/mysql/conf.d/my.cnf

charset="/conf/mysqld-charset.cnf"
if [ -f "/project/mysqld-charset.cnf" ]
then
    charset="/project/mysqld-charset.cnf"
fi
cp -f "$charset" /etc/mysql/mysqld_charset.cnf

mkdir -p /var/log/mysql

if [[ ! -d $SQL_DATA_DIR/mysql ]]
then
    echo "=> An empty or uninitialized MySQL volume is detected in $SQL_DATA_DIR"
    echo "=> Configuring MySQL ..."
    mysql_install_db > /dev/null 2>&1
    echo "=> Done!"
    # chown root:root $SQL_DATA_DIR
    /usr/bin/mysqld_safe > /dev/null 2>&1 &

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
        mysql -uroot -e "status" > /dev/null 2>&1 && break
    done

    echo "=> Creating MySQL user $USER with password: ${PASS:0:8}..."

    mysql -uroot -e "CREATE USER '$USER'@'%' IDENTIFIED BY '$PASS'"
    mysql -uroot -e "GRANT ALL PRIVILEGES ON *.* TO '${USER}'@'%' WITH GRANT OPTION"

    echo "=> Done!"

    echo "========================================================================"
    echo "You can now connect to this MySQL Server using:"
    echo ""
    echo "    mysql -u$USER -p${PASS:0:8}... -h<host> -P<port>"
    echo ""
    echo "MySQL user 'root' has no password but only allows local connections"
    echo "========================================================================"

    mysqladmin -uroot shutdown

    /usr/bin/mysqld_safe > /dev/null 2>&1 &

    echo "=> Creating database $DATABASE"
    RET=1
    while [[ RET -ne 0 ]]
    do
        sleep 5
        mysql -uroot -e "CREATE DATABASE \`$DATABASE\`"
        RET=$?
    done

    mysqladmin -uroot shutdown

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
            /usr/bin/mysqld_safe > /dev/null 2>&1 &
            sleep 5
            echo "   Started with PID $!"

            echo "=> Importing SQL file $SQL_DUMP_FILE. Get coffee, this can take a while..."
            mysql -u"$USER" -p"$PASS" "$DATABASE" < "$SQL_DUMP_FILE"

            echo "=> Stopping MySQL Server"
            mysqladmin -u"$USER" -p"$PASS" shutdown

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