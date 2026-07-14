---
name: research
description: |
  Use when the user requests design research, competitive UI/UX benchmarking, or
  pre-implementation UX exploration for a new screen or feature.
  Trigger on (KR): "디자인 리서치", "디자인 벤치마크", "벤치마킹 해줘",
  "경쟁사 UI 분석", "UI 리서치", "{화면명} 어떻게 만들지", "레퍼런스 찾아줘".
  Trigger on (EN): "design research", "competitive analysis", "UI benchmark",
  "best practices for {screen}", "how do top apps handle {feature}".
  ALWAYS use this skill when designing a new screen or major UI change before
  implementation, especially when the project has an internal design system.
---

# Design Bench

Lazyweb-pattern design benchmarking. Combines curated competitor seeds, web
research, optional browser/Figma context, and **internal design-system mapping**
to produce an evidence-backed UI/UX recommendation report. Runtime-specific
notes are available in `../../runtime/`.

## CRITICAL: Output Behavior

**This skill produces FILES, not a plan.** Regardless of plan mode, ALWAYS:

1. Resolve `OUTPUT_DIR = {config.output_dir or '.bench'}/{topic-slug}-{YYYY-MM-DD}`
2. Write `{OUTPUT_DIR}/report.md`
3. Write `{OUTPUT_DIR}/report.html` (self-contained, inline CSS)
4. Save references to `{OUTPUT_DIR}/references/`
5. Do NOT write research content into a plan file
6. After saving, summarize findings + file paths + suggested next steps
7. If in plan mode, exit plan mode after the user confirms the report
8. Suggest user add `.bench/` to `.gitignore` (one-time)

## When to Use

- New screen or feature is being designed and the user wants research first
- Existing screen needs benchmarking against competitors before redesign
- User says "어떻게 만들지", asks for "best practices", or wants competitor patterns

## When NOT to Use

- User just wants a single screenshot/quick reference → answer directly
- User has finished design and wants code review → use review skills
- User wants creative cross-pollination only → consider future `design-brainstorm`

## Inputs

### Project config (optional, recommended)

If `<project-root>/.bench/config.yml` exists, load it. Otherwise ask the user
inline for the same fields and offer to write the config at the end.

```yaml
project:
  name: dandul
  category: productivity   # see references/competitors-kr.md for canonical names
  market: KR               # KR | Global | Both
  platforms: [mobile, web] # mobile | web | desktop (any combination)

design_system:
  packages:
    - path: ui/                 # grep target — reusable web components
      framework: react
    - path: mobile/             # grep target — RN components
      framework: react-native
  tokens: ui/src/tokens         # optional, design token directory

competitors:
  override: []                  # extra competitors not in seed (by name)
  exclude: []                   # remove from seed (by name)

figma:
  default_file_key: ""          # optional, used when figma URL not provided

output_dir: .bench
```

Use `scripts/load-config.sh` to print the config (or report absence).

## Available Tools — Graceful Degradation

The skill must keep working when optional tools are missing.

| Tool | Required? | Fallback if missing |
|---|---|---|
| Web search | yes | (none — minimum requirement) |
| Web fetch | yes | (none — minimum requirement) |
| Figma context | optional | Skip step 4c, note in report |
| Library-docs lookup | optional | Skip library-docs lookup |
| Headless browser (`gstack`/`browse`) | optional | Live screenshot capture skipped, describe in text |

Verify tool presence at workflow start. Do NOT fail — degrade and proceed.

## Workflow

### 1. Load Config + Clarify Intent

```bash
bash "$(dirname "$0")/scripts/load-config.sh" || true
```

Confirm with user (1 message, multiple AskUserQuestion items if available):
- Target screen/feature (specific, not "the whole app")
- Target package (mobile/ui/web — must match `design_system.packages`)
- Market focus (KR / Global / Both)
- Any specific competitors to include or exclude

### 2. Capture Current State (skip if not applicable)

