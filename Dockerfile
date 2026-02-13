FROM docker.io/library/alpine:3.23

RUN apk update && apk add openjdk17-jre bash

# We keep the configs in separate folder to make custom changes
# This is to avoid volume mount in compose in ./kafka:/kafka to shadow the changed configs (for development loop)
# Remember to use the /config instead of /kafka/config to format and start server!
COPY ./kafka/config /config
COPY ./kafka /kafka
WORKDIR /kafka

### Configs
## variables
ARG NODE_ID
ENV NODE_ID=${NODE_ID}
ARG ADVERTISED_PORT
ENV ADVERTISED_PORT=${ADVERTISED_PORT}

## default to local machine
ENV EXTERNAL_HOSTNAME=${EXTERNAL_HOSTNAME:-localhost}

## constants
ENV KAFKA_CLUSTER_ID=en6x1yegRMycKxtEAM-pJw
ENV CONTROLLER_1_UUID=pWsA9-2IRKWYB9BEAhBpEg
ENV CONTROLLER_2_UUID=jThDYj3mRHWNiQET2ZCZ1g
ENV CONTROLLER_3_UUID=zlje2fi9RgKaoJDUBuJnQA

ENV CONTROLLER_QUORUM_VOTERS=1@kafka-1:9093:${CONTROLLER_1_UUID},2@kafka-2:9093:${CONTROLLER_2_UUID},3@kafka-3:9093:${CONTROLLER_3_UUID}
ENV CONTROLLER_QUORUM_BOOTSTRAP_SERVERS=kafka-1:9093,kafka-2:9093,kafka-3:9093

## Update configs in /config
## Default to 9092 for advertised port. Can override in compose
## We do not advertise the controller listener port 9093 for inter-broker/controller communication
RUN sed -i "s/^node\\.id=1/node.id=${NODE_ID}/" /config/server.properties
RUN sed -i 's/\(^listener\.security\.protocol\.map=.*\)/\1,INTERNAL:PLAINTEXT,EXTERNAL:PLAINTEXT/' /config/server.properties
RUN sed -i 's/^inter\.broker\.listener\.name=.*/inter.broker.listener.name=INTERNAL/' /config/server.properties
RUN sed -i 's/^listeners=.*/listeners=INTERNAL:\/\/:9092,CONTROLLER:\/\/:9093,EXTERNAL:\/\/:9094/' /config/server.properties
RUN sed -i "s/^advertised\\.listeners=.*/advertised.listeners=INTERNAL:\/\/kafka-${NODE_ID}:9092,CONTROLLER:\/\/kafka-${NODE_ID}:9093,EXTERNAL:\/\/${EXTERNAL_HOSTNAME}:${ADVERTISED_PORT}/" /config/server.properties
RUN sed -i "s/^controller\\.quorum\\.bootstrap\\.servers=.*/controller.quorum.bootstrap.servers=${CONTROLLER_QUORUM_BOOTSTRAP_SERVERS}/" /config/server.properties

### Build time
# Only node id needs to be overrided for formatting storage
RUN bin/kafka-storage.sh format --initial-controllers "${CONTROLLER_QUORUM_VOTERS}" -t ${KAFKA_CLUSTER_ID} -c /config/server.properties

### Run time
## Start server at runtime, using advertised port with plaintext
#CMD bin/kafka-server-start.sh /config/server.properties \ 
#    --override node.id=${NODE_ID} \
#    --override advertised.listeners=PLAINTEXT://localhost:${ADVERTISED_PORT} \
#    --override controller.quorum.bootstrap.servers=${CONTROLLER_QUORUM_BOOTSTRAP_SERVERS}
CMD bin/kafka-server-start.sh /config/server.properties
