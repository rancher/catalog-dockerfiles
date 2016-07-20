FROM ubuntu:14.04
MAINTAINER Nathan Valentine < nathan@rancher.com | nrvale0@gmail.com >

ENV DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true

RUN apt-get update && apt-get dist-upgrade -y && \
	rm -rf /var/cache/apt/archive
RUN apt-get install -y mysql-client nmap python-pip curl wget vim bash && \
	rm -rf /var/cache/apt/archive
RUN pip install httpie

CMD /bin/bash
