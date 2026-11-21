"""
Extract + Load: London Air Quality Network API -> DuckDB

What it does, in order:
  1. Refreshes the list of monitoring sites (reference data, small, safe to replace).
  2. For each site + pollutant in config.py, finds the latest reading we already
     have (the "watermark") and only asks the API for data after that point.
  3. Inserts the new readings. The primary key (site, pollutant, timestamp)
     means a reading we already hold can never be stored twice.
  4. Writes one row per site/pollutant to load_log so every run is auditable.

Run it:  python pipeline/extract_load.py
"""

import time
from datetime import date, datetime, timedelta
from pathlib import Path
import duckdb
import requests
import config

BASE_URL = "https://api.erg.ic.ac.uk/AirQuality"
DB_PATH = Path(__file__).resolve().parent.parent / "data" / "air_quality.duckdb"


# ---------- talking to the API ----------

def get_json(path):
    """GET one endpoint and return parsed JSON. Waits between calls to be kind to the API."""
    url = f"{BASE_URL}/{path}"
    response = requests.get(url, timeout=60)
    response.raise_for_status()
    time.sleep(config.SECONDS_BETWEEN_CALLS)
    return response.json()


def as_list(x):
    """The API returns a single object instead of a list when there is only one item. Normalise it."""
    if x is None:
        return []
    return x if isinstance(x, list) else [x]


# ---------- database setup ----------

def create_tables(con):
    con.execute("""
        CREATE TABLE IF NOT EXISTS raw_sites (
            site_code            VARCHAR PRIMARY KEY,
            site_name            VARCHAR,
            site_type            VARCHAR,
            local_authority_name VARCHAR,
            latitude             DOUBLE,
            longitude            DOUBLE,
            date_opened          VARCHAR,
            date_closed          VARCHAR,
            loaded_at            TIMESTAMP
        )
    """)
    con.execute("""
        CREATE TABLE IF NOT EXISTS raw_readings (
            site_code    VARCHAR,
            species_code VARCHAR,
            measured_at  TIMESTAMP,   -- hour the reading is for, in GMT (no daylight saving)
            value        DOUBLE,      -- concentration, µg/m3
            loaded_at    TIMESTAMP,   -- when OUR pipeline stored it
            PRIMARY KEY (site_code, species_code, measured_at)
        )
    """)
    con.execute("""
        CREATE TABLE IF NOT EXISTS load_log (
            run_started_at TIMESTAMP,
            site_code      VARCHAR,
            species_code   VARCHAR,
            requested_from DATE,
            requested_to   DATE,
            rows_from_api  INTEGER,
            rows_inserted  INTEGER
        )
    """)


# ---------- step 1: sites ----------

def load_sites(con, loaded_at):
    payload = get_json("Information/MonitoringSites/GroupName=London/Json")
    sites = as_list(payload["Sites"]["Site"])
    rows = [
        (
            s.get("@SiteCode"),
            s.get("@SiteName"),
            s.get("@SiteType"),
            s.get("@LocalAuthorityName"),
            float(s["@Latitude"]) if s.get("@Latitude") else None,
            float(s["@Longitude"]) if s.get("@Longitude") else None,
            s.get("@DateOpened") or None,
            s.get("@DateClosed") or None,
            loaded_at,
        )
        for s in sites
    ]
    # Sites are reference data: replace the whole table each run (it is ~200 rows).
    con.execute("DELETE FROM raw_sites")
    con.executemany("INSERT INTO raw_sites VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)", rows)
    print(f"Sites: {len(rows)} London monitoring sites refreshed")


# ---------- step 2 + 3: readings, incrementally ----------

def start_date_for(con, site, species):
    """The watermark: re-request from 2 days before our latest reading (catches late-arriving data),
    or go back BACKFILL_DAYS if this is the first time we've seen this site/pollutant."""
    latest = con.execute(
        "SELECT max(measured_at) FROM raw_readings WHERE site_code = ? AND species_code = ?",
        [site, species],
    ).fetchone()[0]
    if latest is None:
        return date.today() - timedelta(days=config.BACKFILL_DAYS)
    return latest.date() - timedelta(days=config.OVERLAP_DAYS)


def load_readings(con, site, species, run_started_at):
    start = start_date_for(con, site, species)
    end = date.today() + timedelta(days=1)  # end date is exclusive, so +1 includes today

    payload = get_json(
        f"Data/SiteSpecies/SiteCode={site}/SpeciesCode={species}"
        f"/StartDate={start.isoformat()}/EndDate={end.isoformat()}/Json"
    )
    readings = as_list(payload.get("RawAQData", {}).get("Data"))

    rows = []
    for r in readings:
        raw_value = r.get("@Value")
        if raw_value in (None, ""):
            continue  # hour with no measurement yet: skip, the overlap window will pick it up later
        rows.append((
            site,
            species,
            datetime.strptime(r["@MeasurementDateGMT"], "%Y-%m-%d %H:%M:%S"),
            float(raw_value),
            run_started_at,
        ))

    before = con.execute("SELECT count(*) FROM raw_readings").fetchone()[0]
    if rows:
        # ON CONFLICT DO NOTHING = if we already hold this site/pollutant/hour, ignore it.
        con.executemany(
            "INSERT INTO raw_readings VALUES (?, ?, ?, ?, ?) ON CONFLICT DO NOTHING", rows
        )
    inserted = con.execute("SELECT count(*) FROM raw_readings").fetchone()[0] - before

    con.execute(
        "INSERT INTO load_log VALUES (?, ?, ?, ?, ?, ?, ?)",
        [run_started_at, site, species, start, end, len(rows), inserted],
    )
    print(f"  {site} {species}: {len(rows)} rows from API, {inserted} new")


def main():
    DB_PATH.parent.mkdir(exist_ok=True)
    run_started_at = datetime.now().replace(microsecond=0)
    con = duckdb.connect(str(DB_PATH))
    create_tables(con)

    load_sites(con, run_started_at)
    print("Readings:")
    for site in config.SITES:
        for species in config.SPECIES:
            try:
                load_readings(con, site, species, run_started_at)
            except requests.RequestException as err:
                # One bad request shouldn't stop the whole run; the next run will retry from the watermark.
                print(f"  {site} {species}: FAILED ({err})")

    total = con.execute("SELECT count(*) FROM raw_readings").fetchone()[0]
    print(f"Done. raw_readings now holds {total} rows.")
    con.close()


if __name__ == "__main__":
    main()
