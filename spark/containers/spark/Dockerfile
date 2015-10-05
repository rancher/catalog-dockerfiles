FROM debian:jessie

RUN apt-get update && apt-get install -y --no-install-recommends openjdk-7-jre-headless \
    curl \
    jq

RUN curl -LO http://d3kbcqa49mib13.cloudfront.net/spark-1.5.0-bin-hadoop2.6.tgz &&\
    tar -xzvf spark-1.5.0-bin-hadoop2.6.tgz -C /usr/local && \
    ln -s /usr/bin/java /bin/java

ENV JAVA_HOME /usr/lib/jvm/java-7-openjdk-amd64
