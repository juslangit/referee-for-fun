#!/usr/bin/env bash
# Runs every check in dev/checks and says what each one reported.
#
#   tools/checks/run_all.sh [pattern]
#
# There are over a hundred of them and until 2026-09-21 nobody had ever run them all in
# one go — they were run one at a time, by hand, when somebody was already suspicious.
# So the suite's real state was unknown: how many pass, how many fail, and how many print
# a wall of numbers and never say whether the numbers are good.
#
# Checks are run several at a time because most of the wall clock is Godot starting up.
# Each gets a hard timeout: a check that hangs is a failed check, and a scene whose script
# has a parse error spins to --quit-after rather than stopping, which is exactly what a
# timeout catches.
set -u
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
OUT=build/checks
LIMIT=${LIMIT:-4}
SECONDS_EACH=${SECONDS_EACH:-180}
pattern=${1:-}

mkdir -p "$OUT"
rm -f "$OUT"/*.log "$OUT"/result_*

run_one() {
  local name="$1"
  local log="$OUT/$name.log"
  # `perl` rather than `timeout`, which is not on a stock macOS.
  perl -e 'alarm shift; exec @ARGV' "$SECONDS_EACH" \
    "$GODOT" --headless --path . "res://dev/checks/$name.tscn" --quit-after 250000 \
    > "$log" 2>&1
  local code=$?
  local verdict
  if [ $code -ne 0 ] && ! grep -qaE '^(PASS|FAIL)' "$log"; then
    verdict="TIMEOUT"
  elif grep -qaE '^FAIL' "$log"; then
    verdict="FAIL"
  elif grep -qaE '^PASS' "$log"; then
    verdict="PASS"
  else
    verdict="NO VERDICT"
  fi
  printf '%s\t%s\n' "$verdict" "$name" > "$OUT/result_$name"
}

names=()
for f in dev/checks/*.tscn; do
  n=$(basename "$f" .tscn)
  [ -n "$pattern" ] && [[ "$n" != *"$pattern"* ]] && continue
  names+=("$n")
done

printf 'running %d checks, %d at a time\n\n' "${#names[@]}" "$LIMIT"
# A free slot is found by counting running jobs, not by `wait -n`.
#
# macOS ships bash 3.2, which has no `wait -n`. The first version of this used it with a
# fallback to plain `wait`, which waits for *every* job — so the suite ran one batch at a
# time, each batch as slow as its slowest member, with five of six slots idle while one
# check ground on. It looked like the checks were slow. The runner was.
for n in "${names[@]}"; do
  while [ "$(jobs -r | wc -l | tr -d ' ')" -ge "$LIMIT" ]; do sleep 0.3; done
  run_one "$n" &
done
wait

for kind in FAIL TIMEOUT "NO VERDICT" PASS; do
  list=$(cat "$OUT"/result_* 2>/dev/null | grep -a "^$kind	" | cut -f2 | sort | tr '\n' ' ')
  count=$(cat "$OUT"/result_* 2>/dev/null | grep -ac "^$kind	")
  printf '%-11s %3s   %s\n' "$kind" "$count" "$list"
  echo
done
