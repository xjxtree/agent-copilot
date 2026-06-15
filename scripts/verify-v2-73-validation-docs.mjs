#!/usr/bin/env node

import { existsSync, readFileSync } from "node:fs";
import { join, resolve } from "node:path";

const repoRoot = resolve(new URL("..", import.meta.url).pathname);
const checklistPath = join(repoRoot, "docs", "v2.73-verification-checklist.md");

function fail(message) {
  console.error(`V2.73 validation docs verification failed: ${message}`);
  process.exit(1);
}

if (!existsSync(checklistPath)) {
  fail(`missing checklist at ${checklistPath}`);
}

const text = readFileSync(checklistPath, "utf8");

const requiredSnippets = [
  "# V2.73 Verification Checklist",
  "Status: completed on 2026-06-15",
  "Completed Evidence",
  "Bounded Cockpit Loading",
  "Timeout, Fallback, Cancel, Retry",
  "Real-local Validation Blockers",
  "Safety Boundaries",
  "Commands Run",
  "Task Cockpit cannot remain in `Preparing...`",
  "timeout/fallback/cancel/retry",
  "Fixture smoke, fixture screenshots, and no-capture launch success can prove build/service health, but they cannot replace blocked real-local Computer Use",
  "Unlocked Computer Use evidence on 2026-06-15",
  "current workspace `dist/SkillsCopilot.app`",
  "docs/ui-artifacts/v2.73-task-cockpit-timeout-recovery/completed.png",
  "pnpm check:macos",
  "git diff --check",
  "No provider default calls.",
  "No skill/config writes.",
  "No triage mutation.",
  "No snapshot creation or rollback.",
  "No script execution.",
  "No credential reads.",
  "No raw prompt, raw response, raw trace, secret, or unredacted local path persistence.",
  "No cloud sync.",
  "No telemetry.",
  "V2.74-V2.81 have since completed, and V2.82-V2.83 remain planned.",
];

for (const snippet of requiredSnippets) {
  if (!text.includes(snippet)) {
    fail(`missing required checklist text: ${snippet}`);
  }
}

const requiredMethods = [
  "task.checkReadiness",
  "task.rankSkillRoutes",
  "task.compareAgentReadiness",
  "remediation.plan",
  "remediation.previewDrafts",
  "remediation.previewImpact",
  "remediation.batchReview",
  "task.buildCockpit",
];

for (const method of requiredMethods) {
  if (!text.includes(method)) {
    fail(`missing required method coverage: ${method}`);
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
  if (!text.includes(`\`${code}\``)) {
    fail(`missing canonical blocker code: ${code}`);
  }
}

if (text.includes("- [ ]")) {
  fail("completed checklist still has unchecked evidence items");
}

const requiredCompletedItems = [
  "Focused service tests prove bounded runtime",
  "Protocol fixtures prove aggregation metadata",
  "Swift tests prove timeout, cancel, retry",
  "Native UI/static verifier coverage",
  "Unlocked real-local Computer Use validation exercised Task Cockpit loading",
  "Real-local screenshot evidence confirms timeout/recovery diagnostics expose no local path",
];

for (const item of requiredCompletedItems) {
  if (!text.includes(`- [x] ${item}`)) {
    fail(`missing completed evidence item: ${item}`);
  }
}

console.log("V2.73 validation docs verification passed");
