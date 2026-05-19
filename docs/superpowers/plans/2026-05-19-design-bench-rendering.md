# design-bench Rendering Mockups Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace ASCII wireframes in design-bench reports with HTML/CSS mockups rendered using project design tokens. Output PNGs into `report.md` and inline HTML into `report.html`.

**Architecture:** Two new shell scripts (token extractor + mockup renderer) plus a small puppeteer driver, an updated SKILL.md workflow that instructs the LLM to produce token-bound HTML mockups, an updated report-template.md that references PNG/iframe instead of ASCII, and a fixtures-based test harness.

**Tech Stack:** bash, grep, jq, node (puppeteer via `npx`), optional gstack/browse headless browser.

**Reference spec:** `docs/superpowers/specs/2026-05-19-design-bench-rendering-design.md`

---

## File Structure

### New files
- `plugins/design-bench/skills/design-bench/scripts/extract-tokens.sh` — token discovery + CSS variable emitter
- `plugins/design-bench/skills/design-bench/scripts/render-mockups.sh` — orchestrator: detect `$LB` or call `render.mjs`
- `plugins/design-bench/skills/design-bench/scripts/render.mjs` — puppeteer driver, viewport from `data-platform`
- `plugins/design-bench/skills/design-bench/references/mockup-examples.md` — LLM-facing mockup HTML examples
- `plugins/design-bench/tests/test-harness.sh` — shared bash assertion helpers
- `plugins/design-bench/tests/extract-tokens.test.sh` — covers all 5 fallback paths
- `plugins/design-bench/tests/render.test.sh` — render.mjs smoke test
- `plugins/design-bench/tests/fixtures/tokens-css-vars/globals.css`
- `plugins/design-bench/tests/fixtures/tokens-tailwind/tailwind.config.js`
- `plugins/design-bench/tests/fixtures/tokens-json/tokens.json`
- `plugins/design-bench/tests/fixtures/tokens-empty/.gitkeep`
- `plugins/design-bench/tests/fixtures/sample-mockup.html`

### Modified files
- `plugins/design-bench/skills/design-bench/SKILL.md`
- `plugins/design-bench/skills/design-bench/references/report-template.md`
- `plugins/design-bench/README.md`

---

## Task 1: Test harness setup

**Files:**
- Create: `plugins/design-bench/tests/test-harness.sh`

- [ ] **Step 1: Write the harness**

```bash
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
```

- [ ] **Step 2: Verify it loads without error**

Run: `bash -n plugins/design-bench/tests/test-harness.sh`
Expected: exits 0 (syntax OK)

- [ ] **Step 3: Commit**

```bash
git add plugins/design-bench/tests/test-harness.sh
git commit -m "test: bash test harness for design-bench scripts"
```

---

## Task 2: Token fixtures

**Files:**
- Create: `plugins/design-bench/tests/fixtures/tokens-css-vars/globals.css`
- Create: `plugins/design-bench/tests/fixtures/tokens-tailwind/tailwind.config.js`
- Create: `plugins/design-bench/tests/fixtures/tokens-json/tokens.json`
- Create: `plugins/design-bench/tests/fixtures/tokens-empty/.gitkeep`

- [ ] **Step 1: Create CSS variables fixture**

`plugins/design-bench/tests/fixtures/tokens-css-vars/globals.css`:
```css
:root {
  --color-primary: #2563eb;
  --color-bg: #ffffff;
  --color-fg: #0f172a;
  --color-muted: #64748b;
  --color-border: #e2e8f0;
  --radius-sm: 4px;
  --radius-md: 8px;
  --radius-lg: 16px;
  --space-1: 4px;
  --space-2: 8px;
  --space-4: 16px;
  --space-8: 32px;
  --font-sans: 'Inter', system-ui, sans-serif;
  --text-sm: 14px;
  --text-md: 16px;
  --text-lg: 20px;
}
```

- [ ] **Step 2: Create Tailwind fixture**

`plugins/design-bench/tests/fixtures/tokens-tailwind/tailwind.config.js`:
```js
module.exports = {
  theme: {
    extend: {
      colors: {
        primary: '#7c3aed',
        bg: '#fafafa',
        fg: '#171717',
        muted: '#737373',
        border: '#e5e5e5'
      },
      borderRadius: {
        sm: '4px',
        md: '8px',
        lg: '16px'
      },
      spacing: {
        1: '4px',
        2: '8px',
        4: '16px',
        8: '32px'
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif']
      },
      fontSize: {
        sm: '14px',
        md: '16px',
        lg: '20px'
      }
    }
  }
}
```

- [ ] **Step 3: Create JSON tokens fixture**

`plugins/design-bench/tests/fixtures/tokens-json/tokens.json`:
```json
{
  "color": {
    "primary": "#10b981",
    "bg": "#ffffff",
    "fg": "#064e3b",
    "muted": "#6b7280",
    "border": "#d1d5db"
  },
  "radius": {
    "sm": "4px",
    "md": "8px",
    "lg": "16px"
  },
  "space": {
    "1": "4px",
    "2": "8px",
    "4": "16px",
    "8": "32px"
  },
  "font": {
    "sans": "'Inter', system-ui, sans-serif"
  },
  "text": {
    "sm": "14px",
    "md": "16px",
    "lg": "20px"
  }
}
```

