#!/bin/bash
# Builds the timetable bundle from the nightly GTFS of visimarsrutai.lt.
#   script/bundle.sh                  writes Begiai/timetable.json, the copy that the app ships
#   script/bundle.sh <folder>         writes <folder>/timetable.json and <folder>/manifest.json, for GitHub Pages
#   --no-download                     uses the zip from the last run
set -euo pipefail
cd "$(dirname "$0")/.."
download=yes
site=""
for argument in "$@"; do
  case $argument in
    --no-download) download=no ;;
    *) site=$argument ;;
  esac
done
work="$HOME/Library/Caches/Begiai/gtfs"
mkdir -p "$work"
if [[ $download == yes ]]; then
  curl -fsS -L -o "$work/gtfs_all.zip" https://www.visimarsrutai.lt/gtfs/gtfs_all.zip
fi
rm -rf "$work/feed" && mkdir "$work/feed"
unzip -q -o "$work/gtfs_all.zip" "*.txt" -d "$work/feed"
date=$(unzip -Z -T "$work/gtfs_all.zip" routes.txt | awk '{print substr($(NF-1),1,8)}')
if [[ -n $site ]]; then
  mkdir -p "$site"
  set -- "$site/timetable.json" --manifest "$site/manifest.json"
else
  set -- Begiai/timetable.json
fi
swift run --package-path BegiaiKit -c release begiai-bundle "$work/feed" "$date" "$@" 2>&1 | grep -vE '^\[|^Building|^Build complete'
