#!/usr/bin/env node

import { existsSync, readdirSync, readFileSync } from "node:fs";
import { extname, join, resolve } from "node:path";

const repoRoot = resolve(new URL("..", import.meta.url).pathname);

const scanRoots = [
  "crates",
  "apps/macos/Sources",
  "apps/macos/Tests",
  "scripts",
];

const defaultBudgets = new Map([
  [".rs", 5_000],
  [".swift", 5_000],
  [".mjs", 5_000],
]);

const legacyBudgets = new Map([
  [
    "crates/commands/src/lib.rs",
    {
      maxLines: 10_100,
      targetLines: 5_000,
      reason: "legacy command surface pending continued domain split",
    },
  ],
]);

const ignoredDirs = new Set([
  ".build",
  ".git",
  "dist",
  "node_modules",
  "target",
]);

const files = scanRoots.flatMap(filesInTree).sort();
const failures = [];
const legacyHits = [];

for (const relativePath of files) {
  const ext = extname(relativePath);
  const defaultMax = defaultBudgets.get(ext);
  if (!defaultMax) {
    continue;
  }
  const budget = legacyBudgets.get(relativePath);
  const maxLines = budget?.maxLines ?? defaultMax;
  const lineCount = readFileSync(join(repoRoot, relativePath), "utf8").split(/\r?\n/).length - 1;
  if (lineCount > maxLines) {
    failures.push(
      `${relativePath}: ${lineCount} lines exceeds ${maxLines}` +
        (budget ? ` legacy budget (${budget.reason})` : ""),
    );
  }
  if (budget) {
    legacyHits.push(
      `${relativePath}: ${lineCount}/${budget.maxLines} lines; target <= ${budget.targetLines} (${budget.reason})`,
    );
  }
}

for (const relativePath of legacyBudgets.keys()) {
  if (!files.includes(relativePath)) {
    failures.push(`${relativePath}: legacy budget points at a missing file`);
  }
}

if (failures.length > 0) {
  console.error("module-size verification failed:");
  for (const failure of failures) {
    console.error(`  - ${failure}`);
  }
  process.exit(1);
}

console.log(
  `module-size verification passed: ${files.length} files scanned; default budgets ${formatDefaultBudgets()}`,
);
if (legacyHits.length > 0) {
  console.log("legacy module-size budgets:");
  for (const hit of legacyHits) {
    console.log(`  - ${hit}`);
  }
}

function filesInTree(relativeDir) {
  const dir = join(repoRoot, relativeDir);
  if (!existsSync(dir)) {
    return [];
  }
  return walk(relativeDir);
}

function walk(relativeDir) {
  const dir = join(repoRoot, relativeDir);
  return readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const relativePath = `${relativeDir}/${entry.name}`;
    if (entry.isDirectory()) {
      if (ignoredDirs.has(entry.name)) {
        return [];
      }
      return walk(relativePath);
    }
    if (!entry.isFile()) {
      return [];
    }
    return defaultBudgets.has(extname(relativePath)) ? [relativePath] : [];
  });
}

function formatDefaultBudgets() {
  return [...defaultBudgets.entries()]
    .map(([ext, maxLines]) => `${ext}<=${maxLines}`)
    .join(", ");
}
