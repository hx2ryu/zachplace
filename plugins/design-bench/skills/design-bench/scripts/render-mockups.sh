#!/usr/bin/env bash
# render-mockups.sh — render every HTML file in INPUT_DIR to PNG in OUTPUT_DIR.
#
# Prefers a project-local headless browser (gstack/browse) if available,
# otherwise falls back to render.mjs (puppeteer via npx).
#
# Usage: render-mockups.sh <input_dir> <output_dir>
#
# Output contract:
#   On success:  prints "RENDER_OK <count> file(s) → <output_dir>"
#   On no-tool:  prints "RENDER_SKIPPED no_headless_browser" to stderr
#   On failure:  prints "RENDER_FAILED <reason>" to stderr, exit code 1

set -uo pipefail

INPUT_DIR="${1:-}"
OUTPUT_DIR="${2:-}"

[ -n "$INPUT_DIR" ] && [ -n "$OUTPUT_DIR" ] || {
  echo "usage: render-mockups.sh <input_dir> <output_dir>" >&2
  exit 2
}

[ -d "$INPUT_DIR" ] || {
  echo "RENDER_FAILED input_dir_missing: $INPUT_DIR" >&2
  exit 1
}

mkdir -p "$OUTPUT_DIR"

# Resolve script directory so puppeteer can be resolved from local node_modules
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Detect gstack/browse (same probe as SKILL.md step 4b)
LB=""
for _P in "$(pwd)/.claude/skills/gstack/browse/dist/browse" \
          "$HOME/.claude/skills/gstack/browse/dist/browse"; do
  [ -x "$_P" ] && LB="$_P" && break
done

# Verify gstack can handle file:// URLs (some versions block them)
if [ -n "$LB" ]; then
  if ! "$LB" goto "file:///dev/null" >/dev/null 2>&1; then
    LB=""
  fi
fi

count=0

if [ -n "$LB" ]; then
  # gstack path: one goto + screenshot per file
  for html in "$INPUT_DIR"/*.html; do
    [ -f "$html" ] || continue
    name="$(basename "$html" .html)"
    out="$OUTPUT_DIR/$name.png"

    # Read viewport hint from data-platform
    platform="$(grep -oE 'data-platform=["'\''](mobile|desktop)["'\'']' "$html" | head -1 | sed -E 's/.*"(.*)".*/\1/' || true)"
    width=1280
    [ "$platform" = "mobile" ] && width=375

    "$LB" goto "file://$html" >/dev/null 2>&1 || {
      echo "RENDER_FAILED gstack_goto_failed: $html" >&2; exit 1;
    }
    "$LB" screenshot "$out" --width "$width" >/dev/null 2>&1 || {
      echo "RENDER_FAILED gstack_screenshot_failed: $out" >&2; exit 1;
    }
    count=$((count + 1))
  done
else
  # puppeteer fallback
  RENDER_MJS="$SCRIPT_DIR/render.mjs"
  if ! command -v node >/dev/null 2>&1; then
    echo "RENDER_SKIPPED no_headless_browser_and_no_node" >&2
    exit 1
  fi
  if ! (cd "$SCRIPT_DIR" && node -e "require.resolve('puppeteer')") >/dev/null 2>&1; then
    echo "Installing puppeteer (one-time, ~200MB Chrome download)..." >&2
    if ! npx -y puppeteer@latest --version >/dev/null 2>&1; then
      echo "RENDER_FAILED puppeteer_install_failed" >&2
      exit 1
    fi
  fi
  (cd "$SCRIPT_DIR" && node "$RENDER_MJS" "$INPUT_DIR" "$OUTPUT_DIR") || {
    echo "RENDER_FAILED render_mjs_failed" >&2
    exit 1
  }
  count="$(find "$OUTPUT_DIR" -maxdepth 1 -name '*.png' | wc -l | tr -d ' ')"
fi

# Clean up _src/
rm -rf "$INPUT_DIR"

echo "RENDER_OK $count file(s) → $OUTPUT_DIR"
