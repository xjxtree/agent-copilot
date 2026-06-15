#!/usr/bin/env node

import { existsSync, readFileSync } from "node:fs";
import { join, resolve } from "node:path";

const repoRoot = resolve(new URL("..", import.meta.url).pathname);
const checklistPath = join(repoRoot, "docs", "v2.74-verification-checklist.md");

function fail(message) {
  console.error(`V2.74 validation docs verification failed: ${message}`);
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
  "# V2.74 Verification Checklist",
  "Status: completed on 2026-06-15.",
  "Required Closeout Evidence",
  "Completed Evidence",
  "Exact Workspace Bundle and PID Targeting",
  "Duplicate Same-bundle Detection",
  "Canonical Blocker Handling",
  "Unlocked Real-local Computer Use Evidence",
  "No Signing, Notarization, or Distribution Scope",
  "Expected Commands",
  "current workspace `dist/SkillsCopilot.app`",
  "bundle id `dev.skills-copilot.native`",
  "absolute app path",
  "running PID",
  "CG window id",
  "AX window",
  "same bundle id",
  "PID `52193`",
  "CG capture evidence",
  "window id `36200`",
  "skills-copilot.main-window",
  "skills-copilot.task-cockpit.input",
  "skills-copilot.task-cockpit.result",
  "docs/ui-artifacts/v2.74-launch-window-targeting/completed.png",
  "activation-failed",
  "Fixture smoke, fixture screenshots, no-capture launch success, and app-name-only lookup are supporting evidence only.",
  "They cannot replace blocked real-local Computer Use evidence.",
  "Do not substitute fixture screenshots, direct CG captures, or smoke success for the missing Computer Use interaction.",
  "No formal signing or certificate workflow.",
  "No notarization.",
  "No DMG or ZIP packaging.",
  "No public distribution or release channel work.",
  "pnpm verify:v2.74-docs",
  "pnpm check:privacy",
  "git diff --check",
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

if (!checklist.includes("Status: completed")) {
  fail("V2.74 checklist is not marked completed after closeout");
}

if (checklist.includes("- [ ]")) {
  fail("V2.74 completed checklist still contains unchecked evidence items");
}

const checkedItems = checklist.match(/- \[x\]/g) ?? [];
if (checkedItems.length < 9) {
  fail(`V2.74 completed checklist has too few checked evidence items: ${checkedItems.length}`);
}

if (!packageJson.includes('"verify:v2.74-docs": "node scripts/verify-v2-74-validation-docs.mjs"')) {
  fail("package.json is missing verify:v2.74-docs script");
}

const requiredReferenceChecks = [
  [readme, "README.md", "V2.74 验证清单"],
  [readme, "README.md", "V2.74 验证清单（completed）"],
  [readme, "README.md", "docs/v2.74-verification-checklist.md"],
  [readme, "README.md", "pnpm verify:v2.74-docs"],
  [readme, "README.md", "V2.75-V2.79 remain planned"],
  [developmentTasks, "docs/development-tasks.md", "v2.74-verification-checklist.md"],
  [developmentTasks, "docs/development-tasks.md", "V2.74 Verification Checklist（completed）"],
  [developmentTasks, "docs/development-tasks.md", "V2.75-V2.79 remain planned"],
  [roadmap, "docs/roadmap.md", "v2.74-verification-checklist.md"],
  [roadmap, "docs/roadmap.md", "V2.74 closeout evidence"],
  [agents, "AGENTS.md", "V2.74 completed boundary"],
  [agents, "AGENTS.md", "exact workspace bundle/PID"],
];

for (const [text, label, snippet] of requiredReferenceChecks) {
  if (!text.includes(snippet)) {
    fail(`${label} missing required V2.74 reference: ${snippet}`);
  }
}

console.log("V2.74 validation docs verification passed");
