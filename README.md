# London's air, on repeat

## What I built and who for

## The data

Data from the London Air Quality Network, provided by the Environmental Research Group, Imperial College London, under the Open Government Licence v2. API: https://api.erg.ic.ac.uk/AirQuality/help

## How it works

![Second run adds 0 new rows](docs/second-run-no-duplicates.png)

## How to run it

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python pipeline/extract_load.py
```

## What I would do next

## Where AI helped
