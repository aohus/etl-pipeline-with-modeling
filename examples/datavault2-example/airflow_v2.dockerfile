# Use Ubuntu as the base image
FROM ubuntu:18.04

# Environment variables for non-interactive installation
ENV DEBIAN_FRONTEND=noninteractive
ENV TERM=linux

# Setup environment variables
ENV AIRFLOW_HOME=/usr/local/airflow
ENV HADOOP_HOME=/usr/local/hadoop
ENV HIVE_HOME=/usr/local/hive
ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/hive/bin:/usr/local/hadoop/bin:/usr/lib/jvm/java-8-openjdk-amd64/bin
ENV HADOOP_OPTS="-Djava.library.path=$HADOOP_HOME/lib/native"
ENV LANGUAGE=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV LC_CTYPE=en_US.UTF-8
ENV LC_MESSAGES=en_US.UTF-8

# Install dependencies
RUN apt-get update -yqq && \
    apt-get install -yqq --no-install-recommends \
    openjdk-8-jdk \
    python2.7 \
    python-pip \
    python-dev \
    libkrb5-dev \
    libsasl2-dev \
    libssl-dev \
    libffi-dev \
    build-essential \
    libblas-dev \
    liblapack-dev \
    libpq-dev \
    libgsasl7-dev \
    libxml2-dev \
    libxslt-dev \
    git \
    wget \
    curl \
    netcat \
    locales && \
    sed -i 's/^# en_US.UTF-8 UTF-8$/en_US.UTF-8 UTF-8/g' /etc/locale.gen && \
    locale-gen && \
    update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# Set up user
RUN useradd -ms /bin/bash -d ${AIRFLOW_HOME} airflow && \
    mkdir -p ${HADOOP_HOME} ${HIVE_HOME} && \
    chown -R airflow:airflow ${AIRFLOW_HOME} ${HADOOP_HOME} ${HIVE_HOME}

# Install Python packages
RUN python -m pip install --upgrade pip && \
    pip install setuptools && \
    pip install PyYAML==5.1 && \
    pip install wheel && \
    pip install pytz pyOpenSSL ndg-httpsclient pyasn1 thrift_sasl==0.3.0 werkzeug==0.16.1 Flask==1.0.4 SQLAlchemy==1.2.19 && \
    pip install 'apache-airflow[celery, crypto, postgres, hive, hdfs, jdbc]==1.9.0' && \
    pip install 'celery[redis]==3.1.17' thrift==0.13.0

# # Hadoop 설치
# RUN wget https://archive.apache.org/dist/hadoop/common/hadoop-2.6.0/hadoop-2.6.0.tar.gz && \
#     tar -xzvf hadoop-2.6.0.tar.gz -C /usr/local/ && \
#     mv /usr/local/hadoop-2.6.0/* $HADOOP_HOME/ && \
#     rm hadoop-2.6.0.tar.gz

# # Hive 설치
# RUN wget https://downloads.apache.org/hive/hive-2.3.10/apache-hive-2.3.10-bin.tar.gz && \
#     tar -xzvf apache-hive-2.3.10-bin.tar.gz -C /usr/local/ && \
#     mv /usr/local/apache-hive-2.3.10-bin/* $HIVE_HOME/ && \
#     rm apache-hive-2.3.10-bin.tar.gz && \
#     rm -rf /usr/local/apache-hive-2.3.10-bin/

COPY ./hadoop/hadoop-2.6.0/* ${HADOOP_HOME}/
COPY ./hadoop/apache-hive-2.3.10-bin/* ${HIVE_HOME}/

# Clean up unnecessary packages
# RUN apt-get remove --purge -yqq $(apt-mark showmanual) --allow-remove-essential && \
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/man/* /usr/share/doc/*

# Configure entrypoint and airflow configuration
COPY entrypoint.sh /entrypoint.sh
COPY airflow.cfg /usr/local/airflow/airflow.cfg
RUN chmod +x /entrypoint.sh && chown -R airflow: ${AIRFLOW_HOME}

# Ports to expose
EXPOSE 8080 5555 8793 5432 10000

# Run as user airflow
USER airflow
WORKDIR /usr/local/airflow
ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]