#!/bin/bash
set -ex

# docker run -itd --rm --name sparrow-recsys-mysql -p 3306:3306 -e MYSQL_ROOT_PASSWORD=123456 mysql:8.0-debian

docker network create hadoop || true

# docker rm -f sparrow-recsys-dev

# container_name=sparrow-recsys-dev
# docker run -td --rm \
#     --privileged=true \
#     --network=hadoop \
#     --name=${container_name} \
#     --network-alias=${container_name} \
#     -p 9870:9870 \
#     -p 8020:8020 \
#     -p 9864:9864 \
#     -v /dev:/dev \
#     -v /home:/mnt/home \
#     sparrow-recsys:dev-latest

docker rm -f sparrow-recsys-dev

container_name=sparrow-recsys-dev
docker run -td --rm \
    --privileged=true \
    --network=hadoop \
    --name=${container_name} \
    --network-alias=${container_name} \
    -e http_proxy=${http_proxy} \
    -e https_proxy=${https_proxy} \
    -e no_proxy=${no_proxy} \
    -p 19001:9001 \
    -p 19870:9870 \
    -p 18088:8088 \
    -p 13307:3306 \
    -v /dev:/dev \
    -v /home:/mnt/home \
    -v `pwd`/supervisor:/etc/supervisor \
    sparrow-recsys:dev-latest

docker network inspect hadoop
docker exec -it ${container_name} bash -c "ip addr"
docker logs ${container_name}
docker exec -it ${container_name} bash
