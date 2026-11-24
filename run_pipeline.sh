#!/usr/bin/env bash
# Runs the whole pipeline in order:
#   1. extract + load the raw data, 2. dbt (staging -> intermediate -> marts, with tests), 3. export marts for Tableau.
# Stops at the first error, so a failed step never feeds bad data into the next one.
set -euo pipefail

# Always run from the project folder, wherever this script is called from
cd "$(dirname "$0")"

echo "=== 1/3 Extract new readings from the API and load them (raw) ==="
python pipeline/extract_load.py

echo "=== 2/3 dbt build: staging -> intermediate -> marts, plus tests ==="
dbt build

echo "=== 3/3 Export marts to CSV for Tableau ==="
python pipeline/export_marts.py

echo "=== Pipeline finished ==="
