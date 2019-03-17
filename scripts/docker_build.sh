#!/bin/bash
set -e
docker rm -f xe303c12 || true
docker build -t xe303c12 .
docker run -d --privileged --name xe303c12 xe303c12 sleep 14400
docker cp configs xe303c12:/configs
docker cp scripts xe303c12:/scripts
docker exec -i xe303c12 bash scripts/build.sh
docker cp xe303c12:/exynos/xe303c12.zip ./xe303c12.zip
find .
file xe303c12.zip
docker rm -f xe303c12 || true
docker system prune -f
