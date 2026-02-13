# Kafka Local - a containerized cluster for rapid development

## Getting started
Clone this repository to local file system. While under the source tree,
1. Clone the Apache Kafka source tree to `./kafka`
2. Build Apache Kafka: `./kafka/gradlew jar`
3. Build container image: `docker compose build`
4. Run containers: `docker compose up`
5. Check cluster health: `bash check.sh ./kafka`

## Debug
Remote attach to server `kafka-1`: `jdb -attach localhost:15005`

## JMX
Get JMX metric from server `kafka-3`: `./kafka/bin/kafka-jmx.sh --object-name kafka.server:type=KafkaServer,name=BrokerState --jmx-url service:jmx:rmi:///jndi/rmi://localhost:39101/jmxrmi --one-time true`
