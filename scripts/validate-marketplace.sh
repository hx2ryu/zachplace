#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
node - "$ROOT" <<'NODE'
const fs = require("node:fs");
const path = require("node:path");
const root = process.argv[2];
const readJson = (relative) => JSON.parse(fs.readFileSync(path.join(root, relative), "utf8"));
const fail = (message) => { console.error(`FAIL: ${message}`); process.exit(1); };
const catalog = readJson("catalog/plugins.json");
const byName = new Map(catalog.plugins.map((plugin) => [plugin.name, plugin]));

for (const relative of [".claude-plugin/marketplace.json", "marketplaces/claude/marketplace.json", "marketplaces/codex/marketplace.json"]) {
  const index = readJson(relative);
  if (index.name !== catalog.marketplace.name) fail(`${relative}: marketplace name mismatch`);
  for (const plugin of index.plugins) {
    const base = relative === ".claude-plugin/marketplace.json"
      ? root
      : path.dirname(path.join(root, relative));
    const source = path.resolve(base, plugin.source);
    if (!fs.existsSync(source)) fail(`${relative}: source does not exist: ${plugin.source}`);
    const canonical = byName.get(plugin.name);
    if (!canonical) fail(`${relative}: unknown plugin ${plugin.name}`);
    if (plugin.description !== canonical.description) fail(`${relative}: description mismatch for ${plugin.name}`);
  }
}

for (const plugin of catalog.plugins) {
  const pluginRoot = path.join(root, plugin.path);
  for (const [platform, relative] of [["claude", ".claude-plugin/plugin.json"], ["codex", ".codex-plugin/plugin.json"]]) {
    if (!plugin.platforms.includes(platform)) continue;
    const manifest = readJson(`${plugin.path}/${relative}`);
    if (manifest.name !== plugin.name) fail(`${plugin.name}: ${platform} name mismatch`);
    if (manifest.version !== plugin.version) fail(`${plugin.name}: ${platform} version mismatch`);
  }
  const skillsRoot = path.join(pluginRoot, "skills");
  if (!fs.existsSync(skillsRoot)) fail(`${plugin.name}: skills directory missing`);
  for (const skill of fs.readdirSync(skillsRoot)) {
    const skillFile = path.join(skillsRoot, skill, "SKILL.md");
    if (!fs.existsSync(skillFile)) fail(`${plugin.name}: missing ${skill}/SKILL.md`);
    const content = fs.readFileSync(skillFile, "utf8");
    if (!/^---\n[\s\S]*?^name:\s*\S+/m.test(content)) fail(`${skillFile}: name frontmatter missing`);
    if (!/^---\n[\s\S]*?^description:\s*/m.test(content)) fail(`${skillFile}: description frontmatter missing`);
    if (/^allowed-tools:/m.test(content)) fail(`${skillFile}: shared skill contains allowed-tools`);
  }
}

for (const platform of ["claude", "codex"]) {
  const actual = readJson(`marketplaces/${platform}/marketplace.json`).plugins.map((p) => p.name).sort();
  const expected = catalog.plugins.filter((p) => p.platforms.includes(platform)).map((p) => p.name).sort();
  if (JSON.stringify(actual) !== JSON.stringify(expected)) fail(`${platform}: plugin list does not match catalog`);
}
console.log("PASS: marketplace manifests and plugin contracts are valid");
NODE
