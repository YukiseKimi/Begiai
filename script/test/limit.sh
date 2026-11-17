#!/bin/bash
limit=$1 lane=$2
shift 2
work=$(mktemp -d -t lane) || exit 4
trap 'rm -rf "$work"' EXIT
mkfifo "$work/out"

tree() { local child; for child in $(pgrep -P "$1"); do echo "$child"; tree "$child"; done; }

set -m
NO_COLOR=1 script -q /dev/null "$@" < /dev/null > "$work/out" 2>&1 &
command=$!
( sleep "$limit"; echo "$command $(tree "$command")" > "$work/tree"
  : > "$work/timeout"; kill -TERM $(cat "$work/tree") ) > /dev/null 2>&1 &
watchdog=$!
disown "$watchdog"
set +m
LC_ALL=C tr -d '\r\010' < "$work/out" | LC_ALL=C sed -l 's/^\^D//' | tee "$work/log" &
tee=$!

wait "$command" 2> /dev/null
code=$?
kill -- -"$watchdog" 2> /dev/null
if [[ -e $work/timeout ]]; then
  pids=$(cat "$work/tree")
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    alive=; for pid in $pids; do kill -0 "$pid" 2> /dev/null && alive=1; done
    [[ -n $alive ]] || break; sleep 1
  done
  kill -KILL $pids 2> /dev/null
fi
kill -TERM -- -"$command" 2> /dev/null
wait "$tee"

if [[ -e $work/timeout ]]; then
  grep -avE 'recorded an issue|Test run (started|with)' "$work/log" > "$work/lines"
  sed -nE "s/.*Test (Case '([^']+)'|(.+)) started\.\$/\2\3/p" "$work/lines" | sort -u > "$work/started"
  sed -nE "s/.*Test (Case '([^']+)'|(.+)) (passed|failed|skipped)( .*|\.|:.*)?\$/\2\3/p" "$work/lines" \
    | sort -u > "$work/ended"
  still=$(comm -23 "$work/started" "$work/ended" | paste -sd, - | sed 's/,/, /g')
  echo "TIMEOUT $lane · stopped after $limit s · still running: ${still:-no test had started}"
  exit 124
fi
exit "$code"
