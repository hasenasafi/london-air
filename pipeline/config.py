
# Site codes come from the MonitoringSites endpoint (the @SiteCode field).
SITES = ["ME2", "MEA", "ME9", "MEB"]

# Pollutant codes: NO2 = nitrogen dioxide, PM25 = fine particulates, PM10, O3 = ozone
SPECIES = ["NO2", "PM25", "PM10"]

# First run: how far back to go
BACKFILL_DAYS = 60

# Later runs: re-ask for this many days before our latest reading, to catch data the API adds late
OVERLAP_DAYS = 2

# Pause between API calls so we don't hammer a free service
SECONDS_BETWEEN_CALLS = 1
