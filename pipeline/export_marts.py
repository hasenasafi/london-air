"""
Export the dbt marts to CSV files in exports/, for Tableau.
Tableau Public can't read DuckDB files, but it reads CSV.
The file names stay the same as before, so the Tableau workbook doesn't need re-linking.

Run it:  python pipeline/export_marts.py   (run_pipeline.sh does this automatically)
"""

from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parent.parent
WAREHOUSE = ROOT / "data" / "warehouse.duckdb"
EXPORTS = ROOT / "exports"

# mart  ->  CSV file Tableau reads
EXPORTS_MAP = {
    "fct_daqi_current": "current_alert.csv",  # one row per site: Today's alert
    "fct_daqi_daily": "daily_alert.csv",      # site x day: calendar and headline numbers
    "fct_daqi_hourly": "hourly_index.csv",    # site x pollutant x hour: PM2.5 charts
}


def main():
    EXPORTS.mkdir(exist_ok=True)
    con = duckdb.connect(str(WAREHOUSE), read_only=True)
    for mart, file_name in EXPORTS_MAP.items():
        path = EXPORTS / file_name
        con.execute(f"COPY (SELECT * FROM {mart}) TO '{path}' (HEADER, DELIMITER ',')")
        rows = con.execute(f"SELECT count(*) FROM {mart}").fetchone()[0]
        print(f"  {mart} -> {file_name}: {rows} rows")
    con.close()


if __name__ == "__main__":
    main()