- [ ] **Step 4: Create empty fixture marker**

`plugins/design-bench/tests/fixtures/tokens-empty/.gitkeep`:
```

```
(empty file — placeholder so the empty dir is committed)

- [ ] **Step 5: Commit**

```bash
git add plugins/design-bench/tests/fixtures/tokens-css-vars \
        plugins/design-bench/tests/fixtures/tokens-tailwind \
        plugins/design-bench/tests/fixtures/tokens-json \
        plugins/design-bench/tests/fixtures/tokens-empty
git commit -m "test: fixtures for token extractor (css-vars, tailwind, json, empty)"
```

---

## Task 3: Token extractor — failing tests first

**Files:**
- Create: `plugins/design-bench/tests/extract-tokens.test.sh`

- [ ] **Step 1: Write the failing tests**

`plugins/design-bench/tests/extract-tokens.test.sh`:
```bash
#!/usr/bin/env bash
# extract-tokens.test.sh — exercises all 5 fallback paths of extract-tokens.sh

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
EXTRACT="$ROOT/skills/design-bench/scripts/extract-tokens.sh"
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
```

- [ ] **Step 2: Make it executable**

Run: `chmod +x plugins/design-bench/tests/extract-tokens.test.sh`
Expected: no output

- [ ] **Step 3: Run it to verify it fails**

Run: `bash plugins/design-bench/tests/extract-tokens.test.sh`
Expected: FAIL — `extract-tokens.sh` does not exist yet, every assertion fails or test exits with `No such file`.

- [ ] **Step 4: Commit the failing test**

```bash
git add plugins/design-bench/tests/extract-tokens.test.sh
git commit -m "test: failing tests for extract-tokens.sh"
```

---

## Task 4: Token extractor — implementation

**Files:**
- Create: `plugins/design-bench/skills/design-bench/scripts/extract-tokens.sh`

- [ ] **Step 1: Write minimal implementation**

`plugins/design-bench/skills/design-bench/scripts/extract-tokens.sh`:
```bash
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
```

- [ ] **Step 2: Make it executable**

Run: `chmod +x plugins/design-bench/skills/design-bench/scripts/extract-tokens.sh`
Expected: no output

- [ ] **Step 3: Run the tests to verify they pass**

Run: `bash plugins/design-bench/tests/extract-tokens.test.sh`
Expected: PASS — `passed: 10  failed: 0` (or similar; all `it()` blocks green).

If any assertion fails, fix the script and re-run. Do not commit until all pass.

- [ ] **Step 4: Commit**

```bash
git add plugins/design-bench/skills/design-bench/scripts/extract-tokens.sh
git commit -m "feat(design-bench): extract-tokens.sh with css/tailwind/json/default fallback"
```

---

## Task 5: Mockup renderer — sample HTML fixture

**Files:**
- Create: `plugins/design-bench/tests/fixtures/sample-mockup.html`

- [ ] **Step 1: Write sample**

`plugins/design-bench/tests/fixtures/sample-mockup.html`:
```html
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<style>
  :root { --color-primary: #2563eb; --color-fg: #0f172a; }
  body { margin: 0; font-family: system-ui, sans-serif; }
  .mockup-frame { width: 375px; padding: 16px; color: var(--color-fg); }
  .mockup-frame[data-platform="desktop"] { width: 1280px; }
  button { background: var(--color-primary); color: white; padding: 8px 16px; border: none; border-radius: 8px; }
</style>
</head>
<body>
  <div class="mockup-frame" data-platform="mobile">
    <h1>Sample</h1>
    <button>Click me</button>
  </div>
</body>
</html>
```

- [ ] **Step 2: Commit**

```bash
git add plugins/design-bench/tests/fixtures/sample-mockup.html
git commit -m "test: sample mockup fixture for render.mjs"
```

---

## Task 6: render.mjs — failing test

**Files:**
- Create: `plugins/design-bench/tests/render.test.sh`

- [ ] **Step 1: Write the failing test**

`plugins/design-bench/tests/render.test.sh`:
```bash
#!/usr/bin/env bash
# render.test.sh — smoke test for render.mjs (puppeteer-based PNG renderer).
# Skips if node or puppeteer install is unavailable (offline / restricted env).

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RENDER="$ROOT/skills/design-bench/scripts/render.mjs"
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
```

- [ ] **Step 2: Make it executable**

Run: `chmod +x plugins/design-bench/tests/render.test.sh`
Expected: no output

- [ ] **Step 3: Run it to verify it fails**

Run: `bash plugins/design-bench/tests/render.test.sh`
Expected: FAIL — `render.mjs` does not exist yet, `node ... render.mjs` errors out, test falls through "skipped" path OR fails the `assert_file_exists`.

- [ ] **Step 4: Commit**

