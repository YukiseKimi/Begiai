#!/bin/bash
# Records the map around Vilnius in dark mode with the trains moving, and writes docs/map.gif
# for the README.
#   BEGIAI_SIM=<udid> script/readme-gif.sh
# The simulator should be an iPhone 17 Pro, en_US, with the status bar at 9:41 (as in
# Store/Screenshots/notes.md). The drive StoreShotsJourney/test07MapTimelapse launches the
# sealed app on the frozen timetable of 17 Nov 2026 at 07:20 in Vilnius, with the clock 60
# times faster, zooms to Vilnius, and writes a `ready` file; this script then records 12 s.
# It sets the simulator to dark mode, and back to light when it ends.
set -uo pipefail
cd "$(dirname "$0")/.."
: "${BEGIAI_SIM:?set BEGIAI_SIM to the UDID of the recording simulator}"
command -v ffmpeg >/dev/null || { echo "readme-gif: needs ffmpeg"; exit 1; }
seconds=${SECONDS_LONG:-12}
work=$(mktemp -d)
trap 'xcrun simctl ui "$BEGIAI_SIM" appearance light; rm -rf "$work"' EXIT

xcrun simctl ui "$BEGIAI_SIM" appearance dark || exit 1
export TEST_RUNNER_BEGIAI_SHOTS="$work/drive"
script/test.sh journey StoreShotsJourney/test07MapTimelapse > "$work/drive.log" 2>&1 &
drive=$!

# The build and the zoom take a minute or two.
for _ in $(seq 1 300); do
  [[ -f "$work/drive/ready" ]] && break
  if ! kill -0 "$drive" 2>/dev/null; then
    echo "readme-gif: the drive ended before the map was ready"; cat "$work/drive.log"; exit 1
  fi
  sleep 1
done
[[ -f "$work/drive/ready" ]] || {
  echo "readme-gif: the map was never ready"; pkill -P "$drive"; kill "$drive"; exit 1
}

xcrun simctl io "$BEGIAI_SIM" recordVideo --codec h264 --force "$work/map.mp4" &
recorder=$!
sleep "$seconds"
kill -INT "$recorder"
wait "$recorder"
wait "$drive" || { echo "readme-gif: the drive failed"; cat "$work/drive.log"; exit 1; }

mkdir -p docs
# The top 62% of the screen: the map and the panel's header, without its list.
filters="fps=12,crop=iw:ih*0.62:0:0,scale=360:-1:flags=lanczos"
ffmpeg -loglevel error -y -i "$work/map.mp4" -vf "$filters,palettegen=stats_mode=diff" "$work/palette.png" || exit 1
ffmpeg -loglevel error -y -i "$work/map.mp4" -i "$work/palette.png" \
  -lavfi "$filters [x]; [x][1:v] paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle" docs/map.gif || exit 1
ls -l docs/map.gif