If a current implementation exists:
- Web: dev server URL → headless browser screenshot if available
- Mobile: ask user to drop a screenshot file path
- No current state: skip

Save as `{OUTPUT_DIR}/references/current-state.png`. Reference it in the report
right after TL;DR.

### 3. Identify Competitors (Seed First, web search to fill)

**Seed grep first** — do NOT skip this:
```bash
grep -A 5 "^### " plugins/design-bench/skills/research/references/competitors-kr.md
grep -A 5 "^### " plugins/design-bench/skills/research/references/competitors-global.md
```
(Adjust paths — when installed as plugin, files are in
`~/.claude/plugins/cache/.../design-bench/skills/research/references/`.)

Filter by `project.category` and `project.market`, apply `competitors.override`
and `competitors.exclude` from config.

**Then use web search** for any gaps (recent entrants, niche players the seed missed):
- `"{category} app 2026 best UX"` — KR market: add `한국` / `Korean`
- `"{competitor name} {screen type}"`

Present the final 5-10 competitor list to the user for one-shot confirmation.

### 4. Collect References

#### 4a. Web search + web fetch
For each confirmed competitor, find URLs of the target screen and capture:
- Pricing, onboarding, dashboard → public marketing page (fetch the HTML, describe)
- Logged-in screens → search for review/teardown articles with screenshots

#### 4b. Headless browser (if available)
Detect once at workflow start:
```bash
LB=""
for _P in "$(pwd)/.claude/skills/gstack/browse/dist/browse" \
          ~/.claude/skills/gstack/browse/dist/browse; do
  [ -x "$_P" ] && LB="$_P" && break
done
[ -n "$LB" ] && echo "BROWSE_READY: $LB" || echo "NO_BROWSE"
```
Use `$LB goto <url>` + `$LB screenshot <path>` for live captures.

#### 4c. Figma MCP (if available + Figma URL provided)
Use the available Figma capability with the `fileKey` and `nodeId` parsed from
the URL. Capture the screenshot and save to
`{OUTPUT_DIR}/references/figma-{nodeId}.png`.

**Cap total references at 30.** Name files: `{company}-{screen-slug}.png`.
Label every reference in the report with its source: `[Web]`, `[Figma]`, `[Browse]`.

### 5. Map Internal Design System ★ (this is the dandul/internal-only step)

This step is what makes design-bench different from generic research.

For each `design_system.packages[].path` from config:
```bash
# List exported components
grep -rE "^export (const|function|class) [A-Z]" {path}/src --include="*.ts" --include="*.tsx" -h | head -100
# List design tokens
[ -d "{tokens}" ] && ls {tokens}
```

**Spawn an Agent (Explore subtype)** to build a component inventory if the package
is large (>50 components):
> "Inventory the components exported from `{path}`. Group by purpose
> (layout/form/feedback/navigation/data-display). Return a markdown table:
> component name, file path, one-line purpose. Under 200 lines."

Save the inventory to `{OUTPUT_DIR}/internal-inventory.md`.

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

### 6. Extract Patterns / Anti-Patterns

From the references gathered:
- **Patterns** — what 3+ competitors do the same way (table stakes)
- **Anti-patterns** — what feels dated/confusing (be specific, cite the example)
- **Unique angles** — the 1-2 standout moves (the "X100 detail")

### 7. Generate Recommendations

Each recommendation MUST include:
- **What to do** (specific, implementable)
- **Why** (tied to evidence — cite which references inspired it)
- **HTML mockup** — see "Mockup Contract" below. One mockup per declared
  platform (mobile=375px, desktop=1280px). Save each to
  `{OUTPUT_DIR}/mockups/_src/rec-{n}-{mobile|desktop}.html`.
  For each pattern/anti-pattern, also generate a mini-mockup to
  `mockups/_src/pattern-{slug}.html` or `mockups/_src/anti-{slug}.html`.
