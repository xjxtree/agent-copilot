#!/usr/bin/env node

import { existsSync, readFileSync } from "node:fs";
import { join, resolve } from "node:path";

const repoRoot = resolve(new URL("..", import.meta.url).pathname);

const versions = {
  "v2.73": {
    title: "# V2.73 Verification Checklist",
    required: [
      "Task / remediation performance and timeout recovery",
      "Task Cockpit cannot remain in `Preparing...`",
      "timeout/fallback/cancel/retry",
      "docs/ui-artifacts/v2.73-task-cockpit-timeout-recovery/completed.png",
      "task.checkReadiness",
      "remediation.batchReview",
    ],
  },
  "v2.74": {
    title: "# V2.74 Verification Checklist",
    required: [
      "Real-local launch and window targeting stability",
      "exact current-bundle launch",
      "duplicate same-bundle",
      "PID `52193`",
      "docs/ui-artifacts/v2.74-launch-window-targeting/completed.png",
      "No formal signing",
    ],
  },
  "v2.75": {
    title: "# V2.75 Verification Checklist",
    required: [
      "Task input and input-method resilience",
      "AX-settable",
      "skills-copilot.task-cockpit.input",
      "PID `43079`",
      "docs/ui-artifacts/v2.75-task-input-resilience/completed.png",
      "No raw prompt persistence",
    ],
  },
  "v2.76": {
    title: "# V2.76 Verification Checklist",
    required: [
      "Progressive Cockpit feedback",
      "skills-copilot.task-cockpit.stage-progress",
      "PID: `39728`",
      "docs/ui-artifacts/v2.76-progressive-cockpit-feedback/completed.png",
      "No new provider default calls",
      "No hidden task state",
    ],
  },
  "v2.77": {
    title: "# V2.77 Verification Checklist",
    required: [
      "real-local validation workbench",
      "skills-copilot.validation-workbench",
      "Running PID: `34909`",
      "docs/ui-artifacts/v2.77-validation-workbench/completed.png",
      "canonical blockers",
      "preserves unlocked manual visual review",
    ],
  },
  "v2.78": {
    title: "# V2.78 Verification Checklist",
    required: [
      "protocol / validation gate parity",
      "SUPPORTED_METHODS",
      "V2.46-V2.64 verification history",
      "pnpm verify:service-protocol-drift",
      "No protocol method rename",
      "No replacement of unlocked manual visual review",
    ],
  },
  "v2.79": {
    title: "# V2.79 Verification Checklist",
    required: [
      "privacy fixture and evidence-surface localization sweep",
      "literal loopback host-port",
      "path redaction/collapse/reveal",
      "PID: `68064`",
      "docs/ui-artifacts/v2.79-privacy-localization/completed.png",
      "No credential reads",
    ],
  },
  "v2.80": {
    title: "# V2.80 Verification Checklist",
    required: [
      "Detail navigation and visual density polish",
      "skills-copilot.detail.top",
      "DenseDisclosureList",
      "PID: `82571`",
      "docs/ui-artifacts/v2.80-detail-density/completed.png",
      "No provider default calls",
    ],
  },
  "v2.81": {
    title: "# V2.81 Verification Checklist",
    required: [
      "Swift stdio sidecar cancellation cleanup",
      "ServiceProcessRunner.swift",
      "SIGKILL",
      "swift test --package-path apps/macos",
      "No daemon or socket redesign",
      "Real-local validation decision",
    ],
  },
  "v2.82": {
    title: "# V2.82 Verification Checklist",
    required: [
      "test isolation and core model test floor",
      "serialized RAII guard",
      "cargo test -p skills-copilot-core",
      "locked-session",
      "No credential reads beyond existing explicitly confirmed provider tests",
      "Real-local validation decision",
    ],
  },
  "v2.83": {
    title: "# V2.83 Verification Checklist",
    required: [
      "continued module splitting",
      "crates/service/src/protocol.rs",
      "DetailOverviewSection.swift",
      "FakeServiceScript.swift",
      "No service protocol method or payload changes",
      "Real-local validation decision",
    ],
  },
  "v2.84": {
    title: "# V2.84 Verification Checklist",
    required: [
      "Swift Detail section splitting",
      "DetailGuidedCleanupFlowPanel.swift",
      "TaskCockpitPanel.swift",
      "verify:module-size",
      "DetailView.swift",
      "Final status decision: completed",
    ],
  },
  "v2.85": {
    title: "# V2.85 Verification Checklist",
    required: [
      "Rust RPC domain module splitting",
      "service_host.rs",
      "service_task.rs",
      "pnpm verify:service-protocol-drift",
      "88-method service protocol",
      "Final status decision: completed",
    ],
  },
  "v2.86": {
    title: "# V2.86 Verification Checklist",
    required: [
      "Rust helper/test split and module-size gate",
      "service_support_helpers.rs",
      "crates/service/src/tests/",
      "verify:module-size",
      "cargo clippy --workspace",
      "Final status decision: completed",
    ],
  },
  "v2.87": {
    title: "# V2.87 Verification Checklist",
    required: [
      "Agent Copilot first pass",
      "Lineup default surface",
      "Agent Profile",
      "session.previewLocalSessions",
      "evidence.previewMcpServers",
      "90 methods",
      "docs/ui-artifacts/native-macos-shell/completed.png",
      "Final status decision: completed",
    ],
  },
  "v2.88": {
    title: "# V2.88 Verification Checklist",
    required: [
      "handoff and per-surface evidence",
      "Lineup",
      "Agent Profile",
      "Local Session Preview",
      "MCP Preview",
      "docs/ui-artifacts/v2.88-handoff-evidence",
      "/tmp/ac-v288",
      "Final status decision: completed",
    ],
  },
  "v2.89": {
    title: "# V2.89 Verification Checklist",
    required: [
      "Brand asset refresh",
      "AppIcon.icns",
      "AppIcon.svg",
      "Agent Copilot display brand",
      "unchanged internal identifiers",
      "docs/ui-artifacts/v2.89-brand-assets",
      "pnpm generate:app-icon",
      "Final status decision: completed",
    ],
  },
};

