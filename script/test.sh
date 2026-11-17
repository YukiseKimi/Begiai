#!/bin/bash
set -uo pipefail
cd "$(dirname "$0")/.."
ROOT=$PWD
CACHE="$HOME/Library/Caches/Begiai/$(echo "$ROOT" | shasum | cut -c1-8)"
DERIVED="$CACHE/DerivedData"
RUNS="$CACHE/runs"
mkdir -p "$RUNS"
UNIT_LIMIT=90
JOURNEY_LIMIT=360

usage() {
  cat <<'USAGE'
script/test.sh <lane>
  unit [--area <id> | --filter <test>]
                              the logic package, headless (swift test)
  journey [<Journey>[/<test>] ...] [--no-build]
                              the UI journeys on $BEGIAI_SIM (a simulator UDID)
  build                       Release, unsigned, and the sealed-launch check
  a11y [--check]              writes A11yID.md from A11yID.swift, or checks it
  all                         a11y --check, unit, build, journey
USAGE
  exit 2
}

lock() {
  shlock -f "$CACHE/run.pid" -p $$ || { echo "BUSY test run $(cat "$CACHE/run.pid") holds $CACHE"; exit 4; }
  trap 'rm -f "$CACHE/run.pid"' EXIT
}

lane_a11y() {
  local out
  out=$(python3 -I script/test/a11y.py "$@") || { echo "$out"; exit 1; }
  echo "$out"
}

lane_unit() {
  local filter=()
  case ${1:-} in
    --area)
      [[ -n ${2:-} ]] || usage
      local targets
      targets=$(python3 -I script/test/area.py "$2") || { echo "$targets"; exit 2; }
      filter=(--filter "^(${targets})\\.") ;;
    --filter)
      [[ -n ${2:-} ]] || usage
      filter=(--filter "$2") ;;
    "") ;;
    *) usage ;;
  esac
  local start=$SECONDS log="$RUNS/unit.log"
  (cd BegiaiKit && timeout 600 swift build --build-tests --scratch-path "$CACHE/package" > "$log" 2>&1) || {
    echo "BUILD FAILED unit · log: $log"; grep -E 'error:' "$log" | head -20; exit 65; }
  (cd BegiaiKit && "$ROOT/script/test/limit.sh" "$UNIT_LIMIT" unit swift test --skip-build --scratch-path "$CACHE/package" ${filter[@]+"${filter[@]}"}) > "$log" 2>&1
  local code=$?
  if [[ $code == 124 ]]; then grep TIMEOUT "$log"; exit 124; fi
  local count
  count=$(grep -oE 'Test run with [0-9]+ test' "$log" | grep -oE '[0-9]+' | tail -1)
  if [[ $code == 0 ]]; then
    echo "GREEN ${count:-0} tests · unit · $((SECONDS - start)) s"
  else
    echo "RED unit · log: $log"
    grep -E '✘ Test .* recorded an issue at ' "$log" | sed -E "s/.*✘ Test (.+)\\(\\) recorded an issue at ([^:]+:[0-9]+:[0-9]+): (.*)/✗ \\1\\n  \\3 · \\2\\n  rerun: script\\/test.sh unit --filter '\\1'/"
    exit 65
  fi
}

simulator() {
  [[ -n ${BEGIAI_SIM:-} ]] || { echo "NO SIMULATOR set BEGIAI_SIM to the UDID of this task's simulator"; exit 4; }
  echo "platform=iOS Simulator,id=$BEGIAI_SIM"
}

lane_journey() {
  local build=1 selectors=()
  for word in "$@"; do
    case $word in
      --no-build) build=0 ;;
      *) selectors+=("-only-testing:BegiaiUITests/$word") ;;
    esac
  done
  local check
  check=$(lane_a11y --check) || { echo "$check"; exit 1; }
  local destination; destination=$(simulator) || { echo "$destination"; exit 4; }
  local stamp; stamp=$(date +%Y%m%d-%H%M%S)
  local bundle="$RUNS/journey-$stamp.xcresult" log="$RUNS/journey-$stamp.log"
  if [[ $build == 1 ]]; then
    local start=$SECONDS
    timeout 900 xcodebuild build-for-testing -scheme Begiai -destination "$destination" \
      -derivedDataPath "$DERIVED" > "$log" 2>&1 || {
      echo "BUILD FAILED journey · log: $log"; grep -E 'error:' "$log" | sort -u | head -20; exit 65; }
    echo "BUILT $((SECONDS - start)) s"
  fi
  local start=$SECONDS
  script/test/limit.sh "$JOURNEY_LIMIT" journey xcodebuild test-without-building -scheme Begiai \
    -destination "$destination" -derivedDataPath "$DERIVED" ${selectors[@]+"${selectors[@]}"} \
    -parallel-testing-enabled NO -test-timeouts-enabled YES \
    -default-test-execution-time-allowance 120 -maximum-test-execution-time-allowance 300 \
    -resultBundlePath "$bundle" >> "$log" 2>&1
  local code=$?
  if [[ $code == 124 ]]; then
    xcrun simctl terminate "$BEGIAI_SIM" app.begiai.Begiai 2> /dev/null
    xcrun simctl terminate "$BEGIAI_SIM" app.begiai.BegiaiUITests.xctrunner 2> /dev/null
    grep TIMEOUT "$log"; exit 124
  fi
  [[ -d $bundle ]] || { echo "NO RESULT journey · log: $log"; tail -20 "$log"; exit 4; }
  python3 -I script/test/report.py "$bundle" journey "script/test.sh journey" "$((SECONDS - start))"
  local verdict=$?
  if [[ $verdict == 65 ]]; then
    local shots="$RUNS/journey-$stamp-shots"
    mkdir -p "$shots"
    timeout 60 xcrun xcresulttool export attachments --path "$bundle" --output-path "$shots" > /dev/null 2>&1
    for shot in "$shots"/*.png; do
      [[ -e $shot ]] || continue
      local look="${shot%.png}-look.png"
      sips -Z 874 "$shot" --out "$look" > /dev/null 2>&1
      echo "shot: $shot"
      echo "look: $look · ~470 tok"
    done
  elif [[ $verdict == 0 ]]; then
    echo "$verdict" > "$RUNS/journey-$stamp.passed"
    rm -rf "$bundle"
    echo "clean removed the result bundle of a passed run"
  fi
  exit $verdict
}

lane_build() {
  local log="$RUNS/build.log" app
  timeout 900 xcodebuild build -scheme Begiai -configuration Release -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$DERIVED" CODE_SIGNING_ALLOWED=NO > "$log" 2>&1 || {
    echo "BUILD FAILED build · log: $log"; grep -E 'error:' "$log" | sort -u | head -20; exit 65; }
  app="$DERIVED/Build/Products/Release-iphonesimulator/Begiai.app"
  local sealed
  sealed=$(/usr/libexec/PlistBuddy -c 'Print :BegiaiSealedLaunch' "$app/Info.plist" 2> /dev/null)
  [[ $sealed == NO ]] || { echo "SEALED CHECK FAILED the Release app has BegiaiSealedLaunch=$sealed, not NO"; exit 65; }
  echo "GREEN build · Release · sealed launch off"
}

lane=${1:-}; shift || true
case $lane in
  a11y) lane_a11y "$@" ;;
  unit) lock; lane_unit "$@" ;;
  journey) lock; lane_journey "$@" ;;
  build) lock; lane_build ;;
  all) lock; lane_a11y --check && lane_unit && lane_build && lane_journey ;;
  *) usage ;;
esac
