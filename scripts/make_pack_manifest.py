#!/usr/bin/env python3
"""Writes the Background Assets manifest for one journey's asset pack.

Delivery memo 2026-09-26: one Apple-hosted pack per paid journey, pack id =
journeyId, holding <journeyId>/<fileStem>.m4a exactly as the pipeline
delivered them, downloaded on demand after purchase. Run from the root of the
uptime-ios-audio checkout; prints the manifest to stdout.
"""
import json
import os
import sys

journey = sys.argv[1]
files = sorted(f for f in os.listdir(journey) if f.endswith(".m4a"))
if not files:
    sys.exit(f"no .m4a files in {journey}/")
print(json.dumps({
    "assetPackID": journey,
    "downloadPolicy": {"onDemand": {}},
    "fileSelectors": [{"file": f"{journey}/{name}"} for name in files],
    "platforms": ["iOS"],
}, indent=2))
