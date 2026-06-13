#!/usr/bin/env node

import { readFileSync } from "node:fs";
import { formatValidationBlocker } from "./validation-blockers.mjs";

const argText = process.argv.slice(2).filter((arg) => arg !== "--").join(" ").trim();
const stdinText = process.stdin.isTTY ? "" : readFileSync(0, "utf8").trim();
const input = argText || stdinText;

console.log(formatValidationBlocker(input, "validation blocker input was empty"));
