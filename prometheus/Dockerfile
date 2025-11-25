FROM prom/prometheus:v2.51.2

USER root

COPY prometheus.yml /etc/prometheus/prometheus.yml
COPY rules /etc/prometheus/rules

RUN mkdir -p /prometheus && \
    chown -R nobody:nobody /prometheus /etc/prometheus

USER nobody

EXPOSE 9090

ENTRYPOINT ["/bin/prometheus"]
CMD [ \
  "--config.file=/etc/prometheus/prometheus.yml", \
  "--storage.tsdb.path=/prometheus", \
  "--web.console.libraries=/usr/share/prometheus/console_libraries", \
  "--web.console.templates=/usr/share/prometheus/consoles" \
]
