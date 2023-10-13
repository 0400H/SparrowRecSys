
```
docker pull mysql:8.0-debian

docker run -itd --rm --name sparrow-recsys-mysql -p 3306:3306 -e MYSQL_ROOT_PASSWORD=123456 mysql:8.0-debian

python3 -u db.py

docker exec -it sparrow-recsys-hadoop-namenode bash
```

