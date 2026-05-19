#!/usr/bin/env bash
# extract-tokens.test.sh — exercises all 5 fallback paths of extract-tokens.sh

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
EXTRACT="$ROOT/skills/research/scripts/extract-tokens.sh"
FIXTURES="$SCRIPT_DIR/fixtures"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/test-harness.sh"

echo "extract-tokens.sh"

it "emits :root block for CSS vars fixture"
OUT="$(bash "$EXTRACT" --search "$FIXTURES/tokens-css-vars" 2>/dev/null)"
assert_contains "$OUT" ":root {"
assert_contains "$OUT" "--color-primary: #2563eb"

it "extracts from tailwind config"
OUT="$(bash "$EXTRACT" --search "$FIXTURES/tokens-tailwind" 2>/dev/null)"
assert_contains "$OUT" "--color-primary: #7c3aed"
assert_contains "$OUT" "--radius-md: 8px"

it "extracts from tokens.json"
OUT="$(bash "$EXTRACT" --search "$FIXTURES/tokens-json" 2>/dev/null)"
assert_contains "$OUT" "--color-primary: #10b981"
assert_contains "$OUT" "--space-4: 16px"

it "emits neutral defaults when nothing is found"
OUT="$(bash "$EXTRACT" --search "$FIXTURES/tokens-empty" 2>/dev/null)"
ERR="$(bash "$EXTRACT" --search "$FIXTURES/tokens-empty" 2>&1 >/dev/null)"
assert_contains "$OUT" ":root {"
assert_contains "$OUT" "--color-primary:"
assert_contains "$ERR" "TOKENS_NOT_FOUND"

it "writes file when --out is given"
TMP="$(mktemp)"
bash "$EXTRACT" --search "$FIXTURES/tokens-css-vars" --out "$TMP" >/dev/null 2>&1
assert_file_exists "$TMP"
assert_contains "$(cat "$TMP")" "--color-primary: #2563eb"
rm -f "$TMP"

finish
