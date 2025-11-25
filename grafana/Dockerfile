FROM grafana/grafana:10.4.2

USER root

COPY provisioning /etc/grafana/provisioning
COPY dashboards /var/lib/grafana/dashboards

# UID/GID 472 existe na imagem base, evita problemas de lookup
RUN chown -R 472:472 /etc/grafana /var/lib/grafana/dashboards

USER grafana

EXPOSE 3000
