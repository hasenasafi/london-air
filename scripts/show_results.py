"""Quick look at the marts and the pipeline's run history."""
import duckdb

con = duckdb.connect("data/warehouse.duckdb", read_only=True)
con.execute("ATTACH 'data/air_quality.duckdb' AS raw (READ_ONLY)")

print("\n=== RIGHT NOW: should we warn patients? ===")
print(con.sql("""
    select site_name, latest_reading_gmt, daqi_index, band, worst_pollutant, warn_respiratory_patients
    from fct_daqi_current order by daqi_index desc
"""))

print("\n=== Days in the history when patients should have been warned (Moderate or worse) ===")
print(con.sql("""
    select reading_date_gmt, site_name, daqi_index, band, worst_pollutant
    from fct_daqi_daily where warn_respiratory_patients
    order by reading_date_gmt desc
"""))

print("\n=== Latest reading per site and pollutant (spot sensors that have gone quiet) ===")
print(con.sql("""
    select site_code, species_code, max(measured_at) as latest_reading
    from raw.raw_readings group by all order by latest_reading
"""))

print("\n=== Pipeline runs: proof that each run adds only new data ===")
print(con.sql("""
    select run_started_at, sum(rows_from_api) as rows_from_api, sum(rows_inserted) as new_rows
    from raw.load_log group by run_started_at order by run_started_at
"""))
