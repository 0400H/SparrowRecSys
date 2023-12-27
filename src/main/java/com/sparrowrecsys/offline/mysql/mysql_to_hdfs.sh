set -ex

# upload data from mysql to hdfs.

MYSQL_HOST=127.0.0.1
MYSQL_PORT=3306
MYSQL_USER=root
MYSQL_PASSWD=123456
MYSQL_DB=sparrow_recsys
HDFS_SERVER=localhost:8020

mysql -h${MYSQL_HOST} -P${MYSQL_PORT} -u${MYSQL_USER} -p${MYSQL_PASSWD} -D${MYSQL_DB} -e "select * from movies" -N  > movies.csv
mysql -h${MYSQL_HOST} -P${MYSQL_PORT} -u${MYSQL_USER} -p${MYSQL_PASSWD} -D${MYSQL_DB} -e "select * from ratings" -N  > ratings.csv

movie_count=`cat movies.csv | wc -l`
rating_count=`cat ratings.csv | wc -l`

echo 'movie_count' $movie_count
echo 'rating_count' $rating_count

if  [ "100" -gt "$movie_count" ]; then
    echo "invalid movies data from mysql."
    exit 1
fi

if  [ "100" -gt "$rating_count" ]; then
    echo "invalid ratings data from mysql."
    exit 1
fi

hdfs dfs -rm -r hdfs://${HDFS_SERVER}/sparrow_recsys/movies/* || true
hdfs dfs -rm -r hdfs://${HDFS_SERVER}/sparrow_recsys/ratings/* || true

hdfs dfs -mkdir -p hdfs://${HDFS_SERVER}/sparrow_recsys/movies/0000
hdfs dfs -mkdir -p hdfs://${HDFS_SERVER}/sparrow_recsys/ratings/0000

hdfs dfs -put movies.csv hdfs://${HDFS_SERVER}/sparrow_recsys/movies/0000/part-0
hdfs dfs -put ratings.csv hdfs://${HDFS_SERVER}/sparrow_recsys/ratings/0000/part-0

rm *.csv
