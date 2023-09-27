#!/bin/bash

if [ ! -f "/var/log/mysql_init.lock" ]; then
touch /var/log/mysql_init.lock

mysql << EOF
use mysql;
update user set plugin='mysql_native_password' where user='root';
flush privileges;
update user set host='%' where user='root';
flush privileges;
exit
EOF

mysqladmin -u root password "123456"

fi
