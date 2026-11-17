#!/usr/bin/env python3 -I
import re
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[2]
source = (root / "Begiai/A11yID.swift").read_text()
table_path = root / "A11yID.md"

constants = {}
scope = []
for line in source.splitlines():
    if m := re.match(r"\s*(?:enum|struct) (\w+)[^{]*\{\s*$", line):
        scope.append(m.group(1))
    elif re.search(r"\{\s*$", line):
        scope.append(None)
    elif m := re.match(r'\s*static let (\w+) = "([^"]+)"', line):
        constants[".".join([n for n in scope[1:] if n] + [m.group(1)])] = m.group(2)
    elif re.match(r"\s*\}\s*$", line) and scope:
        scope.pop()

rows = re.findall(r'Entry\(id: ([\w.]+), element: "([^"]+)", screen: "([^"]+)"\)', source)
named = {ref for ref, _, _ in rows}
missing = sorted(set(constants) - named)
unknown = sorted(named - set(constants))

table = "# Accessibility identifiers\n\nGenerated from `Begiai/A11yID.swift` by `script/test.sh a11y`. Do not edit.\n\n"
table += "| Identifier | Element | Screen |\n| --- | --- | --- |\n"
table += "".join(f"| `{constants.get(ref, ref)}` | {element} | {screen} |\n" for ref, element, screen in rows)

if missing or unknown:
    print("A11Y CHECK FAILED")
    for ref in missing:
        print(f"  {ref} has no Entry row: add one to A11yID.entries")
    for ref in unknown:
        print(f"  Entry {ref} names no identifier")
    sys.exit(1)

if "--check" in sys.argv:
    if not table_path.exists() or table_path.read_text() != table:
        print("A11Y CHECK FAILED A11yID.md is stale: run script/test.sh a11y")
        sys.exit(1)
    print(f"A11Y OK {len(rows)} identifiers")
else:
    table_path.write_text(table)
    print(f"A11Y wrote A11yID.md · {len(rows)} identifiers")