- **Internal mapping** ★ — which existing components from step 5 to use
  (e.g. "Use `ui/src/components/Card` + new `PriceToggle` primitive")
- **PR split suggestion** ★ — recommended PR breakdown
  (e.g. "PR1: PriceToggle primitive; PR2: pricing page composition; PR3: A/B test wiring")

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

### 8. Write report.md

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

### 9. Generate report.html

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

### 10. Summary + Next Steps

Tell the user:
- Where the files are
- The single most important recommendation (1 sentence)
- Suggest: "Want me to scaffold the components for Recommendation 1?" or
  "Should I open a draft PR with the empty file structure?"

## Mockup Contract (Step 7 → 8.5)

Every mockup HTML file must satisfy:

1. **Top wrapper** — `<div class="mockup-frame" data-platform="mobile|desktop">`.
   `data-platform` drives the renderer's viewport (375 or 1280).
2. **`box-sizing: border-box` globally** — apply
   `*, *::before, *::after { box-sizing: border-box; }` so padding stays
   inside the fixed wrapper width. Without this, mobile mockups
   (`375px + padding`) overflow the iframe and clip on the right edge.
3. **Tokens only** — colors, spacing, radii, fonts use `var(--token-name)`.
   No raw hex (`#abc123`) anywhere in the file.
4. **No external assets** — no `<link>`, no `<script src=>`, no
   `<img src="http...">`. Inline SVG and `data:` URIs are OK.
5. **Self-contained** — inline `<style>` block at top. `design-tokens.css`
   is inlined into the iframe srcdoc separately by step 9.
6. **Semantic HTML** — prefer `<button>`, `<nav>`, `<section>` over
   styled `<div>` soup.

Validation before render: grep each generated HTML file for
`#[0-9a-fA-F]{3,8}\b` and `src=["']https?:`. If a match is found,
self-correct once. If self-correction fails, render anyway and add a
warning to the report.

See `references/mockup-examples.md` for 4 reference patterns.

## High Bar for References (Lazyweb-style)

1. The reference MUST directly illustrate the point you're making
2. If you cannot describe what's in the screenshot, do NOT use it — use ASCII instead
3. **3 perfectly-matched references beat 10 loosely-related ones**
4. Better NO image than a mismatched one
5. Never invent a caption — describe what you actually verified

## ASCII Wireframe Convention (fallback only)

ASCII is only used when PNG rendering fails (`RENDER_FAILED`/`RENDER_SKIPPED`).
In that fallback, wrap the ASCII in a `<details>` block in report.md so
the visual mockup in report.html remains the primary surface.

Convention if you do need ASCII fallback: box-drawing chars only
(`┌─┐│└┘├┤┬┴┼`), one screen per block, ≤ 30 lines wide.

## Quality Calibration

- Lazyweb-style: web search results = opinions, screenshots = evidence, your synthesis = interpretation. Label them.
- If the reference corpus is weak for a topic, **say so** — do not pad with irrelevant items.
- A report with 5 strong references + 3 sharp recommendations beats 20 references + 10 vague ones.

## Common Mistakes

| Mistake | Fix |
|---|---|
| Skipped step 5 (internal design-system mapping) | The "internal" in "internal project" means this step is mandatory. |
| Generic recommendations like "make it cleaner" | Each recommendation must be implementable. If you cannot ASCII-sketch it, it's not specific enough. |
| References from very different contexts (gaming → fintech without flag) | Flag context differences explicitly in "Why this works". |
| Forgot PR split suggestion | The user prefers PR-sized checkpoints. Without splits, the report is incomplete. |
| Wrote findings into a plan file instead of `.bench/` | See CRITICAL: Output Behavior. The skill always produces files. |
| Mockup contains raw hex like `#2563eb` | Use `var(--color-primary)`. The renderer accepts the file but the report loses brand fidelity. |
| Mockup loads external CSS or images | Self-contain. External assets break iframe srcdoc rendering and inflate PNG capture latency. |
