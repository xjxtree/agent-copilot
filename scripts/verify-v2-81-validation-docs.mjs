#!/usr/bin/env node

import { existsSync, readFileSync } from "node:fs";
import { join, resolve } from "node:path";

const repoRoot = resolve(new URL("..", import.meta.url).pathname);

function fail(message) {
  console.error(`V2.81 validation docs verification failed: ${message}`);
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
    fail(`${label} missing required V2.81 reference: ${snippet}`);
  }
}

function rejectText(text, label, snippet) {
  if (text.includes(snippet)) {
    fail(`${label} contains stale or over-claimed V2.81 text: ${snippet}`);
  }
}

function rejectRegex(text, label, pattern, description) {
  if (pattern.test(text)) {
    fail(`${label} contains stale or over-claimed V2.81 text: ${description}`);
  }
}

const checklist = readRequired(join(repoRoot, "docs", "v2.81-verification-checklist.md"));
const readme = readRequired(join(repoRoot, "README.md"));
const agents = readRequired(join(repoRoot, "AGENTS.md"));
const developmentTasks = readRequired(join(repoRoot, "docs", "development-tasks.md"));
const roadmap = readRequired(join(repoRoot, "docs", "roadmap.md"));
const runbook = readRequired(join(repoRoot, "docs", "macos-app-runbook.md"));
const serviceProtocol = readRequired(join(repoRoot, "docs", "service-protocol.md"));
const packageJson = readRequired(join(repoRoot, "package.json"));

const requiredChecklistSnippets = [
  "# V2.81 Verification Checklist",
  "Status: completed on 2026-06-15.",
  "V2.81 Swift stdio sidecar cancellation cleanup is completed.",
  "existing short-lived JSON stdio service sidecar",
  "`ServiceClient.runService` cancellation and timeout behavior",
  "terminate the child process",
  "avoid leaked pipe handles",
  "stdin/stdout/stderr handles are closed during cleanup",
  "keep the current JSON service protocol method names and payloads",
  "`pnpm verify:v2.81-docs` is a completed verifier",
  "Code implements Swift stdio sidecar cancellation cleanup through `ServiceProcessRunner.swift`",
  "Focused Swift tests cover cancelled service calls without lingering child processes.",
  "Focused Swift tests cover TERM-ignoring service calls with bounded SIGKILL escalation.",
  "Existing Rust service protocol tests still pass with no method or payload changes.",
  "Real-local validation decision: V2.81 has no user-visible native UI or service-protocol surface change",
  "swift test --package-path apps/macos",
  "pnpm verify:macos-ui-layout",
  "pnpm verify:service-protocol-drift",
  "pnpm verify:v2.81-docs",
  "pnpm verify:gate-parity",
  "pnpm check:privacy",
  "pnpm check:macos",
  "git diff --check",
  "Final status decision: completed.",
  "No daemon or socket redesign by default.",
  "No service protocol method additions, renames, removals, or payload changes.",
  "No service protocol method or payload changes.",
  "No provider default calls",
  "No write/apply path",
  "No hidden task state",
  "No scanner/catalog fact mutation",
  "No script execution",
  "No credential reads",
  "No raw prompt, raw response, or raw trace persistence.",
  "No raw prompt/response/trace persistence.",
  "No cloud sync",
  "No telemetry",
  "No public distribution",
  "No signing, notarization, DMG, or ZIP work.",
];

for (const snippet of requiredChecklistSnippets) {
  requireText(checklist, "docs/v2.81-verification-checklist.md", snippet);
}

if (checklist.includes("- [ ]")) {
  fail("V2.81 completed checklist must not contain unchecked evidence items");
}
const checkedItems = checklist.match(/- \[x\]/g) ?? [];
if (checkedItems.length < 12) {
  fail(`V2.81 completed checklist has too few checked evidence items: ${checkedItems.length}`);
}

for (const snippet of [
  "Status: in progress docs scaffold.",
  "Coordinator closeout is pending",
  "Final status decision: pending.",
  "pending coordinator closeout",
  "pending coordinator decision",
]) {
  rejectText(checklist, "docs/v2.81-verification-checklist.md", snippet);
}

const requiredPackageSnippets = [
  '"verify:v2.81-docs": "node scripts/verify-v2-81-validation-docs.mjs"',
  '"verify:gate-parity": "pnpm verify:service-protocol-drift',
  "pnpm verify:v2.80-docs && pnpm verify:v2.81-docs",
];

