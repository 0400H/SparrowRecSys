
Port:

|Port|Note|
|--|--|
|80|Sparrow RecSys WebUI|
|3306|MySQL Server|
|8080|Spark Master WebUI|
|8081|Spark Worker WebUI|
|8082|Flink WebUI|
|8083|ZooKeeper WebUI|
|8088|YARN ResourceManager WebUI|
|9001|Supervisor WebUI|
|9870|HDFS WebUI|

Start:

```shell
./start_container.sh

# export WORK_DIR=/mnt/home/0400h/github/SparrowRecSys

cd $WORK_DIR


# test tf-serving with W&D model
curl -X POST \
  http://ip_of_your_host:18501/v1/models/sparrow_recsys_widedeep:predict \
  -H 'cache-control: no-cache' \
  -H 'content-type: application/json' \
  -d '{
    "instances":
    [
        {
            "movieGenre2": "",
            "userAvgRating": 4,
            "movieGenre1": "Drama",
            "movieRatingStddev": 0.89,
            "userRatingStddev": 1.1,
            "userGenre4": "War",
            "movieId": 501,
            "userGenre5": "Drama",
            "userGenre2": "Adventure",
            "userId": 55,
            "userGenre3": "Romance",
            "userGenre1": "Action",
            "movieAvgRating": 3.6,
            "userRatedMovie1": 858,
            "movieRatingCount": 5,
            "userRatingCount": 6,
            "releaseYear": 1993,
            "movieGenre3": ""
        }
    ]
}'

# Add new movie
curl --location --request POST 'http://localhost:80/createmovie' \
    --header 'Content-Type: application/x-www-form-urlencoded' \
    --data-urlencode 'title=Test Movile (2022)' \
    --data-urlencode 'genres=1,5'

# Add new rating
curl --location --request POST 'http://localhost:80/createrating' \
    --header 'Content-Type: application/x-www-form-urlencoded' \
    --data-urlencode 'userId=888' \
    --data-urlencode 'movieId=1001' \
    --data-urlencode 'rating=4.8'

(
    cd $WORK_DIR/src/main/java/com/sparrowrecsys

    # flink run -p 2 -c com.sparrowrecsys.nearline.flink.NewMovieHandler $WORK_DIR/target/SparrowRecSys-1.0-SNAPSHOT-jar-with-dependencies.jar &

    # flink run -p 2 -c com.sparrowrecsys.nearline.flink.NewRatingHandler $WORK_DIR/target/SparrowRecSys-1.0-SNAPSHOT-jar-with-dependencies.jar &

    # flink run -p 2 -c com.sparrowrecsys.nearline.flink.RealTimeFeature $WORK_DIR/target/SparrowRecSys-1.0-SNAPSHOT-jar-with-dependencies.jar &
)

```
