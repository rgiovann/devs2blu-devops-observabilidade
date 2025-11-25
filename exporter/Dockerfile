FROM prom/node-exporter:v1.7.0

USER root

COPY config/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
