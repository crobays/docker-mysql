#!/bin/bash
mkdir -p /etc/mysql/conf.d
mycnf="/conf/my.cnf"
if [ -f "/project/my.cnf" ]
then
	mycnf="/project/my.cnf"
fi
cp -f "$mycnf" /etc/mysql/conf.d/my.cnf

charset="/conf/mysqld-charset.cnf"
if [ -f "/project/mysqld-charset.cnf" ]
then
    charset="/project/mysqld-charset.cnf"
fi
cp -f "$charset" /etc/mysql/mysqld_charset.cnf

mkdir -p /var/log/mysql

VOLUME_HOME="/var/lib/mysql"

if [[ ! -d $VOLUME_HOME/mysql ]]
then
    echo "=> An empty or uninitialized MySQL volume is detected in $VOLUME_HOME"
    echo "=> Installing MySQL ..."
    mysql_install_db > /dev/null 2>&1
    echo "=> Done!"  
    
    /usr/bin/mysqld_safe > /dev/null 2>&1 &

    RET=1
    while [[ RET -ne 0 ]]
    do
        echo "=> Waiting for confirmation of MySQL service startup"
        sleep 5
        mysql -uroot -e "status" > /dev/null 2>&1
        RET=$?
    done

    if [ "$PASS" = "**Random**" ]
    then
        PASS="$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)"
    fi
    
    echo "=> Creating MySQL user $USER with password: $PASS"

    mysql -uroot -e "CREATE USER '$USER'@'%' IDENTIFIED BY '$PASS'"
    mysql -uroot -e "GRANT ALL PRIVILEGES ON *.* TO '${USER}'@'%' WITH GRANT OPTION"

    echo "=> Done!"

    echo "========================================================================"
    echo "You can now connect to this MySQL Server using:"
    echo ""
    echo "    mysql -u$USER -p$PASS -h<host> -P<port>"
    echo ""
    echo "Please remember to change the above password as soon as possible!"
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

    if [ $SQL_DUMP_FILE ] && [ -f "/project/$SQL_DUMP_FILE" ]
    then
        echo "=> Starting MySQL Server"
        /usr/bin/mysqld_safe > /dev/null 2>&1 &
        sleep 5
        echo "   Started with PID $!"

        echo "=> Importing SQL file"
        mysql -u"$USER" -p"$PASS" "$DATABASE" < "/project/$SQL_DUMP_FILE"

        echo "=> Stopping MySQL Server"
        mysqladmin -u"$USER" -p"$PASS" shutdown

        echo "=> Done!"

    fi
else
    echo "=> Using an existing volume of MySQL"
fi