const staleStatus = [
  "Status: planned",
  "Status: in progress",
  "Final status decision: pending",
  "remains planned",
  "not completed",
  "coordinator verification pending",
];

const commonSafety = [
  ["No provider", "provider calls", "provider default calls"],
  ["No write", "write path", "write paths", "write action", "write/apply path"],
  ["No script execution", "script execution"],
  ["No credential", "credential read", "credential handling"],
  ["No cloud sync", "cloud sync"],
  ["No telemetry", "telemetry"],
];

function fail(message) {
  console.error(`version validation docs verification failed: ${message}`);
  process.exit(1);
}

function readRequired(relativePath) {
  const path = join(repoRoot, relativePath);
  if (!existsSync(path)) {
    fail(`missing required file: ${relativePath}`);
  }
  return readFileSync(path, "utf8");
}

function requireText(text, label, snippet) {
  if (!text.includes(snippet)) {
    fail(`${label} missing required text: ${snippet}`);
  }
}

function rejectText(text, label, snippet) {
  if (text.includes(snippet)) {
    fail(`${label} contains stale text: ${snippet}`);
  }
}

function requireAnyText(text, label, snippets) {
  if (!snippets.some((snippet) => text.includes(snippet))) {
    fail(`${label} missing one of: ${snippets.join(" | ")}`);
  }
}

function verifyVersion(version) {
  const config = versions[version];
  if (!config) {
    fail(`unknown version '${version}'. Expected one of: ${Object.keys(versions).join(", ")}`);
  }

  const versionNumber = version.replace("v", "").toUpperCase();
  const checklistPath = `docs/${version}-verification-checklist.md`;
  const checklist = readRequired(checklistPath);
  const packageJson = readRequired("package.json");
  const developmentTasks = readRequired("docs/development-tasks.md");
  const roadmap = readRequired("docs/roadmap.md");

  requireText(checklist, checklistPath, config.title);
  requireText(checklist, checklistPath, "Status: completed");
  requireText(checklist, checklistPath, "pnpm check:privacy");
  requireText(checklist, checklistPath, `pnpm verify:${version}-docs`);

  for (const snippets of commonSafety) {
    requireAnyText(checklist, checklistPath, snippets);
  }
  for (const snippet of config.required) {
    requireText(checklist, checklistPath, snippet);
  }
  for (const snippet of staleStatus) {
    rejectText(checklist, checklistPath, snippet);
  }
  rejectText(checklist, checklistPath, "- [ ]");

  const checkedItems = checklist.match(/- \[x\]/g) ?? [];
  if (checkedItems.length < 6) {
    fail(`${checklistPath} has too few completed evidence items: ${checkedItems.length}`);
  }

  const expectedScript = `"verify:${version}-docs": "node scripts/verify-version-validation-docs.mjs ${version}"`;
  requireText(packageJson, "package.json", expectedScript);
  requireText(
    packageJson,
    "package.json",
    `pnpm verify:${version}-docs`,
  );

  requireText(developmentTasks, "docs/development-tasks.md", `${version}-verification-checklist.md`);
  requireText(roadmap, "docs/roadmap.md", `${version}-verification-checklist.md`);

  console.log(`${versionNumber} validation docs verification passed`);
}

const requestedVersions = process.argv.slice(2);
const versionsToVerify =
  requestedVersions.length > 0 ? requestedVersions : Object.keys(versions);

for (const version of versionsToVerify) {
  verifyVersion(version);
}
