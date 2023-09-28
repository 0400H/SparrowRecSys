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

RUN apt-get install -y openssh-server sshpass nginx mysql-server mysql-client redis-server redis intel-mkl

# MKL
ENV MKL_NUM_THREADS=4
RUN ln -sf /usr/lib/x86_64-linux-gnu/liblapack.so /usr/local/lib/libblas.so.3 \
    && ln -sf /usr/lib/x86_64-linux-gnu/liblapack.so /usr/local/lib/liblapack.so.3

# Hadoop
# https://github.com/apache/hadoop/blob/docker-hadoop-3/Dockerfile
# https://github.com/kiwenlau/hadoop-cluster-docker/blob/master/Dockerfile
ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
ENV HADOOP_HOME=${INSTALL_PREFIX}/hadoop
ENV HADOOP_CONF_DIR=${HADOOP_HOME}/etc/hadoop
ENV PATH=${HADOOP_HOME}/bin:${HADOOP_HOME}/sbin:${PATH}
ENV LD_LIBRARY_PATH=${HADOOP_HOME}/lib/native:${LD_LIBRARY_PATH}

ARG HADOOP_VERSION=3.3.6
RUN apt-get install -y openjdk-8-jdk
RUN axel -n 4 https://dlcdn.apache.org/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz && \
    tar -zxvf hadoop-${HADOOP_VERSION}.tar.gz -C ${INSTALL_PREFIX} && \
    rm -rf hadoop-${HADOOP_VERSION}.tar.gz && \
    ln -s ${INSTALL_PREFIX}/hadoop-${HADOOP_VERSION} ${HADOOP_HOME}

# Spark
ENV SPARK_HOME=${INSTALL_PREFIX}/spark
ENV PATH=${SPARK_HOME}bin:${SPARK_HOME}/sbin:${PATH}
ARG SPARK_VERSION=3.5.0
RUN axel -n 4 https://dlcdn.apache.org/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop3.tgz && \
    tar -zxvf spark-${SPARK_VERSION}-bin-hadoop3.tgz -C ${INSTALL_PREFIX} && \
    rm -rf spark-${SPARK_VERSION}-bin-hadoop3.tgz && \
    ln -s ${INSTALL_PREFIX}/spark-${SPARK_VERSION}-bin-hadoop3 ${SPARK_HOME}

# Kafka
ENV KAFKA_HOME=${INSTALL_PREFIX}/kafka
ENV PATH=${KAFKA_HOME}bin:${PATH}
ARG KAFKA_VERSION=3.5.0
RUN axel -n 4 https://downloads.apache.org/kafka/${KAFKA_VERSION}/kafka_2.13-${KAFKA_VERSION}.tgz && \
    tar -zxvf kafka_2.13-${KAFKA_VERSION}.tgz -C ${INSTALL_PREFIX} && \
    rm -rf kafka_2.13-${KAFKA_VERSION}.tgz && \
    ln -s ${INSTALL_PREFIX}/kafka_2.13-${KAFKA_VERSION} ${KAFKA_HOME}

# zookeeper

# SSH without key
RUN ssh-keygen -t rsa -f ~/.ssh/id_rsa -P '' && \
    cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys

RUN pip3 install pip --upgrade && \
    pip3 install tensorflow tensorflow_hub tensorflow_text pyspark pymysql redis kafka-python jupyter

COPY ssh /etc/ssh
COPY mysql/mysql.conf.d /etc/mysql/mysql.conf.d
COPY mysql/mysqld-init.sh ${INSTALL_PREFIX}/bin
COPY hadoop/etc/hadoop ${HADOOP_HOME}/etc/hadoop
COPY spark/conf ${SPARK_HOME}/conf
# COPY supervisor /etc/supervisor

# # Clean tmp files
# RUN apt-get clean all \
#     && rm -rf /var/lib/apt/lists/* \o
#     && rm -rf ~/.cache/* \
#     && rm -rf /tmp/*

ENV WORK_SPACE_PATH=/mnt
WORKDIR ${WORK_SPACE_PATH}

COPY entrypoint.sh /usr/bin/
ENTRYPOINT ["/usr/bin/entrypoint.sh"]
