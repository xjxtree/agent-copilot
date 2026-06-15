#!/usr/bin/env node

import { existsSync, readFileSync } from "node:fs";
import { join, resolve } from "node:path";

const repoRoot = resolve(new URL("..", import.meta.url).pathname);

function fail(message) {
  console.error(`V2.79 validation docs verification failed: ${message}`);
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
    fail(`${label} missing required V2.79 reference: ${snippet}`);
  }
}

function rejectText(text, label, snippet) {
  if (text.includes(snippet)) {
    fail(`${label} contains stale or invalid V2.79 text: ${snippet}`);
  }
}

function rejectRegex(text, label, pattern, description) {
  if (pattern.test(text)) {
    fail(`${label} contains stale or invalid V2.79 text: ${description}`);
  }
}

const checklist = readRequired(join(repoRoot, "docs", "v2.79-verification-checklist.md"));
const readme = readRequired(join(repoRoot, "README.md"));
const agents = readRequired(join(repoRoot, "AGENTS.md"));
const developmentTasks = readRequired(join(repoRoot, "docs", "development-tasks.md"));
const roadmap = readRequired(join(repoRoot, "docs", "roadmap.md"));
const runbook = readRequired(join(repoRoot, "docs", "macos-app-runbook.md"));
const packageJson = readRequired(join(repoRoot, "package.json"));

const requiredChecklistSnippets = [
  "# V2.79 Verification Checklist",
  "Status: completed.",
  "V2.79 scope: privacy fixture and evidence-surface localization sweep after V2.78.",
  "V2.79 is completed with code, tests, docs, shared gates, and fresh unlocked real-local Computer Use evidence",
  "Privacy fixture hardening",
  "non-allowlisted loopback host-port fingerprints",
  "Evidence-surface localization sweep",
  "path redaction/collapse/reveal",
  "Chinese localization",
  "Guided Cleanup",
  "Local Skill Map",
  "Review",
  "Task Cockpit",
  "Provider Observability and Validation Workbench",
  "nested evidence cards",
  "`pnpm verify:v2.79-docs` is run and recorded",
  "`pnpm check:macos` is run and recorded",
  "Fresh unlocked real-local Computer Use evidence is recorded",
  "pnpm check:macos                                     # passed",
  "pnpm check:privacy                                   # passed",
  "git diff --check                                     # passed",
  "PID: `68064`",
  "Main window identity: `skills-copilot.main-window`",
  "skills-copilot.validation-workbench",
  "skills-copilot.validation-workbench.summary",
  "skills-copilot.validation-workbench.evidence-standards",
  "stale-bundle",
  "docs/ui-artifacts/v2.79-privacy-localization/completed.png",
  "Fixture smoke screenshots and smoke success are supporting evidence only.",
  "Final status decision: completed.",
  "No credential reads.",
  "No network behavior change.",
  "No scanner/catalog fact mutation.",
  "No provider default calls",
  "No write/apply path",
  "No script execution",
  "No cloud sync",
  "No telemetry",
];

for (const snippet of requiredChecklistSnippets) {
  requireText(checklist, "docs/v2.79-verification-checklist.md", snippet);
}

rejectRegex(checklist, "docs/v2.79-verification-checklist.md", /^Status:\s*planned\b/im, "planned status");
rejectRegex(checklist, "docs/v2.79-verification-checklist.md", /Final status decision:\s*pending\b/i, "pending final status");
rejectRegex(checklist, "docs/v2.79-verification-checklist.md", /coordinator evidence pending/i, "pending coordinator evidence");
rejectRegex(checklist, "docs/v2.79-verification-checklist.md", /^-\s*\[\s\]/im, "unchecked coordinator evidence item");
rejectText(checklist, "docs/v2.79-verification-checklist.md", "No fresh Computer Use screenshot is required");
rejectText(checklist, "docs/v2.79-verification-checklist.md", "fixture smoke screenshots can replace");

const requiredPackageSnippets = [
  '"verify:v2.79-docs": "node scripts/verify-v2-79-validation-docs.mjs"',
  '"verify:gate-parity": "pnpm verify:service-protocol-drift',
  "pnpm verify:v2.78-docs && pnpm verify:v2.79-docs",
];

for (const snippet of requiredPackageSnippets) {
  requireText(packageJson, "package.json", snippet);
}

const requiredReadmeSnippets = [
  "V2.79 validation",
  "multi-agent V2.79 implementation completed",
  "pnpm verify:v2.79-docs",
  "V2.79 验证清单（completed）",
  "Privacy fixture and evidence-surface localization sweep",
  "PID `68064`",
  "docs/ui-artifacts/v2.79-privacy-localization/completed.png",
  "no credential reads, network behavior change, scanner/catalog fact mutation, provider/write/script/cloud/telemetry expansion",
];

for (const snippet of requiredReadmeSnippets) {
  requireText(readme, "README.md", snippet);
}

const requiredAgentsSnippets = [
  "V2.79 validation: multi-agent V2.79 implementation completed",
  "privacy fixture and evidence-surface localization sweep",
  "PID `68064`",
  "docs/ui-artifacts/v2.79-privacy-localization/completed.png",
  "no credential reads, network behavior change, scanner/catalog fact mutation, provider/write/script/cloud/telemetry expansion",
];

for (const snippet of requiredAgentsSnippets) {
  requireText(agents, "AGENTS.md", snippet);
}

const requiredDevelopmentSnippets = [
  "V2.79 closeout evidence lives in [`v2.79-verification-checklist.md`](./v2.79-verification-checklist.md)",
  "guarded by `pnpm verify:v2.79-docs`",
  "completed with privacy fixture code, localization/UI evidence, focused tests, shared gates, and fresh unlocked real-local Computer Use evidence",
  "No credential reads, network behavior change, scanner/catalog fact mutation, provider/write/script/cloud/telemetry expansion",
];

for (const snippet of requiredDevelopmentSnippets) {
  requireText(developmentTasks, "docs/development-tasks.md", snippet);
}

const requiredRoadmapSnippets = [
  "V2.79 closeout evidence is tracked in [`v2.79-verification-checklist.md`](./v2.79-verification-checklist.md)",
  "guarded by `pnpm verify:v2.79-docs`",
  "completed Privacy fixture and evidence-surface localization sweep",
  "PID `68064`",
  "docs/ui-artifacts/v2.79-privacy-localization/completed.png",
  "No credential reads, network behavior change, scanner/catalog fact mutation, provider/write/script/cloud/telemetry expansion",
];

for (const snippet of requiredRoadmapSnippets) {
  requireText(roadmap, "docs/roadmap.md", snippet);
}

const requiredRunbookSnippets = [
  "`pnpm verify:v2.79-docs`",
  "V2.79 completed verifier",
  "PID `68064`",
  "docs/ui-artifacts/v2.79-privacy-localization/completed.png",
  "stale-bundle",
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
  rejectText(text, label, "V2.79 docs scaffold");
  rejectText(text, label, "V2.79 planned scaffold");
  rejectText(text, label, "planned-scaffold");
  rejectText(text, label, "V2.79 still requires");
  rejectText(text, label, "V2.79 remains planned");
  rejectText(text, label, "V2.79-V2.83 remain planned");
}

console.log("V2.79 validation docs verification passed");
