#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const catalog = JSON.parse(fs.readFileSync(path.join(root, "catalog/plugins.json"), "utf8"));
const supported = new Set(["claude", "codex"]);

function fail(message) { console.error(`catalog error: ${message}`); process.exit(1); }
if (!catalog.marketplace?.name || !catalog.marketplace?.owner?.name) fail("marketplace metadata is incomplete");
if (!Array.isArray(catalog.plugins) || catalog.plugins.length === 0) fail("plugins must be a non-empty array");

const seen = new Set();
for (const plugin of catalog.plugins) {
  for (const field of ["name", "path", "description", "version", "author", "platforms"]) {
    if (!plugin[field]) fail(`${field} is required for a plugin`);
  }
  if (seen.has(plugin.name)) fail(`duplicate plugin name: ${plugin.name}`);
  seen.add(plugin.name);
  if (!Array.isArray(plugin.platforms) || plugin.platforms.length === 0) fail(`platforms are missing for ${plugin.name}`);
  for (const platform of plugin.platforms) if (!supported.has(platform)) fail(`unsupported platform ${platform} for ${plugin.name}`);
  if (!fs.existsSync(path.join(root, plugin.path))) fail(`source path does not exist: ${plugin.path}`);
}

function entries(platform, prefix) {
  return catalog.plugins.filter((p) => p.platforms.includes(platform)).map((p) => ({
    name: p.name, source: `${prefix}${p.path}`, description: p.description, author: p.author
  }));
}
function index(platform, prefix) {
  return { name: catalog.marketplace.name, owner: catalog.marketplace.owner,
    metadata: { description: catalog.marketplace.description }, plugins: entries(platform, prefix) };
}
function writeJson(relative, value) {
  const output = path.join(root, relative);
  fs.mkdirSync(path.dirname(output), { recursive: true });
  fs.writeFileSync(output, `${JSON.stringify(value, null, 2)}\n`);
}

writeJson(".claude-plugin/marketplace.json", index("claude", "./"));
writeJson("marketplaces/claude/marketplace.json", index("claude", "../../"));
writeJson("marketplaces/codex/marketplace.json", index("codex", "../../"));
