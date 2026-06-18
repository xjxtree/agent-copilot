#!/usr/bin/env node
import { existsSync, readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(scriptDir, "..");

function fail(message) {
  console.error(`doc governance verification failed: ${message}`);
  process.exit(1);
}

function read(relativePath) {
  const path = join(repoRoot, relativePath);
  if (!existsSync(path)) fail(`missing ${relativePath}`);
  return readFileSync(path, "utf8");
}

function requireText(text, label, snippet) {
  if (!text.includes(snippet)) fail(`${label} missing required text: ${snippet}`);
}

const roadmap = read("docs/roadmap.md");
const tasks = read("docs/development-tasks.md");
const adapters = read("docs/agent-adapters.md");
const agents = read("AGENTS.md");
const packageJson = read("package.json");
const workflow = read("docs/ai-agent-workflow.md");

for (const [text, label] of [
  [roadmap, "docs/roadmap.md"],
  [tasks, "docs/development-tasks.md"],
]) {
  requireText(text, label, "V2.46-V2.64");
  requireText(text, label, "no separate checklist files");
  requireText(text, label, "V2.41-V2.72");
  requireText(text, label, "no package-level `verify:v2.NN-docs` scripts");
  requireText(text, label, "V2.73+ docs gates");
}

requireText(adapters, "docs/agent-adapters.md", "V2.41-V2.94");
requireText(agents, "AGENTS.md", "V2.78 completed boundary");
requireText(packageJson, "package.json", "\"verify:pi-writable-evidence-fixtures\"");
requireText(packageJson, "package.json", "\"verify:doc-governance\"");
requireText(
  workflow,
  "docs/ai-agent-workflow.md",
  "`verify:macos-ui-layout` is intentionally reached through `pnpm check:macos`"
);

console.log("doc governance verification passed");
