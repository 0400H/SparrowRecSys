#!/bin/bash

set -ex

mkdir -p /var/run/mysqld
chmod -R 777 /var/run/mysqld
kill -9 `pgrep -f mysqld` || true
rm -rf /var/log/mysql/error.log || true

( (
# check mysql start status
while [ true ]
do
    echo "Waiting for MySQL start..."
    if [ -f "/var/log/mysql/error.log" ]; then
        if [ "`cat /var/log/mysql/error.log | grep '/usr/sbin/mysqld: ready for connections'`" != "" ]; then
            break
        fi
    fi
    sleep 5s
done

# start to init mysql
echo "Start to init MySQL..."

mysql << EOF
use mysql;
update user set plugin='mysql_native_password' where user='root';
flush privileges;
update user set host='%' where user='root';
flush privileges;
exit
EOF

mysqladmin -u root password "123456"

) || true ) &

mysqld
