#!/usr/bin/env node

import { existsSync, readFileSync } from "node:fs";
import { join, resolve } from "node:path";

const repoRoot = resolve(new URL("..", import.meta.url).pathname);

function fail(message) {
  console.error(`V2.84 validation docs verification failed: ${message}`);
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
    fail(`${label} missing required V2.84 reference: ${snippet}`);
  }
}

const checklist = readRequired(join(repoRoot, "docs", "v2.84-verification-checklist.md"));
const readme = readRequired(join(repoRoot, "README.md"));
const agents = readRequired(join(repoRoot, "AGENTS.md"));
const developmentTasks = readRequired(join(repoRoot, "docs", "development-tasks.md"));
const roadmap = readRequired(join(repoRoot, "docs", "roadmap.md"));
const runbook = readRequired(join(repoRoot, "docs", "macos-app-runbook.md"));
const packageJson = readRequired(join(repoRoot, "package.json"));
const nativeLayoutVerifier = readRequired(join(repoRoot, "scripts", "verify-native-ui-layout.mjs"));
const moduleSizeVerifier = readRequired(join(repoRoot, "scripts", "verify-module-size.mjs"));

for (const snippet of [
  "# V2.84 Verification Checklist",
  "Status: completed on 2026-06-16.",
  "V2.84 Swift Detail section splitting is completed.",
  "`DetailView.swift` is now a small routing and composition file.",
  "`DetailGuidedCleanupFlowPanel.swift`",
  "`DetailProviderObservabilityPanel.swift`",
  "`DetailReviewCoreSection.swift`",
  "`TaskCockpitPanel.swift` and `ValidationWorkbenchPanel.swift`",
  "`scripts/verify-native-ui-layout.mjs` aggregates the split Detail files",
  "no fresh UI evidence required for this refactor-only source split",
  "swift test --package-path apps/macos      # passed",
  "pnpm verify:macos-ui-layout               # passed",
  "pnpm verify:module-size                   # passed",
  "pnpm verify:v2.84-docs                    # passed",
  "Final status decision: completed.",
]) {
  requireText(checklist, "docs/v2.84-verification-checklist.md", snippet);
}

if (checklist.includes("- [ ]")) {
  fail("V2.84 completed checklist must not contain unchecked evidence items");
}

for (const snippet of [
  '"verify:v2.84-docs": "node scripts/verify-v2-84-validation-docs.mjs"',
  "pnpm verify:v2.83-docs && pnpm verify:v2.84-docs && pnpm verify:v2.85-docs",
]) {
  requireText(packageJson, "package.json", snippet);
}

for (const [text, label] of [
  [readme, "README.md"],
  [agents, "AGENTS.md"],
  [developmentTasks, "docs/development-tasks.md"],
  [roadmap, "docs/roadmap.md"],
  [runbook, "docs/macos-app-runbook.md"],
]) {
  requireText(text, label, "V2.84");
  requireText(text, label, "Swift Detail section splitting");
  requireText(text, label, "DetailView.swift");
  requireText(text, label, "DetailGuidedCleanupFlowPanel.swift");
  requireText(text, label, "verify:module-size");
}

for (const snippet of [
  "detailGuidedCleanup",
  "detailProviderObservability",
  "detailReviewCore",
  "files.detailSurface = [",
]) {
  requireText(nativeLayoutVerifier, "scripts/verify-native-ui-layout.mjs", snippet);
}

for (const snippet of [
  "DetailView.swift",
  "DetailGuidedCleanupFlowPanel.swift",
  "maxLines = 5000",
]) {
  requireText(moduleSizeVerifier, "scripts/verify-module-size.mjs", snippet);
}

console.log("V2.84 validation docs verification passed");
