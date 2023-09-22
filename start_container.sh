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
# export proxy_agent=sparrow-recsys-hadoop-namenode
# export proxy_agent_ip=127.0.0.1

docker run -td --rm \
    --name=${name} \
    --hostname=${name} \
    --network=hadoop \
    --privileged=true \
    --env-file=hadoop/.env \
    --add-host="${name}:127.0.0.1" \
    ${gpu_device} \
    -p 9870:9870 \
    -p 8020:8020 \
    -v /dev:/dev \
    -v /home:/mnt/home \
    -e http_proxy=${http_proxy} \
    -e https_proxy=${https_proxy} \
    -e no_proxy=${no_proxy} \
    ${image}
