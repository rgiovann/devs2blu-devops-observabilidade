#!/bin/sh
set -euo pipefail

DEFAULT_FLAGS="--web.listen-address=:9100 \
  --path.rootfs=/host \
  --collector.textfile.directory=/etc/node-exporter/textfile"

EXTRA_FLAGS=${NODE_EXPORTER_FLAGS:-}

mkdir -p /etc/node-exporter/textfile

exec /bin/node_exporter $DEFAULT_FLAGS $EXTRA_FLAGS "$@"
