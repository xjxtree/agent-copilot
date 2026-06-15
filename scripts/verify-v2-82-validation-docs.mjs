#!/usr/bin/env node

import { existsSync, readFileSync } from "node:fs";
import { join, resolve } from "node:path";

const repoRoot = resolve(new URL("..", import.meta.url).pathname);

function fail(message) {
  console.error(`V2.82 validation docs verification failed: ${message}`);
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
    fail(`${label} missing required V2.82 reference: ${snippet}`);
  }
}

function rejectText(text, label, snippet) {
  if (text.includes(snippet)) {
    fail(`${label} contains stale or over-claimed V2.82 text: ${snippet}`);
  }
}

function rejectRegex(text, label, pattern, description) {
  if (pattern.test(text)) {
    fail(`${label} contains stale or over-claimed V2.82 text: ${description}`);
  }
}

const checklist = readRequired(join(repoRoot, "docs", "v2.82-verification-checklist.md"));
const readme = readRequired(join(repoRoot, "README.md"));
const agents = readRequired(join(repoRoot, "AGENTS.md"));
const developmentTasks = readRequired(join(repoRoot, "docs", "development-tasks.md"));
const roadmap = readRequired(join(repoRoot, "docs", "roadmap.md"));
const runbook = readRequired(join(repoRoot, "docs", "macos-app-runbook.md"));
const serviceProtocol = readRequired(join(repoRoot, "docs", "service-protocol.md"));
const packageJson = readRequired(join(repoRoot, "package.json"));

const boundaryText =
  "no provider credential persistence changes, service protocol method/payload changes, provider default calls, write/apply paths, hidden task state, scanner/catalog fact mutation, script execution, credential reads beyond existing explicitly confirmed provider tests, raw prompt/response/trace persistence, cloud sync, telemetry, public distribution/signing/notarization/DMG/ZIP";

const requiredChecklistSnippets = [
  "# V2.82 Verification Checklist",
  "Status: completed on 2026-06-15.",
  "V2.82 test isolation and core model test floor is completed.",
  "serialized RAII guard",
  "restore prior environment state",
  "`crates/core` remains serde-free",
  "stable `AgentId` and `Scope` wire strings",
  "`PermissionRequest` safe defaults",
  "Protocol stability: current service protocol method names and payloads are unchanged.",
  "no fresh Computer Use screenshot is required",
  "No provider credential persistence changes.",
  "No service protocol method or payload changes.",
  "No provider default calls.",
  "No write/apply path.",
  "No hidden task state.",
  "No scanner/catalog fact mutation.",
  "No script execution.",
  "No credential reads beyond existing explicitly confirmed provider tests.",
  "No raw prompt/response/trace persistence.",
  "No cloud sync.",
  "No telemetry.",
  "No public distribution, signing, notarization, DMG, or ZIP work.",
  "Provider tests that mutate environment variables use serialized execution and RAII cleanup.",
  "Core model tests cover `AgentId` wire-value stability.",
  "Core model tests cover `Scope` wire-value stability.",
  "Core model tests cover safe defaulting for `PermissionRequest`.",
  "Core model tests cover stable skill identity and state fields.",
  "cargo test -p skills-copilot-core -- --nocapture                                              # passed",
  "cargo test -p skills-copilot-service llm_test_provider_connection -- --nocapture              # passed",
  "cargo test -p skills-copilot-service llm_confirm_prompt_sends_redacted_prompt_to_mock_provider_and_audits_metadata_only -- --nocapture # passed",
  "cargo test --workspace                                                                        # passed",
  "pnpm verify:v2.82-docs                                                                        # passed",
  "pnpm verify:gate-parity                                                                       # passed",
  "pnpm check:privacy                                                                            # passed",
  "pnpm smoke:macos-app -- --fixture-data                                                        # passed",
  "pnpm check:macos                                                                              # blocked: locked-session at fixture capture after pre-capture stages passed",
  "./script/build_and_run.sh --verify                                                            # blocked: locked-session after build before UI evidence",
  "git diff --check                                                                              # passed",
  "Implementation evidence: completed in `crates/service/src/lib.rs` and `crates/core/src/model.rs`.",
  "Real-local UI evidence or canonical blocker: fresh UI evidence is not required because V2.82 has no user-visible native UI or service-protocol behavior change.",
  "The current session's canonical blocker is `locked-session` for fixture capture / launch verification UI evidence.",
  "Final status decision: completed.",
];

for (const snippet of requiredChecklistSnippets) {
  requireText(checklist, "docs/v2.82-verification-checklist.md", snippet);
}

if (checklist.includes("- [ ]")) {
  fail("V2.82 completed checklist must not contain unchecked evidence items");
}
const checkedItems = checklist.match(/- \[x\]/g) ?? [];
if (checkedItems.length < 15) {
  fail(`V2.82 completed checklist has too few checked evidence items: ${checkedItems.length}`);
}

