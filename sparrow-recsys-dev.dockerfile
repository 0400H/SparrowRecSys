ARG base_image=ubuntu:20.04
FROM ${base_image}

MAINTAINER 0400H <git@0400h.cn>

ENV INSTALL_PREFIX=/usr/local
ENV LD_LIBRARY_PATH=${INSTALL_PREFIX}/lib:${LD_LIBRARY_PATH}
ENV PATH=${INSTALL_PREFIX}/bin:${LD_LIBRARY_PATH}:${PATH}
ENV DEBIAN_FRONTEND=noninteractive

# Add steps here to set up dependencies
RUN apt-get update && \
    apt-get install -y \
        build-essential \
        ca-certificates \
        python3-pip \
        net-tools \
        supervisor \
        rsync \
        unzip \
        sudo \
        axel \
        wget \
        curl \
        tig \
        git \
        vim

RUN apt-get update && \
    apt-get install -y openjdk-8-jdk openssh-server nginx mysql-server mysql-client redis-server redis

# Scala
ARG SCALA_VERSION=2.12.18
ENV SCALA_HOME=${INSTALL_PREFIX}/scala
RUN axel -n 4 https://downloads.lightbend.com/scala/${SCALA_VERSION}/scala-${SCALA_VERSION}.tgz && \
    tar -zxvf scala-${SCALA_VERSION}.tgz -C ${INSTALL_PREFIX} && \
    rm -rf scala-${SCALA_VERSION}.tgz && \
    ln -s ${INSTALL_PREFIX}/scala-${SCALA_VERSION} ${SCALA_HOME}

# Hadoop
# https://github.com/apache/hadoop/blob/docker-hadoop-3/Dockerfile
# https://github.com/kiwenlau/hadoop-cluster-docker/blob/master/Dockerfile
ARG HADOOP_VERSION=3.3.6
ENV HADOOP_HOME=${INSTALL_PREFIX}/hadoop
ENV HADOOP_CONF_DIR=${HADOOP_HOME}/etc/hadoop
ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
ENV PATH=${HADOOP_HOME}/bin:${HADOOP_HOME}/sbin:${PATH}
ENV LD_LIBRARY_PATH=${HADOOP_HOME}/lib/native:${LD_LIBRARY_PATH}
RUN axel -n 4 https://archive.apache.org/dist/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz && \
    tar -zxvf hadoop-${HADOOP_VERSION}.tar.gz -C ${INSTALL_PREFIX} && \
    rm -rf hadoop-${HADOOP_VERSION}.tar.gz && \
    ln -s ${INSTALL_PREFIX}/hadoop-${HADOOP_VERSION} ${HADOOP_HOME}

# Spark
ARG SPARK_VERSION=3.5.0
ENV SPARK_HOME=${INSTALL_PREFIX}/spark
ENV PATH=${SPARK_HOME}/bin:${SPARK_HOME}/sbin:${PATH}
RUN axel -n 4 https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop3.tgz && \
    tar -zxvf spark-${SPARK_VERSION}-bin-hadoop3.tgz -C ${INSTALL_PREFIX} && \
    rm -rf spark-${SPARK_VERSION}-bin-hadoop3.tgz && \
    ln -s ${INSTALL_PREFIX}/spark-${SPARK_VERSION}-bin-hadoop3 ${SPARK_HOME}

# Flink
ARG FLINK_VERSION=1.17.1
ENV FLINK_HOME=${INSTALL_PREFIX}/flink
ENV PATH=${FLINK_HOME}/bin:${FLINK_HOME}/sbin:${PATH}
RUN axel -n 4 https://archive.apache.org/dist/flink/flink-${FLINK_VERSION}/flink-${FLINK_VERSION}-bin-scala_2.12.tgz && \
    tar -zxvf flink-${FLINK_VERSION}-bin-scala_2.12.tgz -C ${INSTALL_PREFIX} && \
    rm -rf flink-${FLINK_VERSION}-bin-scala_2.12.tgz && \
    ln -s ${INSTALL_PREFIX}/flink-${FLINK_VERSION} ${FLINK_HOME}

