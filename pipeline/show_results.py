"""Quick look at the gold layer and the pipeline's run history."""
import duckdb

con = duckdb.connect("data/warehouse.duckdb", read_only=True)
con.execute("ATTACH 'data/air_quality.duckdb' AS bronze (READ_ONLY)")

print("\n=== RIGHT NOW: should we warn patients? ===")
print(con.sql("""
    select site_name, latest_reading_gmt, daqi_index, band, worst_pollutant, warn_respiratory_patients
    from gold_current_alert order by daqi_index desc
"""))

print("\n=== Days in the history when patients should have been warned (Moderate or worse) ===")
print(con.sql("""
    select reading_date_gmt, site_name, daqi_index, band, worst_pollutant
    from gold_daily_alert where warn_respiratory_patients
    order by reading_date_gmt desc
"""))

print("\n=== Latest reading per site and pollutant (spot sensors that have gone quiet) ===")
print(con.sql("""
    select site_code, species_code, max(measured_at) as latest_reading
    from bronze.raw_readings group by all order by latest_reading
"""))

print("\n=== Pipeline runs: proof that each run adds only new data ===")
print(con.sql("""
    select run_started_at, sum(rows_from_api) as rows_from_api, sum(rows_inserted) as new_rows
    from bronze.load_log group by run_started_at order by run_started_at
"""))