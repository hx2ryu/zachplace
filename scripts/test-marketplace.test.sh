#!/usr/bin/env bash
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VALIDATE="$ROOT/scripts/validate-marketplace.sh"
GENERATE="$ROOT/scripts/generate-marketplaces.sh"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

[ -x "$VALIDATE" ] || fail "validator is missing or not executable"
[ -x "$GENERATE" ] || fail "generator is missing or not executable"

bash "$GENERATE" >/dev/null || fail "generator failed"
bash "$VALIDATE" || fail "validator failed"

node -e '
const fs = require("fs");
const root = process.argv[1];
const files = [
  ".claude-plugin/marketplace.json",
  "marketplaces/claude/marketplace.json",
  "marketplaces/codex/marketplace.json",
  "plugins/design-bench/.claude-plugin/plugin.json",
  "plugins/design-bench/.codex-plugin/plugin.json"
];
for (const file of files) JSON.parse(fs.readFileSync(`${root}/${file}`, "utf8"));
const skill = fs.readFileSync(`${root}/plugins/design-bench/skills/research/SKILL.md`, "utf8");
if (!/^---[\s\S]*^name:\s*research/m.test(skill)) throw new Error("skill name frontmatter missing");
if (!/^---[\s\S]*^description:\s*\|/m.test(skill)) throw new Error("skill description frontmatter missing");
if (/^allowed-tools:/m.test(skill)) throw new Error("Claude-only allowed-tools leaked into shared skill");
' "$ROOT" || fail "runtime-neutral skill contract failed"

echo "PASS: cross-runtime marketplace contract"
