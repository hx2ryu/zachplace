# Cross-Runtime Plugin Marketplace Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend the Claude-only marketplace so the same plugin source can be distributed to Claude and Codex while preserving existing Claude installation paths.

**Architecture:** Keep one canonical JSON catalog under `catalog/`. Generate the legacy root Claude marketplace manifest and platform-specific indexes from it. Place both `.claude-plugin/plugin.json` and `.codex-plugin/plugin.json` inside each dual-runtime plugin, while sharing the platform-neutral `skills/`, `scripts/`, and `references/` assets.

**Tech Stack:** JSON, Node.js built-ins, Bash smoke tests, Markdown.

## Global Constraints

- Preserve `claude plugin marketplace add https://github.com/hx2ryu/zachplace` compatibility.
- Keep `design-bench` version and identity synchronized across catalog and manifests.
- Do not add runtime-specific tool names to the shared `SKILL.md` contract.
- Generator output must be deterministic and fail on malformed or incomplete catalog entries.

---

### Task 1: Add marketplace contract tests

**Files:**
- Create: `scripts/test-marketplace.test.sh`

- [ ] **Step 1: Write the failing test**

Add shell tests that require the canonical catalog, generated Claude/Codex indexes, both plugin manifests, and runtime-neutral skill metadata. The test invokes the validator and generator so it fails before those files exist.

- [ ] **Step 2: Run test to verify it fails**

Run: `bash scripts/test-marketplace.test.sh`
Expected: FAIL because `scripts/validate-marketplace.sh` and the new catalog are not present.

- [ ] **Step 3: Commit the RED checkpoint**

Run: `git add scripts/test-marketplace.test.sh && git commit -m "test: add cross-runtime marketplace contract"`

### Task 2: Add canonical catalog and manifest generator

**Files:**
- Create: `catalog/plugins.json`
- Create: `scripts/generate-marketplaces.mjs`
- Create: `scripts/generate-marketplaces.sh`

- [ ] **Step 1: Implement catalog and generator**

Use Node.js built-ins only. Read `catalog/plugins.json`, validate required fields and supported platforms, and write deterministic JSON to `.claude-plugin/marketplace.json`, `marketplaces/claude/marketplace.json`, and `marketplaces/codex/marketplace.json`.

- [ ] **Step 2: Add validator**

Create `scripts/validate-marketplace.sh` to check JSON syntax, catalog/plugin identity parity, source paths, both plugin manifests, and every skill's required `name`/`description` frontmatter.

- [ ] **Step 3: Run the contract test**

Run: `bash scripts/test-marketplace.test.sh`
Expected: PASS for generated indexes and catalog validation; it may still fail on the missing Codex manifest and runtime-neutral skill metadata.

- [ ] **Step 4: Commit the GREEN checkpoint for catalog tooling**

Run: `git add catalog scripts .claude-plugin/marketplace.json marketplaces && git commit -m "feat: add generated cross-runtime marketplace indexes"`

### Task 3: Make design-bench dual-runtime compatible

**Files:**
- Create: `plugins/design-bench/.codex-plugin/plugin.json`
- Create: `plugins/design-bench/runtime/claude.md`
- Create: `plugins/design-bench/runtime/codex.md`
- Modify: `plugins/design-bench/skills/research/SKILL.md`

- [ ] **Step 1: Add Codex manifest and runtime notes**

Keep the same plugin identity/version as Claude. Document Claude slash-command/tool mapping and Codex skill-picker/tool mapping outside the shared skill.

- [ ] **Step 2: Remove Claude-only metadata from shared skill**

Remove `allowed-tools` and replace named tool assumptions with capability-neutral instructions while retaining the workflow.

- [ ] **Step 3: Run the contract test**

Run: `bash scripts/test-marketplace.test.sh`
Expected: PASS.

- [ ] **Step 4: Commit the plugin compatibility checkpoint**

Run: `git add plugins/design-bench && git commit -m "feat: make design-bench compatible with Codex"`

### Task 4: Update contributor and user documentation

**Files:**
- Modify: `README.md`
- Modify: `plugins/design-bench/README.md`
- Create: `marketplaces/README.md`

- [ ] **Step 1: Document both installation paths**

Explain Claude compatibility, Codex plugin installation/index usage, the canonical catalog, and the generator/validator workflow without claiming unsupported CLI syntax.

- [ ] **Step 2: Document contribution rules**

Require both manifests for dual-runtime plugins and describe platform-specific opt-in metadata.

- [ ] **Step 3: Run all checks**

Run: `bash scripts/test-marketplace.test.sh && bash plugins/design-bench/tests/extract-tokens.test.sh`
Expected: PASS.

- [ ] **Step 4: Commit documentation**

Run: `git add README.md plugins/design-bench/README.md marketplaces/README.md && git commit -m "docs: document Claude and Codex marketplace support"`

### Task 5: Final verification

**Files:**
- Modify: `.github/workflows/validate-marketplace.yml`

- [ ] **Step 1: Add CI validation**

Run the marketplace contract and existing plugin smoke tests on pushes and pull requests.

- [ ] **Step 2: Run final verification**

Run: `bash scripts/test-marketplace.test.sh && bash plugins/design-bench/tests/extract-tokens.test.sh && git diff --check`
Expected: all tests pass and `git diff --check` emits no output.

- [ ] **Step 3: Commit CI and final cleanup**

Run: `git add .github/workflows/validate-marketplace.yml && git commit -m "ci: validate cross-runtime marketplace"`
