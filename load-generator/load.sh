#!/bin/sh
echo "Waiting for database..."
until mysql -h db -uappuser -papppass appdb -e "SELECT 1" &>/dev/null; do
  sleep 2
done

echo "Starting load generator..."
while true; do
  mysql -h db -uappuser -papppass appdb \
    -e "INSERT INTO healthcheck VALUES (NULL, NOW());" 2>/dev/null || echo "Insert failed, retrying..."
  sleep 5
done