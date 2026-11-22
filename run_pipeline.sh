#!/usr/bin/env bash
# Runs the whole pipeline in order: bronze (extract + load), then silver and gold (dbt).
# Stops at the first error, so a failed step never feeds bad data into the next one.
set -euo pipefail

# Always run from the project folder, wherever this script is called from
cd "$(dirname "$0")"

echo "=== 1/2 Bronze: extract new readings from the API and load them ==="
python pipeline/extract_load.py

echo "=== 2/2 Silver and gold: dbt build (models + tests) ==="
dbt build

echo "=== Pipeline finished ==="
