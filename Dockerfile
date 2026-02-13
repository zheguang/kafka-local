FROM docker.io/library/alpine:3.23

RUN apk update && apk add openjdk17-jre bash

# We keep the configs in separate folder to make custom changes
# This is to avoid volume mount in compose in ./kafka:/kafka to shadow the changed configs (for development loop)
# Remember to use the /config instead of /kafka/config to format and start server!
COPY ./kafka/config /config
COPY ./kafka /kafka
COPY ./entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Format storage and start
WORKDIR /kafka
CMD /entrypoint.sh -f

