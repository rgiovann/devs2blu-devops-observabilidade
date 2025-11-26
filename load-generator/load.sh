#!/bin/sh
echo "Waiting for database..."
until mysql -h db -uappuser -papppass appdb -e "SELECT 1" >/dev/null 2>&1; do
  sleep 2
done
echo "Starting load generator..."
while true; do
  mysql -h db -uappuser -papppass appdb <<EOF
INSERT INTO healthcheck VALUES
  (NULL, NOW()),
  (NULL, NOW()),
  (NULL, NOW()),
  (NULL, NOW()),
  (NULL, NOW());
EOF
  sleep 0.3
done