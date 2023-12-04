#!/bin/bash

set -ex

mkdir -p /var/run/mysqld
chmod -R 777 /var/run/mysqld
kill -9 `pgrep -f mysqld` || true

# mysql init
( (
sleep 5s

if [ ! -f "/var/log/mysql_init.lock" ]; then
if [[ `pgrep -f mysqld` ]]; then

echo "Start to init mysql..."

mysql << EOF
use mysql;
update user set plugin='mysql_native_password' where user='root';
flush privileges;
update user set host='%' where user='root';
flush privileges;
exit
EOF

mysqladmin -u root password "123456"
touch /var/log/mysql_init.lock

fi
fi
) || true ) &

mysqld
