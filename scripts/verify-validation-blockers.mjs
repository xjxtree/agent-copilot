#!/usr/bin/env node

import { readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import {
  classifyValidationBlocker,
  formatValidationBlocker,
  validationBlockerCodes,
} from "./validation-blockers.mjs";

const scriptDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(scriptDir, "..");

const cases = [
  ["locked-session: macOS session is locked", "locked-session"],
  ["CGSSessionScreenIsLocked=Yes", "locked-session"],
  ["screenshot is near black", "black-capture"],
  ["black-capture: screenshot is near black", "black-capture"],
  ["screenshot has near-zero visual variance", "flat-capture"],
  ["screenshot is mostly transparent", "transparent-capture"],
  ["invalid-capture: image has zero dimensions", "invalid-capture"],
  ["Computer Use server error -10005: timeoutReached", "computer-use-timeout"],
  ["Computer Use returned cgWindowNotFound", "window-not-found"],
  ["System Events reported 0 AX windows", "no-ax-window"],
  ["remoteConnection while resolving the app", "remote-connection"],
  ["activation error after get_app_state", "activation-failed"],
  ["check macOS Screen Recording permission", "screen-recording-permission"],
  ["Swift app binary is older than source inputs", "stale-bundle"],
  ["unexpected validation failure", "tool-layer-unknown"],
];

for (const [input, expected] of cases) {
  const actual = classifyValidationBlocker(input);
  if (actual !== expected) {
    console.error(`validation blocker classifier mismatch: expected ${expected}, got ${actual} for ${input}`);
    process.exit(1);
  }
}

for (const code of validationBlockerCodes) {
  const formatted = formatValidationBlocker(`${code}: sample`);
  if (!formatted.startsWith(`${code}:`)) {
    console.error(`validation blocker formatter changed canonical prefix for ${code}`);
    process.exit(1);
  }
}

const captureScript = readFileSync(join(repoRoot, "script", "capture_app_window.sh"), "utf8");
if (captureScript.includes("CGWindowListCreateImage")) {
  console.error("capture helper must not use deprecated CGWindowListCreateImage for window screenshots");
  process.exit(1);
}
if (!captureScript.includes("/usr/sbin/screencapture") || !captureScript.includes("\"-l\"")) {
  console.error("capture helper must use screencapture -l for window screenshots");
  process.exit(1);
}

console.log(`validation blocker verification passed: ${cases.length} cases, ${validationBlockerCodes.length} codes`);