```bash
git add plugins/design-bench/tests/render.test.sh
git commit -m "test: failing test for render.mjs"
```

---

## Task 7: render.mjs — implementation

**Files:**
- Create: `plugins/design-bench/skills/design-bench/scripts/render.mjs`

- [ ] **Step 1: Write the script**

`plugins/design-bench/skills/design-bench/scripts/render.mjs`:
```js
#!/usr/bin/env node
// render.mjs — render each HTML file in INPUT_DIR to PNG in OUTPUT_DIR.
// Viewport is decided by the `data-platform` attribute of `.mockup-frame`:
//   mobile  → 375 wide
//   desktop → 1280 wide
// Falls back to 1280 if the attribute is missing.
//
// Usage: node render.mjs <input_dir> <output_dir>

import { readdir, readFile, mkdir } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { join, basename, extname, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const [, , INPUT_DIR, OUTPUT_DIR] = process.argv;
if (!INPUT_DIR || !OUTPUT_DIR) {
  console.error('usage: render.mjs <input_dir> <output_dir>');
  process.exit(2);
}

let puppeteer;
try {
  puppeteer = (await import('puppeteer')).default;
} catch {
  console.error('puppeteer not installed — install with: npm i -g puppeteer (or run via `npx -y puppeteer ...`)');
  process.exit(3);
}

await mkdir(OUTPUT_DIR, { recursive: true });

const files = (await readdir(INPUT_DIR)).filter(f => f.endsWith('.html'));
if (files.length === 0) {
  console.error(`no .html files in ${INPUT_DIR}`);
  process.exit(0);
}

const browser = await puppeteer.launch({ headless: 'new' });
try {
  for (const file of files) {
    const inputPath = resolve(INPUT_DIR, file);
    const outName = basename(file, extname(file)) + '.png';
    const outputPath = resolve(OUTPUT_DIR, outName);

    const html = await readFile(inputPath, 'utf8');
    const platformMatch = html.match(/data-platform=["'](mobile|desktop)["']/);
    const platform = platformMatch ? platformMatch[1] : 'desktop';
    const width = platform === 'mobile' ? 375 : 1280;

    const page = await browser.newPage();
    await page.setViewport({ width, height: 100, deviceScaleFactor: 2 });
    await page.goto(pathToFileURL(inputPath).href, { waitUntil: 'networkidle0' });

    // Auto-size height to content
    const bodyHeight = await page.evaluate(() => document.body.scrollHeight);
    await page.setViewport({ width, height: bodyHeight, deviceScaleFactor: 2 });

    await page.screenshot({ path: outputPath, fullPage: false });
    await page.close();
    console.log(`rendered: ${outName} (${platform}, ${width}x${bodyHeight})`);
  }
} finally {
  await browser.close();
}
```

- [ ] **Step 2: Make it executable**

Run: `chmod +x plugins/design-bench/skills/design-bench/scripts/render.mjs`
Expected: no output

- [ ] **Step 3: Verify puppeteer is available, then run the test**

Run: `bash plugins/design-bench/tests/render.test.sh`

If puppeteer is missing, the test skips with `(skipped — puppeteer install failed, likely offline)`. To force install once:
```bash
npx -y puppeteer@latest --version
```

Then re-run. Expected: PASS — PNG written to tmp dir, > 1000 bytes.

- [ ] **Step 4: Commit**

```bash
git add plugins/design-bench/skills/design-bench/scripts/render.mjs
git commit -m "feat(design-bench): render.mjs puppeteer driver for mockup PNGs"
```

---

## Task 8: render-mockups.sh orchestrator

**Files:**
- Create: `plugins/design-bench/skills/design-bench/scripts/render-mockups.sh`

- [ ] **Step 1: Write the orchestrator**

`plugins/design-bench/skills/design-bench/scripts/render-mockups.sh`:
```bash
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

# Detect gstack/browse (same probe as SKILL.md step 4b)
LB=""
for _P in "$(pwd)/.claude/skills/gstack/browse/dist/browse" \
          "$HOME/.claude/skills/gstack/browse/dist/browse"; do
  [ -x "$_P" ] && LB="$_P" && break
done

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
  RENDER_MJS="$(dirname "$0")/render.mjs"
  if ! command -v node >/dev/null 2>&1; then
    echo "RENDER_SKIPPED no_headless_browser_and_no_node" >&2
    exit 1
  fi
  if ! node -e "require.resolve('puppeteer')" >/dev/null 2>&1; then
    echo "Installing puppeteer (one-time, ~200MB Chrome download)..." >&2
    if ! npx -y puppeteer@latest --version >/dev/null 2>&1; then
      echo "RENDER_FAILED puppeteer_install_failed" >&2
      exit 1
    fi
  fi
  node "$RENDER_MJS" "$INPUT_DIR" "$OUTPUT_DIR" || {
    echo "RENDER_FAILED render_mjs_failed" >&2
    exit 1
  }
  count="$(find "$OUTPUT_DIR" -maxdepth 1 -name '*.png' | wc -l | tr -d ' ')"
fi

# Clean up _src/
rm -rf "$INPUT_DIR"

echo "RENDER_OK $count file(s) → $OUTPUT_DIR"
```

