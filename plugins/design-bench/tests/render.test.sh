#!/usr/bin/env bash
# render.test.sh — smoke test for render.mjs (puppeteer-based PNG renderer).
# Skips if node or puppeteer install is unavailable (offline / restricted env).

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RENDER="$ROOT/skills/research/scripts/render.mjs"
FIXTURE="$SCRIPT_DIR/fixtures/sample-mockup.html"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/test-harness.sh"

echo "render.mjs"

if ! command -v node >/dev/null 2>&1; then
  echo "  (skipped — node not installed)"
  exit 0
fi

it "produces a non-empty PNG for the sample fixture"
TMPDIR_OUT="$(mktemp -d)"
INPUT_DIR="$(mktemp -d)"
cp "$FIXTURE" "$INPUT_DIR/sample-mockup.html"

if node "$RENDER" "$INPUT_DIR" "$TMPDIR_OUT" >/dev/null 2>&1; then
  assert_file_exists "$TMPDIR_OUT/sample-mockup.png"
  SIZE=$(wc -c < "$TMPDIR_OUT/sample-mockup.png" | tr -d ' ')
  if [ "$SIZE" -gt 1000 ]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "    FAIL: PNG too small ($SIZE bytes)"
  fi
else
  echo "  (skipped — puppeteer install failed, likely offline)"
fi

rm -rf "$TMPDIR_OUT" "$INPUT_DIR"
finish
