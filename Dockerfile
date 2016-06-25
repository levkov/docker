FROM ubuntu:14.04
MAINTAINER levkov
ENV DEBIAN_FRONTEND noninteractive
ENV NOTVISIBLE "in users profile"
RUN locale-gen en_US.UTF-8

RUN apt-get update && apt-get upgrade -y &&\
    apt-get install apt-transport-https -y &&\
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
#------------------------------Supervisor------------------------------------------------
RUN apt-get update && apt-get install -y supervisor && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
RUN mkdir -p /var/log/supervisor
COPY conf/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
EXPOSE 9001
CMD ["/usr/bin/supervisord"]
#---------------------------SSH---------------------------------------------------------
RUN apt-get update && apt-get install -y openssh-server && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
RUN mkdir -p /var/run/sshd
RUN sed -i 's/PermitRootLogin without-password/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd
ENV NOTVISIBLE "in users profile"
RUN echo "export VISIBLE=now" >> /etc/profile
COPY conf/sshd.conf /etc/supervisor/conf.d/sshd.conf

RUN echo 'root:ContaineR' | chpasswd
EXPOSE 22
# -------------------------------C9-----------------------------------------------
RUN apt-get update &&\
    apt-get install -y build-essential g++ curl libssl-dev apache2-utils git libxml2-dev sshfs &&\
    curl -sL https://deb.nodesource.com/setup | bash -
RUN apt-get install -y nodejs && \
    git clone https://github.com/c9/core.git /cloud9
WORKDIR /cloud9
RUN scripts/install-sdk.sh
RUN sed -i -e 's_127.0.0.1_0.0.0.0_g' /cloud9/configs/standalone.js
ADD conf/cloud9.conf /etc/supervisor/conf.d/
EXPOSE 80
# -----------------------------------Java--------------------------------------
RUN apt-get update && apt-get install software-properties-common -y && \
    add-apt-repository ppa:openjdk-r/ppa -y && apt-get update && \
    apt-get install -y openjdk-8-jdk && \
    rm -rf /var/lib/apt/lists/* && rm -rf /tmp/*
#------------------------------------Ansible-------------------------------------
RUN apt-get update && apt-get install software-properties-common -y && apt-add-repository ppa:ansible/ansible -y && apt-get update && \
    apt-get install ansible -y && \
    rm -rf /var/lib/apt/lists/* && rm -rf /tmp/*
#--------------------------------S3 Tools-----------------------------------------
RUN wget -O- -q http://s3tools.org/repo/deb-all/stable/s3tools.key | sudo apt-key add - && \
    wget -O/etc/apt/sources.list.d/s3tools.list http://s3tools.org/repo/deb-all/stable/s3tools.list && \
    apt-get update && apt-get -y install s3cmd && \
    rm -rf /var/lib/apt/lists/* && rm -rf /tmp/*
#---------------------------------------------------------------------------------
COPY conf/kali-tools.list /etc/apt/sources.list.d/kali-tools.list
COPY conf/key.pgp /tmp/key.pgp
RUN apt-key add /tmp/key.pgp && \
    apt-get update
#----------------------------------Redis Queue Flask Nginx-----------------------------------
RUN apt-get update && apt-get -y install redis-server nginx python-pip python-dev && \
    pip install requests==2.5.3 Flask gunicorn redis rq rq-dashboard rq-scheduler
#---------------------------------Zookeeper--Kafka------------------------------------------------
RUN cd /opt && \
    wget http://apache.spd.co.il/zookeeper/zookeeper-3.4.8/zookeeper-3.4.8.tar.gz && \ 
    tar xvzf zookeeper-3.4.8.tar.gz && \
    useradd zookeeper && \
    chown -R zookeeper /opt/zookeeper-3.4.8 && \ 
    ln -s /opt/zookeeper-3.4.8 /opt/zookeeper-latest && \
    chown -h zookeeper /opt/zookeeper-latest && \
    mkdir /var/lib/zookeeper && \
    chown zookeeper /var/lib/zookeeper && \
    cd /opt/zookeeper-latest/conf && \ 
    cp zoo_sample.cfg zoo.cfg
  
RUN cd /opt && \
    wget http://apache.spd.co.il/kafka/0.9.0.1/kafka_2.11-0.9.0.1.tgz && tar xvzf kafka_2.11-0.9.0.1.tgz && \
    useradd kafka && \
    chown -R kafka /opt/kafka_2.11-0.9.0.1 && \
    ln -s /opt/kafka_2.11-0.9.0.1 /opt/kafka-latest && \
    chown -h zookeeper /opt/kafka-latest
EXPOSE 2181 9092
#-----------------------------Kafka manager-------------------------------------------------
RUN echo "deb https://dl.bintray.com/sbt/debian /" | sudo tee -a /etc/apt/sources.list.d/sbt.list && \
    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 642AC823
RUN apt-get update && \
    apt-get install sbt -y
RUN cd /opt && git clone https://github.com/yahoo/kafka-manager.git 
RUN cd /opt/kafka-manager && echo 'scalacOptions ++= Seq("-Xmax-classfile-name", "200")' >> build.sbt && sbt clean dist
RUN cd /opt/kafka-manager && \
    sbt debian:packageBin
RUN dpkg -i /opt/kafka-manager/target/kafka-manager_1.3.0.8_all.deb
COPY conf/application.conf /etc/kafka-manager/application.conf
EXPOSE 9000 5052
#-------------------------Influxdb---------------------------------------------------------
RUN wget https://dl.influxdata.com/influxdb/releases/influxdb_0.13.0_amd64.deb
RUN dpkg -i influxdb_0.13.0_amd64.deb
COPY conf/dfg.sh /usr/local/bin/dfg.sh
RUN  chmod +x /usr/local/bin/dfg.sh
EXPOSE 8083 8086
#--------------------------------Cloudera-------------------------------------------
RUN wget http://archive.cloudera.com/director/ubuntu/trusty/amd64/director/cloudera-director.list -O /etc/apt/sources.list.d/cloudera-director.list && \
    curl -s http://archive.cloudera.com/director/ubuntu/trusty/amd64/director/archive.key | sudo apt-key add - && \
    apt-get update -y && \
    apt-get install cloudera-director-client -y && \
    cp /usr/lib/cloudera-director/client/aws.reference.conf /root/aws.conf && \
#--------------------------------------------------------------------------
    rm -rf /var/lib/apt/lists/* && rm -rf /tmp/*
