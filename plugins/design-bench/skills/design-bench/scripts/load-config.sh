#!/usr/bin/env bash
# load-config.sh — print .bench/config.yml from the project root, or report absence.
#
# Output contract (read by the design-bench skill):
#   On success:
#     CONFIG_FOUND: <absolute path>
#     ---
#     <raw YAML contents>
#   On absence:
#     CONFIG_MISSING
#     SUGGESTED_PATH: <absolute path where config should live>
#
# The skill then either parses the YAML inline (LLM reads stdout directly)
# or asks the user for the same fields interactively.

set -u

# Find project root: prefer git toplevel, fall back to PWD
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
CONFIG_PATH="$ROOT/.bench/config.yml"

if [ -f "$CONFIG_PATH" ]; then
  echo "CONFIG_FOUND: $CONFIG_PATH"
  echo "---"
  cat "$CONFIG_PATH"
  exit 0
fi

# Also check .bench/config.yaml (alternate extension)
ALT_PATH="$ROOT/.bench/config.yaml"
if [ -f "$ALT_PATH" ]; then
  echo "CONFIG_FOUND: $ALT_PATH"
  echo "---"
  cat "$ALT_PATH"
  exit 0
fi

echo "CONFIG_MISSING"
echo "SUGGESTED_PATH: $CONFIG_PATH"
exit 0
