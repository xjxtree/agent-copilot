#!/usr/bin/env node

import { existsSync, readFileSync } from "node:fs";
import { join, resolve } from "node:path";

const repoRoot = resolve(new URL("..", import.meta.url).pathname);

function fail(message) {
  console.error(`V2.80 validation docs verification failed: ${message}`);
  process.exit(1);
}

function readRequired(path) {
  if (!existsSync(path)) {
    fail(`missing required file at ${path}`);
  }
  return readFileSync(path, "utf8");
}

function requireText(text, label, snippet) {
  if (!text.includes(snippet)) {
    fail(`${label} missing required V2.80 reference: ${snippet}`);
  }
}

function rejectText(text, label, snippet) {
  if (text.includes(snippet)) {
    fail(`${label} contains stale V2.80 text: ${snippet}`);
  }
}

function rejectRegex(text, label, pattern, description) {
  if (pattern.test(text)) {
    fail(`${label} contains stale V2.80 text: ${description}`);
  }
}

const checklist = readRequired(join(repoRoot, "docs", "v2.80-verification-checklist.md"));
const readme = readRequired(join(repoRoot, "README.md"));
const agents = readRequired(join(repoRoot, "AGENTS.md"));
const developmentTasks = readRequired(join(repoRoot, "docs", "development-tasks.md"));
const roadmap = readRequired(join(repoRoot, "docs", "roadmap.md"));
const runbook = readRequired(join(repoRoot, "docs", "macos-app-runbook.md"));
const packageJson = readRequired(join(repoRoot, "package.json"));

const requiredChecklistSnippets = [
  "# V2.80 Verification Checklist",
  "Status: completed on 2026-06-15.",
  "V2.80 Detail navigation and visual density polish is completed.",
  "stable `skills-copilot.detail.top` anchor",
  "`DenseCountBadge` and `DenseDisclosureList`",
  "fixture smoke remains supporting evidence only",
  "`pnpm verify:v2.80-docs` is part of the shared `pnpm verify:gate-parity` lane.",
  "No service method additions, renames, or payload expansion.",
  "No provider default calls",
  "No write/apply path",
  "No hidden task state",
  "No scanner/catalog fact mutation",
  "No script execution",
  "No credential reads",
  "No raw prompt, raw response, raw trace",
  "No cloud sync",
  "No telemetry",
  "No public distribution",
  "swift test --package-path apps/macos                    # passed",
  "pnpm verify:macos-ui-layout                             # passed",
  "pnpm verify:v2.80-docs                                  # passed",
  "pnpm verify:v2.79-docs                                  # passed",
  "pnpm verify:gate-parity                                 # passed",
  "pnpm check:macos                                        # passed",
  "pnpm check:privacy                                      # passed",
  "pnpm verify:screenshot-artifacts                        # passed",
  "git diff --check                                        # passed",
  "Running PID: `82571`.",
  "Main window identity: `skills-copilot.main-window`.",
  "selected a real catalog skill, opened `复查`, scrolled the long Review detail surface",
  "picker value `验证工作台`",
  "`skills-copilot.validation-workbench`",
  "Dense evidence result",
  "docs/ui-artifacts/v2.80-detail-density/completed.png",
  "window `37734`, PID `82571`",
  "Final status decision: completed.",
  "No weakening of V2.72-V2.79 validation evidence standards.",
];

for (const snippet of requiredChecklistSnippets) {
  requireText(checklist, "docs/v2.80-verification-checklist.md", snippet);
}

if (checklist.includes("- [ ]")) {
  fail("V2.80 completed checklist must not contain unchecked evidence items");
}
const checkedItems = checklist.match(/- \[x\]/g) ?? [];
if (checkedItems.length < 14) {
  fail(`V2.80 completed checklist has too few checked evidence items: ${checkedItems.length}`);
}

for (const snippet of [
  "Status: in progress docs scaffold.",
  "Status: planned",
  "Final status decision: pending.",
  "Running PID: pending.",
  "Screenshot evidence or canonical blocker: pending.",
  "docs/ui-artifacts/v2.80-detail-navigation-density/",
]) {
  rejectText(checklist, "docs/v2.80-verification-checklist.md", snippet);
}

rejectRegex(checklist, "docs/v2.80-verification-checklist.md", /# pending\b/, "pending command result");

const requiredPackageSnippets = [
  '"verify:v2.80-docs": "node scripts/verify-v2-80-validation-docs.mjs"',
  '"verify:gate-parity": "pnpm verify:service-protocol-drift',
  "pnpm verify:v2.79-docs && pnpm verify:v2.80-docs",
];

for (const snippet of requiredPackageSnippets) {
  requireText(packageJson, "package.json", snippet);
}

const requiredReadmeSnippets = [
  "V2.80 validation",
  "Detail navigation and visual density polish",
  "PID `82571`",
  "skills-copilot.validation-workbench",
  "docs/ui-artifacts/v2.80-detail-density/completed.png",
  "V2.80 验证清单（completed）",
  "pnpm verify:v2.80-docs",
  "V2.86 Rust helper/test split and module-size gate closeout completed",
  "No service method, provider default call, write/apply path, hidden task state, scanner/catalog fact mutation, script execution, credential read, raw prompt/response/trace persistence, cloud sync, telemetry, or public distribution",
];

for (const snippet of requiredReadmeSnippets) {
  requireText(readme, "README.md", snippet);
}

const requiredAgentsSnippets = [
  "V2.80 completed boundary",
  "Detail navigation and visual density polish",
  "PID `82571`",
  "skills-copilot.validation-workbench",
  "docs/ui-artifacts/v2.80-detail-density/completed.png",
  "no service method/provider/write/hidden-state/scanner/script/credential/raw-persistence/cloud/telemetry/public-distribution expansion",
];

for (const snippet of requiredAgentsSnippets) {
  requireText(agents, "AGENTS.md", snippet);
}

const requiredDevelopmentSnippets = [
  "V2.80 Verification Checklist（completed）",
  "PID `82571`",
  "docs/ui-artifacts/v2.80-detail-density/completed.png",
  "V2.80 Detail navigation and visual density polish | Completed",
];

for (const snippet of requiredDevelopmentSnippets) {
  requireText(developmentTasks, "docs/development-tasks.md", snippet);
}

const requiredRoadmapSnippets = [
  "V2.80 Detail navigation and visual density polish completed",
  "PID `82571`",
  "docs/ui-artifacts/v2.80-detail-density/completed.png",
  "V2.86 Rust helper/test split and module-size gate closeout completed",
];

for (const snippet of requiredRoadmapSnippets) {
  requireText(roadmap, "docs/roadmap.md", snippet);
}

const requiredRunbookSnippets = [
  "`pnpm verify:v2.80-docs`",
  "V2.80 completed verifier",
  "Detail navigation and visual density polish",
  "PID `82571`",
  "docs/ui-artifacts/v2.80-detail-density/completed.png",
  "V2.73-V2.86 docs verifiers",
];

for (const snippet of requiredRunbookSnippets) {
  requireText(runbook, "docs/macos-app-runbook.md", snippet);
}

for (const [text, label] of [
  [readme, "README.md"],
  [agents, "AGENTS.md"],
  [developmentTasks, "docs/development-tasks.md"],
  [roadmap, "docs/roadmap.md"],
]) {
  rejectText(text, label, "V2.80 docs/verifier scaffold");
  rejectText(text, label, "V2.80 remains in progress");
  rejectText(text, label, "V2.80 in-progress docs scaffold");
  rejectText(text, label, "V2.80 验证清单（in progress）");
}

console.log("V2.80 validation docs verification passed");
