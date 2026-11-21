import requests

url = "https://api.erg.ic.ac.uk/AirQuality/Information/MonitoringSites/GroupName=London/Json"
sites = requests.get(url, timeout=60).json()["Sites"]["Site"]

for s in sites:
    if s["@LocalAuthorityName"] in ("Sutton", "Merton") and not s["@DateClosed"]:
        print(s["@SiteCode"], "|", s["@SiteName"], "|", s["@SiteType"])