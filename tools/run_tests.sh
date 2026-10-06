#!/usr/bin/env bash
# Runs every tests/*_test.gd headlessly and prints one line per test.
# Usage: tools/run_tests.sh [godot-binary] [name-filter]
GODOT="${1:-godot}"
FILTER="${2:-}"
cd "$(dirname "$0")/.." || exit 2
mkdir -p .test_logs
# Refresh the script class cache and imports first, so new scripts/assets are known.
timeout 300 "$GODOT" --headless --editor --quit --path . > .test_logs/_import.log 2>&1
pass=0; fail=0; failed=()
for t in tests/*_test.gd; do
  name="$(basename "$t" .gd)"
  [[ -n "$FILTER" && "$name" != *"$FILTER"* ]] && continue
  start=$(date +%s)
  timeout 600 "$GODOT" --headless --path . -s "res://$t" > ".test_logs/$name.log" 2>&1
  code=$?
  secs=$(( $(date +%s) - start ))
  if [[ $code -eq 0 ]]; then pass=$((pass+1)); printf "PASS %-45s %4ss\n" "$name" "$secs"
  else fail=$((fail+1)); failed+=("$name"); printf "FAIL %-45s %4ss (exit %s)\n" "$name" "$secs" "$code"
    grep -E "ERROR|SCRIPT ERROR|Parse Error|FAILED" ".test_logs/$name.log" | grep -v "root certificate" | head -5 | sed 's/^/     /'
  fi
done
echo "TOTAL pass=$pass fail=$fail"
[[ $fail -eq 0 ]]
