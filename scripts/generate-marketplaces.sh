#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
command -v node >/dev/null 2>&1 || { echo "node is required" >&2; exit 1; }
node "$ROOT/scripts/generate-marketplaces.mjs"
