#!/usr/bin/env bash
# Runs the whole pipeline in order: bronze (extract + load), silver and gold (dbt), then exports for Tableau.
# Stops at the first error, so a failed step never feeds bad data into the next one.
set -euo pipefail

# Always run from the project folder, wherever this script is called from
cd "$(dirname "$0")"

echo "=== 1/3 Bronze: extract new readings from the API and load them ==="
python pipeline/extract_load.py

echo "=== 2/3 Silver and gold: dbt build (models + tests) ==="
dbt build

echo "=== 3/3 Export gold tables to CSV for Tableau ==="
python pipeline/export_gold.py

echo "=== Pipeline finished ==="
