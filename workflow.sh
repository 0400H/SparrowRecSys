#!/bin/bash

set -ex

cd $WORK_DIR/src/main/java/sparrowrecsys

# Wait for mysql
(
while [ ! -f "/var/log/mysql_init.lock" ]
do
    echo "Wait for Mysql ..."
    sleep 5s
done
)

# Offline
(
    cd offline/mysql
    python3 -u db.py -p 123456
    ./mysql_to_hdfs.sh
)

(
    cd offline/pyspark
    python3 -u embedding/Embedding.py
    # spark-submit --name Embedding --master yarn --deploy-mode cluster --class sparrowrecsys.offline.spark.embedding.Embedding $WORK_DIR/target/SparrowRecSys-1.0-SNAPSHOT-jar-with-dependencies.jar

    cd offline/tensorflow
    python3 -u HDFSMoviesBERTEmbedding.py
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
)

(
    # movie embedding
    spark-submit --name EmbeddingLSH --master yarn --deploy-mode cluster --class sparrowrecsys.offline.spark.embedding.EmbeddingLSH $WORK_DIR/target/SparrowRecSys-1.0-SNAPSHOT-jar-with-dependencies.jar

    # feature engineering
    spark-submit --name FeatureEngineering --master yarn --deploy-mode cluster --class sparrowrecsys.offline.spark.featureeng.FeatureEngForRecModel $WORK_DIR/target/SparrowRecSys-1.0-SNAPSHOT-jar-with-dependencies.jar

    cd offline/tensorflow
    export TF_CONFIG='{"cluster":{"worker":["localhost:12345","localhost:12346"],"ps":["localhost:23456","localhost:23457"],"chief":["localhost:34567"]},"task":{"type":"chief","index":0}}'
    python3 -u ./WideNDeep.py
)

(
    MODEL_NAME=sparrow_recsys_widedeep
    MODEL_BASE_PATH=$WORK_DIR/src/main/java/sparrowrecsys/offline/tensorflow/tmp_model
    ln -s ${MODEL_BASE_PATH}/widendeep ${MODEL_BASE_PATH}/${MODEL_NAME}

    tensorflow_model_server --port=8500 --rest_api_port=8501 \
        --model_name=${MODEL_NAME} --model_base_path=${MODEL_BASE_PATH}/${MODEL_NAME} &
)

# Online
(
    java -jar $WORK_DIR/target/SparrowRecSys-1.0-SNAPSHOT-jar-with-dependencies.jar &
)

# Nearline
(
    python3 -u ./nearline/tensorflow/KafkaMoviesBERTEmbedding.py &

    # flink run -p 2 -c sparrowrecsys.nearline.flink.NewMovieHandler $WORK_DIR/target/SparrowRecSys-1.0-SNAPSHOT-jar-with-dependencies.jar &

    # flink run -p 2 -c sparrowrecsys.nearline.flink.NewRatingHandler $WORK_DIR/target/SparrowRecSys-1.0-SNAPSHOT-jar-with-dependencies.jar &
)