#!/bin/bash
set -e

docker_file=sparrow-recsys-dev.dockerfile
if [ "$1" != "" ]; then
    docker_file=$1
fi

image_name=sparrow-recsys:dev-hadoop3-latest
if [ "$2" != "" ]; then
    image_name=$2
fi

# Use the host proxy as the default configuration, or specify a proxy_server
# no_proxy="localhost,127.0.0.1"
# proxy_server="" # your http proxy server
if [ "$proxy_server" != "" ]; then
    http_proxy=${proxy_server}
    https_proxy=${proxy_server}
fi

DOCKER_BUILDKIT=0 docker build \
    -f ${docker_file} \
    -t ${image_name} \
    --build-arg http_proxy=${http_proxy} \
    --build-arg https_proxy=${https_proxy} \
    --build-arg no_proxy=${no_proxy} \
    .
