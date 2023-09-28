set -ex

if  [ ! -n "$1" ] ; then
    image=sparrow-recsys:dev-latest
else
    image=$1
fi

if  [ ! -n "$2" ] ; then
    name="sparrow-recsys-dev"
else
    name=$2
fi

# Use the host proxy as the default configuration, or specify a proxy_server
# no_proxy="localhost,127.0.0.1"
# proxy_server="" # your http proxy server
if [ "$proxy_server" != "" ]; then
    http_proxy=${proxy_server}
    https_proxy=${proxy_server}
fi

# export gpu_device=--gpus=all

docker network create hadoop || true

docker rm -f sparrow-recsys-dev

container_name=sparrow-recsys-dev
docker run -td --rm \
    --privileged=true \
    --network=hadoop \
    --name=${name} \
    --hostname=${name} \
    --network-alias=${name} \
    ${gpu_device} \
    -p 13307:3306 \
    -p 18080:8080 \
    -p 18081:8081 \
    -p 18088:8088 \
    -p 19001:9001 \
    -p 19870:9870 \
    -v /dev:/dev \
    -v /home:/mnt/home \
    -v `pwd`/supervisor:/etc/supervisor \
    -e http_proxy=${http_proxy} \
    -e https_proxy=${https_proxy} \
    -e no_proxy=${no_proxy} \
    ${image}

docker network inspect hadoop
docker exec -it ${name} bash -c "ip addr"
docker logs ${name}
docker exec -it ${name} bash