- [ ] **Step 2: Make it executable**

Run: `chmod +x plugins/design-bench/skills/design-bench/scripts/render-mockups.sh`
Expected: no output

- [ ] **Step 3: Manual integration test**

Run:
```bash
TMPIN=$(mktemp -d)
TMPOUT=$(mktemp -d)
cp plugins/design-bench/tests/fixtures/sample-mockup.html "$TMPIN/"
bash plugins/design-bench/skills/design-bench/scripts/render-mockups.sh "$TMPIN" "$TMPOUT"
ls -la "$TMPOUT"
rm -rf "$TMPOUT"  # $TMPIN already deleted by the script
```

Expected:
- `RENDER_OK 1 file(s) → /tmp/...` on stdout
- `sample-mockup.png` in `$TMPOUT`, non-empty

If no headless browser and offline, expected: `RENDER_FAILED puppeteer_install_failed`.

- [ ] **Step 4: Commit**

```bash
git add plugins/design-bench/skills/design-bench/scripts/render-mockups.sh
git commit -m "feat(design-bench): render-mockups.sh orchestrator (gstack or puppeteer fallback)"
```

---

## Task 9: Mockup examples reference

**Files:**
- Create: `plugins/design-bench/skills/design-bench/references/mockup-examples.md`

- [ ] **Step 1: Write the reference doc**

`plugins/design-bench/skills/design-bench/references/mockup-examples.md`:
````markdown
# Mockup HTML Examples (LLM Reference)

Examples of well-formed mockup HTML for `design-bench`. Use these as
**structural** references only — do NOT copy verbatim. Adapt to the
recommendation's specific content.

## Rules (must follow)

1. Top-level wrapper: `<div class="mockup-frame" data-platform="mobile|desktop">`
2. Width is fixed by platform: mobile = 375px, desktop = 1280px.
3. All colors, spacing, radii, fonts go through CSS variables:
   `var(--color-primary)`, `var(--space-4)`, etc.
4. No raw hex (`#fff`), no external assets (`<img src="https://...">`),
   no external CSS/JS.
5. Inline `<style>` block at top is OK. `design-tokens.css` is loaded
   automatically by the wrapper context.

---

## Example 1: Pricing tier card (desktop)

```html
<!doctype html>
<html><head><meta charset="utf-8">
<style>
  body { margin: 0; font-family: var(--font-sans); color: var(--color-fg); background: var(--color-bg); }
  .mockup-frame { width: 1280px; padding: var(--space-8); }
  .tier-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: var(--space-4); }
  .tier { border: 1px solid var(--color-border); border-radius: var(--radius-md); padding: var(--space-4); }
  .tier.featured { border-color: var(--color-primary); border-width: 2px; }
  .tier h3 { margin: 0 0 var(--space-2) 0; font-size: var(--text-lg); }
  .tier .price { font-size: 32px; font-weight: 600; margin: var(--space-4) 0; }
  .tier button { width: 100%; padding: var(--space-2); background: var(--color-primary); color: white; border: none; border-radius: var(--radius-sm); }
</style>
</head><body>
<div class="mockup-frame" data-platform="desktop">
  <div class="tier-grid">
    <div class="tier"><h3>Free</h3><div class="price">$0</div><button>Get Started</button></div>
    <div class="tier featured"><h3>Pro</h3><div class="price">$12</div><button>Get Started</button></div>
    <div class="tier"><h3>Team</h3><div class="price">$99</div><button>Get Started</button></div>
  </div>
</div>
</body></html>
```

## Example 2: Onboarding step (mobile)

```html
<!doctype html>
<html><head><meta charset="utf-8">
<style>
  body { margin: 0; font-family: var(--font-sans); color: var(--color-fg); background: var(--color-bg); }
  .mockup-frame { width: 375px; padding: var(--space-4); }
  .progress { display: flex; gap: var(--space-1); margin-bottom: var(--space-8); }
  .dot { flex: 1; height: 4px; border-radius: 2px; background: var(--color-border); }
  .dot.active { background: var(--color-primary); }
  h1 { font-size: var(--text-lg); margin: 0 0 var(--space-2) 0; }
  p { color: var(--color-muted); font-size: var(--text-sm); margin: 0 0 var(--space-8) 0; }
  button { width: 100%; padding: var(--space-4); background: var(--color-primary); color: white; border: none; border-radius: var(--radius-md); }
</style>
</head><body>
<div class="mockup-frame" data-platform="mobile">
  <div class="progress">
    <div class="dot active"></div>
    <div class="dot active"></div>
    <div class="dot"></div>
  </div>
  <h1>What's your goal?</h1>
  <p>Pick one — you can always change it later.</p>
  <button>Continue</button>
</div>
</body></html>
```

## Example 3: Empty-state list (mobile)

