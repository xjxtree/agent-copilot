#!/usr/bin/env node

import { readFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = dirname(dirname(fileURLToPath(import.meta.url)));

const files = {
  app: await read("apps/macos/Sources/SkillsCopilot/App/SkillsCopilotApp.swift"),
  content: await read("apps/macos/Sources/SkillsCopilot/Views/ContentView.swift"),
  detail: await read("apps/macos/Sources/SkillsCopilot/Views/DetailView.swift"),
  agentCopilotOverview: await read("apps/macos/Sources/SkillsCopilot/Views/AgentCopilotOverviewPanel.swift"),
  agentCopilotDecision: await read("apps/macos/Sources/SkillsCopilot/Models/AgentCopilotDecision.swift"),
  mcpServerPreview: await read("apps/macos/Sources/SkillsCopilot/Models/McpServerPreview.swift"),
  detailOverview: await read("apps/macos/Sources/SkillsCopilot/Views/DetailOverviewSection.swift"),
  detailPrimitives: await read("apps/macos/Sources/SkillsCopilot/Views/DetailPresentationPrimitives.swift"),
  detailReviewCore: await read("apps/macos/Sources/SkillsCopilot/Views/DetailReviewCoreSection.swift"),
  detailReviewKnowledge: await read("apps/macos/Sources/SkillsCopilot/Views/DetailReviewKnowledgePanels.swift"),
  detailRemediation: await read("apps/macos/Sources/SkillsCopilot/Views/DetailRemediationPanels.swift"),
  detailKnowledgeSkillMap: await read("apps/macos/Sources/SkillsCopilot/Views/DetailKnowledgeSkillMapPanels.swift"),
  detailGuidedCleanup: await read("apps/macos/Sources/SkillsCopilot/Views/DetailGuidedCleanupFlowPanel.swift"),
  detailProviderObservability: await read("apps/macos/Sources/SkillsCopilot/Views/DetailProviderObservabilityPanel.swift"),
  detailLocalSkillMap: await read("apps/macos/Sources/SkillsCopilot/Views/DetailLocalSkillMapViews.swift"),
  detailTaskBenchmark: await read("apps/macos/Sources/SkillsCopilot/Views/DetailTaskBenchmarkSection.swift"),
  detailAgentSession: await read("apps/macos/Sources/SkillsCopilot/Views/DetailAgentSessionSection.swift"),
  detailLLM: await read("apps/macos/Sources/SkillsCopilot/Views/DetailLLMSection.swift"),
  detailHeaderOverview: await read("apps/macos/Sources/SkillsCopilot/Views/DetailHeaderOverviewSection.swift"),
  detailFindingsHistory: await read("apps/macos/Sources/SkillsCopilot/Views/DetailFindingsHistorySection.swift"),
  formatter: await read("apps/macos/Sources/SkillsCopilot/Support/Formatters.swift"),
  guidedCleanupModel: await read("apps/macos/Sources/SkillsCopilot/Models/GuidedCleanupFlow.swift"),
  privacyPath: await read("apps/macos/Sources/SkillsCopilot/Views/PrivacyPathView.swift"),
  serviceClient: await read("apps/macos/Sources/SkillsCopilot/Services/ServiceClient.swift"),
  serviceClientEvidence: await read("apps/macos/Sources/SkillsCopilot/Services/ServiceClientEvidenceRPC.swift"),
  serviceClientTransport: await read("apps/macos/Sources/SkillsCopilot/Services/ServiceClientTransport.swift"),
  serviceProcessRunner: await read("apps/macos/Sources/SkillsCopilot/Services/ServiceProcessRunner.swift"),
  settings: await read("apps/macos/Sources/SkillsCopilot/Views/SettingsView.swift"),
  sidebar: await read("apps/macos/Sources/SkillsCopilot/Views/SidebarView.swift"),
  store: await read("apps/macos/Sources/SkillsCopilot/Stores/SkillStore.swift"),
  storeNavigation: await read("apps/macos/Sources/SkillsCopilot/Stores/SkillStoreNavigationActions.swift"),
  storeWorkflow: await read("apps/macos/Sources/SkillsCopilot/Stores/SkillStoreWorkflowSelectors.swift"),
  taskCockpit: await read("apps/macos/Sources/SkillsCopilot/Views/TaskCockpitPanel.swift"),
  taskInput: await read("apps/macos/Sources/SkillsCopilot/Views/TaskInputTextEditor.swift"),
  validationWorkbench: await read("apps/macos/Sources/SkillsCopilot/Views/ValidationWorkbenchPanel.swift"),
  material: await read("apps/macos/Sources/SkillsCopilot/Views/AdaptiveMaterialSurface.swift"),
  localizable: await read("apps/macos/Sources/SkillsCopilot/Resources/en.lproj/Localizable.strings"),
  serviceProtocol: await read("docs/service-protocol.md"),
  serviceStatusFixture: await read("fixtures/service-protocol/service.status.response.json"),
  serviceRust: await read("crates/service/src/lib.rs"),
  serviceRustProtocol: await read("crates/service/src/protocol.rs"),
};
files.detailSurface = [
  files.detail,
  files.agentCopilotOverview,
  files.detailOverview,
  files.detailPrimitives,
  files.detailReviewCore,
  files.detailReviewKnowledge,
  files.detailRemediation,
  files.detailKnowledgeSkillMap,
  files.detailGuidedCleanup,
  files.detailProviderObservability,
  files.detailLocalSkillMap,
  files.detailTaskBenchmark,
  files.detailAgentSession,
  files.detailLLM,
  files.detailHeaderOverview,
  files.detailFindingsHistory,
  files.taskCockpit,
].join("\n");
files.serviceIPC = [
  files.serviceClient,
  files.serviceClientEvidence,
  files.serviceClientTransport,
  files.serviceProcessRunner,
].join("\n");
files.storeSurface = [
  files.store,
  files.storeNavigation,
  files.storeWorkflow,
].join("\n");
files.serviceRustSurface = [files.serviceRust, files.serviceRustProtocol].join("\n");

const runServiceBody = extractFunctionBody(files.serviceIPC, "runService");
const serviceRequestBody = extractServiceRequestBody(files.serviceIPC);
const supportedMethods = parseSupportedMethods(files.serviceRustSurface);
const statusFixtureMethods = parseStatusFixtureMethods(files.serviceStatusFixture);
const forbiddenProtocolMethods = supportedMethods.filter((method) => /^(ipc|sidecar|daemon|process|socket)\./.test(method));

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
    text: files.detailSurface,
    pattern: /\.pickerStyle\(\.menu\)[\s\S]*?\.labelsHidden\(\)[\s\S]*?\.frame\(width:\s*240,\s*alignment:\s*\.leading\)/,
  },
  {
    label: "V2.80 detail navigation has a stable scroll-to-top anchor",
    text: files.detailSurface,
    pattern: /private static let topAnchorID = "skills-copilot\.detail\.top"[\s\S]*?ScrollViewReader\s*{\s*proxy\s+in[\s\S]*?\.id\(Self\.topAnchorID\)/,
  },
  {
    label: "V2.80 detail navigation scrolls to top when the selected section changes",
    text: files.detailSurface,
    pattern: /\.onChange\(of:\s*store\.selectedDetailSection\)[\s\S]*?proxy\.scrollTo\(Self\.topAnchorID,\s*anchor:\s*\.top\)/,
  },
  {
    label: "detail sections expose task-first IA summaries",
    text: files.detailSurface,
    pattern: /static var primaryWorkCases:[\s\S]*?\[\.lineup,\s*\.agentProfile,\s*\.taskCockpit,\s*\.validationWorkbench,\s*\.skillMap,\s*\.guidedCleanup,\s*\.observability,\s*\.analysis\][\s\S]*?UIStrings\.taskCockpitTitle[\s\S]*?UIStrings\.validationWorkbenchTitle[\s\S]*?UIStrings\.guidedCleanupFlowTitle[\s\S]*?UIStrings\.providerObservabilityTitle/,
  },
  {
    label: "task cockpit renders before empty detail fallback",
    text: files.detailSurface,
    pattern: /else if store\.selectedDetailSection == \.taskCockpit[\s\S]*?TaskCockpitPanel\([\s\S]*?else if let skill[\s\S]*?EmptyDetailView\(\)/,
  },
  {
    label: "local session preview is default-off, explicitly authorized, and privacy-rendered",
    text: files.detailAgentSession + "\n" + files.storeSurface + "\n" + files.serviceProtocol,
    pattern: /LocalSessionPreviewPanel\([\s\S]*?roots:\s*\$localSessionRoots[\s\S]*?Preview is default-off[\s\S]*?TextField\(UIStrings\.text\("localSessionPreview\.placeholder"[\s\S]*?PrivacyEvidenceText\(value:\s*row\.redactedPath[\s\S]*?PrivacyEvidenceText\(value:\s*row\.excerpt[\s\S]*?func previewLocalSessions\(\)\s*async[\s\S]*?service\.previewLocalSessions[\s\S]*?session\.previewLocalSessions/,
  },
  {
    label: "MCP server preview is default-off, explicitly authorized, and privacy-rendered",
    text: files.agentCopilotOverview + "\n" + files.storeSurface + "\n" + files.serviceClientEvidence + "\n" + files.mcpServerPreview + "\n" + files.serviceProtocol,
    pattern: /McpServerPreviewPanel\([\s\S]*?paths:\s*\$store\.mcpServerPreviewPaths[\s\S]*?Preview is default-off[\s\S]*?TextField\(UIStrings\.text\("mcpServerPreview\.placeholder"[\s\S]*?PrivacyEvidenceText\(value:\s*row\.sourcePath[\s\S]*?PrivacyEvidenceText\(value:\s*command[\s\S]*?func previewMcpServers\(\)\s*async[\s\S]*?service\.previewMcpServers[\s\S]*?evidence\.previewMcpServers/,
  },
  {
    label: "Agent Copilot object-level overview renders before skill detail fallback",
    text: files.detailSurface,
    pattern: /if store\.selectedDetailSection == \.lineup[\s\S]*?AgentCopilotOverviewPanel\(\)[\s\S]*?else if store\.selectedDetailSection == \.agentProfile[\s\S]*?AgentProfilePanel\(\)[\s\S]*?else if let skill/,
  },
  {
    label: "Agent Copilot decision queue has explicit sorted priority and evidence refs",
    text: files.agentCopilotDecision + "\n" + files.agentCopilotOverview,
    pattern: /enum AgentCopilotDecisionPriority:[\s\S]*?case critical = 400[\s\S]*?static func sorted\([\s\S]*?left\.priority > right\.priority[\s\S]*?impactScore[\s\S]*?evidenceRefs\.count[\s\S]*?return AgentCopilotDecisionModel\.sorted\(items\)[\s\S]*?DenseDisclosureList\(item\.evidenceRefs,\s*visibleLimit:\s*3[\s\S]*?PrivacyEvidenceText\(value:\s*evidenceRef/,
  },
  {
    label: "guided cleanup renders safe-link buttons",
    text: files.detailSurface,
    pattern: /GuidedCleanupSafeLinkButton\(link:\s*step\.safeActionDeepLink\)[\s\S]*?GuidedCleanupSafeLinkButton\(link:\s*action\.deepLink\)/,
  },
  {
    label: "guided cleanup safe links route through the store",
    text: files.storeSurface,
    pattern: /func openGuidedCleanupSafeLink\([\s\S]*?guard !link\.canApply[\s\S]*?case "selectDetailSection",\s*"openSafeBatchPreviewPanel":[\s\S]*?return[\s\S]*?case "previewRemediationDrafts":[\s\S]*?await previewRemediationDrafts\(\)/,
  },
  {
    label: "guided cleanup safe batch links do not apply changes directly",
    text: files.storeSurface,
    pattern: /case "selectDetailSection",\s*"openSafeBatchPreviewPanel":\s*return/,
  },
  {
    label: "guided cleanup model decodes safe-action deep links",
    text: files.guidedCleanupModel,
    pattern: /struct GuidedCleanupSafeActionDeepLink:[\s\S]*?case canApply = "can_apply"[\s\S]*?defaultTrigger\(for method:[\s\S]*?case "batch\.previewSkillToggles":[\s\S]*?return "openSafeBatchPreviewPanel"/,
  },
  {
    label: "analysis section mounts remediation safe entry panels",
    text: files.detailSurface,
    pattern: /TaskRoutingAssessmentPanel\([\s\S]*?RemediationPlanPanel\([\s\S]*?RemediationPreviewDraftsPanel\([\s\S]*?RemediationImpactPreviewPanel\([\s\S]*?RemediationBatchReviewPanel\([\s\S]*?RemediationHistoryPanel\([\s\S]*?AgentSessionSkillReviewPanel\(/,
  },
  {
    label: "task cockpit panel lives in a dedicated module file",
    text: files.taskCockpit,
    pattern: /struct TaskCockpitPanel:[\s\S]*?TaskCockpitResultView[\s\S]*?TaskCockpitSafetyList/,
  },
  {
    label: "task cockpit exposes progressive staged feedback",
    text: files.taskCockpit,
    pattern: /TaskCockpitStageProgressView\([\s\S]*?TaskCockpitProgressSnapshot\([\s\S]*?ForEach\(snapshot\.stageRows\)[\s\S]*?TaskCockpitStageTile\(row:[\s\S]*?accessibilityIdentifier\(AppAccessibilityID\.taskCockpitStageProgress\)/,
  },
  {
    label: "validation workbench uses shared snapshot and stable accessibility identifiers",
    text: files.validationWorkbench,
    pattern: /ValidationWorkbenchModel\.canonicalSnapshot[\s\S]*?AppAccessibilityID\.validationWorkbench[\s\S]*?AppAccessibilityID\.validationWorkbenchSummary[\s\S]*?AppAccessibilityID\.validationWorkbenchEvidence[\s\S]*?AppAccessibilityID\.validationWorkbenchBlockerRow/,
  },
  {
    label: "task cockpit task input uses an AX-settable multiline TextField",
    text: files.taskInput,
    pattern: /struct TaskInputTextEditor:[\s\S]*?TextField\(placeholder,\s*text:\s*\$text,\s*axis:\s*\.vertical\)[\s\S]*?\.lineLimit\(3\.\.\.5\)[\s\S]*?\.frame\([\s\S]*?minHeight:\s*Self\.minHeight[\s\S]*?maxHeight:\s*Self\.maxHeight[\s\S]*?\.accessibilityIdentifier\(AppAccessibilityID\.taskCockpitInput\)/,
  },
  {
    label: "task cockpit input model preserves raw text and trims only for submit state",
    text: files.taskInput,
    pattern: /struct TaskInputModel:[\s\S]*?let rawText:[\s\S]*?rawText\.trimmingCharacters\(in:\s*\.whitespacesAndNewlines\)[\s\S]*?var canSubmit:[\s\S]*?!trimmedText\.isEmpty/,
  },
  {
    label: "task cockpit build button remains explicit and input-gated",
    text: files.taskCockpit,
    pattern: /Button\s*{[\s\S]*?onBuild\(\)[\s\S]*?\.disabled\(isBuilding \|\| !inputModel\.canSubmit\)/,
  },
  {
    label: "detail presentation primitives live in a dedicated module file",
    text: files.detailPrimitives,
    pattern: /struct SafetyPill:[\s\S]*?struct SummaryChip:[\s\S]*?struct RoutingInlineList:[\s\S]*?struct MetadataRow:/,
  },
  {
    label: "dense disclosure list caps visible rows and reveals overflow",
    text: files.detailPrimitives,
    pattern: /struct DenseDisclosureList<Item,\s*RowContent:\s*View>:[\s\S]*?visibleLimit:\s*Int = 6[\s\S]*?ForEach\(Array\(items\.prefix\(visibleLimit\)\.enumerated\(\)\),\s*id:\s*\\\.offset\)[\s\S]*?DisclosureGroup\(isExpanded:\s*\$isExpanded\)[\s\S]*?items\.dropFirst\(visibleLimit\)/,
  },
  {
    label: "dense inline evidence lists are counted, collapsible, and screenshot-safe",
    text: files.detailPrimitives,
    pattern: /struct RoutingInlineList:[\s\S]*?DenseCountBadge\(count:\s*values\.count\)[\s\S]*?DenseDisclosureList\(values,\s*visibleLimit:\s*3,\s*spacing:\s*3\)[\s\S]*?PrivacyEvidenceLabel\(value:\s*value,\s*systemImage:\s*systemImage,\s*font:\s*\.caption,\s*lineLimit:\s*2\)/,
  },
  {
    label: "task cockpit evidence list is capped and screenshot-safe",
    text: files.taskCockpit,
    pattern: /struct TaskCockpitEvidenceList:[\s\S]*?DenseDisclosureList\(evidence,\s*visibleLimit:\s*6,\s*spacing:\s*6\)[\s\S]*?PrivacyEvidenceText\(value:\s*source,\s*font:\s*\.caption2,\s*lineLimit:\s*1\)[\s\S]*?PrivacyEvidenceText\(value:\s*item\.detail,\s*font:\s*\.caption,\s*lineLimit:\s*nil\)/,
  },
  {
    label: "sidebar exposes primary work surfaces",
    text: files.sidebar,
    pattern: /Text\(UIStrings\.text\("nav\.work",\s*"Work"\)\)[\s\S]*?ForEach\(DetailSection\.primaryWorkCases\)/,
  },
  {
    label: "findings expose severity filter",
    text: files.detailSurface,
    pattern: /Picker\(UIStrings\.findingSeverityFilter,\s*selection:\s*\$severityFilter\)/,
  },
  {
    label: "findings expose rule filter",
    text: files.detailSurface,
    pattern: /Picker\(UIStrings\.findingRuleFilter,\s*selection:\s*\$ruleFilter\)/,
  },
  {
    label: "findings render severity groups",
    text: files.detailSurface,
    pattern: /FindingSeverityHeader\(group:\s*group\)/,
  },
  {
    label: "findings render remediation guidance",
    text: files.detailSurface,
    pattern: /Label\(UIStrings\.findingRemediation,\s*systemImage:\s*"wrench\.and\.screwdriver"\)/,
  },
  {
    label: "detail renders permissions without safety verdicts",
    text: files.detailSurface,
    pattern: /PermissionSummaryCard\(summary:\s*PermissionDisplayModel\.summary\(for:\s*detail\.permissions\)\)/,
  },
  {
    label: "snapshot preview sheet has bounded width",
    text: files.detailSurface,
    pattern: /\.frame\(width:\s*980,\s*height:\s*680\)/,
  },
  {
    label: "snapshot preview panes are scrollable for long content",
    text: files.detailSurface,
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
    text: files.detailSurface,
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
    text: files.detailSurface,
    pattern: /ForEach\(LLMAction\.allCases\)/,
  },
  {
    label: "LLM assist buttons are gated by prepare state only",
    text: files.detailSurface,
    pattern: /\.disabled\(isPreparing\(action\)\)/,
  },
  {
    label: "LLM assist renders read-only review previews",
    text: files.detailSurface,
    pattern: /LLMReviewPreviewView\(preview:\s*reviewPreview\)/,
  },
  {
    label: "LLM review preview exposes no-action boundary",
    text: files.detailSurface,
    pattern: /Label\(UIStrings\.llmReviewNoActions,\s*systemImage:\s*"nosign"\)/,
  },
  {
    label: "LLM draft frontmatter warns about confirmation and copy",
    text: files.detailSurface,
    pattern: /UIStrings\.llmDraftCopyRequired/,
  },
  {
    label: "tool-global preview uses read-only install affordance",
    text: files.detailSurface,
    pattern: /ToolGlobalPreviewCard\(skill:\s*skill\)/,
  },
  {
    label: "tool-global install confirmation uses verified write copy",
    text: files.detailSurface,
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

const detailEvidenceLists = [
  "SkillQualityEvidenceList",
  "TaskReadinessEvidenceList",
  "RoutingEvidenceList",
  "CrossAgentReadinessEvidenceList",
  "RoutingAccuracyEvidenceList",
  "ProviderObservabilityEvidenceList",
];

const nativeIPCCleanupChecks = [
  {
    label: "V2.81 ServiceClient keeps short-lived stdio Process IPC shape",
    passed: /Process\(\)/.test(files.serviceIPC)
      && /\.standardInput\s*=\s*stdin/.test(files.serviceIPC)
      && /\.standardOutput\s*=\s*stdout/.test(files.serviceIPC)
      && /\.standardError\s*=\s*stderr/.test(files.serviceIPC),
  },
  {
    label: "V2.81 ServiceClient wraps runService with task cancellation cleanup",
    passed: /processRunner\.run\(executableURL:\s*resolveServiceURL\(\),\s*input:\s*input\)/.test(runServiceBody)
      && /withTaskCancellationHandler/.test(files.serviceProcessRunner),
  },
  {
    label: "V2.81 ServiceClient terminates and reaps the child process on cancel or timeout",
    passed: /terminate\s*\(/.test(files.serviceProcessRunner)
      && /waitUntilExit\s*\(/.test(files.serviceProcessRunner)
      && /(onCancel|Task\.isCancelled|Cancellation|cancel|timeout|timedOut|forceTerminate)/i.test(files.serviceProcessRunner),
  },
  {
    label: "V2.81 ServiceClient closes stdin, stdout, and stderr handles during IPC cleanup",
    passed: countMatches(files.serviceIPC, /fileHandleForWriting[\s\S]{0,180}\.(?:close|closeFile)\s*\(/g) >= 1
      && /stdinWriter\?\.(?:close|closeFile)\s*\(/.test(files.serviceProcessRunner)
      && /stdoutReader\?\.(?:close|closeFile)\s*\(/.test(files.serviceProcessRunner)
      && /stderrReader\?\.(?:close|closeFile)\s*\(/.test(files.serviceProcessRunner),
  },
  {
    label: "V2.81 ServiceClient clears pipe readability handlers or closes read handles",
    passed: /readabilityHandler\s*=\s*nil/.test(files.serviceIPC)
      || (/stdoutReader\?\.(?:close|closeFile)\s*\(/.test(files.serviceProcessRunner)
        && /stderrReader\?\.(?:close|closeFile)\s*\(/.test(files.serviceProcessRunner)),
  },
  {
    label: "V2.81 ServiceClient protects continuations from stale or duplicate completion",
    passed: /(resumeOnce|finishOnce|completeOnce|didResume|hasResumed|isCompleted|completed|finished|cleanedUp|stale)/i.test(files.serviceIPC)
      && /(NSLock|DispatchQueue|ManagedAtomic|lock\s*\(|actor\b)/.test(files.serviceIPC)
      && /(if\s+cleanedUp|guard\s+!.*cleanedUp|markCancelled|Task\.checkCancellation)/s.test(files.serviceProcessRunner),
  },
  {
    label: "V2.81 ServiceClient does not introduce a daemon, socket, XPC, or network redesign",
    passed: !/(^|\n)\s*import\s+Network\b|NWListener|NWConnection|NSXPCConnection|URLSessionWebSocketTask|SocketPort|UnixDomainSocket|\bdaemon\b|\blaunchd\b/.test(files.serviceIPC),
  },
  {
    label: "V2.81 ServiceRequest IPC payload remains id, method, and params only",
    passed: /let\s+id:\s*String/.test(serviceRequestBody)
      && /let\s+method:\s*String/.test(serviceRequestBody)
      && /let\s+params:\s*Params/.test(serviceRequestBody)
      && !/(cancel|timeout|pid|socket|daemon|token)/i.test(serviceRequestBody),
  },
  {
    label: "V2.87 Agent Copilot protocol method surface remains the current 90-method contract",
    passed: supportedMethods.length === 90
      && statusFixtureMethods.length === 90
      && /current count is 90 methods/.test(files.serviceProtocol),
  },
  {
    label: "V2.81 protocol surface has no IPC control, daemon, process, or socket methods",
    passed: forbiddenProtocolMethods.length === 0,
  },
];

const customChecks = [
  {
    label: "V2.80 detail evidence lists are row-capped and use privacy rendering",
    passed: detailEvidenceLists.every((name) => {
      const body = extractStructBody(files.detailSurface, name);
      return (body.includes("ForEach(evidence.prefix(") || body.includes("DenseDisclosureList(evidence, visibleLimit:"))
        && body.includes("PrivacyEvidenceText(value: item.detail")
        && body.includes("PrivacyEvidenceText(value: source");
    }),
  },
  ...nativeIPCCleanupChecks,
];

const failures = [
  ...checks.filter((check) => !check.pattern.test(check.text)),
  ...customChecks.filter((check) => !check.passed),
];
if (failures.length > 0) {
  for (const failure of failures) {
    console.error(`native-ui-layout-check: missing ${failure.label}`);
  }
  process.exit(1);
}

console.log(`native-ui-layout-check: ${checks.length + customChecks.length} checks passed`);

async function read(path) {
  return readFile(join(repoRoot, path), "utf8");
}

function extractStructBody(text, structName) {
  const marker = `struct ${structName}:`;
  const start = text.indexOf(marker);
  if (start === -1) {
    return "";
  }

  const openBrace = text.indexOf("{", start);
  if (openBrace === -1) {
    return "";
  }

  let depth = 0;
  for (let index = openBrace; index < text.length; index += 1) {
    const char = text[index];
    if (char === "{") {
      depth += 1;
    } else if (char === "}") {
      depth -= 1;
      if (depth === 0) {
        return text.slice(openBrace + 1, index);
      }
    }
  }

  return "";
}

function extractFunctionBody(text, functionName) {
  const match = new RegExp(`func\\s+${escapeRegex(functionName)}\\b`).exec(text);
  if (!match) {
    return "";
  }
  return extractBalancedBody(text, match.index);
}

function extractServiceRequestBody(text) {
  const marker = "struct ServiceRequest";
  const start = text.indexOf(marker);
  if (start === -1) {
    return "";
  }
  return extractBalancedBody(text, start);
}

function extractBalancedBody(text, start) {
  const openBrace = text.indexOf("{", start);
  if (openBrace === -1) {
    return "";
  }

  let depth = 0;
  for (let index = openBrace; index < text.length; index += 1) {
    const char = text[index];
    if (char === "{") {
      depth += 1;
    } else if (char === "}") {
      depth -= 1;
      if (depth === 0) {
        return text.slice(openBrace + 1, index);
      }
    }
  }

  return "";
}

function parseSupportedMethods(rustSource) {
  const block = rustSource.match(/const\s+SUPPORTED_METHODS\s*:\s*&\s*\[\s*&str\s*\]\s*=\s*&\s*\[([\s\S]*?)\];/);
  if (!block) {
    return [];
  }
  return uniqueSorted([...block[1].matchAll(/"([a-z]+\.[A-Za-z][A-Za-z0-9]*)"/g)].map((match) => match[1]));
}

function parseStatusFixtureMethods(text) {
  try {
    const fixture = JSON.parse(text);
    const methods = fixture?.result?.supported_methods;
    return Array.isArray(methods) ? uniqueSorted(methods.filter((method) => typeof method === "string")) : [];
  } catch {
    return [];
  }
}

function uniqueSorted(values) {
  return [...new Set(values)].sort((left, right) => left.localeCompare(right));
}

function countMatches(text, pattern) {
  return [...text.matchAll(pattern)].length;
}

function escapeRegex(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}
