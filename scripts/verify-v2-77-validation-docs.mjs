#!/usr/bin/env node

import { existsSync, readFileSync } from "node:fs";
import { join, resolve } from "node:path";

const repoRoot = resolve(new URL("..", import.meta.url).pathname);
const checklistPath = join(repoRoot, "docs", "v2.77-verification-checklist.md");

function fail(message) {
  console.error(`V2.77 validation docs verification failed: ${message}`);
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
    fail(`${label} missing required V2.77 reference: ${snippet}`);
  }
}

function rejectText(text, label, snippet) {
  if (text.includes(snippet)) {
    fail(`${label} contains planned/stale V2.77 text: ${snippet}`);
  }
}

const checklist = readRequired(checklistPath);
const readme = readRequired(join(repoRoot, "README.md"));
const packageJson = readRequired(join(repoRoot, "package.json"));
const developmentTasks = readRequired(join(repoRoot, "docs", "development-tasks.md"));
const roadmap = readRequired(join(repoRoot, "docs", "roadmap.md"));
const agents = readRequired(join(repoRoot, "AGENTS.md"));

const requiredChecklistSnippets = [
  "# V2.77 Verification Checklist",
  "Status: completed on 2026-06-15.",
  "Completed Boundary",
  "Completed Evidence Checklist",
  "Real-local Computer Use Evidence",
  "Canonical Blocker Explanation Matrix",
  "Safety Boundary",
  "`skills-copilot.validation-workbench`",
  "`skills-copilot.validation-workbench.summary`",
  "`skills-copilot.validation-workbench.evidence-standards`",
  "`skills-copilot.validation-workbench.blocker-row.locked-session`",
  "`skills-copilot.validation-workbench.blocker-row.window-not-found`",
  "`skills-copilot.validation-workbench.blocker-row.tool-layer-unknown`",
  "`<repo>/dist/SkillsCopilot.app`",
  "Bundle id: `dev.skills-copilot.native`",
  "Running PID: `34909`",
  "Captured app window id: `36974`",
  "docs/ui-artifacts/v2.77-validation-workbench/completed.png",
  "规范 blocker",
  "Fixture smoke",
  "仅辅助",
  "可运行动作",
  "pnpm verify:v2.77-docs",
  "pnpm check:macos",
  "pnpm check:privacy",
  "pnpm verify:screenshot-artifacts",
  "git diff --check",
  "No provider default calls.",
  "No write/apply path.",
  "No script execution.",
  "No credential reads.",
  "No cloud sync.",
  "No telemetry.",
  "No replacement of unlocked manual visual review.",
];

for (const snippet of requiredChecklistSnippets) {
  requireText(checklist, "docs/v2.77-verification-checklist.md", snippet);
}

const blockerCodes = [
  "locked-session",
  "window-not-found",
  "no-ax-window",
  "screen-recording-permission",
  "stale-bundle",
  "black-capture",
  "flat-capture",
  "transparent-capture",
  "invalid-capture",
  "computer-use-timeout",
  "remote-connection",
  "activation-failed",
  "tool-layer-unknown",
];

for (const code of blockerCodes) {
  requireText(checklist, "docs/v2.77-verification-checklist.md", `\`${code}\``);
}

rejectText(checklist, "docs/v2.77-verification-checklist.md", "Status: planned");
rejectText(checklist, "docs/v2.77-verification-checklist.md", "V2.77 Real-local validation workbench is not completed");
rejectText(checklist, "docs/v2.77-verification-checklist.md", "- [ ]");

const checkedItems = checklist.match(/- \[x\]/g) ?? [];
if (checkedItems.length < 14) {
  fail(`V2.77 completed checklist has too few checked evidence items: ${checkedItems.length}`);
}

if (!packageJson.includes('"verify:v2.77-docs": "node scripts/verify-v2-77-validation-docs.mjs"')) {
  fail("package.json is missing verify:v2.77-docs script");
}

const requiredReferenceChecks = [
  [readme, "README.md", "V2.77 validation"],
  [readme, "README.md", "V2.77 验证清单（completed）"],
  [readme, "README.md", "skills-copilot.validation-workbench"],
  [readme, "README.md", "PID `34909`"],
  [readme, "README.md", "docs/ui-artifacts/v2.77-validation-workbench/completed.png"],
  [readme, "README.md", "V2.81-V2.83 remain planned"],
  [developmentTasks, "docs/development-tasks.md", "V2.77 Verification Checklist（completed）"],
  [developmentTasks, "docs/development-tasks.md", "V2.77 closeout evidence"],
  [developmentTasks, "docs/development-tasks.md", "PID `34909`"],
  [developmentTasks, "docs/development-tasks.md", "skills-copilot.validation-workbench"],
  [developmentTasks, "docs/development-tasks.md", "V2.80 Verification Checklist（completed）"],
  [roadmap, "docs/roadmap.md", "V2.77 closeout evidence"],
  [roadmap, "docs/roadmap.md", "PID `34909`"],
  [roadmap, "docs/roadmap.md", "skills-copilot.validation-workbench"],
  [roadmap, "docs/roadmap.md", "V2.81-V2.83 remain planned"],
  [agents, "AGENTS.md", "V2.77 completed boundary"],
  [agents, "AGENTS.md", "PID `34909`"],
  [agents, "AGENTS.md", "skills-copilot.validation-workbench"],
  [agents, "AGENTS.md", "no provider/write/apply/script/credential/cloud/telemetry"],
];

for (const [text, label, snippet] of requiredReferenceChecks) {
  requireText(text, label, snippet);
}

const staleReferenceChecks = [
  [readme, "README.md", "V2.77 validation docs scaffold（planned）"],
  [readme, "README.md", "V2.77 验证清单（planned）"],
  [developmentTasks, "docs/development-tasks.md", "V2.77 Verification Checklist（planned）"],
  [developmentTasks, "docs/development-tasks.md", "V2.77 planned checklist"],
  [roadmap, "docs/roadmap.md", "V2.77 planned checklist"],
  [agents, "AGENTS.md", "V2.77 docs/verifier scaffold is prepared but planned only"],
  [agents, "AGENTS.md", "V2.77 planned boundary"],
];

for (const [text, label, snippet] of staleReferenceChecks) {
  rejectText(text, label, snippet);
}

console.log("V2.77 validation docs verification passed");
