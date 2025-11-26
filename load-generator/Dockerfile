FROM alpine:3.19

RUN apk add --no-cache mariadb-client

COPY load.sh /usr/local/bin/load.sh
RUN chmod +x /usr/local/bin/load.sh

CMD ["/usr/local/bin/load.sh"]