# Kafka
ARG KAFKA_VERSION=3.2.3
ENV KAFKA_HOME=${INSTALL_PREFIX}/kafka
ENV PATH=${KAFKA_HOME}/bin:${PATH}
RUN axel -n 4 https://archive.apache.org/dist/kafka/${KAFKA_VERSION}/kafka_2.12-${KAFKA_VERSION}.tgz && \
    tar -zxvf kafka_2.12-${KAFKA_VERSION}.tgz -C ${INSTALL_PREFIX} && \
    rm -rf kafka_2.12-${KAFKA_VERSION}.tgz && \
    ln -s ${INSTALL_PREFIX}/kafka_2.12-${KAFKA_VERSION} ${KAFKA_HOME}

# Zookeeper
ARG ZOOKEEPER_VERSION=3.9.1
ENV ZOOKEEPER_HOME=${INSTALL_PREFIX}/zookeeper
ENV PATH=${ZOOKEEPER_HOME}/bin:${PATH}
RUN axel -n 4 https://archive.apache.org/dist/zookeeper/zookeeper-${ZOOKEEPER_VERSION}/apache-zookeeper-${ZOOKEEPER_VERSION}-bin.tar.gz && \
    tar -zxvf apache-zookeeper-${ZOOKEEPER_VERSION}-bin.tar.gz -C ${INSTALL_PREFIX} && \
    rm -rf apache-zookeeper-${ZOOKEEPER_VERSION}-bin.tar.gz && \
    ln -s ${INSTALL_PREFIX}/apache-zookeeper-${ZOOKEEPER_VERSION}-bin ${ZOOKEEPER_HOME}

# Maven
ARG MAVEN_VERSION=3.9.5
ENV MAVEN_HOME=${INSTALL_PREFIX}/maven
ENV PATH=${MAVEN_HOME}/bin:${PATH}
RUN axel -n 4 https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz && \
    tar -zxvf apache-maven-${MAVEN_VERSION}-bin.tar.gz -C ${INSTALL_PREFIX} && \
    rm -rf apache-maven-${MAVEN_VERSION}-bin.tar.gz && \
    ln -s ${INSTALL_PREFIX}/apache-maven-${MAVEN_VERSION} ${MAVEN_HOME}

# TensorFlow Serving
ARG TF_SERVING_VERSION=2.6.2
ARG TF_SERVING_PKGNAME=tensorflow-model-server
RUN axel -n 4 https://storage.googleapis.com/tensorflow-serving-apt/pool/${TF_SERVING_PKGNAME}-${TF_SERVING_VERSION}/t/${TF_SERVING_PKGNAME}/${TF_SERVING_PKGNAME}_${TF_SERVING_VERSION}_all.deb && \
    apt-get install -y ./${TF_SERVING_PKGNAME}_${TF_SERVING_VERSION}_all.deb && \
    rm -rf *.deb

# SSH auto login
RUN ssh-keygen -t rsa -f ~/.ssh/id_rsa -P '' && \
    cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys

RUN pip3 install pip --upgrade && \
    pip3 install tensorflow tensorflow_hub tensorflow_text pyspark==${SPARK_VERSION} pymysql redis kafka-python jupyter tqdm

ENV WORK_DIR=/SparrowRecSys
WORKDIR ${WORK_DIR}

COPY pom.xml ${WORK_DIR}
COPY src ${WORK_DIR}/src
COPY conf/maven ${MAVEN_HOME}
RUN mvn clean package

COPY conf/hadoop ${HADOOP_HOME}
COPY conf/spark ${SPARK_HOME}
COPY conf/flink ${FLINK_HOME}
COPY conf/zookeeper ${ZOOKEEPER_HOME}
COPY conf/kafka ${KAFKA_HOME}
COPY conf/ssh /etc/ssh
COPY conf/mysql /etc/mysql
COPY supervisor /etc/supervisor
COPY workflow.sh ${WORK_DIR}

# Clean tmp files
RUN apt-get clean all \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf ~/.cache/* \
    && rm -rf /tmp/*

COPY entrypoint.sh /usr/bin
ENTRYPOINT ["/usr/bin/entrypoint.sh"]
