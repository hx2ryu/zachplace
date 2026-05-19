#!/usr/bin/env bash
# test-harness.sh — minimal bash assertions for design-bench scripts.
# Source from each *.test.sh. Exits non-zero on first failure.

set -uo pipefail

TESTS_PASSED=0
TESTS_FAILED=0
CURRENT_TEST=""

it() {
  CURRENT_TEST="$1"
  echo "  • $CURRENT_TEST"
}

assert_eq() {
  local expected="$1" actual="$2"
  if [ "$expected" = "$actual" ]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "    FAIL: $CURRENT_TEST"
    echo "      expected: $expected"
    echo "      actual:   $actual"
  fi
}

assert_contains() {
  local haystack="$1" needle="$2"
  if echo "$haystack" | grep -qF "$needle"; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "    FAIL: $CURRENT_TEST"
    echo "      expected to contain: $needle"
    echo "      in:                  $haystack"
  fi
}

assert_file_exists() {
  local path="$1"
  if [ -f "$path" ]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "    FAIL: $CURRENT_TEST"
    echo "      expected file: $path"
  fi
}

finish() {
  echo ""
  echo "  passed: $TESTS_PASSED  failed: $TESTS_FAILED"
  [ $TESTS_FAILED -eq 0 ] || exit 1
}
