set -ex

if  [ ! -n "$1" ] ; then
    image=sparrow-recsys:dev-hadoop3-latest
else
    image=$1
fi

if  [ ! -n "$2" ] ; then
    name="sparrow-recsys"
else
    name=$2
fi

if  [ ! -n "$3" ] ; then
    network="sparrow-recsys-network"
else
    network=$3
fi

# Use the host proxy as the default configuration, or specify a proxy_server
# no_proxy="localhost,127.0.0.1"
# proxy_server="" # your http proxy server
if [ "$proxy_server" != "" ]; then
    http_proxy=${proxy_server}
    https_proxy=${proxy_server}
fi

# export gpu_device=--gpus=all

docker network remove ${network} || true
docker network create ${network} || true

docker rm -f ${name} || true

docker run -td --rm \
    --privileged=true \
    --name=${name} \
    --hostname=${name} \
    --network-alias=${name} \
    --network=${network} \
    ${gpu_device} \
    -p 10081:80 \
    -p 13306:3306 \
    -p 18080:8080 \
    -p 18081:8081 \
    -p 18082:8082 \
    -p 18083:8083 \
    -p 18088:8088 \
    -p 19001:9001 \
    -p 19870:9870 \
    -v /dev:/dev \
    -v /home:/mnt/home \
    -e http_proxy=${http_proxy} \
    -e https_proxy=${https_proxy} \
    -e no_proxy=${no_proxy} \
    ${image}

# docker network inspect ${network}
# docker exec -it ${name} bash -c "ip addr"
docker logs ${name}
docker exec -it ${name} bash
