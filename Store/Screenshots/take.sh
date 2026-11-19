#!/bin/bash
# Takes the iPhone App Store shots into Store/Screenshots/runs/<run>/shots/iPhone.
#   BEGIAI_SIM=<udid> Store/Screenshots/take.sh <run>
# The simulator must be the one that shots.json names, set up as notes.md says
# (an iPhone 17 Pro, en_US, the status bar at 9:41). It sets light mode for the light
# shots and dark mode for the dark one, then light again.
set -uo pipefail
cd "$(dirname "$0")/../.."
run=${1:?usage: BEGIAI_SIM=<udid> Store/Screenshots/take.sh <run>}
: "${BEGIAI_SIM:?set BEGIAI_SIM to the UDID of the slides simulator}"
out="$PWD/Store/Screenshots/runs/$run/shots/iPhone"
mkdir -p "$out"
export TEST_RUNNER_BEGIAI_SHOTS="$out"

light=(StoreShotsJourney/test01Map StoreShotsJourney/test02Train StoreShotsJourney/test03LineDiagram
  StoreShotsJourney/test04Board StoreShotsJourney/test06About)
dark=(StoreShotsJourney/test05MapDark)

xcrun simctl ui "$BEGIAI_SIM" appearance light
script/test.sh journey "${light[@]}" || exit $?
xcrun simctl ui "$BEGIAI_SIM" appearance dark
script/test.sh journey "${dark[@]}" --no-build
code=$?
xcrun simctl ui "$BEGIAI_SIM" appearance light
[[ $code == 0 ]] || exit $code
python3 -I "$HOME/.claude/skills/app-store-story-slides/scripts/check_slides.py" "$out"
echo "shots: $out"
