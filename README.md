# Kafka Local - a containerized cluster for rapid development

A 3-node Apache Kafka cluster running in KRaft mode (no ZooKeeper), designed for local development against a real multi-broker setup.

## Getting started

Clone this repository to local file system. While under the source tree,
1. Clone the Apache Kafka source tree to `./kafka`
2. Build Apache Kafka: `./kafka/gradlew jar`
3. Build container image: `docker compose build`
4. Run containers: `docker compose up`
5. Check cluster health: `bash check.sh ./kafka`

## Development loop

| What changed | Command |
|---|---|
| Kafka source code in `./kafka/` | `./kafka/gradlew jar && docker compose restart` |
| Server properties via override | Edit `SERVER_PROPERTIES_OVERRIDE` in `docker-compose.yaml`, then `docker compose up -d` |
| Base config in `./kafka/config/` | `docker compose build && docker compose up -d` |

Source code changes don't need a rebuild — `./kafka` is volume-mounted into the containers.

### Overriding server properties

Set `SERVER_PROPERTIES_OVERRIDE` in the compose environment to pass `--override` flags to `kafka-server-start.sh`:

```yaml
environment:
    - SERVER_PROPERTIES_OVERRIDE=--override log.retention.hours=1 --override num.io.threads=4
```

Then run `docker compose up -d` (not `restart`) so compose re-reads the file and recreates the containers with the new environment.

## Port mapping

| Node    | Client    | JDWP Debug | JMX   |
|---------|-----------|------------|-------|
| kafka-1 | localhost:19094 | 15005 | 19101 |
| kafka-2 | localhost:29094 | 25005 | 29101 |
| kafka-3 | localhost:39094 | 35005 | 39101 |

## Debug

Remote attach to server `kafka-1`: `jdb -attach localhost:15005`

## JMX

Get JMX metric from server `kafka-3`:

```bash
./kafka/bin/kafka-jmx.sh --object-name kafka.server:type=KafkaServer,name=BrokerState \
  --jmx-url service:jmx:rmi:///jndi/rmi://localhost:39101/jmxrmi --one-time true
```
