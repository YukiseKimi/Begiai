#!/bin/bash
# Records the map with the trains moving and writes docs/map.gif for the README.
#   BEGIAI_SIM=<udid> script/readme-gif.sh
# The simulator should be an iPhone 17 Pro, en_US, with the status bar at 9:41 (as in
# Store/Screenshots/notes.md). The Debug app runs a sealed launch on the frozen timetable
# of 17 Nov 2026 from 07:20 in Vilnius, with the clock 60 times faster than real time, so
# after the 10 s wait for the map tiles the recording starts at about 07:30.
# It leaves the simulator in light mode.
set -euo pipefail
command -v ffmpeg >/dev/null || { echo "readme-gif: needs ffmpeg"; exit 1; }
cd "$(dirname "$0")/.."
: "${BEGIAI_SIM:?set BEGIAI_SIM to the UDID of the recording simulator}"
speed=${SPEED:-60}
seconds=${SECONDS_LONG:-12}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

xcodebuild -project Begiai.xcodeproj -scheme Begiai -configuration Debug \
  -destination "id=$BEGIAI_SIM" -derivedDataPath "$work/dd" build -quiet
app=$(ls -d "$work"/dd/Build/Products/Debug-iphonesimulator/Begiai.app)
bundle=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app/Info.plist")

xcrun simctl ui "$BEGIAI_SIM" appearance light
xcrun simctl install "$BEGIAI_SIM" "$app"
xcrun simctl terminate "$BEGIAI_SIM" "$bundle" 2>/dev/null || true
xcrun simctl launch "$BEGIAI_SIM" "$bundle" --sealed --reset --now 2026-11-17T05:20:00Z \
  --timetable "$PWD/Fixtures/timetable-20261117.json" --speed "$speed"
# Let the map tiles load before the recording starts.
sleep 10

xcrun simctl io "$BEGIAI_SIM" recordVideo --codec h264 --force "$work/map.mp4" &
recorder=$!
sleep "$seconds"
kill -INT "$recorder"
wait "$recorder" || true

mkdir -p docs
# The top 62% of the screen: the map and the panel's header, without its list.
filters="fps=12,crop=iw:ih*0.62:0:0,scale=360:-1:flags=lanczos"
ffmpeg -loglevel error -y -i "$work/map.mp4" -vf "$filters,palettegen=stats_mode=diff" "$work/palette.png"
ffmpeg -loglevel error -y -i "$work/map.mp4" -i "$work/palette.png" \
  -lavfi "$filters [x]; [x][1:v] paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle" docs/map.gif
ls -l docs/map.gif