for (const snippet of [
  "Status: in progress docs scaffold.",
  "Final status decision: pending.",
  "Implementation evidence: pending.",
  "Focused provider-test isolation evidence: pending.",
  "Focused core model test evidence: pending.",
  "Shared gate evidence: pending.",
  "pending coordinator closeout",
]) {
  rejectText(checklist, "docs/v2.82-verification-checklist.md", snippet);
}

const requiredPackageSnippets = [
  '"verify:v2.82-docs": "node scripts/verify-v2-82-validation-docs.mjs"',
  "pnpm verify:v2.81-docs && pnpm verify:v2.82-docs && pnpm verify:v2.83-docs && pnpm verify:validation-blockers",
];

for (const snippet of requiredPackageSnippets) {
  requireText(packageJson, "package.json", snippet);
}

const requiredReadmeSnippets = [
  "V2.82 test isolation and core model test floor completed",
  "V2.82 validation",
  "multi-agent V2.82 implementation completed",
  "provider environment mutation tests now use serialized RAII cleanup",
  "without adding serde dependencies",
  "`pnpm check:macos` and `./script/build_and_run.sh --verify` failed closed with canonical `locked-session` before UI evidence capture",
  "no fresh Computer Use screenshot is required because V2.82 has no user-visible native UI or service-protocol behavior change.",
  "V2.82 验证清单（completed）",
  "pnpm verify:v2.82-docs",
  "V2.83 continued module splitting completed",
  boundaryText,
];

for (const snippet of requiredReadmeSnippets) {
  requireText(readme, "README.md", snippet);
}

const requiredAgentsSnippets = [
  "Current phase: **V2.83 continued module splitting completed**",
  "2026-06-15 V2.82 validation",
  "serialized RAII cleanup in `crates/service/src/lib.rs`",
  "`crates/core/src/model.rs` locks `AgentId` / `Scope` wire strings",
  "without adding serde dependencies",
  "`pnpm check:macos` and `./script/build_and_run.sh --verify` failed closed with canonical `locked-session` before UI evidence capture",
  "no fresh Computer Use screenshot is required because V2.82 has no user-visible native UI or service-protocol behavior change.",
  "V2.82 completed boundary",
  boundaryText,
];

for (const snippet of requiredAgentsSnippets) {
  requireText(agents, "AGENTS.md", snippet);
}

const requiredDevelopmentSnippets = [
  "Status: V2.83 continued module splitting is complete.",
  "V2.1 through V2.83 are the synchronized completed baseline",
  "V2.82 closeout evidence lives in [`v2.82-verification-checklist.md`](./v2.82-verification-checklist.md)",
  "completed provider-test environment isolation",
  "no-new-UI screenshot decision",
  "current `locked-session` blocker",
  "V2.82 | P1 | Test isolation and core model test floor | Completed",
  "V2.83 continued module splitting completed",
  boundaryText,
];

for (const snippet of requiredDevelopmentSnippets) {
  requireText(developmentTasks, "docs/development-tasks.md", snippet);
}

const requiredRoadmapSnippets = [
  "当前阶段：**V2.83 continued module splitting completed**",
  "V2.82 test isolation and core model test floor completed",
  "V2.83 continued module splitting completed",
  "V2.82 closeout evidence is tracked in [`v2.82-verification-checklist.md`](./v2.82-verification-checklist.md)",
  "completed provider env mutation RAII isolation",
  "current canonical `locked-session` blocker",
  boundaryText,
];

for (const snippet of requiredRoadmapSnippets) {
  requireText(roadmap, "docs/roadmap.md", snippet);
}

const requiredRunbookSnippets = [
  "V2.73-V2.83 docs verifiers",
  "`pnpm verify:v2.82-docs`",
  "V2.82 completed verifier",
  "test isolation and core model test floor closeout",
  "provider environment RAII cleanup",
  "current `locked-session` blocker",
  boundaryText,
];

for (const snippet of requiredRunbookSnippets) {
  requireText(runbook, "docs/macos-app-runbook.md", snippet);
}

const requiredServiceProtocolSnippets = [
  "## V2.82 Test isolation and core model test floor (completed)",
  "It does not add, remove, rename, or reshape service protocol methods or payloads.",
  "Provider-test work is limited to isolating existing explicitly confirmed provider tests that mutate process environment variables with serialized RAII cleanup.",
  "Core model work is limited to wire/default/identity stability tests",
  "`crates/core` remains serde-free.",
  "No credential reads beyond existing explicitly confirmed provider tests.",
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
  [serviceProtocol, "docs/service-protocol.md"],
]) {
  rejectRegex(text, label, /V2\.82\s+(?:is\s+)?in progress/i, "V2.82 in-progress claim");
  rejectRegex(text, label, /V2\.82\s+(?:docs\/gate\s+)?scaffold/i, "V2.82 scaffold claim");
  rejectText(text, label, "V2.82 验证清单（in progress）");
  rejectText(text, label, "V2.82 remains planned");
  rejectText(text, label, "V2.82-V2.83 remain planned");
  rejectText(text, label, "implementation evidence remains pending");
}

console.log("V2.82 validation docs verification passed");
