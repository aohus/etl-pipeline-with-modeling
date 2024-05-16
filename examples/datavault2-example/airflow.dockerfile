# 베이스 이미지
FROM gtoonstra/docker-airflow:1.9.0

# 환경 변수 설정
ENV JAVA_HOME=/usr/lib/jvm/java-7-openjdk-amd64
ENV HADOOP_HOME=/usr/local/hadoop
ENV HIVE_HOME=/usr/local/hive
ENV PATH=$PATH:$HADOOP_HOME/bin:$HIVE_HOME/bin

USER root

RUN echo "deb http://archive.debian.org/debian stretch main" > /etc/apt/sources.list

# 필요한 패키지 설치
RUN apt-get update && \
    apt-get install -y wget procps openjdk-7-jdk && \
    rm -rf /var/lib/apt/lists/* 

# Hadoop 설치
RUN wget https://downloads.apache.org/hadoop/common/hadoop-2.10.2/hadoop-2.10.2.tar.gz && \
    tar -xzvf hadoop-2.10.2.tar.gz -C /usr/local/ && \
    mv /usr/local/hadoop-2.10.2/* $HADOOP_HOME/ && \
    rm hadoop-2.10.2.tar.gz


# Hive 설치
RUN wget https://downloads.apache.org/hive/hive-2.3.10/apache-hive-2.3.10-bin.tar.gz && \
    tar -xzvf apache-hive-2.3.10-bin.tar.gz -C /usr/local/ && \
    mv /usr/local/apache-hive-2.3.10-bin/* $HIVE_HOME/ && \
    rm apache-hive-2.3.10-bin.tar.gz && \
    rm -rf /usr/local/apache-hive-2.3.10-bin/

# Hive 구성
# RUN cp $HIVE_HOME/conf/hive-env.sh.template $HIVE_HOME/conf/hive-env.sh && \
#     echo "export HADOOP_HOME=$HADOOP_HOME" >> $HIVE_HOME/conf/hive-env.sh

# Hadoop 및 Hive 환경 설정
COPY core-site.xml $HADOOP_HOME/etc/hadoop/core-site.xml
COPY hdfs-site.xml $HADOOP_HOME/etc/hadoop/hdfs-site.xml

# # 포트 및 볼륨 설정
EXPOSE 8080 10000
# VOLUME /usr/local/airflow/dags
# VOLUME /usr/local/airflow/logs

# Airflow 설정
# COPY entrypoint.sh /entrypoint.sh
# RUN chmod +x /entrypoint.sh

# 엔트리포인트
USER airflow
ENTRYPOINT ["/entrypoint.sh"]