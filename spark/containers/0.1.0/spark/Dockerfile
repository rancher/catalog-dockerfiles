FROM rancher/hadoop-base:v0.2.0

RUN apt-get update && apt-get install -y --no-install-recommends openjdk-7-jre-headless \
    curl \
    jq \
    maven \
    python \
    git \
    scala

RUN curl -sL http://d3kbcqa49mib13.cloudfront.net/spark-1.5.2-bin-hadoop2.6.tgz | tar -xz -C /usr/local && \
    ln -s /usr/local/spark-1.5.2-bin-hadoop2.6 /usr/local/spark &&\
    useradd -d /home/spark -m spark && \
    cp -r /usr/local/spark/conf /etc/spark && \
    rm -rf /usr/local/spark/conf && ln -s /etc/spark /usr/local/spark/conf && \
    mkdir -p /usr/local/spark/logs && chown -R spark:spark /usr/local/spark/logs

VOLUME ["/etc/spark"]
VOLUME ["/spark/work"]

ADD ./*.sh /

USER spark
ENV JAVA_HOME /usr/lib/jvm/java-7-openjdk-amd64
ENV SPARK_HOME /usr/local/spark

CMD ["/bin/bash"]
