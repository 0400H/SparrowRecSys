
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

```
./start_container.sh

# export WORK_DIR=/mnt/home/0400h/github/SparrowRecSys

cd $WORK_DIR

(
    cd offline/mysql
    python3 -u db.py -p 123456
    ./mysql_to_hdfs.sh
)

(
    cd offline/tensorflow
    python3 -u HDFSMoviesBERTEmbedding.py
)

(
    cd offline/pyspark
    python3 -u embedding/Embedding.py
    python3 -u featureeng/FeatureEngineering.py
    python3 -u featureeng/FeatureEngForRecModel.py
)

(
    hdfs dfs -rm -r hdfs:///sparrow_recsys/sampledata/trainingSamples/* || true
    hdfs dfs -rm -r hdfs:///sparrow_recsys/sampledata/testSamples/* || true
    # hdfs dfs -rm -r hdfs:///sparrow_recsys/modeldata/* || true

    hdfs dfs -mkdir -p hdfs:///sparrow_recsys/sampledata/trainingSamples/0000
    hdfs dfs -mkdir -p hdfs:///sparrow_recsys/sampledata/testSamples/0000
    # hdfs dfs -mkdir -p hdfs:///sparrow_recsys/modeldata/

    cd $WORK_DIR/online/src/main/resources/webroot

    hdfs dfs -put sampledata/trainingSamples.csv hdfs:///sparrow_recsys/sampledata/trainingSamples/0000/part-0.csv
    hdfs dfs -put sampledata/testSamples.csv hdfs:///sparrow_recsys/sampledata/testSamples/0000/part-0.csv
)

(
    cd offline/tensorflow
    export TF_CONFIG='{"cluster":{"worker":["localhost:12345","localhost:12346"],"ps":["localhost:23456","localhost:23457"],"chief":["localhost:34567"]},"task":{"type":"worker","index":0}}'
    python3 -u TFServer.py &

    export TF_CONFIG='{"cluster":{"worker":["localhost:12345","localhost:12346"],"ps":["localhost:23456","localhost:23457"],"chief":["localhost:34567"]},"task":{"type":"worker","index":1}}'
    python3 -u TFServer.py &

    export TF_CONFIG='{"cluster":{"worker":["localhost:12345","localhost:12346"],"ps":["localhost:23456","localhost:23457"],"chief":["localhost:34567"]},"task":{"type":"ps","index":0}}'
    python3 -u TFServer.py &

    export TF_CONFIG='{"cluster":{"worker":["localhost:12345","localhost:12346"],"ps":["localhost:23456","localhost:23457"],"chief":["localhost:34567"]},"task":{"type":"ps","index":1}}'
    python3 -u TFServer.py &

    export TF_CONFIG='{"cluster":{"worker":["localhost:12345","localhost:12346"],"ps":["localhost:23456","localhost:23457"],"chief":["localhost:34567"]},"task":{"type":"chief","index":0}}'
    python3 -u WideNDeep.py &
)

(
    cd online
    mvn clean package
)

```