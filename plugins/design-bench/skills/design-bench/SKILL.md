---
name: design-bench
description: |
  Use when the user requests design research, competitive UI/UX benchmarking, or
  pre-implementation UX exploration for a new screen or feature.
  Trigger on (KR): "디자인 리서치", "디자인 벤치마크", "벤치마킹 해줘",
  "경쟁사 UI 분석", "UI 리서치", "{화면명} 어떻게 만들지", "레퍼런스 찾아줘".
  Trigger on (EN): "design research", "competitive analysis", "UI benchmark",
  "best practices for {screen}", "how do top apps handle {feature}".
  ALWAYS use this skill when designing a new screen or major UI change before
  implementation, especially when the project has an internal design system.
allowed-tools:
  - Bash
  - Read
  - Write
  - Glob
  - Grep
  - WebSearch
  - WebFetch
  - Agent
---

# Design Bench

Lazyweb-pattern design benchmarking. Combines curated competitor seeds, web
research, optional Figma MCP context, and **internal design-system mapping**
to produce an evidence-backed UI/UX recommendation report.

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
| `WebSearch` | yes | (none — minimum requirement) |
| `WebFetch` | yes | (none — minimum requirement) |
| Figma MCP (`mcp__plugin_figma_figma__*`) | optional | Skip step 4c, note in report |
| `Context7` (`mcp__plugin_context7_context7__*`) | optional | Skip library-docs lookup |
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

### 3. Identify Competitors (Seed First, WebSearch to Fill)

**Seed grep first** — do NOT skip this:
```bash
grep -A 5 "^### " plugins/design-bench/skills/design-bench/references/competitors-kr.md
grep -A 5 "^### " plugins/design-bench/skills/design-bench/references/competitors-global.md
```
(Adjust paths — when installed as plugin, files are in
`~/.claude/plugins/cache/.../design-bench/skills/design-bench/references/`.)

Filter by `project.category` and `project.market`, apply `competitors.override`
and `competitors.exclude` from config.

**Then WebSearch** for any gaps (recent entrants, niche players the seed missed):
- `"{category} app 2026 best UX"` — KR market: add `한국` / `Korean`
- `"{competitor name} {screen type}"`

Present the final 5-10 competitor list to the user for one-shot confirmation.

### 4. Collect References

#### 4a. WebSearch + WebFetch
For each confirmed competitor, find URLs of the target screen and capture:
- Pricing, onboarding, dashboard → public marketing page (WebFetch the HTML, describe)
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
Use `mcp__plugin_figma_figma__get_design_context` with the `fileKey` and `nodeId`
parsed from the URL. Capture the screenshot via `get_screenshot`. Save to
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

### 6. Extract Patterns / Anti-Patterns

From the references gathered:
- **Patterns** — what 3+ competitors do the same way (table stakes)
- **Anti-patterns** — what feels dated/confusing (be specific, cite the example)
- **Unique angles** — the 1-2 standout moves (the "X100 detail")

### 7. Generate Recommendations

Each recommendation MUST include:
- **What to do** (specific, implementable)
- **Why** (tied to evidence — cite which references inspired it)
- **ASCII wireframe** (box-drawing characters, just enough to communicate layout)
- **Internal mapping** ★ — which existing components from step 5 to use
  (e.g. "Use `ui/src/components/Card` + new `PriceToggle` primitive")
- **PR split suggestion** ★ — recommended PR breakdown
  (e.g. "PR1: PriceToggle primitive; PR2: pricing page composition; PR3: A/B test wiring")

Example ASCII wireframe:
```
┌─────────────────────────────┐
│  Logo            [Sign In]  │
├─────────────────────────────┤
│   ◉ Monthly  ○ Annual       │
│                             │
│   ┌─────┐ ┌─────┐ ┌─────┐  │
│   │ Free│ │ Pro │ │ Team│  │
│   │ $0  │ │ $12 │ │ $99 │  │
│   └──┬──┘ └──┬──┘ └──┬──┘  │
│   [Get Started →]           │
└─────────────────────────────┘
```

### 8. Write report.md

Use `references/report-template.md` as the structure. Reverse-pyramid:
TL;DR → Recommendations → Evidence → Findings.

### 9. Generate report.html

Self-contained HTML, inline CSS, max-width 900px, system fonts, light-blue
TL;DR callout, rounded-corner image styling, relative `references/` paths.
Do NOT depend on external CSS or JS.

After writing: `open "{OUTPUT_DIR}/report.html"`.

### 10. Summary + Next Steps

Tell the user:
- Where the files are
- The single most important recommendation (1 sentence)
- Suggest: "Want me to scaffold the components for Recommendation 1?" or
  "Should I open a draft PR with the empty file structure?"

## High Bar for References (Lazyweb-style)

1. The reference MUST directly illustrate the point you're making
2. If you cannot describe what's in the screenshot, do NOT use it — use ASCII instead
3. **3 perfectly-matched references beat 10 loosely-related ones**
4. Better NO image than a mismatched one
5. Never invent a caption — describe what you actually verified

## ASCII Wireframe Convention

- Box-drawing chars only: `┌─┐│└┘├┤┬┴┼`
- One screen per block, ≤ 30 lines wide
- Annotate interactive bits inline: `[Button]`, `◉ Selected`, `○ Unselected`
- Don't try to render visual style — just layout and hierarchy

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
