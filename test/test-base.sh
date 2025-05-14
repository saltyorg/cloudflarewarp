#!/bin/bash

echo "";
echo "";
echo "*** STARTING TEST FOR : ${1}-${2}-${3}";
echo "";
echo "";

rm -rf ./logs;
rm -rf ./tempconfig;

mkdir ./logs;
mkdir ./tempconfig;

touch ./logs/access.log;
touch ./logs/debug.log;
touch ./logs/traefik.log;
touch ./logs/output.log;

cp "./config/${1}.${2}" "./tempconfig/config.${2}"

chmod -R 7777 ./logs;
chmod -R 7777 ./tempconfig;

sleep 2s

# Check if containers are already running
if [ "$(docker ps -q -f name=traefik)" ]; then
  echo "Containers are running, restarting only traefik"
  # Restart only the traefik container using docker compose
  docker compose restart traefik
else
  echo "Starting containers for the first time"
  docker compose up -d
fi

sleep 1s

docker ps -a

iterations=0
while ! grep -q "Starting TCP Server" "./logs/debug.log" && [ $iterations -lt 30 ]; do
  sleep 1s
  echo "Waiting for Traefik to be ready [${iterations}s/30]"
  (( iterations++ ))
done

iterations=0
while ! grep -q "Provider connection established with docker" "./logs/debug.log" && [ $iterations -lt 30 ]; do
  sleep 1s
  echo "Waiting for Traefik to connect to docker [${iterations}s/30]"
  (( iterations++ ))
done

iterations=0
while ! grep -q "test-instance-traefik-whoami@docker" "./logs/debug.log" && [ $iterations -lt 30 ]; do
  sleep 1s
  echo "Waiting for Traefik to UP the service [${iterations}s/30]"
  (( iterations++ ))
done

docker ps -a

sleep 5

HTTP_STATUS=$(curl -s -o ./logs/output.log -w "%{http_code}" -H "CF-Connecting-IP:${4}" -H "CF-Visitor:{\"scheme\":\"https\"}" http://localhost:4008/)

# Check if the captured HTTP status is not 200
if [ "$HTTP_STATUS" -ne 200 ]; then
  echo "Error: Received HTTP status code $HTTP_STATUS, expected 200." >&2
  cat ./logs/output.log # Still show the output log content
  exit 1 # Exit with a non-zero status code
fi

# Original logging and cat commands remain if the script didn't exit
printf "Headers:\nCF-Connecting-IP:%s\nCF-Visitor:{\"scheme\":\"https\"}\n\n" "${4}" >> ./logs/request.log
cat ./logs/output.log;

# Don't stop containers after test, just continue to next test
