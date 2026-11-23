"""
Export the gold tables to CSV files in exports/, for Tableau.
Tableau Public can't read DuckDB files, but it reads CSV.
The CSVs are small text files, so they're committed to git: they are the pipeline's output.

Run it:  python pipeline/export_gold.py   (run_pipeline.sh does this automatically)
"""

from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parent.parent
WAREHOUSE = ROOT / "data" / "warehouse.duckdb"
EXPORTS = ROOT / "exports"

QUERIES = {
    # One row per site per day: the day's DAQI band and patient advice (main dashboard view)
    "daily_alert": """
        select a.*, s.latitude, s.longitude, s.site_type
        from gold_daily_alert a
        left join silver_sites s using (site_code)
        order by reading_date_gmt, site_code
    """,
    # Right now, per site: should patients be warned today?
    "current_alert": """
        select a.*, s.latitude, s.longitude, s.site_type
        from gold_current_alert a
        left join silver_sites s using (site_code)
        order by site_code
    """,
    # Every hour, per site and pollutant: for line charts and "worst time of day"
    "hourly_index": """
        select * from gold_hourly_index
        order by measured_at_gmt, site_code, species_code
    """,
}


def main():
    EXPORTS.mkdir(exist_ok=True)
    con = duckdb.connect(str(WAREHOUSE), read_only=True)
    for name, sql in QUERIES.items():
        path = EXPORTS / f"{name}.csv"
        con.execute(f"COPY ({sql}) TO '{path}' (HEADER, DELIMITER ',')")
        rows = con.execute(f"select count(*) from ({sql})").fetchone()[0]
        print(f"  {path.name}: {rows} rows")
    con.close()


if __name__ == "__main__":
    main()
