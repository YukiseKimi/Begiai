#!/usr/bin/env python3 -I
import json
import subprocess
import sys

bundle, lane, rerun, seconds = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]


def results(kind):
    try:
        out = subprocess.run(
            ["xcrun", "xcresulttool", "get", "test-results", kind, "--path", bundle, "--compact"],
            capture_output=True, text=True, timeout=60,
        )
    except subprocess.TimeoutExpired:
        print(f"NO RESULT {lane} · xcresulttool took over 60 s on {bundle}")
        sys.exit(4)
    if out.returncode != 0:
        print(f"NO RESULT {lane} · xcresulttool failed on {bundle}: {out.stderr.strip()[:300]}")
        sys.exit(4)
    return json.loads(out.stdout)


summary = results("summary")
tests = results("tests")
device = (summary.get("devicesAndConfigurations") or [{}])[0].get("device", {})
where = f"{device.get('modelName', '?')} · {device.get('platform', '')} {device.get('osVersion', '')}".strip()

failures, passed, skipped, skips_why = [], 0, 0, []


def walk(node, trail):
    global passed, skipped
    kind = node.get("nodeType")
    if kind == "Test Case":
        if node.get("result") == "Passed":
            passed += 1
        elif node.get("result") == "Skipped":
            skipped += 1
            notes = [c.get("name", "") for c in node.get("children", []) if "Message" in c.get("nodeType", "")]
            skips_why.append((trail + [node.get("name", "")], notes))
        elif node.get("result") == "Failed":
            notes = [c.get("name", "") for c in node.get("children", []) if c.get("nodeType") == "Failure Message"]
            failures.append((trail + [node.get("name", "")], notes))
        return
    for child in node.get("children", []):
        walk(child, trail + ([node["name"]] if kind == "Test Suite" else []))


for node in tests.get("testNodes", []):
    walk(node, [])


def why_skipped():
    for trail, notes in skips_why:
        suite, name = trail[-2] if len(trail) > 1 else "", trail[-1].removesuffix("()")
        print(f"– {suite}/{name} skipped: {' '.join(notes) or 'no reason given'}")


# A journey that does not apply to the device skips, such as the Duo's column on an iPhone.
# Each skip prints its reason, so a skip that hides a fault shows in the lane's output.
skips = f" · {skipped} skipped" if skipped else ""
if not failures and passed == 0:
    print(f"SKIPPED all {skipped} tests · {lane} · {where}" if skipped else f"NO TESTS ran · {lane}")
    why_skipped()
    sys.exit(0 if skipped else 3)
if not failures:
    print(f"GREEN {passed} tests{skips} · {lane} · {where} · {seconds} s")
    why_skipped()
    sys.exit(0)
print(f"RED {len(failures)} failures · {passed} passed{skips} · {lane} · {where}")
why_skipped()
for trail, notes in failures:
    suite, name = trail[-2] if len(trail) > 1 else "", trail[-1].removesuffix("()")
    print(f"✗ {suite}/{name}")
    for note in notes:
        print(f"  {note}")
    print(f"  rerun: {rerun} {suite}/{name}")
sys.exit(65)
