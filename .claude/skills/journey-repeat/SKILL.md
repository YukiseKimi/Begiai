---
name: journey-repeat
description: Run one UI journey several times on a simulator and report each run, to check whether it is flaky
argument-hint: <Journey>[/<test>] <count> [simulator UDID or name]
---

Check whether a journey is flaky. Do not edit code or tests here.

1. Pick the simulator: the one the user names, else `$BEGIAI_SIM`. If neither is set, take the
   device for the journey from the `matrix` in `TestPlans/areas.json` (for a Duo question, the
   iPhone Duo) and say which UDID you used.
2. Another session may hold the test lock. `script/test.sh` then prints
   `BUSY test run <pid> holds …` and runs nothing. Do not stop that run. Find what started it
   (`ps -o ppid= -p <pid>`): if a loop of groups started it, wait for the loop's pid, not
   the one group's, or the next group takes the lock again.
3. In one background command: wait while that pid lives, then run
   `BEGIAI_SIM=<udid> script/test.sh journey <Journey>` `<count>` times, one after another, with
   `--no-build` on every run after the first, printing `--- run <n>` and the lane's last lines.
4. Report one line per run (GREEN, or RED with the failing step and its `rerun:` line), then
   the pass count, the simulator and iOS version, and the commit tested (`git rev-parse --short HEAD`).
   If any run printed BUSY, say that it did not run; it is not a pass.
