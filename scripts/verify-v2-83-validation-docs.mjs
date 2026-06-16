#!/usr/bin/env node

import { existsSync, readFileSync } from "node:fs";
import { join, resolve } from "node:path";

const repoRoot = resolve(new URL("..", import.meta.url).pathname);

function fail(message) {
  console.error(`V2.83 validation docs verification failed: ${message}`);
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
    fail(`${label} missing required V2.83 reference: ${snippet}`);
  }
}

function rejectText(text, label, snippet) {
  if (text.includes(snippet)) {
    fail(`${label} contains stale or over-claimed V2.83 text: ${snippet}`);
  }
}

function rejectRegex(text, label, pattern, description) {
  if (pattern.test(text)) {
    fail(`${label} contains stale or over-claimed V2.83 text: ${description}`);
  }
}

const checklist = readRequired(join(repoRoot, "docs", "v2.83-verification-checklist.md"));
const readme = readRequired(join(repoRoot, "README.md"));
const agents = readRequired(join(repoRoot, "AGENTS.md"));
const developmentTasks = readRequired(join(repoRoot, "docs", "development-tasks.md"));
const roadmap = readRequired(join(repoRoot, "docs", "roadmap.md"));
const runbook = readRequired(join(repoRoot, "docs", "macos-app-runbook.md"));
const serviceProtocol = readRequired(join(repoRoot, "docs", "service-protocol.md"));
const packageJson = readRequired(join(repoRoot, "package.json"));
const nativeLayoutVerifier = readRequired(join(repoRoot, "scripts", "verify-native-ui-layout.mjs"));
const protocolDriftVerifier = readRequired(join(repoRoot, "scripts", "verify-service-protocol-drift.mjs"));

const boundaryText =
  "no service protocol method or payload changes, protocol version bump, new UI surface, provider default calls, write/apply paths, hidden task state, scanner/catalog fact mutation, script execution, credential reads, raw prompt/response/trace persistence, cloud sync, telemetry, public distribution/signing/notarization/DMG/ZIP";

const requiredChecklistSnippets = [
  "# V2.83 Verification Checklist",
  "Status: completed on 2026-06-15.",
  "V2.83 continued module splitting is completed.",
  "refactor-only module-boundary slice",
  "`crates/service/src/protocol.rs`",
  "`DetailOverviewSection.swift`",
  "`FakeServiceScript.swift`",
  "no fresh Computer Use screenshot is required",
  "No service protocol method or payload changes.",
  "No protocol version bump.",
  "No new UI surface, label, navigation behavior, or product workflow.",
  "No provider default calls.",
  "No write/apply path.",
  "No hidden task state.",
  "No scanner/catalog fact mutation.",
  "No script execution.",
  "No credential reads.",
  "No raw prompt/response/trace persistence.",
  "No cloud sync.",
  "No telemetry.",
  "No public distribution, signing, notarization, DMG, or ZIP work.",
  "Rust protocol constants and envelope DTOs live in `crates/service/src/protocol.rs`.",
  "Service protocol drift verifier reads the split protocol module.",
  "Swift detail overview code lives in `DetailOverviewSection.swift` without changing visible IA semantics.",
  "Swift fake service test helper lives in `FakeServiceScript.swift`.",
  "cargo test -p skills-copilot-service supported_methods_have_dispatch_coverage -- --nocapture # passed",
  "cargo test -p skills-copilot-service service_protocol_fixtures_decode -- --nocapture         # passed",
  "pnpm verify:service-protocol-drift                                                          # passed",
  "swift test --package-path apps/macos                                                        # passed",
  "pnpm verify:macos-ui-layout                                                                 # passed",
  "pnpm verify:v2.83-docs                                                                      # passed",
  "pnpm verify:gate-parity                                                                     # passed",
  "pnpm check:privacy                                                                          # passed",
  "pnpm smoke:macos-app -- --fixture-data                                                      # passed",
  "pnpm check:macos                                                                            # blocked: locked-session before UI evidence capture",
  "git diff --check                                                                            # passed",
  "Implementation evidence: completed in `crates/service/src/protocol.rs`",
  "Real-local UI evidence or canonical blocker: fresh UI evidence is not required because V2.83 has no user-visible native UI or service-protocol behavior change.",
  "Final status decision: completed.",
];

for (const snippet of requiredChecklistSnippets) {
  requireText(checklist, "docs/v2.83-verification-checklist.md", snippet);
}

if (checklist.includes("- [ ]")) {
  fail("V2.83 completed checklist must not contain unchecked evidence items");
}
const checkedItems = checklist.match(/- \[x\]/g) ?? [];
if (checkedItems.length < 12) {
  fail(`V2.83 completed checklist has too few checked evidence items: ${checkedItems.length}`);
}

for (const snippet of [
  "Status: in progress",
  "Final status decision: pending.",
  "Implementation evidence: pending.",
  "V2.83 remains planned",
  "continued module splitting remains planned",
  "pending coordinator closeout",
]) {
  rejectText(checklist, "docs/v2.83-verification-checklist.md", snippet);
}

const requiredPackageSnippets = [
  '"verify:v2.83-docs": "node scripts/verify-v2-83-validation-docs.mjs"',
  "pnpm verify:v2.82-docs && pnpm verify:v2.83-docs && pnpm verify:v2.84-docs",
];