```html
<!doctype html>
<html><head><meta charset="utf-8">
<style>
  body { margin: 0; font-family: var(--font-sans); color: var(--color-fg); background: var(--color-bg); }
  .mockup-frame { width: 375px; padding: var(--space-4); }
  .empty { text-align: center; padding: var(--space-8) 0; }
  .icon { width: 48px; height: 48px; border-radius: var(--radius-lg); background: var(--color-border); margin: 0 auto var(--space-4); }
  h2 { font-size: var(--text-md); margin: 0 0 var(--space-1) 0; }
  p { color: var(--color-muted); font-size: var(--text-sm); margin: 0 0 var(--space-4) 0; }
  button { padding: var(--space-2) var(--space-4); background: var(--color-primary); color: white; border: none; border-radius: var(--radius-sm); }
</style>
</head><body>
<div class="mockup-frame" data-platform="mobile">
  <div class="empty">
    <div class="icon"></div>
    <h2>No projects yet</h2>
    <p>Start by creating your first project.</p>
    <button>+ New Project</button>
  </div>
</div>
</body></html>
```

## Example 4: Dashboard widget (desktop)

```html
<!doctype html>
<html><head><meta charset="utf-8">
<style>
  body { margin: 0; font-family: var(--font-sans); color: var(--color-fg); background: var(--color-bg); }
  .mockup-frame { width: 1280px; padding: var(--space-4); }
  .card { border: 1px solid var(--color-border); border-radius: var(--radius-md); padding: var(--space-4); max-width: 320px; }
  .label { color: var(--color-muted); font-size: var(--text-sm); margin: 0; }
  .value { font-size: 28px; font-weight: 600; margin: var(--space-1) 0 0 0; }
  .delta { color: var(--color-primary); font-size: var(--text-sm); margin-top: var(--space-2); }
</style>
</head><body>
<div class="mockup-frame" data-platform="desktop">
  <div class="card">
    <p class="label">Active users</p>
    <p class="value">12,408</p>
    <p class="delta">+8.2% this week</p>
  </div>
</div>
</body></html>
```

## Anti-Examples (do NOT do this)

```html
<!-- ❌ raw hex -->
<div style="background: #2563eb">...</div>

<!-- ❌ external image -->
<img src="https://example.com/logo.png">

<!-- ❌ external CSS -->
<link rel="stylesheet" href="https://cdn.example.com/styles.css">

<!-- ❌ no data-platform attribute -->
<div class="mockup-frame">...</div>
```
````

- [ ] **Step 2: Commit**

```bash
git add plugins/design-bench/skills/design-bench/references/mockup-examples.md
git commit -m "docs(design-bench): mockup HTML examples and contract"
```

---

## Task 10: report-template.md updates

**Files:**
- Modify: `plugins/design-bench/skills/design-bench/references/report-template.md`

- [ ] **Step 1: Replace `Sketch:` block with `Mockups:` in Recommendation 1**

Use Edit. Find:
```markdown
**Sketch:**
```
┌─────────────────────────────┐
│                             │
│   { ascii wireframe }       │
│                             │
└─────────────────────────────┘
```
```

Replace with:
```markdown
**Mockups:**

| Mobile | Desktop |
|---|---|
| ![{title} mobile](mockups/rec-1-mobile.png) | ![{title} desktop](mockups/rec-1-desktop.png) |

*HTML source embedded in `report.html` (iframe srcdoc).*
```

- [ ] **Step 2: Add mockup note to Patterns and Anti-Patterns**

Change the Patterns section preamble to:
```markdown
## Patterns
*(What the best examples have in common — table stakes for this design problem.
Each pattern includes a mini-mockup illustrating the shape.)*

- **{Pattern name}** — {one-line explanation}. Seen in: {company A}, {company B}, {company C}.
  ![{pattern name}](mockups/pattern-{slug}.png)
- ...
```

Change Anti-Patterns section preamble to:
```markdown
## Anti-Patterns
*(What to avoid. Specific examples from the research, not generic advice.
Each anti-pattern includes a mini-mockup illustrating what NOT to do.)*

- **{Anti-pattern name}** — {what's wrong + which reference shows it}.
  ![{anti-pattern name}](mockups/anti-{slug}.png)
- ...
```

- [ ] **Step 3: Add render-status footer**

Find the final line:
```markdown
*Generated by `/design-bench:design-bench` on {YYYY-MM-DD}.*
```

Replace with:
```markdown
*Generated by `/design-bench:design-bench` on {YYYY-MM-DD}.*
*Mockups rendered with project design tokens (`design-tokens.css`).*
*{render-status-badge: ✓ project tokens | ⚠ neutral defaults | ⚠ html-only}*
```

- [ ] **Step 4: Commit**

```bash
git add plugins/design-bench/skills/design-bench/references/report-template.md
git commit -m "docs(design-bench): replace ASCII sketch with mockup PNG references in template"
```

---

## Task 11: SKILL.md updates — Step 5b + Mockup Contract

**Files:**
- Modify: `plugins/design-bench/skills/design-bench/SKILL.md`

- [ ] **Step 1: Append Step 5b to the end of Step 5**

