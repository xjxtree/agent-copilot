#!/usr/bin/env node

import { existsSync, readFileSync } from "node:fs";
import { join, resolve } from "node:path";

const repoRoot = resolve(new URL("..", import.meta.url).pathname);
const checklistPath = join(repoRoot, "docs", "v2.75-verification-checklist.md");

function fail(message) {
  console.error(`V2.75 validation docs verification failed: ${message}`);
  process.exit(1);
}

function readRequired(path) {
  if (!existsSync(path)) {
    fail(`missing required file at ${path}`);
  }
  return readFileSync(path, "utf8");
}

const checklist = readRequired(checklistPath);
const readme = readRequired(join(repoRoot, "README.md"));
const packageJson = readRequired(join(repoRoot, "package.json"));
const developmentTasks = readRequired(join(repoRoot, "docs", "development-tasks.md"));
const roadmap = readRequired(join(repoRoot, "docs", "roadmap.md"));
const agents = readRequired(join(repoRoot, "AGENTS.md"));

const requiredChecklistSnippets = [
  "# V2.75 Verification Checklist",
  "Status: completed on 2026-06-15",
  "V2.75 Task input and input-method resilience is complete",
  "Task input and input-method resilience",
  "Chinese input method composition",
  "pasted text",
  "multiline tasks",
  "leading/trailing whitespace",
  "emoji",
  "automation input",
  "explicit submit",
  "focus restoration",
  "real-local Computer Use evidence",
  "Completed Boundary",
  "Completed Evidence Checklist",
  "Real-local Computer Use Evidence",
  "Real-local Matrix",
  "Canonical Blockers",
  "Safety Boundary",
  "Commands",
  "skills-copilot.task-cockpit.input",
  "skills-copilot.task-cockpit.input.status",
  "skills-copilot.main-window",
  "Ready for explicit submit",
  "settable",
  "PID `43079`",
  "window id: `36527`",
  "docs/ui-artifacts/v2.75-task-input-resilience/completed.png",
  "修复 Task Cockpit 输入",
  "第二行 paste / 自动化输入",
  "whitespace-only input returns no task",
  "nonblank `submissionText` preserves raw text",
  "pnpm verify:v2.75-docs",
  "pnpm check:privacy",
  "pnpm check:macos",
  "git diff --check",
  "unlocked real-local Computer Use",
  "No raw prompt persistence",
  "No cloud sync",
  "No provider default calls",
  "No write/apply path",
  "No script execution",
  "No credential reads",
  "No telemetry",
];

for (const snippet of requiredChecklistSnippets) {
  if (!checklist.includes(snippet)) {
    fail(`missing required checklist text: ${snippet}`);
  }
}

const blockerCodes = [
  "locked-session",
  "window-not-found",
  "no-ax-window",
  "computer-use-timeout",
  "remote-connection",
  "activation-failed",
  "black-capture",
  "flat-capture",
  "transparent-capture",
  "invalid-capture",
  "screen-recording-permission",
  "stale-bundle",
  "tool-layer-unknown",
];

for (const code of blockerCodes) {
  if (!checklist.includes(`\`${code}\``)) {
    fail(`missing canonical blocker code: ${code}`);
  }
}

if (checklist.includes("Status: planned") || checklist.includes("V2.75 is not completed")) {
  fail("V2.75 checklist still contains planned status wording");
}

if (checklist.includes("- [ ]")) {
  fail("V2.75 completed checklist must not contain unchecked evidence items");
}

const checkedItems = checklist.match(/- \[x\]/g) ?? [];
if (checkedItems.length < 12) {
  fail(`V2.75 completed checklist has too few checked evidence items: ${checkedItems.length}`);
}

if (!packageJson.includes('"verify:v2.75-docs": "node scripts/verify-v2-75-validation-docs.mjs"')) {
  fail("package.json is missing verify:v2.75-docs script");
}

const requiredReferenceChecks = [
  [readme, "README.md", "V2.75 validation"],
  [readme, "README.md", "V2.75 验证清单（completed）"],
  [readme, "README.md", "docs/v2.75-verification-checklist.md"],
  [readme, "README.md", "docs/ui-artifacts/v2.75-task-input-resilience/completed.png"],
  [readme, "README.md", "pnpm verify:v2.75-docs"],
  [readme, "README.md", "V2.81-V2.83 remain planned"],
  [readme, "README.md", "AX-settable"],
  [readme, "README.md", "PID `43079`"],
  [developmentTasks, "docs/development-tasks.md", "v2.75-verification-checklist.md"],
  [developmentTasks, "docs/development-tasks.md", "V2.75 Verification Checklist（completed）"],
  [developmentTasks, "docs/development-tasks.md", "AX-settable"],
  [developmentTasks, "docs/development-tasks.md", "PID `43079`"],
  [developmentTasks, "docs/development-tasks.md", "No raw prompt persistence"],
  [roadmap, "docs/roadmap.md", "v2.75-verification-checklist.md"],
  [roadmap, "docs/roadmap.md", "V2.75 closeout evidence"],
  [roadmap, "docs/roadmap.md", "AX-settable"],
  [roadmap, "docs/roadmap.md", "No raw prompt persistence"],
  [agents, "AGENTS.md", "V2.75 completed boundary"],
  [agents, "AGENTS.md", "input-method resilience"],
  [agents, "AGENTS.md", "PID `43079`"],
  [agents, "AGENTS.md", "raw prompt persistence"],
];

for (const [text, label, snippet] of requiredReferenceChecks) {
  if (!text.includes(snippet)) {
    fail(`${label} missing required V2.75 reference: ${snippet}`);
  }
}

console.log("V2.75 validation docs verification passed");
