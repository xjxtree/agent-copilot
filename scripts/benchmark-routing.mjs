#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import { platform } from "node:os";

const cargoArgs = [
  "test",
  "-p",
  "skills-copilot-service",
  "benchmark_routing_fixture",
  "--",
  "--ignored",
  "--nocapture",
];

function run(command, args) {
  return spawnSync(command, args, {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
    env: {
      ...process.env,
      PATH: `${process.env.HOME}/.cargo/bin:${process.env.PATH}`,
    },
  });
}

function printOutput(result) {
  if (result.stdout) {
    process.stdout.write(result.stdout);
  }
  if (result.stderr) {
    process.stderr.write(result.stderr);
  }
}

const timeArgs =
  platform() === "darwin"
    ? ["-l", "cargo", ...cargoArgs]
    : ["-v", "cargo", ...cargoArgs];
const result = run("/usr/bin/time", timeArgs);
printOutput(result);

const combined = `${result.stdout}\n${result.stderr}`;
const benchLine = combined
  .split("\n")
  .find((line) => line.includes("skills-copilot-bench"));
const rssMatch =
  platform() === "darwin"
    ? combined.match(/(\d+)\s+maximum resident set size/)
    : combined.match(/Maximum resident set size \(kbytes\):\s+(\d+)/);

if (benchLine) {
  console.log(`benchmark: ${benchLine.trim()}`);
}
if (rssMatch) {
  const rssBytes =
    platform() === "darwin" ? Number(rssMatch[1]) : Number(rssMatch[1]) * 1024;
  console.log(`benchmark: max_rss_mb=${(rssBytes / 1024 / 1024).toFixed(1)}`);
}

const benchmarkSucceeded =
  result.status === 0 ||
  (benchLine !== undefined && combined.includes("test result: ok"));

if (!benchmarkSucceeded) {
  process.exit(result.status ?? 1);
}
