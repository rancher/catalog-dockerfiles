FROM debian:jessie

RUN apt-get update && apt-get install -y --no-install-recommends openjdk-7-jre-headless \
    curl

ENV HADOOP_VERSION 2.7.1
ENV JAVA_HOME /usr/lib/jvm/java-7-openjdk-amd64

RUN curl -LO http://mirrors.advancedhosters.com/apache/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz && \
    tar -zxvf hadoop-${HADOOP_VERSION}.tar.gz -C /usr/local && \
    ln -s /usr/bin/java /bin/java

RUN useradd -d /home/hadoop -m hadoop && \
    useradd -d /home/mapred -m -G hadoop mapred && \
    useradd -d /home/hdfs -m -G hadoop hdfs && \
    useradd -d /home/yarn -m -G hadoop yarn && \
    chown -R hadoop:hadoop /usr/local/hadoop-${HADOOP_VERSION} && \
    mv /usr/local/hadoop-${HADOOP_VERSION}/etc/hadoop /etc/ && \
    ln -s /etc/hadoop/ /usr/local/hadoop-${HADOOP_VERSION}/etc/hadoop && \
    mkdir -p /hadoop/dfs/name \
             /hadoop/dfs/sname1 \
             /hadoop/dfs/data1 \
             /hadoop/yarn/nm-local \
             /hadoop/yarn/staging && \
    chown -R hdfs:hdfs /hadoop/dfs && \
    chown -R yarn:yarn /hadoop/yarn && \
    mkdir -p /var/log/hadoop && chown hadoop:hadoop /var/log/hadoop && \
    chmod g+w /var/log/hadoop

ADD ./hdfs-site.xml /etc/hadoop/hdfs-site.xml
ADD ./bootstrap-hdfs.sh /bootstrap-hdfs.sh
ADD ./refreshnodes.sh /refreshnodes.sh
RUN su -c "/usr/local/hadoop-${HADOOP_VERSION}/bin/hdfs namenode -format" hdfs

VOLUME [ "/usr/local/hadoop-${HADOOP_VERSION}" ]
VOLUME [ "/etc/hadoop", "/hadoop/dfs/name", "/hadoop/dfs/sname1", "/hadoop/dfs/data1"]
VOLUME ["/hadoop/yarn/nm-local", "/hadoop/yarn/staging"]

ENV HADOOP_HOME /usr/local/hadoop-${HADOOP_VERSION}

# HDFS
EXPOSE 8020 50010 50020 50070 50075 50090
# MapRed
EXPOSE 50030 50060
#Yarn
EXPOSE 8032 8033 8030 8031 8040 8088 8042
