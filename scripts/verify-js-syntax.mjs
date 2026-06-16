#!/usr/bin/env node

import { readdirSync } from "node:fs";
import { join, resolve } from "node:path";
import { spawnSync } from "node:child_process";

const repoRoot = resolve(new URL("..", import.meta.url).pathname);
const scriptDir = join(repoRoot, "scripts");

function listMjsFiles(dir) {
  return readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const path = join(dir, entry.name);
    if (entry.isDirectory()) {
      return listMjsFiles(path);
    }
    return entry.isFile() && entry.name.endsWith(".mjs") ? [path] : [];
  });
}

const files = listMjsFiles(scriptDir).sort();
const failures = [];

for (const file of files) {
  const result = spawnSync(process.execPath, ["--check", file], {
    encoding: "utf8",
    stdio: "pipe",
  });
  if (result.status !== 0) {
    failures.push({
      file,
      output: [result.stdout, result.stderr].filter(Boolean).join("\n").trim(),
    });
  }
}

if (failures.length > 0) {
  console.error(`JS syntax verification failed for ${failures.length} file(s):`);
  for (const failure of failures) {
    console.error(`\n${failure.file}`);
    console.error(failure.output || "(no output)");
  }
  process.exit(1);
}

console.log(`JS syntax verification passed: ${files.length} .mjs files checked`);