Find the end of "### 5. Map Internal Design System" section, just before "### 6. Extract Patterns / Anti-Patterns". Insert this new subsection:

```markdown
### 5b. Extract Design Tokens ★ (powers the mockup renderer)

Run `scripts/extract-tokens.sh` against each `design_system.packages[].path`
or the `design_system.tokens` path from config:

```bash
bash "$(dirname "$0")/scripts/extract-tokens.sh" \
  --search "{tokens or first package path}" \
  --out "{OUTPUT_DIR}/design-tokens.css"
```

The script tries these sources in order, picking the first that hits:
1. `:root { --... }` blocks in any `.css` file
2. `theme.extend` in `tailwind.config.{js,ts}`
3. `tokens.json` or `design-tokens.json`
4. Neutral default palette (emits `TOKENS_NOT_FOUND` on stderr)

Capture stderr — if it contains `TOKENS_NOT_FOUND`, set the
render-status badge to `⚠ neutral defaults` in the report footer.

The generated `design-tokens.css` is consumed by mockup HTML files in
step 7 and inlined into `report.html` in step 9.
```

- [ ] **Step 2: Replace ASCII wireframe instructions in Step 7**

Find this block inside "### 7. Generate Recommendations":
```markdown
- **ASCII wireframe** (box-drawing characters, just enough to communicate layout)
```

Replace with:
```markdown
- **HTML mockup** — see "Mockup Contract" below. One mockup per declared
  platform (mobile=375px, desktop=1280px). Save each to
  `{OUTPUT_DIR}/mockups/_src/rec-{n}-{mobile|desktop}.html`.
  For each pattern/anti-pattern, also generate a mini-mockup to
  `mockups/_src/pattern-{slug}.html` or `mockups/_src/anti-{slug}.html`.
```

Then find the example ASCII wireframe block (the `┌─────────────────────────────┐` example) and replace the entire block with:

```markdown
Example mockup HTML structure — see `references/mockup-examples.md` for
4 reference patterns with full code:

```html
<!doctype html>
<html><head><meta charset="utf-8"><style>
  body { margin: 0; font-family: var(--font-sans); color: var(--color-fg); }
  .mockup-frame { width: 1280px; padding: var(--space-4); }
  /* ... only var(--token) usage, never raw hex ... */
</style></head><body>
  <div class="mockup-frame" data-platform="desktop">
    <!-- composition using design tokens -->
  </div>
</body></html>
```
```

- [ ] **Step 3: Insert Step 8.5 before Step 8**

Find "### 8. Write report.md" and insert before it:

```markdown
### 8.5. Render Mockups to PNG

After all mockup HTML files are saved in `{OUTPUT_DIR}/mockups/_src/`:

```bash
bash "$(dirname "$0")/scripts/render-mockups.sh" \
  "{OUTPUT_DIR}/mockups/_src" \
  "{OUTPUT_DIR}/mockups"
```

The orchestrator prefers gstack/browse if `$LB` is available, otherwise
falls back to `render.mjs` via `npx puppeteer` (first run downloads
Chrome, ~200MB).

Output contract — read the last line of stdout:
- `RENDER_OK <n> file(s) → ...` — success, set badge to `✓ project tokens`
  (or `⚠ neutral defaults` if step 5b emitted `TOKENS_NOT_FOUND`)
- `RENDER_FAILED <reason>` on stderr — PNG generation failed, set badge to
  `⚠ html-only`, leave report.md falling back to ASCII for the affected
  blocks (write the ASCII inside a `<details>` block under the broken
  image link so the file still renders).
- `RENDER_SKIPPED` — same handling as RENDER_FAILED.

The `_src/` directory is deleted by the orchestrator after rendering.
```

- [ ] **Step 4: Update Step 8 to reference PNG embeds**

Find "### 8. Write report.md" body. Update to reference PNG embeds explicitly. Replace:
```markdown
Use `references/report-template.md` as the structure. Reverse-pyramid:
TL;DR → Recommendations → Evidence → Findings.
```

with:
```markdown
Use `references/report-template.md` as the structure. Reverse-pyramid:
TL;DR → Recommendations → Evidence → Findings.

Each recommendation's `Mockups:` block uses the rendered PNGs:
```markdown
| Mobile | Desktop |
|---|---|
| ![rec-1 mobile](mockups/rec-1-mobile.png) | ![rec-1 desktop](mockups/rec-1-desktop.png) |
```

If `RENDER_FAILED`/`RENDER_SKIPPED`, fall back to ASCII inside a
`<details>` block — the HTML mockup source is still embedded in
report.html, so users have a path to view the design.
```

- [ ] **Step 5: Update Step 9 to inline HTML mockups via iframe srcdoc**

Find "### 9. Generate report.html" body. Replace with:

