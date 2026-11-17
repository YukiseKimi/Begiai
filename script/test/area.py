#!/usr/bin/env python3 -I
import json
import sys
from pathlib import Path

areas = {a["id"]: a for a in json.loads((Path(__file__).resolve().parents[2] / "TestPlans/areas.json").read_text())["areas"]}
wanted = sys.argv[1]
if wanted not in areas:
    print(f"NO AREA {wanted} · areas: {', '.join(areas)}")
    sys.exit(2)
print("|".join(areas[wanted]["unit"]))
