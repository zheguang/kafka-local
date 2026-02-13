#!bin/bash

COMPOSE_HOME="$(dirname $(readlink -f "0"))"
echo $COMPOSE_HOME
KAFKA_HOME="$COMPOSE_HOME"/kafka
echo $KAFKA_HOME

[ -d "$KAFKA_HOME" ] ||
{
    echo '[error] <kafka-local>/kafka does not exist. Clone Apache Kafka first.'
    exit 1
}

cd $COMPOSE_HOME
echo "=== Container Status ==="
docker compose ps

echo -e "\n=== Recent Errors ==="
docker compose logs --tail=20 | grep -i --color error

cd $KAFKA_HOME
echo -e "\n=== Broker Registration ==="
./bin/kafka-cluster.sh list-endpoints --bootstrap-server localhost:19094 

echo -e "\n=== Cluster Metadata ==="
./bin/kafka-metadata-quorum.sh --bootstrap-server localhost:19094 describe --status

echo -e "\n=== Broker Metrics ==="
###
# File: metadata/src/main/java/org/apache/kafka/metadata/BrokerState.java
# State Transition Flow (from the source):
# 
# NOT_RUNNING (0)
#     ↓
# STARTING (1)
#     ↓
# RECOVERY (2)  ← Caught up with metadata, waiting to be unfenced
#     ↓
# RUNNING (3)   ← Accepting client requests ✅
#     ↓
# PENDING_CONTROLLED_SHUTDOWN (6)
#     ↓
# SHUTTING_DOWN (7)
###
bin/kafka-jmx.sh --object-name kafka.server:type=KafkaServer,name=BrokerState --jmx-url service:jmx:rmi:///jndi/rmi://localhost:19101/jmxrmi --one-time true
bin/kafka-jmx.sh --object-name kafka.server:type=KafkaServer,name=BrokerState --jmx-url service:jmx:rmi:///jndi/rmi://localhost:29101/jmxrmi --one-time true
bin/kafka-jmx.sh --object-name kafka.server:type=KafkaServer,name=BrokerState --jmx-url service:jmx:rmi:///jndi/rmi://localhost:39101/jmxrmi --one-time true

echo -e "\n=== Debugger attach ==="
echo quit | jdb -attach localhost:15005 2>&1 | grep -q 'Initializing jdb' || 
{
    echo "[error] JDWP not reachable on kakfa-1"
    exit 1
}

echo -e "\n=== Under-Replicated Partitions ==="
./bin/kafka-topics.sh --bootstrap-server localhost:19094 --describe --under-replicated-partitions

echo -e "\n=== Offline Partitions ==="
./bin/kafka-topics.sh --bootstrap-server localhost:19094 --describe --unavailable-partitions


echo -e "\n=== End-to-end latency test ==="
./bin/kafka-topics.sh --bootstrap-server localhost:19094 --create --topic my-e2e-test --partitions 3 --replication-factor 3
./bin/kafka-e2e-latency.sh --bootstrap-server localhost:19094 --topic my-e2e-test --num-records 10000 --producer-acks 1 --record-size 128
./bin/kafka-topics.sh --bootstrap-server localhost:19094 --describe --under-replicated-partitions
./bin/kafka-topics.sh --bootstrap-server localhost:19094 --describe --unavailable-partitions
./bin/kafka-topics.sh --bootstrap-server localhost:19094 --delete --topic my-e2e-test


echo -e "\n=== Clean up ==="
echo "Done!"
