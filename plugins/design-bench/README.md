# design-bench

A Lazyweb-pattern **design benchmarking skill** — the first plugin in the `zachplace` Claude Code marketplace.

Before you design a new screen, this skill:

1. Researches competitors (greps the curated KR/Global seeds, then fills gaps with WebSearch)
2. Extracts shared patterns and anti-patterns
3. **Maps the project's internal design system (`ui/`, etc.) to ground every recommendation** ← the key difference from Lazyweb
4. Produces a report at `.bench/{topic}-{date}/` with **HTML/CSS mockups rendered using your project's design tokens** (mobile + desktop), recommended components, and PR-split guidance

How it differs from Lazyweb:

- **Zero paid-MCP dependency** — `WebSearch` + `WebFetch` baseline, with optional Figma MCP / Context7 / headless browser
- **Korean-market seed bundled** — fintech / productivity / commerce / content / social / delivery / health / travel / education / B2B SaaS, with leading apps in each category
- **Internal design-system mapping is a first-class workflow step** — "optimal UI/UX" starts by checking whether existing components can solve the problem before introducing new ones
- **Recommendations include PR splits and reference code paths** — the report doubles as an execution plan

## Installation

Add the marketplace first:

```bash
claude plugin marketplace add https://github.com/hx2ryu/zachplace
```

Install the plugin:

```bash
claude plugin install design-bench@zachplace
```

After install, every project can call `/design-bench:research`. Auto-trigger phrases live in the [`SKILL.md`](./skills/research/SKILL.md) description.

## Per-project config (optional)

Add `.bench/config.yml` to a project root and the skill uses it instead of asking interactively.

```yaml
project:
  name: dandul
  category: productivity      # must match a category in competitors-kr.md
  market: KR                  # KR | Global | Both
  platforms: [mobile, web]

design_system:
  packages:
    - path: ui/
      framework: react
    - path: mobile/
      framework: react-native
  tokens: ui/src/tokens

competitors:
  override: []                # extras not in the seed
  exclude: []                 # remove from the seed

figma:
  default_file_key: ""

output_dir: .bench
```

The skill works without this config — workflow step 1 asks for the same fields interactively and offers to save them at the end.

## Output

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

Add `.bench/` to your project `.gitignore` (large + personal).

## Contributing to the seeds

PR against `skills/research/references/competitors-{kr,global}.md`.

Acceptance bar:

- The app must be actively maintained
- "Just popular" isn't enough — there must be **something genuinely worth referencing** (one X100 detail beats a high average)
- Fill all 5 fields. Keep `strengths` to **one line** — that's the discoverability hook

Quarterly stale-review using the `last_reviewed` field.

## License

MIT — see the marketplace root [`LICENSE`](../../LICENSE).
