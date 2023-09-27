#!/bin/bash

set -e

if [ ! -f "/var/log/namenode_format.lock" ]; then
    touch /var/log/namenode_format.lock
    hdfs namenode -format
fi

