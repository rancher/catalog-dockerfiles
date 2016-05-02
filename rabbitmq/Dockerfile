FROM rabbitmq:3.6.1-management

VOLUME /etc/rabbitmq

ENV RABBITMQ_ERLANG_COOKIE="jellycookie"

RUN echo "deb http://ftp.de.debian.org/debian jessie main" >> /etc/apt/sources.list && apt-get update && apt-get install -y curl supervisor

COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY make_cluster.sh /make_cluster.sh

ADD ./dockerentry.sh /dockerentry.sh

ENTRYPOINT ["/dockerentry.sh"]

