#!/usr/bin/env node

import { existsSync, readFileSync } from "node:fs";
import { join, resolve } from "node:path";

const repoRoot = resolve(new URL("..", import.meta.url).pathname);

function fail(message) {
  console.error(`V2.86 validation docs verification failed: ${message}`);
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
    fail(`${label} missing required V2.86 reference: ${snippet}`);
  }
}

const checklist = readRequired(join(repoRoot, "docs", "v2.86-verification-checklist.md"));
const readme = readRequired(join(repoRoot, "README.md"));
const agents = readRequired(join(repoRoot, "AGENTS.md"));
const developmentTasks = readRequired(join(repoRoot, "docs", "development-tasks.md"));
const roadmap = readRequired(join(repoRoot, "docs", "roadmap.md"));
const runbook = readRequired(join(repoRoot, "docs", "macos-app-runbook.md"));
const serviceProtocol = readRequired(join(repoRoot, "docs", "service-protocol.md"));
const packageJson = readRequired(join(repoRoot, "package.json"));
const moduleSizeVerifier = readRequired(join(repoRoot, "scripts", "verify-module-size.mjs"));

for (const snippet of [
  "# V2.86 Verification Checklist",
  "Status: completed on 2026-06-16.",
  "V2.86 Rust helper/test split and module-size gate closeout is completed.",
  "`service_support_helpers.rs`, `service_knowledge_helpers.rs`, `service_remediation_helpers.rs`, `service_task_helpers.rs`, `service_observability_helpers.rs`, `service_llm_prompt_helpers.rs`, and `service_guided_cleanup_helpers.rs`",
  "Rust service tests moved into `crates/service/src/tests.rs` plus focused include chunks under `crates/service/src/tests/`.",
  "`scripts/verify-module-size.mjs` verifies the split Rust service files, Rust test chunks, and Swift Detail files are all <= 5000 lines.",
  "cargo test --workspace           # passed",
  "cargo clippy --workspace --all-targets --all-features -- -D warnings # passed",
  "pnpm verify:module-size          # passed",
  "Final status decision: completed.",
]) {
  requireText(checklist, "docs/v2.86-verification-checklist.md", snippet);
}

if (checklist.includes("- [ ]")) {
  fail("V2.86 completed checklist must not contain unchecked evidence items");
}

for (const snippet of [
  '"verify:v2.86-docs": "node scripts/verify-v2-86-validation-docs.mjs"',
  '"verify:module-size": "node scripts/verify-module-size.mjs"',
  "pnpm verify:service-protocol-drift && pnpm verify:module-size",
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
  requireText(text, label, "V2.86");
  requireText(text, label, "Rust helper/test split");
  requireText(text, label, "module-size");
  requireText(text, label, "service_support_helpers.rs");
  requireText(text, label, "crates/service/src/tests/");
}

for (const snippet of [
  "const scanRoots = [",
  "\"crates\"",
  "\"apps/macos/Sources\"",
  "\"apps/macos/Tests\"",
  "\"scripts\"",
  "[\".rs\", 5_000]",
  "[\".swift\", 5_000]",
  "[\".mjs\", 5_000]",
  "legacyBudgets",
]) {
  requireText(moduleSizeVerifier, "scripts/verify-module-size.mjs", snippet);
}

console.log("V2.86 validation docs verification passed");
