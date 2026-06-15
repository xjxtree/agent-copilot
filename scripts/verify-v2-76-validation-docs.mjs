#!/usr/bin/env node

import { existsSync, readFileSync } from "node:fs";
import { join, resolve } from "node:path";

const repoRoot = resolve(new URL("..", import.meta.url).pathname);
const checklistPath = join(repoRoot, "docs", "v2.76-verification-checklist.md");

function fail(message) {
  console.error(`V2.76 validation docs verification failed: ${message}`);
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
    fail(`${label} missing required V2.76 reference: ${snippet}`);
  }
}

function rejectText(text, label, snippet) {
  if (text.includes(snippet)) {
    fail(`${label} still contains planned/stale V2.76 text: ${snippet}`);
  }
}

const checklist = readRequired(checklistPath);
const readme = readRequired(join(repoRoot, "README.md"));
const packageJson = readRequired(join(repoRoot, "package.json"));
const developmentTasks = readRequired(join(repoRoot, "docs", "development-tasks.md"));
const roadmap = readRequired(join(repoRoot, "docs", "roadmap.md"));
const agents = readRequired(join(repoRoot, "AGENTS.md"));

const requiredChecklistSnippets = [
  "# V2.76 Verification Checklist",
  "Status: completed on 2026-06-15.",
  "readiness/routing/cross-agent/remediation/provider/session staged feedback",
  "partial rows",
  "elapsed time",
  "timeout/fallback/blocked states",
  "real-local Computer Use evidence",
  "Completed Boundary",
  "Completed Evidence Checklist",
  "Real-local Computer Use Evidence",
  "Stage Feedback Matrix",
  "Safety Boundary",
  "Canonical Blockers",
  "skills-copilot.main-window",
  "skills-copilot.task-cockpit.input",
  "skills-copilot.task-cockpit.input.status",
  "skills-copilot.task-cockpit.stage-progress",
  "PID: `39728`",
  "Captured app window id: `36736`",
  "docs/ui-artifacts/v2.76-progressive-cockpit-feedback/completed.png",
  "耗时：5 秒",
  "耗时：6 秒",
  "Fallback / 部分",
  "10 个阻塞项",
  "已超时",
  "Provider 观测",
  "Agent Session Skill Review",
  "pnpm verify:v2.76-docs",
  "pnpm check:privacy",
  "pnpm check:macos",
  "pnpm verify:screenshot-artifacts",
  "git diff --check",
  "No new provider default calls",
  "No write/apply path",
  "No script execution",
  "No credential reads",
  "No cloud sync",
  "No telemetry",
  "No hidden task state",
  "No new analysis/provider service semantics by default",
];

for (const snippet of requiredChecklistSnippets) {
  requireText(checklist, "docs/v2.76-verification-checklist.md", snippet);
}

const stageSnippets = [
  "Readiness",
  "Routing",
  "Cross-agent",
  "Remediation",
  "Provider",
  "Session",
  "Overall Cockpit",
];

for (const snippet of stageSnippets) {
  requireText(checklist, "docs/v2.76-verification-checklist.md", `| ${snippet} |`);
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
  requireText(checklist, "docs/v2.76-verification-checklist.md", `\`${code}\``);
}

rejectText(checklist, "docs/v2.76-verification-checklist.md", "Status: planned");
rejectText(checklist, "docs/v2.76-verification-checklist.md", "V2.76 Progressive Cockpit feedback is not completed");
rejectText(checklist, "docs/v2.76-verification-checklist.md", "- [ ]");

const checkedItems = checklist.match(/- \[x\]/g) ?? [];
if (checkedItems.length < 16) {
  fail(`V2.76 completed checklist has too few checked evidence items: ${checkedItems.length}`);
}

if (!packageJson.includes('"verify:v2.76-docs": "node scripts/verify-v2-76-validation-docs.mjs"')) {
  fail("package.json is missing verify:v2.76-docs script");
}

const requiredReferenceChecks = [
  [readme, "README.md", "V2.76 validation"],
  [readme, "README.md", "V2.76 验证清单（completed）"],
  [readme, "README.md", "docs/ui-artifacts/v2.76-progressive-cockpit-feedback/completed.png"],
  [readme, "README.md", "skills-copilot.task-cockpit.stage-progress"],
  [readme, "README.md", "PID `39728`"],
  [readme, "README.md", "V2.77-V2.79 remain planned"],
  [developmentTasks, "docs/development-tasks.md", "V2.76 Verification Checklist（completed）"],
  [developmentTasks, "docs/development-tasks.md", "V2.76 closeout evidence"],
  [developmentTasks, "docs/development-tasks.md", "PID `39728`"],
  [developmentTasks, "docs/development-tasks.md", "skills-copilot.task-cockpit.stage-progress"],
  [developmentTasks, "docs/development-tasks.md", "V2.77 remains planned"],
  [roadmap, "docs/roadmap.md", "V2.76 closeout evidence"],
  [roadmap, "docs/roadmap.md", "PID `39728`"],
  [roadmap, "docs/roadmap.md", "skills-copilot.task-cockpit.stage-progress"],
  [roadmap, "docs/roadmap.md", "V2.77-V2.79 remain planned"],
  [agents, "AGENTS.md", "V2.76 completed boundary"],
  [agents, "AGENTS.md", "PID `39728`"],
  [agents, "AGENTS.md", "skills-copilot.task-cockpit.stage-progress"],
  [agents, "AGENTS.md", "provider/write/execute/credentials/cloud/telemetry"],
];

for (const [text, label, snippet] of requiredReferenceChecks) {
  requireText(text, label, snippet);
}

const staleReferenceChecks = [
  [readme, "README.md", "V2.76 validation scaffold（planned）"],
  [readme, "README.md", "V2.76 验证清单（planned）"],
  [developmentTasks, "docs/development-tasks.md", "V2.76 Verification Checklist（planned）"],
  [developmentTasks, "docs/development-tasks.md", "V2.76 planned validation evidence"],
  [roadmap, "docs/roadmap.md", "V2.76 planned validation evidence"],
  [agents, "AGENTS.md", "V2.76 validation scaffold is prepared but planned only."],
  [agents, "AGENTS.md", "V2.76 planned boundary"],
];

for (const [text, label, snippet] of staleReferenceChecks) {
  rejectText(text, label, snippet);
}

console.log("V2.76 validation docs verification passed");