for (const snippet of requiredPackageSnippets) {
  requireText(packageJson, "package.json", snippet);
}

const requiredReadmeSnippets = [
  "V2.81 Swift service IPC cancellation cleanup completed",
  "V2.81 validation",
  "multi-agent V2.81 implementation completed",
  "TERM-ignoring sidecar force-kill cleanup",
  "No fresh Computer Use screenshot is required because V2.81 does not change user-visible native UI.",
  "V2.81 验证清单（completed）",
  "pnpm verify:v2.81-docs",
  "V2.86 Rust helper/test split and module-size gate closeout completed",
];

for (const snippet of requiredReadmeSnippets) {
  requireText(readme, "README.md", snippet);
}

const requiredAgentsSnippets = [
  "Current phase: **V2.86 Rust helper/test split and module-size gate closeout completed**",
  "2026-06-15 V2.81 validation",
  "StdioServiceProcessRunner",
  "Task Cockpit cancel/timeout cancels the active service task",
  "No fresh Computer Use screenshot is required because V2.81 has no user-visible native UI change.",
  "V2.81 completed boundary",
];

for (const snippet of requiredAgentsSnippets) {
  requireText(agents, "AGENTS.md", snippet);
}

const requiredDevelopmentSnippets = [
  "Status: V2.86 Rust helper/test split and module-size gate closeout is complete.",
  "V2.1 through V2.86 are the synchronized completed baseline",
  "V2.81 closeout evidence lives in [`v2.81-verification-checklist.md`](./v2.81-verification-checklist.md)",
  "focused Swift cancellation and force-kill tests",
  "no-new-UI screenshot decision",
  "V2.81 | P1 | Swift service IPC cancellation cleanup | Completed",
];

for (const snippet of requiredDevelopmentSnippets) {
  requireText(developmentTasks, "docs/development-tasks.md", snippet);
}

const requiredRoadmapSnippets = [
  "V2.81 Swift stdio sidecar cancellation cleanup completed",
  "V2.86 Rust helper/test split and module-size gate closeout completed",
  "Completed: added cancellation/timeout cleanup around short-lived stdio sidecar calls",
  "V2.81 closeout evidence is tracked in [`v2.81-verification-checklist.md`](./v2.81-verification-checklist.md)",
  "no fresh Computer Use screenshot required because no user-visible UI changed",
];

for (const snippet of requiredRoadmapSnippets) {
  requireText(roadmap, "docs/roadmap.md", snippet);
}

const requiredRunbookSnippets = [
  "V2.73-V2.86 docs verifiers",
  "`pnpm verify:v2.81-docs`",
  "V2.81 completed verifier",
  "Swift stdio sidecar cancellation cleanup closeout",
  "no-new-UI screenshot decision",
];

for (const snippet of requiredRunbookSnippets) {
  requireText(runbook, "docs/macos-app-runbook.md", snippet);
}

const requiredServiceProtocolSnippets = [
  "## V2.81 Swift stdio sidecar cancellation cleanup (completed)",
  "It does not add, remove, rename, or reshape service protocol methods or payloads.",
  "`ServiceClient.runService` delegates process execution to a cancellable stdio runner.",
  "Task Cockpit cancel and timeout paths cancel the active service task",
  "No daemon/socket/XPC/network redesign",
];

for (const snippet of requiredServiceProtocolSnippets) {
  requireText(serviceProtocol, "docs/service-protocol.md", snippet);
}

for (const [text, label] of [
  [readme, "README.md"],
  [agents, "AGENTS.md"],
  [developmentTasks, "docs/development-tasks.md"],
  [roadmap, "docs/roadmap.md"],
  [runbook, "docs/macos-app-runbook.md"],
]) {
  rejectRegex(text, label, /V2\.81\s+(?:is\s+)?in progress/i, "V2.81 in-progress claim");
  rejectRegex(text, label, /V2\.81\s+(?:docs\s+)?scaffold/i, "V2.81 scaffold claim");
  rejectText(text, label, "V2.81-V2.83 remain planned");
  rejectText(text, label, "V2.81 验证清单（in progress）");
  rejectText(text, label, "does not mark V2.81 completed");
}

console.log("V2.81 validation docs verification passed");
