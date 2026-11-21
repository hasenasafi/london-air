import time
from datetime import date, timedelta
import requests

BASE = "https://api.erg.ic.ac.uk/AirQuality"
BOROUGHS = ["Sutton", "Merton", "Croydon", "Kingston", "Wandsworth"]

sites = requests.get(f"{BASE}/Information/MonitoringSites/GroupName=London/Json", timeout=60).json()["Sites"]["Site"]

print("=== Sutton sites, including closed ones ===")
for s in sites:
    if "Sutton" in s["@LocalAuthorityName"]:
        print(s["@SiteCode"], "|", s["@SiteName"], "| closed:", s["@DateClosed"] or "still open")

def species_with_data(node, found):
    # Look through the whole response for readings that have a value
    if isinstance(node, dict):
        if node.get("@SpeciesCode") and node.get("@Value"):
            found.add(node["@SpeciesCode"])
        for v in node.values():
            species_with_data(v, found)
    elif isinstance(node, list):
        for v in node:
            species_with_data(v, found)
    return found

start = (date.today() - timedelta(days=3)).isoformat()
end = date.today().isoformat()

print("\n=== Open sites nearby and what they measured in the last 3 days ===")
for s in sites:
    if any(b in s["@LocalAuthorityName"] for b in BOROUGHS) and not s["@DateClosed"]:
        data = requests.get(f"{BASE}/Data/Site/SiteCode={s['@SiteCode']}/StartDate={start}/EndDate={end}/Json", timeout=60).json()
        found = species_with_data(data, set())
        print(s["@SiteCode"], "|", s["@SiteName"], "|", s["@SiteType"], "|", ", ".join(sorted(found)) or "no recent data")
        time.sleep(1)