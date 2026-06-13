#!/usr/bin/env node

import { readFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = dirname(dirname(fileURLToPath(import.meta.url)));

const files = {
  app: await read("apps/macos/Sources/SkillsCopilot/App/SkillsCopilotApp.swift"),
  content: await read("apps/macos/Sources/SkillsCopilot/Views/ContentView.swift"),
  detail: await read("apps/macos/Sources/SkillsCopilot/Views/DetailView.swift"),
  detailPrimitives: await read("apps/macos/Sources/SkillsCopilot/Views/DetailPresentationPrimitives.swift"),
  formatter: await read("apps/macos/Sources/SkillsCopilot/Support/Formatters.swift"),
  guidedCleanupModel: await read("apps/macos/Sources/SkillsCopilot/Models/GuidedCleanupFlow.swift"),
  privacyPath: await read("apps/macos/Sources/SkillsCopilot/Views/PrivacyPathView.swift"),
  settings: await read("apps/macos/Sources/SkillsCopilot/Views/SettingsView.swift"),
  sidebar: await read("apps/macos/Sources/SkillsCopilot/Views/SidebarView.swift"),
  store: await read("apps/macos/Sources/SkillsCopilot/Stores/SkillStore.swift"),
  taskCockpit: await read("apps/macos/Sources/SkillsCopilot/Views/TaskCockpitPanel.swift"),
  material: await read("apps/macos/Sources/SkillsCopilot/Views/AdaptiveMaterialSurface.swift"),
  localizable: await read("apps/macos/Sources/SkillsCopilot/Resources/en.lproj/Localizable.strings"),
};
files.detailSurface = [files.detail, files.detailPrimitives, files.taskCockpit].join("\n");

const checks = [
  {
    label: "app window defines stable minimum size",
    text: files.app,
    pattern: /\.frame\(minWidth:\s*920,\s*minHeight:\s*600\)/,
  },
  {
    label: "main shell uses NavigationSplitView",
    text: files.content,
    pattern: /NavigationSplitView\s*{/,
  },
  {
    label: "sidebar column has bounded native width",
    text: files.content,
    pattern: /\.navigationSplitViewColumnWidth\(min:\s*300,\s*ideal:\s*340,\s*max:\s*430\)/,
  },
  {
    label: "sidebar exposes scan action",
    text: files.sidebar,
    pattern: /Label\(UIStrings\.text\("action\.scanSkills",\s*"Scan Skills"\),\s*systemImage:\s*"folder\.badge\.gearshape"\)/,
  },
  {
    label: "sidebar exposes reload action",
    text: files.sidebar,
    pattern: /Label\(UIStrings\.text\("action\.reloadCatalog",\s*"Reload Catalog"\),\s*systemImage:\s*"arrow\.clockwise"\)/,
  },
  {
    label: "sidebar exposes adapter capability status",
    text: files.sidebar,
    pattern: /AdapterCapabilityCard\(\s*capability:\s*capability,\s*scanSummary:/,
  },
  {
    label: "sidebar exposes state filter",
    text: files.sidebar,
    pattern: /Picker\(UIStrings\.state,\s*selection:\s*\$store\.stateFilter\)/,
  },
  {
    label: "sidebar exposes sort picker",
    text: files.sidebar,
    pattern: /Picker\(UIStrings\.sort,\s*selection:\s*\$store\.sortOrder\)/,
  },
  {
    label: "detail sections use bounded menu picker",
    text: files.detail,
    pattern: /\.pickerStyle\(\.menu\)[\s\S]*?\.labelsHidden\(\)[\s\S]*?\.frame\(width:\s*240,\s*alignment:\s*\.leading\)/,
  },
  {
    label: "detail sections expose task-first IA summaries",
    text: files.detail,
    pattern: /static var primaryWorkCases:[\s\S]*?\[\.taskCockpit,\s*\.skillMap,\s*\.guidedCleanup,\s*\.observability,\s*\.analysis\][\s\S]*?UIStrings\.taskCockpitTitle[\s\S]*?UIStrings\.guidedCleanupFlowTitle[\s\S]*?UIStrings\.providerObservabilityTitle/,
  },
  {
    label: "task cockpit renders before empty detail fallback",
    text: files.detail,
    pattern: /if store\.selectedDetailSection == \.taskCockpit[\s\S]*?TaskCockpitPanel\([\s\S]*?else if let skill[\s\S]*?EmptyDetailView\(\)/,
  },
  {
    label: "guided cleanup renders safe-link buttons",
    text: files.detail,
    pattern: /GuidedCleanupSafeLinkButton\(link:\s*step\.safeActionDeepLink\)[\s\S]*?GuidedCleanupSafeLinkButton\(link:\s*action\.deepLink\)/,
  },
  {
    label: "guided cleanup safe links route through the store",
    text: files.store,
    pattern: /func openGuidedCleanupSafeLink\([\s\S]*?guard !link\.canApply[\s\S]*?case "selectDetailSection",\s*"openSafeBatchPreviewPanel":[\s\S]*?return[\s\S]*?case "previewRemediationDrafts":[\s\S]*?await previewRemediationDrafts\(\)/,
  },
  {
    label: "guided cleanup safe batch links do not apply changes directly",
    text: files.store,
    pattern: /case "selectDetailSection",\s*"openSafeBatchPreviewPanel":\s*return/,
  },
  {
    label: "guided cleanup model decodes safe-action deep links",
    text: files.guidedCleanupModel,
    pattern: /struct GuidedCleanupSafeActionDeepLink:[\s\S]*?case canApply = "can_apply"[\s\S]*?defaultTrigger\(for method:[\s\S]*?case "batch\.previewSkillToggles":[\s\S]*?return "openSafeBatchPreviewPanel"/,
  },
  {
    label: "analysis section mounts remediation safe entry panels",
    text: files.detail,
    pattern: /TaskRoutingAssessmentPanel\([\s\S]*?RemediationPlanPanel\([\s\S]*?RemediationPreviewDraftsPanel\([\s\S]*?RemediationImpactPreviewPanel\([\s\S]*?RemediationBatchReviewPanel\([\s\S]*?RemediationHistoryPanel\([\s\S]*?AgentSessionSkillReviewPanel\(/,
  },
  {
    label: "task cockpit panel lives in a dedicated module file",
    text: files.taskCockpit,
    pattern: /struct TaskCockpitPanel:[\s\S]*?TaskCockpitResultView[\s\S]*?TaskCockpitSafetyList/,
  },
  {
    label: "detail presentation primitives live in a dedicated module file",
    text: files.detailPrimitives,
    pattern: /struct SafetyPill:[\s\S]*?struct SummaryChip:[\s\S]*?struct RoutingInlineList:[\s\S]*?struct MetadataRow:/,
  },
  {
    label: "sidebar exposes primary work surfaces",
    text: files.sidebar,
    pattern: /Text\(UIStrings\.text\("nav\.work",\s*"Work"\)\)[\s\S]*?ForEach\(DetailSection\.primaryWorkCases\)/,
  },
  {
    label: "findings expose severity filter",
    text: files.detail,
    pattern: /Picker\(UIStrings\.findingSeverityFilter,\s*selection:\s*\$severityFilter\)/,
  },
  {
    label: "findings expose rule filter",
    text: files.detail,
    pattern: /Picker\(UIStrings\.findingRuleFilter,\s*selection:\s*\$ruleFilter\)/,
  },
  {
    label: "findings render severity groups",
    text: files.detail,
    pattern: /FindingSeverityHeader\(group:\s*group\)/,
  },
  {
    label: "findings render remediation guidance",
    text: files.detail,
    pattern: /Label\(UIStrings\.findingRemediation,\s*systemImage:\s*"wrench\.and\.screwdriver"\)/,
  },
  {
    label: "detail renders permissions without safety verdicts",
    text: files.detail,
    pattern: /PermissionSummaryCard\(summary:\s*PermissionDisplayModel\.summary\(for:\s*detail\.permissions\)\)/,
  },
  {
    label: "snapshot preview sheet has bounded width",
    text: files.detail,
    pattern: /\.frame\(width:\s*980,\s*height:\s*680\)/,
  },
  {
    label: "snapshot preview panes are scrollable for long content",
    text: files.detail,
    pattern: /ScrollView\(\[\.vertical,\s*\.horizontal\]\)/,
  },
  {
    label: "settings window has stable minimum dimensions",
    text: files.settings,
    pattern: /\.frame\(minWidth:\s*760,\s*idealWidth:\s*860,\s*minHeight:\s*620,\s*idealHeight:\s*680\)/,
  },
  {
    label: "settings exposes screenshot privacy mode as app-local preference",
    text: files.settings,
    pattern: /@AppStorage\(DisplayText\.screenshotPrivacyModeStorageKey\)[\s\S]*?screenshotPrivacyModeEnabled[\s\S]*?Toggle\(UIStrings\.privacyScreenshotMode,\s*isOn:\s*\$screenshotPrivacyModeEnabled\)/,
  },
  {
    label: "privacy path helper redacts and collapses local paths",
    text: files.formatter,
    pattern: /screenshotPrivacyModeStorageKey[\s\S]*?static func privacyPath[\s\S]*?redactLocalPath[\s\S]*?collapsePath/,
  },
  {
    label: "privacy path view supports explicit reveal",
    text: files.privacyPath,
    pattern: /struct PrivacyPathRow[\s\S]*?@AppStorage\(DisplayText\.screenshotPrivacyModeStorageKey\)[\s\S]*?UIStrings\.privacyRevealPath[\s\S]*?UIStrings\.privacyScreenshotSafe/,
  },
  {
    label: "detail uses privacy path rows for high-risk paths",
    text: files.detail,
    pattern: /PrivacyPathRow\(label:\s*UIStrings\.source,\s*path:\s*skill\.displayPath\)[\s\S]*?PrivacyPathRow\(label:\s*UIStrings\.source,\s*path:\s*preview\.sourcePath\)/,
  },
  {
    label: "sidebar uses privacy path display for report, project, roots, and catalog paths",
    text: files.sidebar,
    pattern: /PrivacyPathText\(path:\s*result\.displayPath[\s\S]*?PrivacyPathLabel\(path:\s*value[\s\S]*?PrivacyPathText\(path:\s*rootPath[\s\S]*?PrivacyPathLabel\(path:\s*store\.status\?\.catalogPath/,
  },
  {
    label: "material surfaces respect reduced transparency",
    text: files.material,
    pattern: /accessibilityReduceTransparency/,
  },
  {
    label: "LLM assist exposes all explicit actions",
    text: files.detail,
    pattern: /ForEach\(LLMAction\.allCases\)/,
  },
  {
    label: "LLM assist buttons are gated by prepare state only",
    text: files.detail,
    pattern: /\.disabled\(isPreparing\(action\)\)/,
  },
  {
    label: "LLM assist renders read-only review previews",
    text: files.detail,
    pattern: /LLMReviewPreviewView\(preview:\s*reviewPreview\)/,
  },
  {
    label: "LLM review preview exposes no-action boundary",
    text: files.detailSurface,
    pattern: /Label\(UIStrings\.llmReviewNoActions,\s*systemImage:\s*"nosign"\)/,
  },
  {
    label: "LLM draft frontmatter warns about confirmation and copy",
    text: files.detail,
    pattern: /UIStrings\.llmDraftCopyRequired/,
  },
  {
    label: "tool-global preview uses read-only install affordance",
    text: files.detail,
    pattern: /ToolGlobalPreviewCard\(skill:\s*skill\)/,
  },
  {
    label: "tool-global install confirmation uses verified write copy",
    text: files.detail,
    pattern: /store\.confirmToolInstall\(skill:\s*skill,\s*target:\s*preview\.target\)/,
  },
  {
    label: "sidebar labels read-only preview rows",
    text: files.sidebar,
    pattern: /UIStrings\.readOnlyPreview/,
  },
  {
    label: "localized LLM action labels are present",
    text: files.localizable,
    pattern: /"llm\.action\.analyze".*"llm\.action\.recommend".*"llm\.action\.explainConflict".*"llm\.action\.draftFrontmatter"/s,
  },
  {
    label: "localized LLM review preview labels are present",
    text: files.localizable,
    pattern: /"llm\.reviewPreview".*"llm\.reviewPurpose".*"llm\.reviewRisk".*"llm\.reviewCrossAgentFit".*"llm\.reviewNoActions"/s,
  },
  {
    label: "localized tool-global preview labels are present",
    text: files.localizable,
    pattern: /"detail\.toolGlobal\.previewTitle".*"detail\.toolGlobal\.installReady".*"detail\.toolGlobal\.installConfirmation"/s,
  },
  {
    label: "localized finding filter labels are present",
    text: files.localizable,
    pattern: /"findings\.filter\.severity".*"findings\.filter\.rule".*"findings\.visibleSummary"/s,
  },
  {
    label: "localized adapter capability labels are present",
    text: files.localizable,
    pattern: /"sidebar\.adapterCapabilities".*"adapter\.capability\.scan".*"adapter\.capability\.toggle".*"adapter\.capability\.install"/s,
  },
  {
    label: "localized screenshot privacy labels are present",
    text: files.localizable,
    pattern: /"settings\.privacy\.screenshotMode".*"settings\.privacy\.screenshotBoundary".*"privacy\.path\.reveal".*"privacy\.path\.screenshotSafe"/s,
  },
  {
    label: "localized task cockpit labels are present",
    text: files.localizable,
    pattern: /"taskCockpit\.boundary".*"taskCockpit\.action\.build".*"taskCockpit\.empty\.result".*"taskCockpit\.recommendedSkill"/s,
  },
  {
    label: "localized remediation and permissions labels are present",
    text: files.localizable,
    pattern: /"findings\.remediation".*"permissions\.undeclared".*"permissions\.declarationNote"/s,
  },
];

const failures = checks.filter((check) => !check.pattern.test(check.text));
if (failures.length > 0) {
  for (const failure of failures) {
    console.error(`native-ui-layout-check: missing ${failure.label}`);
  }
  process.exit(1);
}

console.log(`native-ui-layout-check: ${checks.length} checks passed`);

async function read(path) {
  return readFile(join(repoRoot, path), "utf8");
}