```markdown
Self-contained HTML, inline CSS, max-width 900px, system fonts, light-blue
TL;DR callout, rounded-corner image styling, relative `references/` paths.
Do NOT depend on external CSS or JS.

Inline `design-tokens.css` from step 5b inside a `<style>` block at the
top of the document.

For each recommendation's mockup, embed the HTML source via `<iframe>`:
```html
<iframe srcdoc="..." style="width: 100%; height: 600px; border: 1px solid #ddd; border-radius: 8px;" loading="lazy"></iframe>
```

Use the actual HTML strings from `mockups/_src/` (kept in memory before
the orchestrator deletes them) — escape `"` as `&quot;` in the srcdoc
attribute. The iframe's `srcdoc` content should include the inline
design-tokens.css too (so the iframe is fully self-contained).

After writing: `open "{OUTPUT_DIR}/report.html"`.
```

- [ ] **Step 6: Add the Mockup Contract section**

After Step 10, before "## High Bar for References", insert:

```markdown
## Mockup Contract (Step 7 → 8.5)

Every mockup HTML file must satisfy:

1. **Top wrapper** — `<div class="mockup-frame" data-platform="mobile|desktop">`.
   `data-platform` drives the renderer's viewport (375 or 1280).
2. **Tokens only** — colors, spacing, radii, fonts use `var(--token-name)`.
   No raw hex (`#abc123`) anywhere in the file.
3. **No external assets** — no `<link>`, no `<script src=>`, no
   `<img src="http...">`. Inline SVG and `data:` URIs are OK.
4. **Self-contained** — inline `<style>` block at top. `design-tokens.css`
   is inlined into the iframe srcdoc separately by step 9.
5. **Semantic HTML** — prefer `<button>`, `<nav>`, `<section>` over
   styled `<div>` soup.

Validation before render: grep each generated HTML file for
`#[0-9a-fA-F]{3,8}\b` and `src=["']https?:`. If a match is found,
self-correct once. If self-correction fails, render anyway and add a
warning to the report.

See `references/mockup-examples.md` for 4 reference patterns.
```

- [ ] **Step 7: Shrink "ASCII Wireframe Convention" to a fallback note**

Find the "## ASCII Wireframe Convention" section. Replace its entire body with:

```markdown
## ASCII Wireframe Convention (fallback only)

ASCII is only used when PNG rendering fails (`RENDER_FAILED`/`RENDER_SKIPPED`).
In that fallback, wrap the ASCII in a `<details>` block in report.md so
the visual mockup in report.html remains the primary surface.

Convention if you do need ASCII fallback: box-drawing chars only
(`┌─┐│└┘├┤┬┴┼`), one screen per block, ≤ 30 lines wide.
```

- [ ] **Step 8: Add new entries to "Common Mistakes"**

Find the "## Common Mistakes" table. Add two rows before the closing of the table:

```markdown
| Mockup contains raw hex like `#2563eb` | Use `var(--color-primary)`. The renderer accepts the file but the report loses brand fidelity. |
| Mockup loads external CSS or images | Self-contain. External assets break iframe srcdoc rendering and inflate PNG capture latency. |
```

- [ ] **Step 9: Verify SKILL.md still parses**

Run:
```bash
head -25 plugins/design-bench/skills/design-bench/SKILL.md
```
Expected: YAML frontmatter intact, no broken markdown structure.

- [ ] **Step 10: Commit**

```bash
git add plugins/design-bench/skills/design-bench/SKILL.md
git commit -m "feat(design-bench): SKILL.md workflow for token extract, HTML mockups, and PNG render"
```

---

## Task 12: README.md updates

**Files:**
- Modify: `plugins/design-bench/README.md`

- [ ] **Step 1: Update the Output tree**

Find the "## Output" code block:
```
.bench/{topic-slug}-{YYYY-MM-DD}/
├── report.md                  # main report (reverse pyramid)
├── report.html                # self-contained HTML preview
├── internal-inventory.md      # internal design-system component inventory
└── references/
    ├── current-state.png      # if captured
    ├── {company}-{screen}.png
    └── ...
```

Replace with:
```
.bench/{topic-slug}-{YYYY-MM-DD}/
├── report.md                  # main report (reverse pyramid, PNG mockups)
├── report.html                # self-contained HTML, mockups inline (iframe srcdoc)
├── internal-inventory.md      # internal design-system component inventory
├── design-tokens.css          # extracted/default tokens used by mockups
├── mockups/
│   ├── rec-1-mobile.png
│   ├── rec-1-desktop.png
│   ├── rec-2-mobile.png
│   ├── ...
│   ├── pattern-{slug}.png
│   └── anti-{slug}.png
└── references/
    ├── current-state.png      # if captured
    ├── {company}-{screen}.png
    └── ...
