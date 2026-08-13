#!/usr/bin/env bash
set -euo pipefail

# Navigate to repository root (script lives in scripts/)
cd "$(dirname "$0")/.."

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker not found. Install Docker and try again."
  exit 1
fi

if docker compose version >/dev/null 2>&1; then
  echo "Using 'docker compose' to start the DB..."
  docker compose up -d
else
  echo "Using 'docker-compose' to start the DB..."
  docker-compose up -d
fi

echo "Postgres container is starting. Run 'docker ps' to check status."
