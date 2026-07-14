# zachplace — Claude Code and Codex plugin marketplace

A personal Claude Code and Codex plugin marketplace by [hx2ryu](https://github.com/hx2ryu). Curated skills for design research, internal product workflows, and team-shared automation.

Plugins live self-contained under `plugins/`. Once registered in the root `.claude-plugin/marketplace.json`, any plugin installs with one command: `claude plugin install <name>@zachplace`.

## Add the marketplace

```bash
claude plugin marketplace add https://github.com/hx2ryu/zachplace
```

The same plugin sources also include Codex manifests under
`plugins/<plugin>/.codex-plugin/` and a generated Codex index at
`marketplaces/codex/marketplace.json`. Use the Codex plugin/marketplace flow
supported by your current Codex client, or point local development directly at
the plugin directory.

## Catalog

| Plugin | One-liner | Install | Details |
|---|---|---|---|
| `design-bench` | Evidence-backed UI/UX benchmarking with KR/Global competitor seeds and internal design-system mapping | `claude plugin install design-bench@zachplace` | [README](./plugins/design-bench/README.md) |

To add a new plugin: append one row here, add one entry to `catalog/plugins.json`, generate the indexes, and ship the plugin directory (see "Adding a new plugin" below).

## Repository layout

```
zachplace/                                  ← repo (the marketplace)
├── .claude-plugin/
│   └── marketplace.json                    ← legacy Claude index (generated)
├── catalog/
│   └── plugins.json                         ← canonical plugin catalog
├── marketplaces/
│   ├── claude/marketplace.json              ← generated Claude index
│   └── codex/marketplace.json               ← generated Codex index
├── plugins/
│   └── design-bench/                       ← plugin 1: self-contained
│       ├── .claude-plugin/plugin.json
│       ├── .codex-plugin/plugin.json
│       ├── README.md
│       └── skills/research/
│           ├── SKILL.md
│           ├── references/
│           └── scripts/
├── README.md                               ← catalog (this file)
└── LICENSE                                 ← MIT (covers the whole marketplace)
```

## Adding a new plugin

1. **Create the plugin directory**
   ```
   plugins/<plugin-name>/
   ├── .claude-plugin/plugin.json     ← metadata (name, description, version, author, license)
   ├── .codex-plugin/plugin.json      ← Codex metadata for dual-runtime plugins
   ├── README.md                      ← plugin-level usage docs
   └── skills/<skill-name>/
       ├── SKILL.md
       ├── references/                ← optional
       └── scripts/                   ← optional
   ```

2. **Register in `catalog/plugins.json`** by adding a catalog entry:
   ```json
   {
     "name": "<plugin-name>",
     "path": "plugins/<plugin-name>",
     "description": "One-line description.",
     "version": "0.1.0",
     "platforms": ["claude", "codex"],
     "author": { "name": "...", "email": "..." }
   }
   ```

3. **Add the platform manifests** inside the plugin:
   ```text
   plugins/<plugin-name>/.claude-plugin/plugin.json
   plugins/<plugin-name>/.codex-plugin/plugin.json
   ```

4. **Regenerate and validate indexes:**
   ```bash
   bash scripts/generate-marketplaces.sh
   bash scripts/validate-marketplace.sh
   ```

5. **One PR per plugin.** Bundle catalog, generated indexes, manifests, and plugin code so they land atomically.

6. **Bump the plugin's `version`** ([SemVer](https://semver.org/)) on every release and keep both manifests synchronized.

### Authoring tips

- The skill's `description` is the **only signal** the agent uses to auto-trigger. Start with "Use when ...", list concrete trigger phrases (KR + EN), and use the `ALWAYS use ...` pattern to prevent under-triggering. Keep it under 1024 characters.
- Move heavy reference data and templates to `references/` — keep `SKILL.md` under 500 lines.
- Put deterministic, repetitive operations in `scripts/` as bash files.
- Document **graceful degradation** for any optional MCP/CLI dependency — the skill must still do something useful when the dependency is missing.
- For skills that produce artifacts, put a `CRITICAL: Output Behavior` section at the top of `SKILL.md` to force file creation regardless of plan mode.

## License

MIT for the whole marketplace and every plugin — see the root `LICENSE`. To use a different license for a specific plugin, drop a `LICENSE` into `plugins/<name>/` and update its `plugin.json` `license` field.