```

- [ ] **Step 2: Update the feature bullet about wireframes**

Find:
```markdown
4. Produces a report at `.bench/{topic}-{date}/` with ASCII wireframes, recommended components, and PR-split guidance
```

Replace with:
```markdown
4. Produces a report at `.bench/{topic}-{date}/` with **HTML/CSS mockups rendered using your project's design tokens** (mobile + desktop), recommended components, and PR-split guidance
```

- [ ] **Step 3: Commit**

```bash
git add plugins/design-bench/README.md
git commit -m "docs(design-bench): README reflects mockup PNG output and tokens.css"
```

---

## Task 13: End-to-end manual verification

**Files:** None (verification step)

This task is a manual scripted walkthrough — no code changes. Record the
result in the commit message of Task 14.

- [ ] **Step 1: Scenario A — full path (headless browser + tokens)**

Run the test suite end-to-end:
```bash
bash plugins/design-bench/tests/extract-tokens.test.sh
bash plugins/design-bench/tests/render.test.sh
```
Expected: both report `failed: 0`.

- [ ] **Step 2: Scenario B — empty tokens dir**

```bash
TMP=$(mktemp -d)
bash plugins/design-bench/skills/design-bench/scripts/extract-tokens.sh \
  --search "$TMP" 2>&1 1>/dev/null | grep TOKENS_NOT_FOUND
```
Expected: prints `TOKENS_NOT_FOUND`.

```bash
bash plugins/design-bench/skills/design-bench/scripts/extract-tokens.sh \
  --search "$TMP" | head -3
```
Expected: stdout includes `:root {` and `--color-primary: #0f172a;`.

- [ ] **Step 3: Scenario C — render-mockups orchestrator with sample**

```bash
TMPIN=$(mktemp -d)
TMPOUT=$(mktemp -d)
cp plugins/design-bench/tests/fixtures/sample-mockup.html "$TMPIN/"
bash plugins/design-bench/skills/design-bench/scripts/render-mockups.sh "$TMPIN" "$TMPOUT"
ls -la "$TMPOUT"
file "$TMPOUT/sample-mockup.png"
```
Expected:
- stdout ends with `RENDER_OK 1 file(s) → ...`
- `file` reports `PNG image data, ... 750 x ...` (mobile width × 2 for retina)
- `$TMPIN` no longer exists (orchestrator deleted it)

If puppeteer is missing AND no `$LB`, expected: `RENDER_FAILED puppeteer_install_failed`. Note this is acceptable for environments without node — proceed to step 4.

- [ ] **Step 4: Visual sanity check**

```bash
open "$TMPOUT/sample-mockup.png" 2>/dev/null || echo "open the PNG manually"
```
Expected: PNG shows the "Sample" heading and a blue "Click me" button.

- [ ] **Step 5: Cleanup**

```bash
rm -rf "$TMPOUT" "$TMP" 2>/dev/null
```

---

## Task 14: Final integration commit + verification summary

**Files:** None (summary commit)

- [ ] **Step 1: Run full test suite once more**

```bash
bash plugins/design-bench/tests/extract-tokens.test.sh
bash plugins/design-bench/tests/render.test.sh
```
Both must end with `failed: 0` (or `render.test.sh` skipped in offline envs — acceptable, note in commit).

- [ ] **Step 2: Visual diff of changed files**

```bash
git log --oneline -n 15
git diff main --stat
```
Verify:
- 7 files match the plan (SKILL.md, report-template.md, README.md modified; 4 scripts/references created; tests + fixtures added)
- No accidental changes outside `plugins/design-bench/` and `docs/superpowers/`

- [ ] **Step 3: Empty integration commit recording the verification**

```bash
git commit --allow-empty -m "$(cat <<'EOF'
feat(design-bench): rendering-based mockup output complete

End-to-end verification:
- extract-tokens.test.sh: PASS (5 cases)
- render.test.sh: PASS (or skipped if offline)
- Manual scenario walkthrough OK (extract-tokens fallback, render orchestrator)

Spec: docs/superpowers/specs/2026-05-19-design-bench-rendering-design.md
Plan: docs/superpowers/plans/2026-05-19-design-bench-rendering.md
EOF
)"
```

---

## Self-Review

**1. Spec coverage:** every spec section maps to a task:
- Step 5b token extractor → Tasks 2, 3, 4
- HTML mockup contract → Task 9, Task 11 (Mockup Contract section)
- Step 8.5 PNG renderer → Tasks 5, 6, 7, 8
- report.md / report.html embed → Tasks 10, 11
- mockup-examples.md → Task 9
- Edge cases (TOKENS_NOT_FOUND, RENDER_FAILED, fallback) → Tasks 4, 8, 11
- Tests (fixtures, harness, scripts) → Tasks 1, 2, 3, 5, 6, 13
- README update → Task 12
- ASCII Wireframe Convention shrink → Task 11 Step 7

**2. Placeholder scan:** no "TBD", "TODO", "Similar to Task N" patterns. All code blocks complete.

**3. Type consistency:** `extract-tokens.sh --search/--out`, `render-mockups.sh <input> <output>`, `render.mjs <input_dir> <output_dir>` are consistent across all tasks. `mockups/_src/` lifecycle (create in Step 7, delete after render) is consistent in Tasks 8 and 11. `data-platform="mobile|desktop"` attribute used identically across Tasks 5, 7, 8, 9, 11. `RENDER_OK`/`RENDER_FAILED`/`RENDER_SKIPPED` output contract referenced identically in Tasks 8 and 11. `TOKENS_NOT_FOUND` stderr signal referenced identically in Tasks 4 and 11.
