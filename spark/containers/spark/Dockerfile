FROM rancher/hadoop-base:v0.1.0

RUN apt-get update && apt-get install -y --no-install-recommends openjdk-7-jre-headless \
    curl \
    jq

RUN curl -sL http://d3kbcqa49mib13.cloudfront.net/spark-1.5.1-bin-hadoop2.6.tgz | tar -xz -C /usr/local && 
    ln -s /usr/local/spark-1.5.1-bin-hadoop2.6 /usr/local/spark &&\
    ln -s /usr/bin/java /bin/java && \
    useradd -d /home/spark -m spark

USER spark
ENV JAVA_HOME /usr/lib/jvm/java-7-openjdk-amd64
ENV SPARK_HOME /usr/local/spark

CMD ["/bin/bash"]
