#!/bin/bash
set -e
docker rm -f xe303c12_bullseye || true
docker system prune -f -a
docker build -t xe303c12_bullseye scripts/bullseye
docker run -d --privileged --name xe303c12_bullseye xe303c12_bullseye sleep 43200
docker cp configs xe303c12_bullseye:/configs
docker cp scripts xe303c12_bullseye:/scripts
docker exec -i xe303c12_bullseye bash scripts/bullseye.sh
docker cp xe303c12_bullseye:/release ./
docker rm -f xe303c12_bullseye || true
docker system prune -f -a
