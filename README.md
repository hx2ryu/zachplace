# zachplace — Claude Code plugin marketplace

A personal Claude Code plugin marketplace by [hx2ryu](https://github.com/hx2ryu). Curated skills for design research, internal product workflows, and team-shared automation.

Plugins live self-contained under `plugins/`. Once registered in the root `.claude-plugin/marketplace.json`, any plugin installs with one command: `claude plugin install <name>@zachplace`.

## Add the marketplace

```bash
claude plugin marketplace add https://github.com/hx2ryu/zachplace
```

## Catalog

| Plugin | One-liner | Install | Details |
|---|---|---|---|
| `design-bench` | Evidence-backed UI/UX benchmarking with KR/Global competitor seeds and internal design-system mapping | `claude plugin install design-bench@zachplace` | [README](./plugins/design-bench/README.md) |

To add a new plugin: append one row here, one entry in `marketplace.json`, and ship the plugin directory (see "Adding a new plugin" below).

## Repository layout

```
zachplace/                                  ← repo (the marketplace)
├── .claude-plugin/
│   └── marketplace.json                    ← marketplace manifest (registers all plugins)
├── plugins/
│   └── design-bench/                       ← plugin 1: self-contained
│       ├── .claude-plugin/plugin.json
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
   ├── README.md                      ← plugin-level usage docs
   └── skills/<skill-name>/
       ├── SKILL.md
       ├── references/                ← optional
       └── scripts/                   ← optional
   ```

2. **Register in `.claude-plugin/marketplace.json`** by appending to the `plugins` array:
   ```json
   {
     "name": "<plugin-name>",
     "source": "./plugins/<plugin-name>",
     "description": "One-line description.",
     "author": { "name": "...", "email": "..." }
   }
   ```

3. **Add a row to the catalog table** in this README.

4. **One PR per plugin.** Bundle the marketplace metadata change with the plugin code so the manifest and plugin land atomically.

5. **Bump the plugin's `version`** ([SemVer](https://semver.org/)) on every release. Users get updates via `claude plugin update`.

### Authoring tips

- The skill's `description` is the **only signal** the agent uses to auto-trigger. Start with "Use when ...", list concrete trigger phrases (KR + EN), and use the `ALWAYS use ...` pattern to prevent under-triggering. Keep it under 1024 characters.
- Move heavy reference data and templates to `references/` — keep `SKILL.md` under 500 lines.
- Put deterministic, repetitive operations in `scripts/` as bash files.
- Document **graceful degradation** for any optional MCP/CLI dependency — the skill must still do something useful when the dependency is missing.
- For skills that produce artifacts, put a `CRITICAL: Output Behavior` section at the top of `SKILL.md` to force file creation regardless of plan mode.

## License

MIT for the whole marketplace and every plugin — see the root `LICENSE`. To use a different license for a specific plugin, drop a `LICENSE` into `plugins/<name>/` and update its `plugin.json` `license` field.
