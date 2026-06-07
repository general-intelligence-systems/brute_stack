FROM matrixdotorg/synapse:latest

COPY --chown=991:991 homeserver.yaml /data/homeserver.yaml
COPY --chown=991:991 localhost.log.config /data/localhost.log.config
COPY --chown=991:991 localhost.signing.key /data/localhost.signing.key
COPY --chown=991:991 appservices /data/appservices

RUN mkdir -p /data/media_store && chown -R 991:991 /data
