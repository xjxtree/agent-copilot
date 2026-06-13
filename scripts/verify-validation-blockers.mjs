#!/usr/bin/env node

import {
  classifyValidationBlocker,
  formatValidationBlocker,
  validationBlockerCodes,
} from "./validation-blockers.mjs";

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

console.log(`validation blocker verification passed: ${cases.length} cases, ${validationBlockerCodes.length} codes`);
