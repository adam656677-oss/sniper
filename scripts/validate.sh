#!/usr/bin/env bash
# Local mirror of the CI validation steps. Exit code 0 means every suite passed.
#
#   GODOT=/path/to/Godot_v4.7-stable_linux.x86_64 scripts/validate.sh
#   scripts/validate.sh --export     # also export the Windows debug build
#
# Only "SCRIPT ERROR:" and "FAIL:" lines fail a step. The headless dummy renderer
# prints 'ERROR: Parameter "m" is null' when BoxMesh nodes are created without a
# display; that line is benign and is ignored here.
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"
REPORTS=reports
mkdir -p "$REPORTS"
failures=0

run_step() {
  local name="$1"; shift
  local log="$REPORTS/$name.log"
  echo "== $name"
  if ! timeout 120s "$GODOT" --headless --path . "$@" >"$log" 2>&1; then
    echo "   process exited non-zero (see $log)"
    cat "$log"
    failures=$((failures + 1))
    return
  fi
  if grep -E 'SCRIPT ERROR:|FAIL:' "$log"; then
    echo "   FAILED (see $log)"
    failures=$((failures + 1))
  else
    grep -E 'PASSED|checks, 0 failures|Checks:' "$log" || true
  fi
}

run_step import --editor --quit
for path in tests/*.gd; do
  suite="$(basename "$path" .gd)"
  run_step "$suite" --script "res://tests/$suite.gd"
done

if [ "${1:-}" = "--export" ]; then
  mkdir -p builds/windows
  run_step export --export-debug "Windows Desktop" builds/windows/EchoRidge.exe
  test -s builds/windows/EchoRidge.exe && test -s builds/windows/EchoRidge.pck && echo "   build present"
fi

echo
if [ "$failures" -eq 0 ]; then
  echo "ALL VALIDATION STEPS PASSED"
else
  echo "$failures step(s) failed"
  exit 1
fi
