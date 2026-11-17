#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
work="$HOME/Library/Caches/Begiai/gtfs"
mkdir -p "$work"
if [[ ${1:-} != --no-download ]]; then
  curl -fsS -L -o "$work/gtfs_all.zip" https://www.visimarsrutai.lt/gtfs/gtfs_all.zip
fi
rm -rf "$work/feed" && mkdir "$work/feed"
unzip -q -o "$work/gtfs_all.zip" "*.txt" -d "$work/feed"
date=$(unzip -Z -T "$work/gtfs_all.zip" routes.txt | awk '{print substr($(NF-1),1,8)}')
swift run --package-path BegiaiKit -c release begiai-bundle "$work/feed" "$date" Begiai/timetable.json 2>&1 | grep -vE '^\[|^Building|^Build complete'
