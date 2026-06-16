#!/usr/bin/env node

import { existsSync, readdirSync, readFileSync } from "node:fs";
import { join, resolve } from "node:path";

const repoRoot = resolve(new URL("..", import.meta.url).pathname);
const maxLines = 5000;

const exactFiles = [
  "crates/service/src/lib.rs",
  "crates/service/src/service_cleanup.rs",
  "crates/service/src/service_host.rs",
  "crates/service/src/service_knowledge.rs",
  "crates/service/src/service_llm.rs",
  "crates/service/src/service_remediation.rs",
  "crates/service/src/service_task.rs",
  "crates/service/src/service_support_helpers.rs",
  "crates/service/src/service_knowledge_helpers.rs",
  "crates/service/src/service_remediation_helpers.rs",
  "crates/service/src/service_task_helpers.rs",
  "crates/service/src/service_observability_helpers.rs",
  "crates/service/src/service_llm_prompt_helpers.rs",
  "crates/service/src/service_guided_cleanup_helpers.rs",
  "crates/service/src/tests.rs",
  "apps/macos/Sources/SkillsCopilot/Views/DetailView.swift",
  "apps/macos/Sources/SkillsCopilot/Views/DetailOverviewSection.swift",
  "apps/macos/Sources/SkillsCopilot/Views/DetailReviewCoreSection.swift",
  "apps/macos/Sources/SkillsCopilot/Views/DetailReviewKnowledgePanels.swift",
  "apps/macos/Sources/SkillsCopilot/Views/DetailRemediationPanels.swift",
  "apps/macos/Sources/SkillsCopilot/Views/DetailKnowledgeSkillMapPanels.swift",
  "apps/macos/Sources/SkillsCopilot/Views/DetailGuidedCleanupFlowPanel.swift",
  "apps/macos/Sources/SkillsCopilot/Views/DetailProviderObservabilityPanel.swift",
  "apps/macos/Sources/SkillsCopilot/Views/DetailLocalSkillMapViews.swift",
  "apps/macos/Sources/SkillsCopilot/Views/DetailTaskBenchmarkSection.swift",
  "apps/macos/Sources/SkillsCopilot/Views/DetailAgentSessionSection.swift",
  "apps/macos/Sources/SkillsCopilot/Views/DetailLLMSection.swift",
  "apps/macos/Sources/SkillsCopilot/Views/DetailHeaderOverviewSection.swift",
  "apps/macos/Sources/SkillsCopilot/Views/DetailFindingsHistorySection.swift",
  "apps/macos/Sources/SkillsCopilot/Views/TaskCockpitPanel.swift",
  "apps/macos/Sources/SkillsCopilot/Views/ValidationWorkbenchPanel.swift",
];

const files = [
  ...exactFiles,
  ...filesInDir("crates/service/src/tests").filter((file) => file.endsWith(".rs")),
];

const failures = [];
for (const relativePath of files) {
  const path = join(repoRoot, relativePath);
  if (!existsSync(path)) {
    failures.push(`${relativePath}: missing`);
    continue;
  }
  const lineCount = readFileSync(path, "utf8").split(/\r?\n/).length - 1;
  if (lineCount > maxLines) {
    failures.push(`${relativePath}: ${lineCount} lines exceeds ${maxLines}`);
  }
}

if (failures.length > 0) {
  console.error("module-size verification failed:");
  for (const failure of failures) {
    console.error(`  - ${failure}`);
  }
  process.exit(1);
}

console.log(`module-size verification passed: ${files.length} files <= ${maxLines} lines`);

function filesInDir(relativeDir) {
  const dir = join(repoRoot, relativeDir);
  if (!existsSync(dir)) {
    return [];
  }
  return readdirSync(dir, { withFileTypes: true })
    .filter((entry) => entry.isFile())
    .map((entry) => `${relativeDir}/${entry.name}`);
}
