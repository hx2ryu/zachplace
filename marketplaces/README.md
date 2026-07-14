# Marketplace indexes

The files in this directory are generated from [`catalog/plugins.json`](../catalog/plugins.json).

- `claude/marketplace.json` is the Claude-compatible index.
- `codex/marketplace.json` is the Codex-compatible index.

Regenerate and validate them with:

```bash
bash scripts/generate-marketplaces.sh
bash scripts/validate-marketplace.sh
```

The legacy root `.claude-plugin/marketplace.json` is generated as well so existing Claude installation commands remain valid.
