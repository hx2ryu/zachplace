#!/usr/bin/env bash
# extract-tokens.sh — discover design tokens for design-bench mockups.
#
# Output contract: stdout is a CSS :root { … } block of variables.
# Returns neutral defaults when nothing is found, plus "TOKENS_NOT_FOUND"
# on stderr so the skill can surface a warning badge.
#
# Usage:
#   extract-tokens.sh --search <dir>            # print to stdout
#   extract-tokens.sh --search <dir> --out PATH # also write to PATH

set -uo pipefail

SEARCH=""
OUT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --search) SEARCH="$2"; shift 2 ;;
    --out)    OUT="$2";    shift 2 ;;
    *)        echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[ -n "$SEARCH" ] || { echo "missing --search" >&2; exit 2; }

emit() {
  if [ -n "$OUT" ]; then
    printf '%s\n' "$1" >> "$OUT"
  fi
  printf '%s\n' "$1"
}

# Initialize output file if --out is given
[ -n "$OUT" ] && : > "$OUT"

found=0

# 1) CSS :root variables in any .css file
CSS_FILE="$(grep -rl --include="*.css" -E "^\s*:root\s*\{" "$SEARCH" 2>/dev/null | head -1 || true)"
if [ -n "$CSS_FILE" ]; then
  found=1
  emit ":root {"
  awk '/:root[[:space:]]*\{/,/\}/' "$CSS_FILE" \
    | grep -E "^\s*--" \
    | sed 's/^[[:space:]]*/  /' \
    | while IFS= read -r line; do emit "$line"; done
  emit "}"
fi

# 2) Tailwind config (extract via node eval if available)
if [ $found -eq 0 ]; then
  TW="$(find "$SEARCH" -maxdepth 3 -name 'tailwind.config.*' 2>/dev/null | head -1)"
  if [ -n "$TW" ] && command -v node >/dev/null 2>&1; then
    found=1
    emit ":root {"
    node -e "
      const c = require('$TW');
      const ext = (c.theme && c.theme.extend) || {};
      const lines = [];
      for (const [k, v] of Object.entries(ext.colors || {})) lines.push('  --color-' + k + ': ' + v + ';');
      for (const [k, v] of Object.entries(ext.borderRadius || {})) lines.push('  --radius-' + k + ': ' + v + ';');
      for (const [k, v] of Object.entries(ext.spacing || {})) lines.push('  --space-' + k + ': ' + v + ';');
      for (const [k, v] of Object.entries(ext.fontFamily || {})) lines.push('  --font-' + k + ': ' + (Array.isArray(v) ? v.join(', ') : v) + ';');
      for (const [k, v] of Object.entries(ext.fontSize || {})) lines.push('  --text-' + k + ': ' + (Array.isArray(v) ? v[0] : v) + ';');
      console.log(lines.join('\n'));
    " 2>/dev/null | while IFS= read -r line; do emit "$line"; done
    emit "}"
  fi
fi

# 3) tokens.json / design-tokens.json
if [ $found -eq 0 ]; then
  JSON="$(find "$SEARCH" -maxdepth 4 \( -name 'tokens.json' -o -name 'design-tokens.json' \) 2>/dev/null | head -1)"
  if [ -n "$JSON" ] && command -v jq >/dev/null 2>&1; then
    found=1
    emit ":root {"
    jq -r '
      to_entries[] as $group |
      ($group.value | to_entries[]) as $tok |
      "  --\($group.key)-\($tok.key): \($tok.value);"
    ' "$JSON" 2>/dev/null | while IFS= read -r line; do emit "$line"; done
    emit "}"
  fi
fi

# 4) Neutral default fallback
if [ $found -eq 0 ]; then
  echo "TOKENS_NOT_FOUND" >&2
  emit ":root {"
  emit "  --color-primary: #0f172a;"
  emit "  --color-bg: #ffffff;"
  emit "  --color-fg: #0f172a;"
  emit "  --color-muted: #64748b;"
  emit "  --color-border: #e5e7eb;"
  emit "  --radius-sm: 4px;"
  emit "  --radius-md: 8px;"
  emit "  --radius-lg: 16px;"
  emit "  --space-1: 4px;"
  emit "  --space-2: 8px;"
  emit "  --space-4: 16px;"
  emit "  --space-8: 32px;"
  emit "  --font-sans: system-ui, -apple-system, sans-serif;"
  emit "  --text-sm: 14px;"
  emit "  --text-md: 16px;"
  emit "  --text-lg: 20px;"
  emit "}"
fi

exit 0
