#!/bin/bash
set -e
if [ $# -eq 0 ]; then
	distrib="trixie"
elif [ $# -eq 1 ]; then
	if [ "$1" != "bullseye" ] && [ "$1" != "bookworm" ] && [ "$1" != "trixie" ]; then
		echo "Only bullseye, bookworm or trixie are supported."
		exit 1
	fi
	distrib="$1"
else
	echo "Invalid number of args"
	exit 1
fi
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
cp "$SCRIPT_DIR/Dockerfile.$distrib" "$SCRIPT_DIR/Dockerfile"
docker rm -f xe303c12 || true
docker system prune -f -a
docker build -t xe303c12 scripts/
docker run --memory 16000m --memory-swap 16000m -d --privileged --name xe303c12 xe303c12 sleep 43200
docker cp configs xe303c12:/configs
docker cp scripts xe303c12:/scripts
docker exec -i xe303c12 bash scripts/build.sh
docker cp xe303c12:/release ./
docker rm -f xe303c12 || true
docker system prune -f -a
