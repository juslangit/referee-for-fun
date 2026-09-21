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
running=0
for n in "${names[@]}"; do
  run_one "$n" &
  running=$((running + 1))
  if [ "$running" -ge "$LIMIT" ]; then wait -n 2>/dev/null || wait; running=$((running - 1)); fi
done
wait

for kind in FAIL TIMEOUT "NO VERDICT" PASS; do
  list=$(cat "$OUT"/result_* 2>/dev/null | grep -a "^$kind	" | cut -f2 | sort | tr '\n' ' ')
  count=$(cat "$OUT"/result_* 2>/dev/null | grep -ac "^$kind	")
  printf '%-11s %3s   %s\n' "$kind" "$count" "$list"
  echo
done
