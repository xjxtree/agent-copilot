#!/usr/bin/env node

import { existsSync, readFileSync } from "node:fs";
import { join, resolve } from "node:path";

const repoRoot = resolve(new URL("..", import.meta.url).pathname);

function fail(message) {
  console.error(`V2.85 validation docs verification failed: ${message}`);
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
    fail(`${label} missing required V2.85 reference: ${snippet}`);
  }
}

const checklist = readRequired(join(repoRoot, "docs", "v2.85-verification-checklist.md"));
const readme = readRequired(join(repoRoot, "README.md"));
const agents = readRequired(join(repoRoot, "AGENTS.md"));
const developmentTasks = readRequired(join(repoRoot, "docs", "development-tasks.md"));
const roadmap = readRequired(join(repoRoot, "docs", "roadmap.md"));
const runbook = readRequired(join(repoRoot, "docs", "macos-app-runbook.md"));
const serviceProtocol = readRequired(join(repoRoot, "docs", "service-protocol.md"));
const packageJson = readRequired(join(repoRoot, "package.json"));
const protocolDriftVerifier = readRequired(join(repoRoot, "scripts", "verify-service-protocol-drift.mjs"));
const moduleSizeVerifier = readRequired(join(repoRoot, "scripts", "verify-module-size.mjs"));

for (const snippet of [
  "# V2.85 Verification Checklist",
  "Status: completed on 2026-06-16.",
  "V2.85 Rust RPC domain module splitting is completed.",
  "`service_host.rs`, `service_cleanup.rs`, `service_knowledge.rs`, `service_llm.rs`, `service_remediation.rs`, and `service_task.rs`",
  "`SUPPORTED_METHODS` remains in `crates/service/src/protocol.rs`",
  "cargo test -p skills-copilot-service supported_methods_have_dispatch_coverage -- --nocapture # passed",
  "cargo test -p skills-copilot-service service_protocol_fixtures_decode -- --nocapture         # passed",
  "pnpm verify:service-protocol-drift                                                          # passed",
  "pnpm verify:module-size                                                                      # passed",
  "Final status decision: completed.",
]) {
  requireText(checklist, "docs/v2.85-verification-checklist.md", snippet);
}

if (checklist.includes("- [ ]")) {
  fail("V2.85 completed checklist must not contain unchecked evidence items");
}

for (const snippet of [
  '"verify:v2.85-docs": "node scripts/verify-v2-85-validation-docs.mjs"',
  "pnpm verify:v2.84-docs && pnpm verify:v2.85-docs && pnpm verify:v2.86-docs",
]) {
  requireText(packageJson, "package.json", snippet);
}

for (const [text, label] of [
  [readme, "README.md"],
  [agents, "AGENTS.md"],
  [developmentTasks, "docs/development-tasks.md"],
  [roadmap, "docs/roadmap.md"],
  [runbook, "docs/macos-app-runbook.md"],
  [serviceProtocol, "docs/service-protocol.md"],
]) {
  requireText(text, label, "V2.85");
  requireText(text, label, "Rust RPC domain module splitting");
  requireText(text, label, "service_host.rs");
  requireText(text, label, "service_task.rs");
}

for (const snippet of [
  "service_host.rs",
  "service_cleanup.rs",
  "service_knowledge.rs",
  "service_llm.rs",
  "service_remediation.rs",
  "service_task.rs",
]) {
  requireText(protocolDriftVerifier, "scripts/verify-service-protocol-drift.mjs", snippet);
}

for (const snippet of [
  "\"crates\"",
  "[\".rs\", 5_000]",
  "filesInTree",
]) {
  requireText(moduleSizeVerifier, "scripts/verify-module-size.mjs", snippet);
}

console.log("V2.85 validation docs verification passed");