for (const snippet of requiredPackageSnippets) {
  requireText(packageJson, "package.json", snippet);
}

const requiredReadmeSnippets = [
  "V2.83 validation",
  "Continued module splitting",
  "V2.83 validation",
  "multi-agent V2.83 implementation completed",
  "`crates/service/src/protocol.rs`",
  "`DetailOverviewSection.swift`",
  "`FakeServiceScript.swift`",
  "no fresh Computer Use screenshot is required because V2.83 has no user-visible native UI or service-protocol behavior change.",
  "V2.83 验证清单（completed）",
  "pnpm verify:v2.83-docs",
  "V2.1-V2.86",
  "V2.41-V2.86",
  boundaryText,
];

for (const snippet of requiredReadmeSnippets) {
  requireText(readme, "README.md", snippet);
}

const requiredAgentsSnippets = [
  "Current phase: **V2.86 Rust helper/test split and module-size gate closeout completed**",
  "2026-06-15 V2.83 validation",
  "`crates/service/src/protocol.rs`",
  "`DetailOverviewSection.swift`",
  "`FakeServiceScript.swift`",
  "no fresh Computer Use screenshot is required because V2.83 has no user-visible native UI or service-protocol behavior change.",
  "V2.83 completed boundary",
  boundaryText,
];

for (const snippet of requiredAgentsSnippets) {
  requireText(agents, "AGENTS.md", snippet);
}

const requiredDevelopmentSnippets = [
  "Status: V2.86 Rust helper/test split and module-size gate closeout is complete.",
  "V2.1 through V2.86 are the synchronized completed baseline",
  "V2.83 closeout evidence lives in [`v2.83-verification-checklist.md`](./v2.83-verification-checklist.md)",
  "V2.83 | P2 | Continued module splitting | Completed",
  "P2 | V2.83 Continued module splitting | Completed",
  "V2.78-V2.86 are completed",
  boundaryText,
];

for (const snippet of requiredDevelopmentSnippets) {
  requireText(developmentTasks, "docs/development-tasks.md", snippet);
}

const requiredRoadmapSnippets = [
  "当前阶段：**V2.86 Rust helper/test split and module-size gate closeout completed**",
  "V2.83 continued module splitting completed",
  "V2.83 closeout evidence is tracked in [`v2.83-verification-checklist.md`](./v2.83-verification-checklist.md)",
  "Completed: split Rust protocol DTOs/constants",
  "no fresh Computer Use screenshot required because no user-visible UI or service-protocol behavior changed",
  boundaryText,
];

for (const snippet of requiredRoadmapSnippets) {
  requireText(roadmap, "docs/roadmap.md", snippet);
}

const requiredRunbookSnippets = [
  "V2.73-V2.86 docs verifiers",
  "`pnpm verify:v2.83-docs`",
  "V2.83 completed verifier",
  "continued module splitting closeout",
  "split protocol/detail/test fixture modules",
  "current `locked-session` blocker",
  boundaryText,
];

for (const snippet of requiredRunbookSnippets) {
  requireText(runbook, "docs/macos-app-runbook.md", snippet);
}

const requiredServiceProtocolSnippets = [
  "## V2.83 Continued module splitting (completed)",
  "V2.83 is a refactor-only protocol-module split and native module-boundary cleanup.",
  "It does not add, remove, rename, or reshape service protocol methods or payloads.",
  "`SUPPORTED_METHODS`, `DEFAULT_BUNDLE_ID`, `SERVICE_PROTOCOL_VERSION`, `ServiceRequest`, `ServiceResponse`, and `ServiceErrorRecord` live in `crates/service/src/protocol.rs`.",
  "`crates/service/src/lib.rs` re-exports the protocol constants and envelope types.",
];

for (const snippet of requiredServiceProtocolSnippets) {
  requireText(serviceProtocol, "docs/service-protocol.md", snippet);
}

for (const snippet of [
  "DetailOverviewSection.swift",
  "crates/service/src/protocol.rs",
  "files.detailSurface = [",
  "files.detailOverview",
  "files.serviceRustSurface = [files.serviceRust, files.serviceRustProtocol]",
]) {
  requireText(nativeLayoutVerifier, "scripts/verify-native-ui-layout.mjs", snippet);
}

for (const snippet of [
  '"crates", "service", "src", "protocol.rs"',
  "parseSupportedMethods(protocolSource, \"crates/service/src/protocol.rs\")",
]) {
  requireText(protocolDriftVerifier, "scripts/verify-service-protocol-drift.mjs", snippet);
}

for (const [text, label] of [
  [readme, "README.md"],
  [agents, "AGENTS.md"],
  [developmentTasks, "docs/development-tasks.md"],
  [roadmap, "docs/roadmap.md"],
  [runbook, "docs/macos-app-runbook.md"],
  [serviceProtocol, "docs/service-protocol.md"],
]) {
  rejectRegex(text, label, /V2\.83\s+(?:is\s+)?in progress/i, "V2.83 in-progress claim");
  rejectRegex(text, label, /V2\.83\s+(?:docs\/gate\s+)?scaffold/i, "V2.83 scaffold claim");
  rejectText(text, label, "V2.83 验证清单（in progress）");
  rejectText(text, label, "V2.83 remains planned");
  rejectText(text, label, "continued module splitting remains planned");
  rejectText(text, label, "implementation evidence remains pending");
}

console.log("V2.83 validation docs verification passed");
