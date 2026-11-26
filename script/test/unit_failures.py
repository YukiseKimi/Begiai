#!/usr/bin/env python3 -I
"""unit_failures.py <log> <tests folder>: prints each failure in a swift test log, with a
rerun: line. It never prints nothing: after a crash it names each test still running."""
import re
import sys
from pathlib import Path

log, tests = Path(sys.argv[1]), Path(sys.argv[2])
# Swift Testing starts each line with a symbol that differs by platform (an SF Symbol on
# macOS, ✘ elsewhere), so the patterns skip it.
lines = [re.sub(r"\x1b\[[0-9;]*[A-Za-z]", "", line) for line in log.read_text(errors="replace").splitlines()]
NAME = r'("[^"]*"|[^ (]+\([^)]*\))'
ISSUE = re.compile(rf"^\S+ +Test {NAME} recorded an issue (?:with (.+) )?at ([^:]+:\d+:\d+): (.*)$")
DETAIL = re.compile(r"^\S+  (?!Test |Suite )(.*)$")
STARTED = re.compile(rf"^\S+ +Test {NAME} started\.$")
FINISHED = re.compile(rf"^\S+ +Test {NAME} (?:with \d+ test cases? )?(?:passed|failed|skipped)")


def rerun(name, place):
    """A filter that runs this one test. A display name is not an identifier swift test can
    filter by, so the test's function is found in its file."""
    if not name.startswith('"'):
        return f"rerun: script/test.sh unit --filter '/{name.split('(')[0]}\\('"
    file = place.split(":")[0] if place else ""
    for source in tests.rglob(file or "*.swift"):
        found = re.search(r"@Test\(\s*" + re.escape(name) + r"[^\n]*\)\s*func\s+(\w+)", source.read_text())
        if found:
            return f"rerun: script/test.sh unit --filter '/{found.group(1)}\\('"
    return f"rerun: script/test.sh unit --filter '{Path(file).stem}'" if file else "rerun: script/test.sh unit"


printed = False
for index, line in enumerate(lines):
    issue = ISSUE.match(line)
    if not issue:
        continue
    name, case, place, message = issue.groups()
    print(f"✗ {name}" + (f" with {case}" if case else ""))
    print(f"  {message} · {place}")
    # The lines after an expectation give its comment first, then the values of its expression.
    expression = message.removeprefix("Expectation failed: ")
    for detail in lines[index + 1 :]:
        found = DETAIL.match(detail)
        if not found or found.group(1).startswith(expression + " → ") or found.group(1).startswith(expression + " ->"):
            break
        print(f"  {found.group(1)}")
    print(f"  {rerun(name, place)}")
    printed = True

crashed = any("Fatal error" in line or "exited with unexpected signal" in line for line in lines)
if crashed or not printed:
    # The test process stopped, or no issue was recorded: say why, and which test was running.
    for line in lines:
        if "Fatal error" in line:
            print(f"  {line.strip()}")
        elif line.startswith("error:"):
            signal = re.search(r"exited with unexpected signal code \d+", line)
            print(f"  error: the test process {signal.group(0)}" if signal else f"  {line[:300]}")
    started = [m.group(1) for m in map(STARTED.match, lines) if m]
    finished = {m.group(1) for m in map(FINISHED.match, lines) if m}
    running = [name for name in started if name not in finished]
    if running:
        # Tests run side by side, so the last one started is not always the one that crashed:
        # each one still running gets its own rerun line.
        print("✗ the process stopped while these tests ran; rerun each alone to find the cause:")
        for name in running:
            print(f"  {name} · {rerun(name, None)}")
    else:
        print("  no test was named; the log's last lines:")
        for line in [line for line in lines if line.strip()][-5:]:
            print(f"  {line[:300]}")
