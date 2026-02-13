#!/bin/bash

set -e 

export START_MODE=$1

if [ "$START_MODE" = '-f' ]; then
    export NODE_ID=${NODE_ID:?Require NODE_ID}
    ## constants
    export KAFKA_CLUSTER_ID=en6x1yegRMycKxtEAM-pJw
    export CONTROLLER_1_UUID=pWsA9-2IRKWYB9BEAhBpEg
    export CONTROLLER_2_UUID=jThDYj3mRHWNiQET2ZCZ1g
    export CONTROLLER_3_UUID=zlje2fi9RgKaoJDUBuJnQA
    export CONTROLLER_QUORUM_VOTERS="1@kafka-1:9093:${CONTROLLER_1_UUID},2@kafka-2:9093:${CONTROLLER_2_UUID},3@kafka-3:9093:${CONTROLLER_3_UUID}"

    echo "[info] Formatting"
    sed -i "s/^node\\.id=.*/node.id=${NODE_ID}/" /config/server.properties
    bin/kafka-storage.sh format --initial-controllers "${CONTROLLER_QUORUM_VOTERS}" -t ${KAFKA_CLUSTER_ID} -c /config/server.properties

    ### Update /config further, assume deploying to local machine
    echo '[info] Updating config'
    export EXTERNAL_HOSTNAME=${EXTERNAL_HOSTNAME:?Required EXTERNAL_HOSTNAME}
    export ADVERTISED_PORT=${ADVERTISED_PORT:?Require ADVERTISED_PORT}
    export CONTROLLER_QUORUM_BOOTSTRAP_SERVERS=kafka-1:9093,kafka-2:9093,kafka-3:9093

    sed -i 's/\(^listener\.security\.protocol\.map=.*\)/\1,INTERNAL:PLAINTEXT,EXTERNAL:PLAINTEXT/' /config/server.properties
    sed -i 's/^inter\.broker\.listener\.name=.*/inter.broker.listener.name=INTERNAL/' /config/server.properties
    sed -i 's/^listeners=.*/listeners=INTERNAL:\/\/:9092,CONTROLLER:\/\/:9093,EXTERNAL:\/\/:9094/' /config/server.properties
    ## We do not advertise the controller listener port 9093 for inter-broker/controller communication
    #sed -i "s/^advertised\\.listeners=.*/advertised.listeners=INTERNAL:\/\/kafka-${NODE_ID}:9092,CONTROLLER:\/\/kafka-${NODE_ID}:9093,EXTERNAL:\/\/${EXTERNAL_HOSTNAME}:${ADVERTISED_PORT}/" /config/server.properties
    sed -i "s/^advertised\\.listeners=.*/advertised.listeners=INTERNAL:\/\/kafka-${NODE_ID}:9092,EXTERNAL:\/\/${EXTERNAL_HOSTNAME}:${ADVERTISED_PORT}/" /config/server.properties
    sed -i "s/^controller\\.quorum\\.bootstrap\\.servers=.*/controller.quorum.bootstrap.servers=${CONTROLLER_QUORUM_BOOTSTRAP_SERVERS}/" /config/server.properties

    ### Run time
    # JDWP: Simple TCP, no "call back" needed -- listen on/bind to all interfaces (via wildcard, i.e., 0.0.0.0). Important because docker forwards port mapping traffic to the container's eth0 interface
    # This port can be the same across all nodes
    export JDWP_BIND_PORT=5005
    export JAVA_DEBUG_OPTS="-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:${JDWP_BIND_PORT}"

    # RMI: like Kafka, not a simple TCP, but requires "callback" -- separating bind endpoint and advertised endpoint for redirect. 
    # But worse than Kafka, same jmxremote.port and jmxremote.rmi.port is used for BOTH bind and callback.
    # In local deployment, tell JMX clients to use "localhost" to connect to JMX server in the container.
    # But in remote deployement, use the container's host machine's hostname, passed in EXTERNAL_HOSTNAME.
    # This port needs to be overriden at runtime so it's unique per node
    export RMI_JMX_BIND_PORT=${RMI_JMX_BIND_PORT:?Required RMI_JMX_BIND_PORT}
    export KAFKA_JMX_OPTS="-Djava.rmi.server.hostname=${EXTERNAL_HOSTNAME} \
                           -Dcom.sun.management.jmxremote=true \
                           -Dcom.sun.management.jmxremote.authenticate=false  \
                           -Dcom.sun.management.jmxremote.ssl=false \
                           -Dcom.sun.management.jmxremote.port=${RMI_JMX_BIND_PORT} \
                           -Dcom.sun.management.jmxremote.rmi.port=${RMI_JMX_BIND_PORT}"
fi

echo "[info] Starting"
exec bin/kafka-server-start.sh /config/server.properties

