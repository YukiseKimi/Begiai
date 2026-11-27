---
description: Run one UI journey several times on a simulator and report each run, to check whether it is flaky
argument-hint: <Journey>[/<test>] <count> [<simulator UDID>]
---

Run the journey `$1` $2 times, one run after another, on the simulator `$3`. If no UDID is given, use `$BEGIAI_SIM`.

- Run each time `script/test.sh journey $1`, adding `--no-build` after the first run, under `bash -c` so the arguments split the same way in every shell.
- Run in the background if the runs take long. Never run two lanes at once.
- If the simulator is an iPhone Duo, never change its posture.
- Report one line per run: GREEN, or RED with the failing step and its `rerun:` line. Then report the pass count, for example "4 of 5 GREEN".
- On a RED run, name the run's log and xcresult under `~/Library/Caches/Begiai/*/runs/`.
- Do not edit code in this command.
