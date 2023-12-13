
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

(
    mvn clean package
)

(
    cd $WORK_DIR/src/main/java/com/sparrowrecsys/offline/mysql
    python3 -u db.py -p 123456
    ./mysql_to_hdfs.sh
)

(
    cd $WORK_DIR/src/main/java/com/sparrowrecsys
    cd offline/pyspark/
    python3 -u embedding/Embedding.py
    cd offline/tensorflow
    python3 -u ./HDFSMoviesBERTEmbedding.py
)

(
    cd $WORK_DIR/src/main/java/com/sparrowrecsys/offline/tensorflow
    export TF_CONFIG='{"cluster":{"worker":["localhost:12345","localhost:12346"],"ps":["localhost:23456","localhost:23457"],"chief":["localhost:34567"]},"task":{"type":"worker","index":0}}'
    python3 -u TFServer.py &

    export TF_CONFIG='{"cluster":{"worker":["localhost:12345","localhost:12346"],"ps":["localhost:23456","localhost:23457"],"chief":["localhost:34567"]},"task":{"type":"worker","index":1}}'
    python3 -u TFServer.py &

    export TF_CONFIG='{"cluster":{"worker":["localhost:12345","localhost:12346"],"ps":["localhost:23456","localhost:23457"],"chief":["localhost:34567"]},"task":{"type":"ps","index":0}}'
    python3 -u TFServer.py &

    export TF_CONFIG='{"cluster":{"worker":["localhost:12345","localhost:12346"],"ps":["localhost:23456","localhost:23457"],"chief":["localhost:34567"]},"task":{"type":"ps","index":1}}'
    python3 -u TFServer.py &
)

# (
#     cd $WORK_DIR/src/main/java/com/sparrowrecsys/offline/pyspark
#     python3 -u embedding/Embedding.py
#     python3 -u featureeng/FeatureEngineering.py
#     python3 -u featureeng/FeatureEngForRecModel.py
# )

(
    # movie embedding
    spark-submit --name EmbeddingLSH --master yarn --deploy-mode cluster --class sparrowrecsys.offline.spark.embedding.EmbeddingLSH $WORK_DIR/target/SparrowRecSys-1.0-SNAPSHOT-jar-with-dependencies.jar

    # feature engineering
    spark-submit --name FeatureEngineering --master yarn --deploy-mode cluster --class sparrowrecsys.offline.spark.featureeng.FeatureEngForRecModel $WORK_DIR/target/SparrowRecSys-1.0-SNAPSHOT-jar-with-dependencies.jar

    cd $WORK_DIR/src/main/java/com/sparrowrecsys/offline/tensorflow
    export TF_CONFIG='{"cluster":{"worker":["localhost:12345","localhost:12346"],"ps":["localhost:23456","localhost:23457"],"chief":["localhost:34567"]},"task":{"type":"chief","index":0}}'
    python3 -u ./WideNDeep.py
)

(
    MODEL_NAME=sparrow_recsys_widedeep
    MODEL_BASE_PATH=$WORK_DIR/src/main/java/com/sparrowrecsys/offline/tensorflow/tmp_model/widendeep
    ln -s ${MODEL_BASE_PATH} ${MODEL_BASE_PATH}/${MODEL_NAME}

    tensorflow_model_server --port=8500 --rest_api_port=8501 \
        --model_name=${MODEL_NAME} --model_base_path=${MODEL_BASE_PATH}/${MODEL_NAME} &
)

(
    java -jar $WORK_DIR/target/SparrowRecSys-1.0-SNAPSHOT-jar-with-dependencies.jar &
)

(
    cd $WORK_DIR/src/main/java/com/sparrowrecsys

    python3 -u ./nearline/tensorflow/KafkaMoviesBERTEmbedding.py &

    # flink run -p 2 -c sparrowrecsys.nearline.flink.NewMovieHandler $WORK_DIR/target/SparrowRecSys-1.0-SNAPSHOT-jar-with-dependencies.jar &

    # flink run -p 2 -c sparrowrecsys.nearline.flink.NewRatingHandler $WORK_DIR/target/SparrowRecSys-1.0-SNAPSHOT-jar-with-dependencies.jar &
)

```
