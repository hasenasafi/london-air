#!/usr/bin/env bash
# Starts Kestra in Docker, in the background, and loads my flow from the flows/ folder.
# Open http://localhost:8080 once the logs say the server is running.
set -euo pipefail
cd "$(dirname "$0")"

# Remove an old Kestra container if one exists, so this script can be re-run safely
docker rm -f kestra >/dev/null 2>&1 || true

docker run -d \
  --name kestra \
  --restart unless-stopped \
  --user=root \
  -p 8080:8080 \
  -v kestra_data:/app/storage \
  -v kestra_db:/app/data \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /tmp:/tmp \
  -v "$(pwd)/flows:/flows" \
  -e KESTRA_CONFIGURATION="$(cat config.yml)" \
  kestra/kestra:latest \
  server local --flow-path /flows

echo "Kestra is starting. Watch the logs with:  docker logs -f kestra"
echo "Then open http://localhost:8080"
