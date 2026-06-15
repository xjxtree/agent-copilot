#!/usr/bin/env node

import { existsSync, readFileSync } from "node:fs";
import { join, resolve } from "node:path";

const repoRoot = resolve(new URL("..", import.meta.url).pathname);

function fail(message) {
  console.error(`V2.78 validation docs verification failed: ${message}`);
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
    fail(`${label} missing required V2.78 reference: ${snippet}`);
  }
}

function rejectText(text, label, snippet) {
  if (text.includes(snippet)) {
    fail(`${label} contains stale or over-claimed V2.78 text: ${snippet}`);
  }
}

const checklist = readRequired(join(repoRoot, "docs", "v2.78-verification-checklist.md"));
const readme = readRequired(join(repoRoot, "README.md"));
const runbook = readRequired(join(repoRoot, "docs", "macos-app-runbook.md"));
const serviceProtocol = readRequired(join(repoRoot, "docs", "service-protocol.md"));
const fixturesReadme = readRequired(join(repoRoot, "fixtures", "service-protocol", "README.md"));
const packageJson = readRequired(join(repoRoot, "package.json"));
const workflow = readRequired(join(repoRoot, ".github", "workflows", "ci.yml"));

const requiredChecklistSnippets = [
  "# V2.78 Verification Checklist",
  "Status: completed on 2026-06-15 after coordinator verification.",
  "V2.78 is completed because the protocol/docs/gate parity implementation landed",
  "V2.78 scope: protocol / validation gate parity after V2.77.",
  "protocol / validation gate parity only",
  "`SUPPORTED_METHODS` remains the canonical list",
  "docs verifier should compare names against `SUPPORTED_METHODS`",
  "local and CI-equivalent gates must tell the same story",
  "V2.46-V2.64 verification history",
  "pnpm verify:service-protocol-drift",
  "pnpm verify:v2.78-docs",
  "pnpm verify:gate-parity",
  "Coordinator command results:",
  "pnpm check:macos                                     # passed",
  "pnpm check:privacy                                   # passed",
  "Final status decision: completed.",
  "Real-local UI evidence: not required because V2.78 changed protocol docs",
  "V2.82 has since completed after V2.78 closeout, V2.83 remains planned",
  "No protocol method rename.",
  "No protocol payload expansion.",
  "No provider default calls",
  "No write/apply path",
  "No script execution",
  "No credential reads",
  "No cloud sync",
  "No telemetry",
];

for (const snippet of requiredChecklistSnippets) {
  requireText(checklist, "docs/v2.78-verification-checklist.md", snippet);
}

rejectText(checklist, "docs/v2.78-verification-checklist.md", "coordinator verification pending");
rejectText(checklist, "docs/v2.78-verification-checklist.md", "pending coordinator run");
rejectText(checklist, "docs/v2.78-verification-checklist.md", "public release automation added");

const requiredPackageSnippets = [
  '"verify:service-protocol-drift": "node scripts/verify-service-protocol-drift.mjs"',
  '"verify:v2.78-docs": "node scripts/verify-v2-78-validation-docs.mjs"',
  '"verify:gate-parity": "pnpm verify:service-protocol-drift',
  "pnpm verify:v2.78-docs",
  "pnpm verify:validation-blockers",
  "pnpm verify:screenshot-artifacts",
  '"check:macos": "cargo fmt --all -- --check',
  "pnpm verify:gate-parity",
];

for (const snippet of requiredPackageSnippets) {
  requireText(packageJson, "package.json", snippet);
}

const requiredWorkflowSnippets = [
  "name: CI",
  "runs-on: macos-latest",
  "run: pnpm verify:gate-parity",
  "run: swift test --package-path apps/macos",
  "run: pnpm smoke:macos-app -- --bundle-only",
];

for (const snippet of requiredWorkflowSnippets) {
  requireText(workflow, ".github/workflows/ci.yml", snippet);
}

const requiredReadmeSnippets = [
  "pnpm verify:service-protocol-drift",
  "pnpm verify:v2.78-docs",
  "pnpm verify:gate-parity",
  "Service protocol drift",
  "V2.78 gate parity",
  "CI/local gate parity",
  "V2.78 validation",
  "V2.78 验证清单（completed）",
];

for (const snippet of requiredReadmeSnippets) {
  requireText(readme, "README.md", snippet);
}

const requiredRunbookSnippets = [
  "## Local vs CI Gate Parity",
  "`pnpm verify:gate-parity`",
  "`pnpm verify:service-protocol-drift`",
  "`pnpm verify:v2.78-docs`",
  "GitHub Actions",
  "does not replace unlocked real-local Computer Use",
];

for (const snippet of requiredRunbookSnippets) {
  requireText(runbook, "docs/macos-app-runbook.md", snippet);
}

const requiredProtocolSnippets = [
  "| `session.reviewAgentSkillUse` |",
  "| `session.listSkillReviews` |",
  "| `session.deleteSkillReview` |",
  "| `adapter.listDiagnostics` |",
  "| `analysis.scoreSkillQuality` |",
  "| `batch.previewSkillToggles` |",
  "| `remediation.previewDrafts` |",
  "Shared request/response examples live in [`../fixtures/service-protocol`](../fixtures/service-protocol).",
  "## V2.78 Protocol / validation gate parity (completed)",
  "V2.78 records completed protocol/docs/gate parity requirements without changing protocol semantics.",
];

for (const snippet of requiredProtocolSnippets) {
  requireText(serviceProtocol, "docs/service-protocol.md", snippet);
}

requireText(
  fixturesReadme,
  "fixtures/service-protocol/README.md",
  "Fixture methods should stay additive and match `service.status.supported_methods`.",
);

console.log("V2.78 validation docs verification passed");
