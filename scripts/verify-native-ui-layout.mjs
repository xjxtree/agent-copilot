#!/usr/bin/env node

import { readFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = dirname(dirname(fileURLToPath(import.meta.url)));

const files = {
  app: await read("apps/macos/Sources/SkillsCopilot/App/SkillsCopilotApp.swift"),
  mainWindowCoordinator: await read("apps/macos/Sources/SkillsCopilot/App/MainWindowCoordinator.swift"),
  content: await read("apps/macos/Sources/SkillsCopilot/Views/ContentView.swift"),
  detail: await read("apps/macos/Sources/SkillsCopilot/Views/DetailView.swift"),
  agentCopilotOverview: await read("apps/macos/Sources/SkillsCopilot/Views/AgentCopilotOverviewPanel.swift"),
  agentCopilotDecision: await read("apps/macos/Sources/SkillsCopilot/Models/AgentCopilotDecision.swift"),
  mcpServerPreview: await read("apps/macos/Sources/SkillsCopilot/Models/McpServerPreview.swift"),
  detailSection: await read("apps/macos/Sources/SkillsCopilot/Models/DetailSection.swift"),
  detailOverview: await read("apps/macos/Sources/SkillsCopilot/Views/DetailOverviewSection.swift"),
  detailPrimitives: await read("apps/macos/Sources/SkillsCopilot/Views/DetailPresentationPrimitives.swift"),
  detailReviewCore: await read("apps/macos/Sources/SkillsCopilot/Views/DetailReviewCoreSection.swift"),
  detailReviewKnowledge: await read("apps/macos/Sources/SkillsCopilot/Views/DetailReviewKnowledgePanels.swift"),
  detailRemediation: await read("apps/macos/Sources/SkillsCopilot/Views/DetailRemediationPanels.swift"),
  detailKnowledgeSkillMap: await read("apps/macos/Sources/SkillsCopilot/Views/DetailKnowledgeSkillMapPanels.swift"),
  detailGuidedCleanup: await read("apps/macos/Sources/SkillsCopilot/Views/DetailGuidedCleanupFlowPanel.swift"),
  detailProviderObservability: await read("apps/macos/Sources/SkillsCopilot/Views/DetailProviderObservabilityPanel.swift"),
  providerObservabilitySettings: await read("apps/macos/Sources/SkillsCopilot/Views/ProviderObservabilitySettingsPanel.swift"),
  skillManager: await read("apps/macos/Sources/SkillsCopilot/Views/SkillManagerPanel.swift"),
  workflowSheet: await read("apps/macos/Sources/SkillsCopilot/Views/WorkflowSheetChrome.swift"),
  skillManagerModel: await read("apps/macos/Sources/SkillsCopilot/Models/SkillManager.swift"),
  batchSkillOperation: await read("apps/macos/Sources/SkillsCopilot/Views/BatchSkillOperationSheet.swift"),
  detailLocalSkillMap: await read("apps/macos/Sources/SkillsCopilot/Views/DetailLocalSkillMapViews.swift"),
  detailTaskBenchmark: await read("apps/macos/Sources/SkillsCopilot/Views/DetailTaskBenchmarkSection.swift"),
  detailAgentSession: await read("apps/macos/Sources/SkillsCopilot/Views/DetailAgentSessionSection.swift"),
  detailLLM: await read("apps/macos/Sources/SkillsCopilot/Views/DetailLLMSection.swift"),
  markdownRender: await read("apps/macos/Sources/SkillsCopilot/Models/MarkdownRenderDocument.swift"),
  markdownTableDisplay: await read("apps/macos/Sources/SkillsCopilot/Models/MarkdownTableDisplayModel.swift"),
  agentConfigWorkspace: await read("apps/macos/Sources/SkillsCopilot/Views/AgentConfigWorkspacePanel.swift"),
  detailHeaderOverview: await read("apps/macos/Sources/SkillsCopilot/Views/DetailHeaderOverviewSection.swift"),
  detailFindingsHistory: await read("apps/macos/Sources/SkillsCopilot/Views/DetailFindingsHistorySection.swift"),
  agentIconProvider: await read("apps/macos/Sources/SkillsCopilot/Support/AgentIconProvider.swift"),
  formatter: await read("apps/macos/Sources/SkillsCopilot/Support/Formatters.swift"),
  uiStrings: await read("apps/macos/Sources/SkillsCopilot/Support/UIStrings.swift"),
  guidedCleanupModel: await read("apps/macos/Sources/SkillsCopilot/Models/GuidedCleanupFlow.swift"),
  privacyPath: await read("apps/macos/Sources/SkillsCopilot/Views/PrivacyPathView.swift"),
  serviceClient: await read("apps/macos/Sources/SkillsCopilot/Services/ServiceClient.swift"),
  serviceClientEvidence: await read("apps/macos/Sources/SkillsCopilot/Services/ServiceClientEvidenceRPC.swift"),
  serviceClientTransport: await read("apps/macos/Sources/SkillsCopilot/Services/ServiceClientTransport.swift"),
  serviceProcessRunner: await read("apps/macos/Sources/SkillsCopilot/Services/ServiceProcessRunner.swift"),
  settings: await read("apps/macos/Sources/SkillsCopilot/Views/SettingsView.swift"),
  sidebar: await read("apps/macos/Sources/SkillsCopilot/Views/SidebarView.swift"),
  sidebarSelection: await read("apps/macos/Sources/SkillsCopilot/Models/SidebarSelection.swift"),
  uiOptimization: await read("apps/macos/Sources/SkillsCopilot/Models/UIOptimizationPresentation.swift"),
  store: await read("apps/macos/Sources/SkillsCopilot/Stores/SkillStore.swift"),
  storeList: await read("apps/macos/Sources/SkillsCopilot/Stores/SkillListModel.swift"),
  storeDerivedState: await read("apps/macos/Sources/SkillsCopilot/Stores/SkillStoreDerivedState.swift"),
  storeNavigation: await read("apps/macos/Sources/SkillsCopilot/Stores/SkillStoreNavigationActions.swift"),
  storeWorkflow: await read("apps/macos/Sources/SkillsCopilot/Stores/SkillStoreWorkflowSelectors.swift"),
  taskCockpit: await read("apps/macos/Sources/SkillsCopilot/Views/TaskCockpitPanel.swift"),
  taskInput: await read("apps/macos/Sources/SkillsCopilot/Views/TaskInputTextEditor.swift"),
  taskInputModel: await read("apps/macos/Sources/SkillsCopilot/Models/TaskInputModel.swift"),
  material: await read("apps/macos/Sources/SkillsCopilot/Views/AdaptiveMaterialSurface.swift"),
  localizable: await read("apps/macos/Sources/SkillsCopilot/Resources/en.lproj/Localizable.strings"),
  localizableZh: await read("apps/macos/Sources/SkillsCopilot/Resources/zh-Hans.lproj/Localizable.strings"),
  serviceProtocol: await read("docs/service-protocol.md"),
  serviceStatusFixture: await read("fixtures/service-protocol/service.status.response.json"),
  serviceRust: await read("crates/service/src/lib.rs"),
  serviceKnowledge: await read("crates/service/src/service_knowledge.rs"),
  serviceLLMPromptHelpers: await read("crates/service/src/service_llm_prompt_helpers.rs"),
  serviceRustProtocol: await read("crates/service/src/protocol.rs"),
};
files.detailSurface = [
  files.detail,
  files.agentCopilotOverview,
  files.detailSection,
  files.detailOverview,
  files.detailPrimitives,
  files.detailReviewCore,
  files.detailReviewKnowledge,
  files.detailRemediation,
  files.detailKnowledgeSkillMap,
  files.detailGuidedCleanup,
  files.detailProviderObservability,
  files.providerObservabilitySettings,
  files.detailLocalSkillMap,
  files.detailTaskBenchmark,
  files.detailAgentSession,
  files.detailLLM,
  files.agentConfigWorkspace,
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
  files.storeDerivedState,
  files.storeNavigation,
  files.storeWorkflow,
].join("\n");
files.serviceRustSurface = [
  files.serviceRust,
  files.serviceKnowledge,
  files.serviceLLMPromptHelpers,
  files.serviceRustProtocol,
].join("\n");

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
    label: "list pages use a unified window toolbar with global search and creation actions",
    text: files.content + "\n" + files.uiOptimization,
    passed: /static let unifiedToolbar = UnifiedToolbarPresentation\(\)[\s\S]*?static let listPage = ListPagePresentation\(\)[\s\S]*?static let sidebarShell = SidebarShellPresentation\(\)/.test(files.uiOptimization)
      && /struct UnifiedToolbarPresentation:[\s\S]*?spansEntireWindow = true[\s\S]*?searchPlacement = UnifiedToolbarSearchPlacement\.globalTrailing[\s\S]*?collapsesAtScrollEdge = true[\s\S]*?settingsActionUsesSystemSettingsLink = true/.test(files.uiOptimization)
      && /struct ListPagePresentation:[\s\S]*?filterStyle = ListPageFilterStyle\.capsule[\s\S]*?searchScope = ListPageSearchScope\.localList[\s\S]*?rowStyle = ListPageRowStyle\.materialCard[\s\S]*?minimumCardRowHeight = 58[\s\S]*?cardRowSpacing = 8/.test(files.uiOptimization)
      && /\.toolbar\s*\{[\s\S]*?AppBrandToolbarItem\(\)[\s\S]*?ToolbarContextSummary\([\s\S]*?GlobalToolbarSearchField\([\s\S]*?isSkillManagerSheetPresented = true[\s\S]*?questionmark\.circle[\s\S]*?ToolbarSettingsControl\(\)[\s\S]*?ToolbarAvatarView/.test(files.content)
      && /private struct ToolbarSettingsControl:[\s\S]*?if #available\(macOS 14\.0,\s*\*\)[\s\S]*?SettingsLink[\s\S]*?settingsLabel[\s\S]*?openSettingsFallback\(\)[\s\S]*?showPreferencesWindow/.test(files.content)
      && /private var contextSubtitle:[\s\S]*?DisplayText\.privacyPath\(projectPath,\s*privacyModeEnabled:\s*true\)/.test(files.content)
      && /private func applyGlobalSearch\(\)[\s\S]*?case \.skills:[\s\S]*?store\.searchText = query[\s\S]*?case \.sessions:[\s\S]*?store\.localSessionSearchText = query[\s\S]*?case \.config:[\s\S]*?store\.configSidebarSearchText = query/.test(files.content),
  },
  {
    label: "startup prewarm shows only loading progress before revealing the app shell",
    text: files.content + "\n" + files.store + "\n" + files.localizable,
    passed: /ZStack\s*{[\s\S]*?appShell[\s\S]*?\.opacity\(store\.startupLoadingState == nil \? 1 : 0\)[\s\S]*?\.allowsHitTesting\(store\.startupLoadingState == nil\)[\s\S]*?if let state = store\.startupLoadingState[\s\S]*?AppStartupLoadingView\(state:\s*state\)/.test(files.content)
      && /\.task\s*{[\s\S]*?await store\.loadAppStartupDataIfNeeded\(\)[\s\S]*?}/.test(files.content)
      && /private struct AppStartupLoadingView:[\s\S]*?Text\(state\.message\)[\s\S]*?ProgressView\(value:\s*state\.progress\)[\s\S]*?\.background\(Color\(nsColor:\s*\.windowBackgroundColor\)\)/.test(files.content)
      && !/if store\.status == nil && store\.skills\.isEmpty[\s\S]*?await store\.reload\(\)/.test(files.content)
      && /struct AppStartupLoadingState:[\s\S]*?let message: String[\s\S]*?let progress: Double/.test(files.store)
      && /@Published private\(set\) var startupLoadingState:[\s\S]*?UIStrings\.startupPreparingLoading/.test(files.store)
      && /@Published private\(set\) var hasCompletedStartupLoad = false/.test(files.store)
      && /func loadAppStartupDataIfNeeded\(\) async[\s\S]*?try await refreshCollections\(\)[\s\S]*?await loadCleanupQueue\(\)[\s\S]*?await loadCrossAgentComparisons\(\)[\s\S]*?await refreshSelectedAgentLocalSessions\(\)[\s\S]*?await loadCurrentAgentConfigDocuments\(agent:\s*agentFilter\.rawValue\)[\s\S]*?await loadSelectedDetail\(\)/.test(files.store)
      && /"startup\.catalog" = "Loading catalog data\.\.\."/.test(files.localizable),
  },
  {
    label: "primary and secondary sidebar columns have bounded native widths",
    text: files.content + "\n" + files.uiOptimization,
    passed: /struct SidebarShellPresentation:[\s\S]*?let width = 260/.test(files.uiOptimization)
      && /minimumSecondaryColumnWidth = 360[\s\S]*?idealSecondaryColumnWidth = 400[\s\S]*?maximumSecondaryColumnWidth = 520/.test(files.uiOptimization)
      && /SidebarView\(\)[\s\S]*?UIOptimizationPresentation\.sidebarShell\.width[\s\S]*?UIOptimizationPresentation\.sidebarShell\.width[\s\S]*?UIOptimizationPresentation\.sidebarShell\.width[\s\S]*?SecondarySidebarView\(\)[\s\S]*?UIOptimizationPresentation\.skillList\.minimumSecondaryColumnWidth[\s\S]*?UIOptimizationPresentation\.skillList\.idealSecondaryColumnWidth[\s\S]*?UIOptimizationPresentation\.skillList\.maximumSecondaryColumnWidth/.test(files.content),
  },
  {
    label: "selected agent session metrics refresh from the root view uses need-based prewarm",
    text: files.content + "\n" + files.storeSurface,
    pattern: /(?=[\s\S]*?\.task\(id:\s*store\.selectedAgentLocalSessionRefreshKey\)[\s\S]*?await store\.refreshSelectedAgentLocalSessionsIfNeeded\(\))(?=[\s\S]*?var selectedAgentLocalSessionRefreshKey:[\s\S]*?agentFilter\.rawValue[\s\S]*?activeProjectContext\?\.rootPath)(?=[\s\S]*?func refreshSelectedAgentLocalSessionsIfNeeded\(\)\s*async[\s\S]*?previewLocalSessions\(allowDuringCatalogRefresh:\s*true,\s*force:\s*false\))/,
  },
  {
    label: "primary sidebar exposes agent cards plus global skill manager and preflight footer tools",
    text: files.sidebar + "\n" + files.detail + "\n" + files.app + "\n" + files.mainWindowCoordinator + "\n" + files.workflowSheet,
    passed: /@State private var isSkillManagerSheetPresented = false/.test(files.sidebar)
      && /@State private var isPreflightSheetPresented = false/.test(files.sidebar)
      && /AgentWorkspaceHeader\(\)[\s\S]*?ProjectContextControls\(\)/.test(files.sidebar)
      && /SidebarNavigationCardButton\([\s\S]*?title:\s*SidebarContentMode\.sessions\.title[\s\S]*?sessionCardMetrics[\s\S]*?selectSessions\(\)/.test(files.sidebar)
      && /SidebarNavigationCardButton\([\s\S]*?title:\s*SidebarContentMode\.skills\.title[\s\S]*?skillCardMetrics[\s\S]*?selectSkills\(\)/.test(files.sidebar)
      && /SidebarNavigationCardButton\([\s\S]*?title:\s*SidebarContentMode\.config\.title[\s\S]*?configCardMetrics[\s\S]*?selectConfig\(\)/.test(files.sidebar)
      && /SidebarFooterToolRow\([\s\S]*?isSkillManagerPresented:\s*isSkillManagerSheetPresented[\s\S]*?onOpenSkillManager:[\s\S]*?isSkillManagerSheetPresented = true[\s\S]*?onOpenPreflight:[\s\S]*?isPreflightSheetPresented = true[\s\S]*?\)/.test(files.sidebar)
      && /private struct SidebarFooterToolRow:[\s\S]*?skillManager\.title[\s\S]*?skillManager\.sidebar\.subtitle[\s\S]*?sidebar\.skillManager\.metric\.global[\s\S]*?UIStrings\.taskCockpitTitle[\s\S]*?sidebar\.preflight\.subtitle/.test(files.sidebar)
      && /\.sheet\(isPresented:\s*\$isSkillManagerSheetPresented\)[\s\S]*?SkillPackageManagerSheet\(\)/.test(files.sidebar + "\n" + files.content)
      && /struct SkillPackageManagerSheet:[\s\S]*?WorkflowSheetShell\([\s\S]*?SkillManagerPanel\(showsHeader:\s*false\)/.test(files.sidebar)
      && /\.sheet\(isPresented:\s*\$isPreflightSheetPresented\)[\s\S]*?TaskPreflightPreviewSheet\(\)/.test(files.sidebar)
      && /\.navigationTitle\(""\)/.test(files.detail)
      && /window\.titleVisibility = \.hidden/.test(files.mainWindowCoordinator)
      && /window\.titlebarAppearsTransparent = true/.test(files.mainWindowCoordinator)
      && /window\.styleMask\.insert\(\.fullSizeContentView\)/.test(files.mainWindowCoordinator)
      && /\.padding\(\.top,\s*8\)[\s\S]*?\.padding\(\.horizontal,\s*28\)[\s\S]*?\.padding\(\.bottom,\s*28\)/.test(files.detail)
      && !/isReportSheetPresented|LocalReportPreviewSheet|sidebar\.report\.title/.test(files.sidebar)
      && !/Section\(UIStrings\.text\("skillManager\.title"[\s\S]*?SidebarSelection\.work\(\.skillManager\)/.test(files.sidebar)
      && !/selectedSidebarSelection\s*=\s*\.work\(\.skillManager\)/.test(files.sidebar)
      && !/selectedDetailSection == \.skillManager[\s\S]*?SkillManagerPanel\(\)/.test(files.detail)
      && !/navigationTitle\(UIStrings\.appWindowTitle\)/.test(files.detail)
      && !/SidebarNavigationCardButton\(\s*title:\s*UIStrings\.text\("sidebar\.report\.title"/.test(files.sidebar)
      && !/SidebarNavigationCardButton\([\s\S]*?UIStrings\.taskCockpitTitle[\s\S]*?selectedSidebarSelection = \.preflight/.test(files.sidebar)
      && !/selectedSidebarSelection\s*=\s*\.report/.test(files.sidebar),
  },
  {
    label: "secondary sidebar omits the agent profile row and switches session, skill, or config lists",
    text: files.sidebar,
    passed: /struct SecondarySidebarView:[\s\S]*?List\(selection:\s*\$store\.selectedSidebarSelection\)[\s\S]*?switch store\.sidebarContentMode[\s\S]*?case \.sessions:[\s\S]*?SessionSidebarPanel\(\)[\s\S]*?case \.skills:[\s\S]*?SkillSidebarPanel/.test(files.sidebar)
      && /case \.config:[\s\S]*?ConfigSidebarPanel\(\)/.test(files.sidebar)
      && !/AgentProfileSidebarRow/.test(files.sidebar)
      && !/SidebarSelection\.agentWorkspace/.test(files.sidebar),
  },
  {
    label: "sidebar sessions surface exposes refresh, compact rows, and top skill usage",
    text: files.sidebar + "\n" + files.store,
    passed: /private struct SessionSidebarPanel:[\s\S]*?let preview = store\.localSessionPreviewResult[\s\S]*?sidebar\.sessions\.list[\s\S]*?SessionSidebarRow\([\s\S]*?showsProjectRoot:\s*store\.localSessionScopeFilter == \.all[\s\S]*?store\.selectedSidebarSelection == \.session\(session\.id\)[\s\S]*?store\.selectLocalSession\(session\)[\s\S]*?preview\.skillUsageRows/.test(files.sidebar)
      && /private var sessionRefreshButton:[\s\S]*?await store\.previewLocalSessions\(\)/.test(files.sidebar)
      && /private struct SessionSidebarRow:[\s\S]*?let showsProjectRoot:\s*Bool[\s\S]*?session\.projectRoot[\s\S]*?if let startedAt = session\.startedAt[\s\S]*?sidebar\.sessions\.startShort[\s\S]*?if let endedAt = session\.endedAt[\s\S]*?sidebar\.sessions\.lastShort/.test(files.sidebar)
      && /private func selectSessions\(\)[\s\S]*?refreshSelectedAgentLocalSessionsIfNeeded\(\)/.test(files.sidebar)
      && /private func selectSessions\(\)[\s\S]*?store\.filteredLocalSessionRows\.first/.test(files.sidebar)
      && !/private func selectSessions\(\)[\s\S]*?localSessionPreviewResult\.sessionRows\.first/.test(files.sidebar)
      && /private var sessionStatusMessage:[\s\S]*?fallbackReason[\s\S]*?authorizationRequired[\s\S]*?return nil/.test(files.sidebar)
      && !/private var sessionStatusMessage:[\s\S]*?UIStrings\.loading[\s\S]*?return nil/.test(files.sidebar)
      && /@Published var localSessionScopeFilter:[\s\S]*?guard oldValue != localSessionScopeFilter else \{ return \}[\s\S]*?normalizeSelectedLocalSession\(\)/.test(files.store)
      && /func previewLocalSessions\([\s\S]*?service\.previewLocalSessions\([\s\S]*?scope:\s*\.all/.test(files.store)
      && !/private func localSessionPreviewRequestKey[\s\S]*?localSessionScopeFilter\.rawValue/.test(files.store)
      && /func refreshSelectedAgentLocalSessionsIfNeeded\(\) async[\s\S]*?force:\s*false/.test(files.store)
      && /\.task\(id:\s*store\.selectedAgentLocalSessionRefreshKey\)[\s\S]*?refreshSelectedAgentLocalSessionsIfNeeded\(\)/.test(files.content)
      && /func selectLocalSession\(_ session:[\s\S]*?guard selectedLocalSessionID != session\.id \|\| selectedSidebarSelection != \.session\(session\.id\)[\s\S]*?setSidebarSelection\(\.session\(session\.id\)\)/.test(files.store)
      && !/sessionTimeRangeSummary/.test(files.sidebar),
  },
  {
    label: "session empty states explain filtered counts without secondary-sidebar wording",
    text: files.sidebar + "\n" + files.uiStrings + "\n" + files.localizable,
    passed: /else if filteredRows\.isEmpty[\s\S]*?SidebarEmptyMessage\(message:\s*UIStrings\.localSessionNoMatchesMessage\(totalCount:\s*preview\.sessionRows\.count\)\)/.test(files.sidebar)
      && /static func localSessionNoMatchesMessage\(totalCount:\s*Int\)[\s\S]*?sidebar\.sessions\.noMatchesWithCount/.test(files.uiStrings)
      && /"sidebar\.sessions\.noMatchesWithCount"\s*=/.test(files.localizable)
      && !/empty\.noSessionSelected\.message" = ".*secondary sidebar/.test(files.localizable),
  },
  {
    label: "skill sidebar exposes filter scope sort and direction controls",
    text: files.sidebar,
    pattern: /private struct SkillSidebarPanel:[\s\S]*?skillToolbar\(visibleSkills:\s*visibleSkills\)[\s\S]*?private var filterControls:[\s\S]*?selection:\s*\$store\.stateFilter[\s\S]*?SkillStateFilter\.sidebarCases[\s\S]*?selection:\s*\$store\.skillScopeFilter[\s\S]*?selection:\s*\$store\.sortOrder[\s\S]*?store\.sortDirection = store\.sortDirection == \.ascending \? \.descending : \.ascending/,
  },
  {
    label: "skill sidebar filter controls use compact adaptive sizing",
    text: files.sidebar + "\n" + files.uiOptimization,
    passed: /struct SkillListPresentation:[\s\S]*?let filterControlWidth = 72[\s\S]*?let filterControlHeight = 28[\s\S]*?let filterControlSpacing = 4[\s\S]*?let filterToolbarVerticalPadding = 4[\s\S]*?let sortDirectionButtonWidth = 28/.test(files.uiOptimization)
      && /private var filterControls:[\s\S]*?let layout = UIOptimizationPresentation\.skillList[\s\S]*?HStack\(alignment:\s*\.center,\s*spacing:\s*CGFloat\(layout\.filterControlSpacing\)\)[\s\S]*?SkillFilterMenuPicker\([\s\S]*?selection:\s*\$store\.stateFilter[\s\S]*?options:\s*SkillStateFilter\.sidebarCases[\s\S]*?width:\s*CGFloat\(layout\.filterControlWidth\)[\s\S]*?height:\s*CGFloat\(layout\.filterControlHeight\)[\s\S]*?SkillFilterMenuPicker\([\s\S]*?selection:\s*\$store\.skillScopeFilter[\s\S]*?options:\s*SkillScopeFilter\.allCases[\s\S]*?width:\s*CGFloat\(layout\.filterControlWidth\)[\s\S]*?height:\s*CGFloat\(layout\.filterControlHeight\)[\s\S]*?SkillFilterMenuPicker\([\s\S]*?selection:\s*\$store\.sortOrder[\s\S]*?options:\s*SkillSortOrder\.allCases[\s\S]*?width:\s*CGFloat\(layout\.filterControlWidth\)[\s\S]*?height:\s*CGFloat\(layout\.filterControlHeight\)[\s\S]*?sortDirectionButton\(width:\s*CGFloat\(layout\.sortDirectionButtonWidth\),\s*height:\s*CGFloat\(layout\.filterControlHeight\)\)[\s\S]*?\.padding\(\.vertical,\s*CGFloat\(layout\.filterToolbarVerticalPadding\)\)/.test(files.sidebar)
      && /private struct SkillFilterMenuPicker<Option:[\s\S]*?var expands = true[\s\S]*?SidebarMenuButtonLabel\([\s\S]*?title:\s*title,[\s\S]*?value:\s*optionTitle\(selection\),[\s\S]*?expands:\s*expands/.test(files.sidebar)
      && /private struct SidebarMenuButtonLabel:[\s\S]*?\.frame\(minWidth:\s*width,\s*maxWidth:\s*expands \? \.infinity : nil,\s*minHeight:\s*height,\s*maxHeight:\s*height[\s\S]*?\.fixedSize\(horizontal:\s*!expands,\s*vertical:\s*false\)[\s\S]*?in:\s*Capsule\(\)/.test(files.sidebar)
      && /private struct SkillFilterMenuPicker<Option:[\s\S]*?Menu\s*\{[\s\S]*?ForEach\(options\)[\s\S]*?Button \{[\s\S]*?selection = option[\s\S]*?\.menuStyle\(\.button\)[\s\S]*?\.buttonStyle\(\.plain\)/.test(files.sidebar)
      && !/private struct SkillFilterMenuPicker<Option:[\s\S]*?\.popover\(isPresented:/.test(files.sidebar),
  },
  {
    label: "skill rows expose issue badges and navigation affordance",
    text: files.sidebar + "\n" + files.storeList,
    passed: /SkillRow\([\s\S]*?skill:\s*skill,[\s\S]*?issueCount:\s*issueIndicatorCount\(for:\s*skill\),[\s\S]*?isSelected:\s*store\.selectedSidebarSelection == \.skill\(skill\.id\)/.test(files.sidebar)
      && /private func issueIndicatorCount\(for skill:\s*SkillRecord\)[\s\S]*?SkillListModel\.issueIndicatorCount\([\s\S]*?skills:\s*store\.skills,[\s\S]*?findings:\s*store\.findings,[\s\S]*?conflicts:\s*store\.conflicts/.test(files.sidebar)
      && /static func issueIndicatorCount\([\s\S]*?displayFindings\(skills:\s*skills,\s*findings:\s*findings\)[\s\S]*?\.filter \{ \$0\.instanceId == skill\.id \}[\s\S]*?sameAgentConflictGroups[\s\S]*?statusIssueCount/.test(files.storeList)
      && /private struct SkillRow:[\s\S]*?let issueCount:\s*Int[\s\S]*?let isSelected:\s*Bool[\s\S]*?if issueCount > 0[\s\S]*?exclamationmark\.triangle\.fill[\s\S]*?chevron\.right[\s\S]*?\.listPageCardBackground\(isSelected:\s*isSelected\)[\s\S]*?accessibilityAddTraits\(isSelected \? \.isSelected : \[\]\)/.test(files.sidebar)
      && !/private struct SkillRow:[\s\S]*?foregroundStyle\(isSelected \? (?:Color\.)?\.?white/.test(files.sidebar),
  },
  {
    label: "config sidebar exposes scope filtering, clean operation support, disabled skills, and selectable config history",
    text: files.sidebar + "\n" + files.agentConfigWorkspace,
    passed: /var visibleConfigDocuments:[\s\S]*?currentAgentConfigDocuments[\s\S]*?document\.agent == agentFilter\.rawValue[\s\S]*?configScopeFilter\.includes\(document\)[\s\S]*?configDocumentMatchesSidebarQuery\(document\)[\s\S]*?lhs\.scope\.lowercased\(\)\.contains\("project"\)[\s\S]*?localizedStandardCompare/.test(files.store)
      && /private struct ConfigSidebarPanel:[\s\S]*?private var selectedConfigDocuments:[\s\S]*?store\.visibleConfigDocuments[\s\S]*?Section\s*{[\s\S]*?configToolbar[\s\S]*?Section\(UIStrings\.currentConfigFile\)[\s\S]*?ForEach\(selectedConfigDocuments,\s*id:\s*\\\.target\)[\s\S]*?ConfigCurrentDocumentSidebarRow\([\s\S]*?document:\s*document[\s\S]*?isSelected:\s*store\.selectedSidebarSelection == \.configDocument\(document\.target\)[\s\S]*?store\.selectConfigDocument\(document\)[\s\S]*?Supported operations[\s\S]*?ConfigOperationRow\(title:\s*UIStrings\.scan[\s\S]*?ConfigOperationRow\(title:\s*UIStrings\.writableConfig[\s\S]*?UIStrings\.agentConfigSkillEnablement[\s\S]*?ConfigDisabledSkillSummaryRow\(skills:\s*disabledSkills\)[\s\S]*?ForEach\(selectedSnapshots\)[\s\S]*?ConfigSnapshotSidebarRow\([\s\S]*?store\.selectedSidebarSelection == \.configSnapshot\(snapshot\.id\)[\s\S]*?store\.selectConfigSnapshot\(snapshot\)/.test(files.sidebar)
      && /private var configToolbar:[\s\S]*?let layout = UIOptimizationPresentation\.skillList[\s\S]*?VStack\(alignment:\s*\.leading,\s*spacing:\s*8\)[\s\S]*?HStack\(alignment:\s*\.center,\s*spacing:\s*CGFloat\(layout\.filterControlSpacing\)\)[\s\S]*?configScopePicker[\s\S]*?configRefreshButton\([\s\S]*?width:\s*CGFloat\(layout\.sortDirectionButtonWidth\),[\s\S]*?height:\s*CGFloat\(layout\.filterControlHeight\)[\s\S]*?configSearchField/.test(files.sidebar)
      && !/private var configToolbar:[\s\S]*?ViewThatFits\(in:\s*\.horizontal\)[\s\S]*?private var configScopePicker/.test(files.sidebar)
      && !/private var configToolbar:[\s\S]*?Spacer\(minLength:[\s\S]*?private var configScopePicker/.test(files.sidebar)
      && /private var configScopePicker:[\s\S]*?SkillFilterMenuPicker\([\s\S]*?title:\s*UIStrings\.scope[\s\S]*?selection:\s*\$store\.configScopeFilter[\s\S]*?options:\s*AgentConfigScopeFilter\.allCases[\s\S]*?expands:\s*false/.test(files.sidebar)
      && /private var configSearchField:[\s\S]*?SidebarSearchField\([\s\S]*?sidebar\.config\.search[\s\S]*?\$store\.configSidebarSearchText/.test(files.sidebar)
      && /private func configRefreshButton\(width:\s*CGFloat,\s*height:\s*CGFloat\)[\s\S]*?await store\.refreshSelectedAgentConfigData\(\)[\s\S]*?Image\(systemName:\s*"arrow\.clockwise"\)[\s\S]*?\.frame\(width:\s*width,\s*height:\s*height\)[\s\S]*?\.buttonStyle\(\.plain\)/.test(files.sidebar)
      && /@Published var configSidebarSearchText/.test(files.store)
      && /private var disabledSkills:[\s\S]*?AgentConfigDisplay\.disabledSkills\(for:\s*store\.agentFilter,\s*store:\s*store\)/.test(files.sidebar)
      && /private struct ConfigDisabledSkillSummaryRow:[\s\S]*?UIStrings\.agentConfigDisabledSkillsCount\(skills\.count\)[\s\S]*?UIStrings\.agentConfigDisabledSkillsEmpty/.test(files.sidebar)
      && /private struct ConfigCurrentDocumentSidebarRow:[\s\S]*?let isSelected:\s*Bool[\s\S]*?DisplayText\.scope\(document\.scope\)[\s\S]*?AgentConfigDisplay\.pathSummary\(document\.target\)[\s\S]*?document\.exists \? UIStrings\.existingFile : UIStrings\.willCreateFile[\s\S]*?optimizedSidebarSelection\(isSelected:\s*isSelected\)/.test(files.sidebar)
      && /private struct ConfigSnapshotSidebarRow:[\s\S]*?item\.timeText[\s\S]*?item\.scopeText[\s\S]*?item\.capturedText[\s\S]*?item\.targetSummary/.test(files.sidebar)
      && /\.task\(id:\s*store\.selectedAgentConfigRefreshKey\)[\s\S]*?await store\.loadSelectedAgentConfigDataIfNeeded\(\)/.test(files.sidebar)
      && /func loadSelectedAgentConfigDataIfNeeded\(\) async[\s\S]*?loadAgentConfigSnapshotsIfNeeded[\s\S]*?loadCurrentAgentConfigDocumentsIfNeeded/.test(files.store)
      && /func loadCurrentAgentConfigDocumentsIfNeeded\(agent requestedAgent:[\s\S]*?force:\s*false/.test(files.store)
      && !/\.onChange\(of:\s*store\.configScopeFilter\)[\s\S]*?loadAgentConfigSnapshots|\.onChange\(of:\s*store\.configScopeFilter\)[\s\S]*?loadCurrentAgentConfigDocuments/.test(files.sidebar)
      && /case configDocument\(String\)[\s\S]*?case \.configOverview,\s*\.configDocument,\s*\.configSnapshot/.test(files.sidebarSelection)
      && /var selectedConfigDocument:[\s\S]*?case let \.configDocument\(target\)[\s\S]*?currentAgentConfigDocuments\.first[\s\S]*?func selectConfigDocument\(_ document:[\s\S]*?guard selectedSidebarSelection != \.configDocument\(document\.target\)[\s\S]*?selectedSidebarSelection = \.configDocument\(document\.target\)/.test(files.storeSurface)
      && /AgentConfigOverviewDetailPanel\(selectedDocument:\s*store\.selectedConfigDocument\)[\s\S]*?let selectedDocument:[\s\S]*?if let selectedDocument[\s\S]*?currentAgentConfigSection\(documents:\s*\[selectedDocument\]\)/.test(files.agentConfigWorkspace)
      && !/AgentConfigCapabilityCard|AgentConfigDisabledSkillsPanel/.test(files.agentConfigWorkspace)
      && !/Text\(capability\?\.status/.test(files.sidebar + "\n" + files.agentConfigWorkspace),
  },
  {
    label: "current config detail uses the unified single-card editor layout",
    text: files.agentConfigWorkspace + "\n" + files.uiOptimization,
    passed: /static let configEditor = ConfigEditorPresentation\(\)/.test(files.uiOptimization)
      && /struct ConfigEditorPresentation:[\s\S]*?usesSingleCodeCard = true[\s\S]*?showsLineNumbers = true[\s\S]*?usesCompactToolbarActions = true[\s\S]*?primarySaveButtonVisible = false[\s\S]*?autosaveEnabled = true/.test(files.uiOptimization)
      && /private struct ConfigCodeCard<[\s\S]*?PrivacyPathText\(path:\s*path[\s\S]*?toolbar\(\)[\s\S]*?content\(\)[\s\S]*?\.adaptiveMaterialSurface\(\)/.test(files.agentConfigWorkspace)
      && /private struct ConfigCodeToolbar:[\s\S]*?UIStrings\.reload[\s\S]*?UIStrings\.formatJSON[\s\S]*?isSensitiveVisible \? "eye\.slash" : "eye"[\s\S]*?onReveal/.test(files.agentConfigWorkspace)
      && /private struct AgentCurrentConfigDocumentsSection:[\s\S]*?ConfigCodeCard\([\s\S]*?title:\s*UIStrings\.currentConfigFile[\s\S]*?path:\s*primaryDocument\?\.target[\s\S]*?statusText:\s*primaryDocument\?\.exists == true \? UIStrings\.existingFile : UIStrings\.willCreateFile[\s\S]*?ConfigCodeToolbar\([\s\S]*?onReload:\s*reload[\s\S]*?JSONSyntaxHighlightedText\(content:\s*displayedContent\)/.test(files.agentConfigWorkspace)
      && !/Label\(UIStrings\.save,\s*systemImage:\s*"square\.and\.arrow\.down"\)/.test(files.agentConfigWorkspace)
      && !/Read-only agent config previews intentionally keep the save slot disabled/.test(files.agentConfigWorkspace)
      && !/AgentCurrentConfigDocumentPane/.test(files.agentConfigWorkspace)
      && !/UIStrings\.agentConfigReadOnlyPreview/.test(files.agentConfigWorkspace)
      && !/UIStrings\.agentConfigReadOnlyBoundary/.test(files.agentConfigWorkspace),
  },
  {
    label: "config raw editing is confirmation-gated and read-only previews use syntax highlighting",
    text: files.agentConfigWorkspace + "\n" + files.uiStrings + "\n" + files.localizable + "\n" + files.localizableZh,
    passed: /@State private var isConfirmingConfigEdit = false/.test(files.agentConfigWorkspace)
      && /@State private var configAutosaveTask: Task<Void,\s*Never>\?/.test(files.agentConfigWorkspace)
      && /private func toggleSensitiveEditing\(\)[\s\S]*?if revealsSensitiveConfig \{[\s\S]*?configAutosaveTask\?\.cancel\(\)[\s\S]*?revealsSensitiveConfig = false[\s\S]*?\} else \{[\s\S]*?isConfirmingConfigEdit = true[\s\S]*?\}/.test(files.agentConfigWorkspace)
      && /\.confirmationDialog\(\s*UIStrings\.agentConfigEditConfirmationTitle,[\s\S]*?isPresented:\s*\$isConfirmingConfigEdit[\s\S]*?Button\(UIStrings\.agentConfigShowSensitive,\s*role:\s*\.destructive\)[\s\S]*?revealsSensitiveConfig = true[\s\S]*?Text\(UIStrings\.agentConfigEditConfirmationMessage\)/.test(files.agentConfigWorkspace)
      && /if revealsSensitiveConfig \{[\s\S]*?JSONLineNumberedEditor\(text:\s*displayedDraft\)[\s\S]*?\} else \{[\s\S]*?JSONSyntaxHighlightedText\(content:\s*displayedDraft\.wrappedValue\)/.test(files.agentConfigWorkspace)
      && /private func handleConfigDraftChange\(\)[\s\S]*?configAutosaveTask\?\.cancel\(\)[\s\S]*?Task\.sleep\(nanoseconds:\s*UIOptimizationPresentation\.configEditor\.autosaveDelayNanoseconds\)[\s\S]*?await store\.saveClaudeSettings\(content:\s*draftSnapshot\)[\s\S]*?await store\.loadAgentConfigSnapshots/.test(files.agentConfigWorkspace)
      && /private struct JSONSyntaxHighlightedText:[\s\S]*?ForEach\(Array\(Self\.lines\(in:\s*content\)\.enumerated\(\)\)[\s\S]*?Text\(Self\.highlighted[\s\S]*?NSRegularExpression[\s\S]*?AttributedString/.test(files.agentConfigWorkspace)
      && /private struct JSONLineNumberedEditor:[\s\S]*?ConfigLineNumberColumn\(lineCount:\s*lineCount\)[\s\S]*?TextEditor\(text:\s*\$text\)/.test(files.agentConfigWorkspace)
      && /static var agentConfigEditConfirmationTitle/.test(files.uiStrings)
      && /static var agentConfigEditConfirmationMessage/.test(files.uiStrings)
      && /static var configAutosavePending/.test(files.uiStrings)
      && /static var formatJSON/.test(files.uiStrings)
      && /"settings\.agentConfig\.editConfirmation\.title"/.test(files.localizable)
      && /"settings\.agentConfig\.editConfirmation\.message"/.test(files.localizableZh)
      && /"settings\.agentConfig\.autosavePending"/.test(files.localizable)
      && /"action\.formatJSON"/.test(files.localizableZh),
  },
  {
    label: "detail sections use expanded tag selector",
    text: files.detailSurface,
    pattern: /struct DetailSectionSwitcher:[\s\S]*?ScrollView\(\.horizontal,\s*showsIndicators:\s*false\)[\s\S]*?ForEach\(DetailSection\.visibleCases\)[\s\S]*?DetailSectionTagButton\([\s\S]*?isSelected:\s*selection == item[\s\S]*?selection = item[\s\S]*?private struct DetailSectionTagButton:[\s\S]*?\.background\(background,\s*in:\s*Capsule\(\)\)[\s\S]*?\.accessibilityAddTraits\(isSelected \? \.isSelected : \[\]\)/,
  },
  {
    label: "detail navigation has a stable scroll-to-top anchor",
    text: files.detailSurface,
    pattern: /private static let topAnchorID = "skills-copilot\.detail\.top"[\s\S]*?ScrollViewReader\s*{\s*proxy\s+in[\s\S]*?\.id\(Self\.topAnchorID\)/,
  },
  {
    label: "detail navigation scrolls to top when the selected section changes",
    text: files.detailSurface,
    pattern: /\.onChange\(of:\s*store\.selectedDetailSection\)[\s\S]*?proxy\.scrollTo\(Self\.topAnchorID,\s*anchor:\s*\.top\)/,
  },
  {
    label: "detail sections expose issues and conflicts while omitting retired work surfaces",
    text: files.detailSurface,
    pattern: /static var visibleCases:[\s\S]*?\[\.overview,\s*\.findings,\s*\.conflicts,\s*\.history,\s*\.analysis,\s*\.metadata\][\s\S]*?static var primaryWorkCases:[\s\S]*?\[\][\s\S]*?case \.conflicts:[\s\S]*?UIStrings\.conflicts[\s\S]*?UIStrings\.providerObservabilityTitle/,
  },
  {
    label: "detail router separates session, config, and skill details while report/preflight are modal tools",
    text: files.detailSurface,
    passed: /if store\.selectedSidebarSelection\?\.isSession == true[\s\S]*?AgentSessionDetailPanel\(\)[\s\S]*?else if store\.selectedSidebarSelection\?\.isConfig == true[\s\S]*?AgentConfigDetailPanel\(\)[\s\S]*?else if store\.selectedDetailSection == \.guidedCleanup[\s\S]*?else if store\.selectedSidebarSelection\?\.isSkill == true,\s*let skill[\s\S]*?EmptyDetailView\([\s\S]*?title:\s*emptyDetailTitle[\s\S]*?message:\s*emptyDetailMessage/.test(files.detailSurface)
      && !/isReport/.test(files.detailSurface)
      && !/isPreflight/.test(files.detailSurface)
      && !/LocalReportExportPanel\(includeSelectedSkill:\s*false\)/.test(files.detailSurface),
  },
  {
    label: "definition hashes stay in metadata instead of overview/header grids",
    text: files.detailOverview + "\n" + files.detailHeaderOverview,
    passed: /private var diagnosticRows:[\s\S]*?CompactMetadataRow\(label:\s*UIStrings\.agent[\s\S]*?CompactMetadataRow\(label:\s*UIStrings\.scope[\s\S]*?CompactMetadataRow\(label:\s*UIStrings\.provenanceKind[\s\S]*?CompactMetadataRow\([\s\S]*?label:\s*UIStrings\.source/.test(files.detailOverview)
      && !/private var diagnosticRows:[\s\S]*?UIStrings\.definition[\s\S]*?\n\s*\]\n\s*\}/.test(files.detailOverview)
      && !/private var headerMetadataRows:[\s\S]*?UIStrings\.definition[\s\S]*?\n\s*\]\n\s*\}/.test(files.detailHeaderOverview)
      && /MetadataRow\(label:\s*UIStrings\.definition,\s*value:\s*skill\.definitionId\)/.test(files.detailHeaderOverview),
  },
  {
    label: "high-priority accessibility and localized summary fixes are present",
    text: files.detailPrimitives + "\n" + files.agentConfigWorkspace + "\n" + files.skillManager + "\n" + files.sidebar + "\n" + files.agentCopilotOverview + "\n" + files.uiStrings,
    passed: /struct SummaryChip:[\s\S]*?\.accessibilityElement\(children:\s*\.combine\)[\s\S]*?\.accessibilityLabel\(title\)[\s\S]*?\.accessibilityValue\(value\)/.test(files.detailPrimitives)
      && /private struct AgentConfigAgentIcon:[\s\S]*?\.accessibilityLabel\(filter\.title\)/.test(files.agentConfigWorkspace)
      && /private struct SearchResultRow:[\s\S]*?\.accessibilityElement\(children:\s*\.combine\)[\s\S]*?\.accessibilityLabel\(result\.name\)/.test(files.skillManager)
      && /private struct InstalledSkillRow:[\s\S]*?\.accessibilityElement\(children:\s*\.combine\)[\s\S]*?\.accessibilityLabel\(record\.name\)/.test(files.skillManager)
      && /private struct LocalSkillLibraryRow:[\s\S]*?\.accessibilityElement\(children:\s*\.combine\)[\s\S]*?\.accessibilityLabel\(skill\.name\)/.test(files.skillManager)
      && /private var projectMenu:[\s\S]*?\.accessibilityLabel\(UIStrings\.text\("project\.chooseMenu"/.test(files.sidebar)
      && /static func mcpServerArgEnvSummary\(args:\s*Int,\s*envKeys:\s*Int\)[\s\S]*?mcpServerPreview\.counts/.test(files.uiStrings)
      && /UIStrings\.mcpServerArgEnvSummary\(args:\s*row\.argsCount,\s*envKeys:\s*row\.envKeyCount\)/.test(files.agentCopilotOverview),
  },
  {
    label: "UIStrings falls back through native localization before defaults",
    text: files.uiStrings,
    pattern: /static func text\(_ key:\s*String,\s*_ defaultValue:\s*String\) -> String[\s\S]*?if let value = localizedStrings\(\)\[key\][\s\S]*?Bundle\.main\.localizedString\(forKey:\s*key,\s*value:\s*nil,\s*table:\s*nil\)[\s\S]*?nativeValue != key[\s\S]*?return defaultValue/,
  },
  {
    label: "local session preview is auto-discovered and privacy-rendered",
    text: files.detailAgentSession + "\n" + files.storeSurface + "\n" + files.serviceProtocol,
    pattern: /LocalSessionPreviewPanel\([\s\S]*?Auto discovery[\s\S]*?result\.skillUsageRows[\s\S]*?PrivacyEvidenceText\(value:\s*row\.redactedPath[\s\S]*?PrivacyEvidenceText\(value:\s*row\.excerpt[\s\S]*?func previewLocalSessions\(\)\s*async[\s\S]*?service\.previewLocalSessions[\s\S]*?session\.previewLocalSessions/,
  },
  {
    label: "MCP server preview component remains default-off, explicitly authorized, and privacy-rendered",
    text: files.agentCopilotOverview + "\n" + files.storeSurface + "\n" + files.serviceClientEvidence + "\n" + files.mcpServerPreview + "\n" + files.serviceProtocol,
    pattern: /McpServerPreviewPanel[\s\S]*?Preview is default-off[\s\S]*?TextField\(UIStrings\.text\("mcpServerPreview\.placeholder"[\s\S]*?PrivacyEvidenceText\(value:\s*row\.sourcePath[\s\S]*?PrivacyEvidenceText\(value:\s*command[\s\S]*?func previewMcpServers\(\)\s*async[\s\S]*?service\.previewMcpServers[\s\S]*?evidence\.previewMcpServers/,
  },
  {
    label: "agent summary metrics are folded into primary sidebar cards",
    text: files.sidebar,
    passed: /private var sessionCardMetrics:[\s\S]*?scopedLocalSessionUserMessageCount[\s\S]*?scopedLocalSessionTotalMessageCount[\s\S]*?scopedLocalSessionToolCallCount[\s\S]*?scopedLocalSessionSkillCallCount[\s\S]*?private var skillCardMetrics:[\s\S]*?agentEnabledCount[\s\S]*?agentCopilot\.metric\.disabled[\s\S]*?agentDisabledCount[\s\S]*?agentFindingCount[\s\S]*?agentConflictCount[\s\S]*?private var configCardMetrics:[\s\S]*?sidebar\.config\.filesShort[\s\S]*?configDocumentCount[\s\S]*?sidebar\.config\.projectShort[\s\S]*?projectConfigDocumentCount[\s\S]*?sidebar\.config\.historyShort[\s\S]*?configHistoryCount[\s\S]*?private struct SidebarNavigationCardButton:[\s\S]*?if !metrics\.isEmpty[\s\S]*?HStack\(spacing:\s*5\)[\s\S]*?private struct SidebarNavigationMetricPill:/.test(files.sidebar)
      && !/configSupportMetric/.test(files.sidebar)
      && !/private var configCardMetrics:[\s\S]*?sidebar\.config\.disabledShort/.test(files.sidebar)
      && !/configCapability\?\.scan|configCapability\?\.configToggle|configCapability\?\.configSnapshot|configCapability\?\.writable/.test(files.sidebar),
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
    label: "analysis section mounts focused smart-analysis panels",
    text: files.detailSurface,
    pattern: /SkillQualityScorePanel\([\s\S]*?TaskRoutingAssessmentPanel\([\s\S]*?struct SkillQualityScorePanel/,
  },
  {
    label: "LLM Markdown output renders wide tables as readable cards",
    text: `${files.markdownTableDisplay}\n${files.detailLLM}`,
    pattern: /struct MarkdownTableDisplayModel[\s\S]*?var usesCardLayout:[\s\S]*?columnCount > 3 \|\| \(columnCount > 2 && containsLongBodyCell\)[\s\S]*?struct MarkdownTableView:[\s\S]*?if model\.usesCardLayout[\s\S]*?MarkdownTableCardList\(model:\s*model\)[\s\S]*?struct MarkdownTableCard:/,
  },
  {
    label: "LLM Markdown output normalizes collapsed provider markdown tables",
    text: files.markdownRender,
    pattern: /normalizeMarkdownBlocks\(in text:[\s\S]*?normalizeInlineMarkdownBreaks\(in: line\)[\s\S]*?normalizeInlineTableRows\(in text:[\s\S]*?\| \|[\s\S]*?isStandaloneTableLine/,
  },
  {
    label: "LLM Markdown compact previews collapse tables into summary rows",
    text: `${files.detailLLM}\n${files.localizable}`,
    pattern: /case let \.table\(rows\):[\s\S]*?if maxBlocks == nil[\s\S]*?MarkdownTableView\(rows:\s*rows[\s\S]*?else[\s\S]*?MarkdownTableSummaryView\(rows:\s*rows\)[\s\S]*?llm\.markdown\.table\.previewSummary/,
  },
  {
    label: "LLM Markdown output unwraps whole-response markdown fences",
    text: files.markdownRender,
    pattern: /static func renderableText\(from text: String\)[\s\S]*?hasPrefix\("```"\)[\s\S]*?\["markdown", "md", "gfm"\]\.contains\(language\)[\s\S]*?return body/,
  },
  {
    label: "LLM Markdown compact previews wrap code blocks instead of horizontal overflow",
    text: files.detailLLM,
    pattern: /MarkdownCodeBlockView\([\s\S]*?wrapsLines:\s*maxBlocks != nil[\s\S]*?struct MarkdownCodeBlockView:[\s\S]*?if wrapsLines[\s\S]*?\.fixedSize\(horizontal:\s*false,\s*vertical:\s*true\)/,
  },
  {
    label: "LLM prompt instructions forbid model tables and whole-answer code fences",
    text: `${files.serviceRust}\n${files.serviceLLMPromptHelpers}`,
    pattern: /Do not use Markdown tables[\s\S]*?Do not wrap the answer in fenced code blocks[\s\S]*?Required quality-score response shape/,
  },
  {
    label: "task cockpit panel lives in a dedicated module file",
    text: files.taskCockpit,
    pattern: /struct TaskCockpitPanel:[\s\S]*?TaskCockpitResultView[\s\S]*?TaskCockpitSafetyList/,
  },
  {
    label: "task cockpit keeps progressive staged feedback inside technical diagnostics",
    text: files.taskCockpit,
    pattern: /struct TaskCockpitStageProgressView:[\s\S]*?TaskCockpitProgressSnapshot\([\s\S]*?ForEach\(snapshot\.stageRows\)[\s\S]*?TaskCockpitStageTile\(row:[\s\S]*?accessibilityIdentifier\(AppAccessibilityID\.taskCockpitStageProgress\)[\s\S]*?struct TaskCockpitTechnicalDiagnosticsView:[\s\S]*?TaskCockpitStageProgressView\(/,
  },
  {
    label: "task cockpit task input uses an AX-settable multiline TextField",
    text: files.taskInput,
    pattern: /struct TaskInputTextEditor:[\s\S]*?TextField\(placeholder,\s*text:\s*\$text,\s*axis:\s*\.vertical\)[\s\S]*?\.lineLimit\(3\.\.\.5\)[\s\S]*?\.frame\([\s\S]*?minHeight:\s*Self\.minHeight[\s\S]*?maxHeight:\s*Self\.maxHeight[\s\S]*?\.accessibilityIdentifier\(AppAccessibilityID\.taskCockpitInput\)/,
  },
  {
    label: "task cockpit input model preserves raw text and trims only for submit state",
    text: files.taskInputModel,
    pattern: /struct TaskInputModel:[\s\S]*?let rawText:[\s\S]*?rawText\.trimmingCharacters\(in:\s*\.whitespacesAndNewlines\)[\s\S]*?var canSubmit:[\s\S]*?!trimmedText\.isEmpty/,
  },
  {
    label: "task cockpit build button remains explicit and input-gated",
    text: files.taskCockpit,
    pattern: /Button\s*{[\s\S]*?onBuild\(\)[\s\S]*?\.disabled\(isBuilding \|\| !inputModel\.canSubmit \|\| selectedAgentIDs\.isEmpty \|\| providerGateMessage != nil\)/,
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
    label: "primary sidebar header keeps the agent selector inline and compact",
    passed: /Section\s*{[\s\S]*?AgentWorkspaceHeader\(\)[\s\S]*?Section\s*{[\s\S]*?ProjectContextControls\(\)/.test(files.sidebar)
      && /private struct AgentWorkspaceHeader:[\s\S]*?AgentSelectorMenu\(\)[\s\S]*?\.layoutPriority\(1\)[\s\S]*?\.padding\(\.vertical,\s*10\)[\s\S]*?\.frame\(maxWidth:\s*\.infinity,\s*alignment:\s*\.leading\)/.test(files.sidebar)
      && !/private struct AgentWorkspaceHeader:[\s\S]*?AgentIconBadge\(filter:\s*store\.agentFilter/.test(files.sidebar)
      && /private struct AgentSelectorMenu:[\s\S]*?Menu\s*\{[\s\S]*?ForEach\(SkillAgentFilter\.managementCases\)[\s\S]*?store\.agentFilter = filter[\s\S]*?SidebarMenuButtonLabel\([\s\S]*?value:\s*shortTitle\(for:\s*store\.agentFilter\),[\s\S]*?agentFilter:\s*store\.agentFilter,[\s\S]*?width:\s*118,[\s\S]*?height:\s*34,[\s\S]*?expands:\s*false[\s\S]*?\.menuStyle\(\.button\)[\s\S]*?\.buttonStyle\(\.plain\)[\s\S]*?\.accessibilityValue\(store\.agentFilter\.title\)/.test(files.sidebar)
      && /private struct SidebarMenuButtonLabel:[\s\S]*?var agentFilter:\s*SkillAgentFilter\?[\s\S]*?if let agentFilter[\s\S]*?AgentIconBadge\(filter:\s*agentFilter,\s*size:\s*26\)[\s\S]*?else if let systemImage/.test(files.sidebar)
      && /private struct AgentIconBadge:[\s\S]*?var size:\s*CGFloat = 28[\s\S]*?frame\(width:\s*imageSize,\s*height:\s*imageSize\)[\s\S]*?frame\(width:\s*size,\s*height:\s*size\)/.test(files.sidebar)
      && !/private struct AgentWorkspaceHeader:[\s\S]*?Text\(store\.agentFilter\.title\)[\s\S]*?AgentSelectorMenu/.test(files.sidebar)
      && !/store\.selectedSidebarSelection\s*=\s*\.agentWorkspace/.test(files.sidebar)
      && !/\.tag\(SidebarSelection\.agentWorkspace\)/.test(files.sidebar),
  },
  {
    label: "project title row owns merged project selection and actions",
    text: files.sidebar,
    pattern: /private struct ProjectContextControls:[\s\S]*?HStack\(alignment:\s*\.center,\s*spacing:\s*8\)[\s\S]*?Text\(store\.activeProjectContext\?\.name \?\? UIStrings\.text\("project\.globalRoots"[\s\S]*?PrivacyPathText\(path:\s*rootPath,[\s\S]*?showsRevealControl:\s*false\)[\s\S]*?projectMenu[\s\S]*?private var projectMenu: some View[\s\S]*?Label\(UIStrings\.chooseProject,\s*systemImage:\s*"folder\.badge\.plus"\)[\s\S]*?Section\(UIStrings\.recentProjects\)[\s\S]*?await store\.setProject\([\s\S]*?Label\(UIStrings\.revealInFinder,[\s\S]*?arrow\.up\.forward\.app[\s\S]*?Label\(UIStrings\.clearProject,[\s\S]*?xmark\.circle[\s\S]*?SidebarMenuButtonLabel\([\s\S]*?systemImage:\s*"folder\.badge\.plus"[\s\S]*?width:\s*66,[\s\S]*?height:\s*34,[\s\S]*?expands:\s*false[\s\S]*?\.menuStyle\(\.button\)[\s\S]*?\.buttonStyle\(\.plain\)/,
  },
  {
    label: "skill-list batch action lives in the compact toolbar",
    text: files.sidebar,
    passed: /private func skillToolbar\(visibleSkills:[\s\S]*?searchField[\s\S]*?batchToolbarButton\(visibleSkills:\s*visibleSkills\)/.test(files.sidebar)
      && /private func batchToolbarButton\(visibleSkills:[\s\S]*?resetBatchToggleSelectionToVisibleSkills\(\)[\s\S]*?isBatchOperationPresented = true[\s\S]*?Image\(systemName:\s*"checklist\.checked"\)/.test(files.sidebar)
      && /private struct SkillListSectionHeader:[\s\S]*?Text\(UIStrings\.batchToggleSelectedCount\(visibleCount\)\)/.test(files.sidebar)
      && !/private struct SkillListSectionHeader:[\s\S]*?Button\(action:\s*action\)/.test(files.sidebar),
  },
  {
    label: "findings expose only the rule filter in the control panel",
    passed: /Picker\(UIStrings\.findingRuleFilter,\s*selection:\s*\$ruleFilter\)/.test(files.detailSurface)
      && /rulePicker\.frame\(width:\s*250\)/.test(files.detailSurface)
      && !/Picker\(UIStrings\.findingSeverityFilter,\s*selection:\s*\$severityFilter\)/.test(files.detailSurface)
      && !/FindingsSummaryOverview/.test(files.detailSurface)
      && !/FindingsSummaryStrip/.test(files.detailSurface),
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
    passed: /UIOptimizationPresentation\.settings\.minimumWidth/.test(files.settings)
      && /UIOptimizationPresentation\.settings\.idealWidth/.test(files.settings)
      && /UIOptimizationPresentation\.settings\.minimumHeight/.test(files.settings)
      && /UIOptimizationPresentation\.settings\.idealHeight/.test(files.settings)
      && /UIOptimizationPresentation\.settings\.sidebarWidth/.test(files.settings)
      && /minimumWidth = 760[\s\S]*?idealWidth = 860[\s\S]*?minimumHeight = 620[\s\S]*?idealHeight = 680/.test(files.uiOptimization),
  },
  {
    label: "settings window uses sidebar navigation and close-only window controls",
    text: files.settings + "\n" + files.uiOptimization + "\n" + files.localizable + "\n" + files.localizableZh,
    passed: /private enum SettingsTab:[\s\S]*?CaseIterable[\s\S]*?case language[\s\S]*?case provider[\s\S]*?case providerObservability[\s\S]*?case service/.test(files.settings)
      && /HStack\(spacing:\s*0\)[\s\S]*?settingsSidebar[\s\S]*?Divider\(\)[\s\S]*?selectedSettingsPane/.test(files.settings)
      && /private var settingsSidebar:[\s\S]*?ForEach\(SettingsTab\.allCases\)[\s\S]*?SettingsSidebarItem/.test(files.settings)
      && /private var selectedSettingsPane:[\s\S]*?switch selectedSettingsTab[\s\S]*?case \.providerObservability:[\s\S]*?ProviderObservabilitySettingsPanel\(\)/.test(files.settings)
      && /private struct SettingsWindowConfigurator:[\s\S]*?window\.title = UIStrings\.settingsWindowTitle[\s\S]*?window\.styleMask\.remove\(\.miniaturizable\)[\s\S]*?standardWindowButton\(\.miniaturizeButton\)\?\.isHidden = true[\s\S]*?standardWindowButton\(\.zoomButton\)\?\.isHidden = true/.test(files.settings)
      && /navigationStyle = SettingsNavigationStyle\.sidebar[\s\S]*?usesDedicatedSettingsScene = true[\s\S]*?windowControlPolicy = SettingsWindowControlPolicy\.closeOnly[\s\S]*?primarySaveButtonsVisible = false[\s\S]*?sidebarWidth = 190/.test(files.uiOptimization)
      && /"settings\.window\.title"/.test(files.localizable)
      && /"settings\.nav\.provider\.subtitle"/.test(files.localizableZh)
      && !/TabView\(selection:\s*\$selectedSettingsTab\)/.test(files.settings),
  },
  {
    label: "settings pages use unified headers and compact sections",
    text: files.settings,
    passed: /private struct SettingsPageHeader/.test(files.settings)
      && /private struct SettingsSectionCard/.test(files.settings)
      && /SettingsPageHeader\([\s\S]*?title:\s*UIStrings\.languageSettings/.test(files.settings)
      && /SettingsPageHeader\([\s\S]*?title:\s*UIStrings\.aiProviderSettings/.test(files.settings)
      && /SettingsSectionCard\(title:\s*UIStrings\.text\("settings\.aiProvider\.connection"/.test(files.settings)
      && /SettingsSectionCard\(title:\s*UIStrings\.text\("settings\.aiProvider\.limits"/.test(files.settings)
      && /SettingsSectionCard\(title:\s*UIStrings\.text\("settings\.aiProvider\.credentialSafety"/.test(files.settings)
      && /SettingsPageHeader\([\s\S]*?title:\s*UIStrings\.service/.test(files.settings)
      && /DetailMetricGrid\(maxColumns:\s*3/.test(files.settings),
  },
  {
    label: "settings AI provider autosaves profile edits while confirming provider tests",
    text: files.settings + "\n" + files.uiStrings + "\n" + files.localizable + "\n" + files.localizableZh,
    passed: /@State private var providerAutosaveTask: Task<Void,\s*Never>\?/.test(files.settings)
      && /@State private var isConfirmingProviderTest = false/.test(files.settings)
      && /\.onChange\(of:\s*providerDraft\)[\s\S]*?handleProviderDraftChange\(\)/.test(files.settings)
      && /private func handleProviderDraftChange\(\)[\s\S]*?providerAutosaveTask\?\.cancel\(\)[\s\S]*?Task\.sleep\(nanoseconds:\s*900_000_000\)[\s\S]*?await store\.saveAIProviderSettings\(draft:\s*draftSnapshot\)[\s\S]*?providerDraft\.apiKey = ""/.test(files.settings)
      && /UIStrings\.aiProviderAutosavePending/.test(files.settings)
      && /Button\s*\{[\s\S]*?isConfirmingProviderTest = true[\s\S]*?\} label:\s*\{[\s\S]*?Label\(UIStrings\.aiProviderTest,\s*systemImage:\s*"network"\)/.test(files.settings)
      && /\.confirmationDialog\(\s*UIStrings\.aiProviderTestConfirmationTitle,[\s\S]*?isPresented:\s*\$isConfirmingProviderTest[\s\S]*?Button\(UIStrings\.aiProviderTest,\s*role:\s*\.destructive\)[\s\S]*?testProviderConnection\(\)[\s\S]*?Text\(UIStrings\.aiProviderTestConfirmationMessage\)/.test(files.settings)
      && /private func testProviderConnection\(\)[\s\S]*?await store\.testAIProviderConnection\(draft:\s*providerDraft\)/.test(files.settings)
      && !/isConfirmingProviderSave/.test(files.settings)
      && !/Label\(UIStrings\.aiProviderSave,\s*systemImage:\s*"square\.and\.arrow\.down"\)/.test(files.settings)
      && /static var aiProviderAutosavePending/.test(files.uiStrings)
      && /static var aiProviderTestConfirmationMessage/.test(files.uiStrings)
      && /"settings\.aiProvider\.autosavePending"/.test(files.localizable)
      && /"settings\.aiProvider\.testConfirmation\.message"/.test(files.localizableZh),
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
    label: "sidebar uses privacy path display for project paths",
    text: files.sidebar,
    pattern: /PrivacyPathText\(path:\s*rootPath/,
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
    pattern: /"findings\.filter\.rule".*"findings\.filter\.allRules"/s,
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
    passed: [
      "taskCockpit.boundary",
      "taskCockpit.history.summary",
      "taskCockpit.action.build",
      "taskCockpit.empty.result",
      "taskCockpit.recommendedSkill",
    ].every((key) => files.localizable.includes(`"${key}" =`)),
  },
  {
    label: "localized skill manager workflow and unavailable-tool labels are present",
    text: files.localizable,
    pattern: /"skillManager\.workflow\.accessibility".*"skillManager\.workflow\.searchInstall".*"skillManager\.workflow\.installedUpdates".*"skillManager\.workflow\.localLibrary".*"skillManager\.toolUnavailable\.title".*"skillManager\.toolUnavailable\.message"/s,
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
    passed: /processRunner\.run\(\s*executableURL:\s*resolveServiceURL\(\),\s*input:\s*input(?:,\s*timeoutNanoseconds:\s*timeoutNanoseconds)?\s*\)/.test(runServiceBody)
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
    label: "ServiceClient clears pipe readability handlers or closes read handles",
    passed: /readabilityHandler\s*=\s*nil/.test(files.serviceIPC)
      || (/stdoutReader\?\.(?:close|closeFile)\s*\(/.test(files.serviceProcessRunner)
        && /stderrReader\?\.(?:close|closeFile)\s*\(/.test(files.serviceProcessRunner)),
  },
  {
    label: "ServiceClient protects continuations from stale or duplicate completion",
    passed: /(resumeOnce|finishOnce|completeOnce|didResume|hasResumed|isCompleted|completed|finished|cleanedUp|stale)/i.test(files.serviceIPC)
      && /(NSLock|DispatchQueue|ManagedAtomic|lock\s*\(|actor\b)/.test(files.serviceIPC)
      && /(if\s+cleanedUp|guard\s+!.*cleanedUp|markCancelled|Task\.checkCancellation)/s.test(files.serviceProcessRunner),
  },
  {
    label: "ServiceClient does not introduce a daemon, socket, XPC, or network redesign",
    passed: !/(^|\n)\s*import\s+Network\b|NWListener|NWConnection|NSXPCConnection|URLSessionWebSocketTask|SocketPort|UnixDomainSocket|\bdaemon\b|\blaunchd\b/.test(files.serviceIPC),
  },
  {
    label: "ServiceRequest IPC payload remains id, method, and params only",
    passed: /let\s+id:\s*String/.test(serviceRequestBody)
      && /let\s+method:\s*String/.test(serviceRequestBody)
      && /let\s+params:\s*Params/.test(serviceRequestBody)
      && !/(cancel|timeout|pid|socket|daemon|token)/i.test(serviceRequestBody),
  },
  {
    label: "Agent Copilot protocol method surface matches the supported method contract",
    passed: supportedMethods.length === 106
      && statusFixtureMethods.length === 106,
  },
  {
    label: "protocol surface has no IPC control, daemon, process, or socket methods",
    passed: forbiddenProtocolMethods.length === 0,
  },
];

const customChecks = [
  {
    label: "sidebar omits the retired Work section",
    passed: !/Section\(UIStrings\.text\("nav\.work",\s*"Work"\)\)/.test(files.sidebar)
      && !/SidebarWorkSurfaceRow/.test(files.sidebar)
      && !/ForEach\(DetailSection\.primaryWorkCases\)/.test(files.sidebar),
  },
  {
    label: "secondary sidebar rows use muted selection or material card treatment",
    passed: ["ConfigCurrentDocumentSidebarRow", "ConfigSnapshotSidebarRow"].every((name) => {
      const body = extractStructBody(files.sidebar, name);
      return body.includes(".optimizedSidebarSelection(isSelected: isSelected)")
        && !/foregroundStyle\(isSelected \? (?:Color\.)?\.?white/.test(body)
        && !/fill\(Color\.accentColor\)/.test(body);
    })
      && ["SessionSidebarRow", "SkillRow"].every((name) => {
        const body = extractStructBody(files.sidebar, name);
        return body.includes(".listPageCardBackground(isSelected: isSelected)")
          && body.includes("minimumCardRowHeight")
          && !/foregroundStyle\(isSelected \? (?:Color\.)?\.?white/.test(body);
      })
      && /struct SidebarSelectionPresentation:[\s\S]*?usesSaturatedAccentBackground = false[\s\S]*?usesWhiteSelectedText = false[\s\S]*?accentLineWidth = 3/.test(files.uiOptimization)
      && /private struct ListPageCardBackgroundModifier:[\s\S]*?selectedContentBackgroundColor/.test(files.sidebar)
      && /private struct ListPageCardBackgroundModifier:[\s\S]*?UIOptimizationPresentation\.sidebarSelection\.accentLineWidth/.test(files.sidebar)
      && /private struct OptimizedSidebarSelectionModifier:[\s\S]*?selectedContentBackgroundColor[\s\S]*?UIOptimizationPresentation\.sidebarSelection\.accentLineWidth/.test(files.sidebar),
  },
  {
    label: "session and config sidebars use compact search plus icon refresh toolbars",
    passed: /struct SidebarSecondaryListPresentation:[\s\S]*?minimumSearchWidth = 220[\s\S]*?compactRowMinHeight = 40[\s\S]*?compactRowMaxHeight = 44[\s\S]*?refreshUsesIconOnly = true/.test(files.uiOptimization)
      && /private struct SidebarSearchField:[\s\S]*?Image\(systemName:\s*"magnifyingglass"\)[\s\S]*?TextField\(placeholder,\s*text:\s*\$text\)[\s\S]*?frame\(minWidth:\s*minimumWidth,\s*maxWidth:\s*\.infinity\)/.test(files.sidebar)
      && /private var sessionToolbar:[\s\S]*?let layout = UIOptimizationPresentation\.skillList[\s\S]*?VStack\(alignment:\s*\.leading,\s*spacing:\s*8\)[\s\S]*?ListPageTitleBlock\([\s\S]*?HStack\(alignment:\s*\.center,\s*spacing:\s*CGFloat\(layout\.filterControlSpacing\)\)[\s\S]*?sessionScopePicker[\s\S]*?sessionSortPicker[\s\S]*?sessionSortDirectionButton[\s\S]*?sessionRefreshButton[\s\S]*?sessionSearchField/.test(files.sidebar)
      && /private var sessionScopePicker:[\s\S]*?SkillFilterMenuPicker\([\s\S]*?title:\s*UIStrings\.scope[\s\S]*?selection:\s*\$store\.localSessionScopeFilter[\s\S]*?options:\s*LocalSessionScopeFilter\.allCases[\s\S]*?expands:\s*false/.test(files.sidebar)
      && /private var sessionSortPicker:[\s\S]*?SkillFilterMenuPicker\([\s\S]*?title:\s*UIStrings\.sort[\s\S]*?selection:\s*\$store\.localSessionSortOrder[\s\S]*?options:\s*LocalSessionSortOrder\.allCases/.test(files.sidebar)
      && /private func sessionSortDirectionButton\(width:\s*CGFloat,\s*height:\s*CGFloat\)[\s\S]*?store\.localSessionSortDirection = store\.localSessionSortDirection == \.ascending \? \.descending : \.ascending[\s\S]*?Image\(systemName:\s*store\.localSessionSortDirection == \.ascending \? "arrow\.up" : "arrow\.down"\)/.test(files.sidebar)
      && /enum LocalSessionSortOrder:[\s\S]*?case recent[\s\S]*?case title/.test(files.storeList)
      && /@Published var localSessionSortOrder:\s*LocalSessionSortOrder = \.recent/.test(files.store)
      && /@Published var localSessionSortDirection:\s*SkillSortDirection = \.descending/.test(files.store)
      && /private func sortedLocalSessionRows\(_ rows:[\s\S]*?case \.recent:[\s\S]*?localSessionSortTimestamp[\s\S]*?case \.title:[\s\S]*?localizedStandardCompare/.test(files.store)
      && !/SessionScopeToggle/.test(files.sidebar)
      && /private var sessionRefreshButton:[\s\S]*?Image\(systemName:\s*"arrow\.clockwise"\)[\s\S]*?\.accessibilityLabel\(UIStrings\.text\("sidebar\.sessions\.preview"/.test(files.sidebar)
      && /private var configToolbar:[\s\S]*?VStack\(alignment:\s*\.leading,\s*spacing:\s*8\)[\s\S]*?HStack\(alignment:\s*\.center,\s*spacing:\s*CGFloat\(layout\.filterControlSpacing\)\)[\s\S]*?configScopePicker[\s\S]*?configRefreshButton\([\s\S]*?configSearchField/.test(files.sidebar)
      && /private func configRefreshButton\(width:\s*CGFloat,\s*height:\s*CGFloat\)[\s\S]*?Image\(systemName:\s*"arrow\.clockwise"\)[\s\S]*?\.accessibilityLabel\(UIStrings\.reload\)/.test(files.sidebar),
  },
  {
    label: "session detail copy and expand actions appear only on row hover",
    passed: /private struct LocalSessionContentItemRow:[\s\S]*?@State private var isHoveringActions = false/.test(files.agentCopilotOverview)
      && /private var actionOpacity:\s*Double[\s\S]*?isHoveringActions \? 1 : 0/.test(files.agentCopilotOverview)
      && /HStack\(spacing:\s*4\)[\s\S]*?detailButton[\s\S]*?copyButton[\s\S]*?\.opacity\(actionOpacity\)[\s\S]*?\.allowsHitTesting\(isHoveringActions\)/.test(files.agentCopilotOverview)
      && /\.onHover\s*\{\s*isHovering in[\s\S]*?isHoveringActions = isHovering/.test(files.agentCopilotOverview)
      && /contextMenu[\s\S]*?copyToPasteboard\(item\.text\)[\s\S]*?isShowingFullText = true/.test(files.agentCopilotOverview),
  },
  {
    label: "session detail chips use semantic colors for user agent tool and skill content",
    passed: /private func filterLabel\([\s\S]*?tint:\s*Color[\s\S]*?Text\("\\\(count\)"\)[\s\S]*?\.foregroundStyle\(isSelected \? tint : \.secondary\)[\s\S]*?\.background\(\s*isSelected \? tint\.opacity\(0\.16\)/.test(files.agentCopilotOverview)
      && /private extension LocalSessionContentKind[\s\S]*?var semanticTint:\s*Color[\s\S]*?case \.userMessage:[\s\S]*?return \.blue[\s\S]*?case \.agentReply:[\s\S]*?return \.purple[\s\S]*?case \.toolCall:[\s\S]*?return \.orange[\s\S]*?case \.skillCall:[\s\S]*?return \.green/.test(files.agentCopilotOverview)
      && /Label\(item\.title\.isEmpty \? item\.kind\.title : item\.title,\s*systemImage:\s*item\.kind\.systemImage\)[\s\S]*?\.foregroundStyle\(item\.kind\.semanticTint\)/.test(files.agentCopilotOverview),
  },
  {
    label: "detail feedback uses an overlay toast instead of full-width content banners",
    passed: /struct DetailFeedbackPresentation:[\s\S]*?usesOverlayToast = true[\s\S]*?maximumWidth = 420/.test(files.uiOptimization)
      && /ZStack\(alignment:\s*\.topTrailing\)[\s\S]*?ScrollViewReader[\s\S]*?detailFeedbackOverlay[\s\S]*?allowsHitTesting\(false\)/.test(files.detail)
      && /private var detailFeedbackOverlay:[\s\S]*?store\.errorMessage[\s\S]*?DetailFeedbackToast\([\s\S]*?store\.lastMutationMessage[\s\S]*?DetailFeedbackToast\(/.test(files.detail)
      && /struct DetailFeedbackToast:[\s\S]*?UIOptimizationPresentation\.detailFeedback\.maximumWidth[\s\S]*?regularMaterial/.test(files.detailPrimitives)
      && !/VStack\(alignment:\s*\.leading,\s*spacing:\s*24\)[\s\S]{0,240}?ErrorBanner\(message:\s*error\)/.test(files.detail)
      && !/VStack\(alignment:\s*\.leading,\s*spacing:\s*24\)[\s\S]{0,260}?SuccessBanner\(message:\s*message\)/.test(files.detail),
  },
  {
    label: "settings owns Provider Observability with dashboard-first logs",
    passed: /ProviderObservabilitySettingsPanel\(\)/.test(files.settings)
      && /loadAIProviderStatusIfNeeded\(\)/.test(files.settings)
      && !/store\.reload\(\)/.test(files.settings)
      && /case \.providerObservability:\s*break/.test(files.settings)
      && /func loadAIProviderStatusIfNeeded\(\) async/.test(files.store)
      && /func loadProviderObservabilityIfNeeded\(\) async/.test(files.store)
      && !/\.task\s*\{[\s\S]{0,240}?loadProviderObservability\(/.test(files.providerObservabilitySettings)
      && /case \.providerObservability:[\s\S]*?return UIStrings\.providerObservabilityTitle/.test(files.settings)
      && /case \.providerObservability:[\s\S]*?return "waveform\.path\.ecg\.rectangle"/.test(files.settings)
      && /selectedMode:\s*ProviderObservabilitySettingsMode\s*=\s*\.dashboard/.test(files.providerObservabilitySettings)
      && /case \.dashboard:[\s\S]*ProviderObservabilityDashboardSettingsView\(result:\s*result\)/.test(files.providerObservabilitySettings)
      && /case \.logs:[\s\S]*ProviderObservabilityLogSettingsView\(/.test(files.providerObservabilitySettings)
      && /statusFilter/.test(files.providerObservabilitySettings)
      && /providerFilter/.test(files.providerObservabilitySettings)
      && /modelFilter/.test(files.providerObservabilitySettings)
      && /destinationFilter/.test(files.providerObservabilitySettings)
      && /showIssuesOnly/.test(files.providerObservabilitySettings)
      && /searchText/.test(files.providerObservabilitySettings)
      && /result\.isDashboardEmpty/.test(files.providerObservabilitySettings)
      && /ProviderObservabilityEmptyDashboard/.test(files.providerObservabilitySettings)
      && /renderedRowLimit\s*=\s*40/.test(files.providerObservabilitySettings)
      && /let visibleRows = Array\(rows\.prefix\(Self\.renderedRowLimit\)\)/.test(files.providerObservabilitySettings)
      && /providerObservability\.logs\.moreRows/.test(files.uiStrings + "\n" + files.localizable + "\n" + files.localizableZh)
      && /providerObservability\.empty\.dashboardTitle/.test(files.providerObservabilitySettings + "\n" + files.localizable),
  },
  {
    label: "Agent Config moved from Settings into the main sidebar workflow",
    passed: !/AgentConfigSettingsPanel\(/.test(files.settings)
      && /SidebarContentMode\.config/.test(files.sidebar)
      && /AgentConfigDetailPanel\(\)/.test(files.detail)
      && /struct AgentConfigOverviewDetailPanel/.test(files.agentConfigWorkspace)
      && /struct AgentConfigSnapshotDetailPanel/.test(files.agentConfigWorkspace)
      && !/private struct AgentConfigSnapshotDetailPanel[\s\S]*?DetailMetricGrid[\s\S]*?SummaryChip\(title:\s*UIStrings\.agent/.test(files.agentConfigWorkspace),
  },
  {
    label: "Agent Workspace does not expose the retired evidence surface navigation grid",
    passed: !/AgentProfileNavigationGrid|agentCopilot\.evidenceSurfaces|selectedSidebarSelection\s*=\s*\.work\(section\)/.test(files.agentCopilotOverview),
  },
  {
    label: "local report preview UI is removed from sidebar surfaces",
    passed: !/LocalReportPreviewSheet|LocalReportExportPanel|isReportSheetPresented|sidebar\.report\.title|localReport\.preview|localReport\.download|localReport\.history/.test(
      files.sidebar + "\n" + files.agentCopilotOverview + "\n" + files.detailSurface + "\n" + files.localizable,
    ),
  },
  {
    label: "modal workflows share liquid-glass sheet chrome, columns, and inline feedback",
    passed: /static let workflowSheet = WorkflowSheetPresentation\(\)/.test(files.uiOptimization)
      && /struct WorkflowSheetPresentation:[\s\S]*?titlebarStyle = WorkflowSheetTitlebarStyle\.liquidGlass[\s\S]*?closeActionPlacement = WorkflowSheetCloseActionPlacement\.trailingTitlebar[\s\S]*?feedbackStyle = WorkflowSheetFeedbackStyle\.inlineTintedBanner[\s\S]*?columnLayout = WorkflowSheetColumnLayout\.twoColumn/.test(files.uiOptimization)
      && /struct WorkflowSheetShell<Content: View>:[\s\S]*?Label\(title,\s*systemImage:\s*systemImage\)[\s\S]*?Button\s*\{[\s\S]*?dismiss\(\)[\s\S]*?\} label:\s*\{[\s\S]*?Label\(UIStrings\.done,\s*systemImage:\s*"xmark"\)[\s\S]*?\.background\(\.bar\)/.test(files.workflowSheet)
      && /struct WorkflowSheetSplitLayout<Primary: View,\s*Secondary: View>:[\s\S]*?primary\(\)[\s\S]*?Divider\(\)[\s\S]*?secondary\(\)/.test(files.workflowSheet)
      && /struct WorkflowSheetInlineBanner:[\s\S]*?Label\(message,\s*systemImage:\s*style\.systemImage\)[\s\S]*?\.background\(style\.color\.opacity\(0\.08\)[\s\S]*?Rectangle\(\)[\s\S]*?\.fill\(style\.color\)/.test(files.workflowSheet)
      && /struct TaskPreflightPreviewSheet:[\s\S]*?WorkflowSheetShell\([\s\S]*?WorkflowSheetSplitLayout\([\s\S]*?TaskPreflightEditorPane[\s\S]*?TaskPreflightHistoryPanel/.test(files.taskCockpit)
      && /struct SkillPackageManagerSheet:[\s\S]*?WorkflowSheetShell\([\s\S]*?SkillManagerPanel\(showsHeader:\s*false\)/.test(files.sidebar)
      && /struct SkillManagerPanel:[\s\S]*?WorkflowSheetSplitLayout\(primaryMinWidth:\s*430,\s*secondaryWidth:\s*360\)[\s\S]*?workflowInputContent[\s\S]*?workflowResultsContent/.test(files.skillManager)
      && !/struct SkillPackageManagerSheet:[\s\S]*?ErrorBanner\(message:\s*error\)/.test(files.sidebar)
      && !/struct SkillPackageManagerSheet:[\s\S]*?SuccessBanner\(message:\s*message\)/.test(files.sidebar),
  },
  {
    label: "task preflight opens from the fixed sidebar footer sheet and keeps selectable history",
    passed: /TaskPreflightPreviewSheet\(\)/.test(files.sidebar)
      && /struct TaskPreflightPreviewSheet:[\s\S]*?WorkflowSheetShell\([\s\S]*?WorkflowSheetSplitLayout\([\s\S]*?TaskPreflightHistoryPanel/.test(files.taskCockpit)
      && /TaskPreflightEditorPane:[\s\S]*?TaskCockpitPanel\(/.test(files.taskCockpit)
      && /providerGateMessage/.test(files.taskCockpit)
      && /WorkflowSheetInlineBanner\(message:\s*providerGateMessage,\s*style:\s*\.warning\)/.test(files.taskCockpit)
      && /\.disabled\([\s\S]*?providerGateMessage != nil[\s\S]*?\)/.test(files.taskCockpit)
      && /\.help\(providerGateMessage \?\? UIStrings\.taskCockpitBoundary\)/.test(files.taskCockpit)
      && /private struct TaskCockpitAgentChip:[\s\S]*?\.frame\(minHeight:\s*44,\s*alignment:\s*\.leading\)[\s\S]*?\.frame\(maxWidth:\s*\.infinity,\s*alignment:\s*\.leading\)/.test(files.taskCockpit)
      && !/private struct TaskCockpitAgentChip:[\s\S]*?fixedAgentChipWidth/.test(files.taskCockpit)
      && /taskCockpit\.history\.summary/.test(files.taskCockpit + "\n" + files.localizable)
      && /taskCockpitHistory/.test(files.taskCockpit + "\n" + files.store)
      && /selectTaskCockpitHistoryRecord/.test(files.taskCockpit + "\n" + files.store)
      && /recordTaskCockpitHistory/.test(files.store)
      && !/case preflight/.test(files.sidebarSelection)
      && !/selectedSidebarSelection\s*=\s*\.preflight/.test(files.sidebar + "\n" + files.storeSurface),
  },
  {
    label: "task preflight history empty state uses the shared empty-state component",
    passed: /private struct TaskPreflightHistoryPanel:[\s\S]*?if records\.isEmpty \{[\s\S]*?EmptyState\([\s\S]*?title:\s*UIStrings\.text\("taskCockpit\.history\.emptyTitle"[\s\S]*?systemImage:\s*"clock\.badge\.questionmark"[\s\S]*?message:\s*UIStrings\.text\("taskCockpit\.history\.emptyMessage"/.test(files.taskCockpit)
      && !/Text\(UIStrings\.text\("taskCockpit\.history\.empty"/.test(files.taskCockpit),
  },
  {
    label: "settings provider status copy uses precise disabled and audit-state labels",
    passed: /static var aiProviderDisabledReason:[\s\S]*?settings\.aiProvider\.disabledReason/.test(files.uiStrings)
      && /static var aiProviderAuditApplied:[\s\S]*?settings\.aiProvider\.audit\.applied/.test(files.uiStrings)
      && /static var aiProviderAuditNotApplied:[\s\S]*?settings\.aiProvider\.audit\.notApplied/.test(files.uiStrings)
      && /static var aiProviderAuditStored:[\s\S]*?settings\.aiProvider\.audit\.stored/.test(files.uiStrings)
      && /static var aiProviderAuditNotStored:[\s\S]*?settings\.aiProvider\.audit\.notStored/.test(files.uiStrings)
      && /SettingsMetadataRow\(label:\s*UIStrings\.aiProviderDisabledReason,\s*value:\s*UIStrings\.localizedServiceMessage\(disabledReason\)\)/.test(files.settings)
      && /audit\.redactionApplied \? UIStrings\.aiProviderAuditApplied : UIStrings\.aiProviderAuditNotApplied/.test(files.settings)
      && /audit\.promptStored \? UIStrings\.aiProviderAuditStored : UIStrings\.aiProviderAuditNotStored/.test(files.settings)
      && /audit\.responseStored \? UIStrings\.aiProviderAuditStored : UIStrings\.aiProviderAuditNotStored/.test(files.settings)
      && /"settings\.aiProvider\.disabledReason" = "Disabled reason";/.test(files.localizable)
      && /"settings\.aiProvider\.audit\.notStored" = "Not stored";/.test(files.localizable)
      && /"settings\.aiProvider\.disabledReason" = "禁用原因";/.test(files.localizableZh)
      && /"settings\.aiProvider\.audit\.notStored" = "未存储";/.test(files.localizableZh)
      && !/SettingsMetadataRow\(label:\s*UIStrings\.aiProviderUnconfigured,\s*value:\s*UIStrings\.localizedServiceMessage\(disabledReason\)\)/.test(files.settings)
      && !/aiProviderAuditPromptStored,\s*value:\s*audit\.promptStored \? UIStrings\.llmEnabled : UIStrings\.llmDisabled/.test(files.settings),
  },
  {
    label: "guided cleanup safe links require in-view confirmation before confirmed entries open",
    passed: /@State private var isConfirmingOpen = false/.test(files.detailGuidedCleanup)
      && /private var needsConfirmation:[\s\S]*?link\.requiresConfirmation/.test(files.detailGuidedCleanup)
      && /if needsConfirmation && !isConfirmingOpen[\s\S]*?isConfirmingOpen = true[\s\S]*?else[\s\S]*?onOpen\(\)/.test(files.detailGuidedCleanup)
      && /UIStrings\.guidedCleanupSafeLinkConfirmOpen/.test(files.detailGuidedCleanup)
      && /UIStrings\.guidedCleanupSafeLinkCancelOpen/.test(files.detailGuidedCleanup)
      && /"guidedCleanup\.safeLink\.confirmOpen"/.test(files.localizable)
      && /"guidedCleanup\.safeLink\.confirmOpen"/.test(files.localizableZh),
  },
  {
    label: "task cockpit presentation uses structured tokens instead of English substring classification",
    passed: /private var hasRouteAmbiguity:[\s\S]*?candidateScores[\s\S]*?routeCandidateCount/.test(files.taskCockpit)
      && /private static func isReviewOnlyRisk\(_ row: TaskCockpitContextRow\) -> Bool[\s\S]*?signalTokens\(for:\s*row\)/.test(files.taskCockpit)
      && /private static func isInternalBoundary\(_ row: TaskCockpitContextRow\) -> Bool[\s\S]*?signalTokens\(for:\s*row\)/.test(files.taskCockpit)
      && /private static func signalTokens\(for row: TaskCockpitContextRow\) -> Set<String>/.test(files.taskCockpit)
      && /private static func normalizedSignalToken\(_ value: String\) -> String/.test(files.taskCockpit)
      && !/normalized\.contains\("task readiness is blocked"\)/.test(files.taskCockpit)
      && !/normalized\.contains\("routing confidence is blocked"\)/.test(files.taskCockpit)
      && !/normalized\.contains\("small score margin"\)/.test(files.taskCockpit)
      && !/normalized\.contains\("close or overlapping alternatives"\)/.test(files.taskCockpit)
      && !/normalized\.contains\("read-only"\)/.test(files.taskCockpit)
      && !/normalized\.contains\("provider not sent"\)/.test(files.taskCockpit)
      && !/normalized\.contains\("task cockpit combined"\)/.test(files.taskCockpit),
  },
  {
    label: "skill filter controls show their role alongside the current value",
    passed: /private struct SkillFilterMenuPicker[\s\S]*?SidebarMenuButtonLabel\([\s\S]*?title:\s*title,[\s\S]*?value:\s*optionTitle\(selection\)/.test(files.sidebar)
      && /private struct SidebarMenuButtonLabel[\s\S]*?Text\(title\)[\s\S]*?Text\(value\)/.test(files.sidebar)
      && /private struct SkillFilterMenuPicker[\s\S]*?\.accessibilityLabel\(title\)[\s\S]*?\.accessibilityValue\(optionTitle\(selection\)\)/.test(files.sidebar)
      && /SkillFilterMenuPicker\([\s\S]*?title:\s*UIStrings\.text\("sidebar\.skillFilter",\s*"Filter"\)/.test(files.sidebar)
      && /SkillFilterMenuPicker\([\s\S]*?title:\s*UIStrings\.text\("sidebar\.scopeFilter",\s*"Scope"\)/.test(files.sidebar)
      && /SkillFilterMenuPicker\([\s\S]*?title:\s*UIStrings\.sort/.test(files.sidebar),
  },
  {
    label: "detail adopting-agent summary uses store-derived cache instead of scanning skills in body",
    passed: /@Published private\(set\) var adoptingAgentSummaryBySkillID: \[SkillRecord\.ID: String\] = \[:\]/.test(files.store)
      && /didSet\s*{[\s\S]*?invalidateFilteredSkillListCache\(\)[\s\S]*?rebuildAdoptingAgentSummaryCache\(\)[\s\S]*?}/.test(files.store)
      && /private func rebuildAdoptingAgentSummaryCache\(\)[\s\S]*?SkillListModel\.adoptingAgentSummaryBySkillID\(for:\s*skills\)/.test(files.store)
      && /adoptingAgentSummary:\s*store\.adoptingAgentSummary\(for:\s*skill\)/.test(files.detail)
      && /func adoptingAgentSummary\(for skill: SkillRecord\) -> String/.test(files.storeDerivedState)
      && !/private func adoptingAgentSummary\(for skill: SkillRecord\)[\s\S]*?store\.skills[\s\S]*?\.filter/.test(files.detail),
  },
  {
    label: "adaptive material surface uses shared presentation corner radius",
    passed: /static let materialCornerRadius = sidebarSelection\.rowCornerRadius/.test(files.uiOptimization)
      && /RoundedRectangle\(cornerRadius:\s*CGFloat\(UIOptimizationPresentation\.materialCornerRadius\)\)/.test(files.material)
      && !/RoundedRectangle\(cornerRadius:\s*8\)/.test(files.material),
  },
  {
    label: "Skill Manager uses segmented workflows, local feedback, and unavailable-tool gating",
    passed: /enum SkillManagerWorkflow:[\s\S]*?case searchInstall[\s\S]*?case installedUpdates[\s\S]*?case localLibrary/.test(files.skillManagerModel)
      && /@State private var selectedWorkflow:\s*SkillManagerWorkflow = \.searchInstall/.test(files.skillManager)
      && /Picker\(selection:\s*\$selectedWorkflow\)[\s\S]*?Label\(workflow\.title,\s*systemImage:\s*workflow\.systemImage\)\.tag\(workflow\)[\s\S]*?\.labelsHidden\(\)[\s\S]*?\.accessibilityLabel\(UIStrings\.text\("skillManager\.workflow\.accessibility"/.test(files.skillManager)
      && !/Picker\(UIStrings\.text\("skillManager\.workflow\.label"/.test(files.skillManager)
      && /private var workflowInputContent:[\s\S]*?case \.searchInstall:[\s\S]*?searchAndInstallControls[\s\S]*?case \.installedUpdates:[\s\S]*?installedActionControls[\s\S]*?case \.localLibrary:[\s\S]*?localLibraryControls/.test(files.skillManager)
      && /private var workflowResultsContent:[\s\S]*?case \.searchInstall:[\s\S]*?searchResultsSection[\s\S]*?case \.installedUpdates:[\s\S]*?installedResultsSection[\s\S]*?case \.localLibrary:[\s\S]*?localLibraryResultsSection/.test(files.skillManager)
      && /private var skillManagerFeedback:[\s\S]*?WorkflowSheetInlineBanner\(message:\s*error,\s*style:\s*\.error\)[\s\S]*?WorkflowSheetInlineBanner\(message:\s*message,\s*style:\s*\.success\)/.test(files.skillManager)
      && /externalMutationDisabled/.test(files.skillManager)
      && /externalManagerUnavailableMessage/.test(files.skillManager)
      && /toolUnavailableCard/.test(files.skillManager)
      && /search\.isBlockedByNetwork/.test(files.skillManager)
      && /skillManager\.search\.networkBlocked/.test(files.skillManager + "\n" + files.localizable)
      && /preview\.localizedSummary/.test(files.skillManager)
      && /var localizedSummary:\s*String/.test(files.skillManagerModel)
      && /store\.skillManagerErrorMessage/.test(files.skillManager)
      && /store\.skillManagerMessage/.test(files.skillManager)
      && /skillManagerInstallSkillName/.test(files.store + "\n" + files.skillManager)
      && /skillManagerRemoveSkillName/.test(files.store + "\n" + files.skillManager)
      && /clearSkillManagerWorkflowPreviews/.test(files.store + "\n" + files.skillManager + "\n" + files.sidebar)
      && /private var canSearchSkillManager:[\s\S]*?skillManagerSearchQuery\.trimmingCharacters\(in:\s*\.whitespacesAndNewlines\)[\s\S]*?!store\.isSearchingSkillManager[\s\S]*?!externalMutationDisabled/.test(files.skillManager)
      && /\.disabled\(!canSearchSkillManager\)/.test(files.skillManager)
      && !/TextField\([\s\S]*?\$store\.skillManagerSkillName/.test(files.skillManager),
  },
  {
    label: "Skill Manager target controls collapse to an icon summary bar",
    passed: /@State private var isShowingSkillManagerTargets = false/.test(files.skillManager)
      && /private var selectedTargetAgents:\s*\[SkillManagerAgent\][\s\S]*?SkillManagerAgent\.defaultTargets\.filter[\s\S]*?store\.skillManagerSelectedAgentIDs\.contains/.test(files.skillManager)
      && /private var targetControls:[\s\S]*?SkillManagerTargetSummary\(agents:\s*selectedTargetAgents\)[\s\S]*?Button\s*\{[\s\S]*?isShowingSkillManagerTargets\.toggle\(\)[\s\S]*?\} label:[\s\S]*?isShowingSkillManagerTargets \? "chevron\.up" : "chevron\.down"[\s\S]*?if isShowingSkillManagerTargets \{[\s\S]*?LazyVGrid/.test(files.skillManager)
      && /private struct SkillManagerTargetSummary:[\s\S]*?ForEach\(agents\.prefix\(4\)\)[\s\S]*?SkillManagerTargetIcon\(agent:\s*agent\)[\s\S]*?UIStrings\.text\("skillManager\.agents\.allSelected"/.test(files.skillManager)
      && /private struct SkillManagerTargetIcon:[\s\S]*?AgentIconProvider\.image\(for:\s*agent\.skillAgentFilter\)[\s\S]*?Image\(nsImage:\s*image\)/.test(files.skillManager)
      && /private extension SkillManagerAgent\s*\{[\s\S]*?var skillAgentFilter:\s*SkillAgentFilter[\s\S]*?case \.hermesAgent:[\s\S]*?return \.hermes/.test(files.skillManager),
  },
  {
    label: "Skill Manager search suggestions render as clickable tag pills",
    passed: /private var skillManagerSearchSuggestions:\s*\[String\][\s\S]*?store\.localSkillLibrarySkills\.map\(\\\.name\)[\s\S]*?store\.skillManagerInstalled\?\.installed\.map\(\\\.name\)/.test(files.skillManager)
      && /skillManagerSuggestionBar/.test(files.skillManager)
      && /private var skillManagerSuggestionBar:[\s\S]*?ForEach\(skillManagerSearchSuggestions,\s*id:\s*\\\.self\)[\s\S]*?store\.skillManagerSearchQuery = suggestion[\s\S]*?SkillManagerSuggestionPill\(title:\s*suggestion\)[\s\S]*?\.help\(suggestion\)/.test(files.skillManager)
      && /private struct SkillManagerSuggestionPill:[\s\S]*?Text\(title\)[\s\S]*?\.background\(Color\.accentColor\.opacity\(0\.12\),\s*in:\s*Capsule\(\)\)/.test(files.skillManager),
  },
  {
    label: "local report export clears stale result when report scope changes",
    passed: /private func clearLocalReportExportState\(\)/.test(files.store)
      && /@Published var selectedSkillID:[\s\S]*?clearLocalReportExportState\(\)[\s\S]*?synchronizeSidebarSelectionWithSelectedSkill\(\)/.test(files.store)
      && /@Published var searchText[\s\S]*?clearLocalReportExportState\(\)[\s\S]*?handleListCriteriaChanged\(\)/.test(files.store)
      && /@Published var agentFilter[\s\S]*?clearLocalReportExportState\(\)[\s\S]*?handleListCriteriaChanged\(\)/.test(files.store)
      && /@Published var stateFilter[\s\S]*?clearLocalReportExportState\(\)[\s\S]*?handleListCriteriaChanged\(\)/.test(files.store)
      && /@Published var localReportFormat:[\s\S]*?didSet\s*{\s*clearLocalReportExportState\(\)\s*}/.test(files.store)
      && /@Published var sortOrder[\s\S]*?clearLocalReportExportState\(\)[\s\S]*?handleListCriteriaChanged\(\)/.test(files.store),
  },
  {
    label: "smart analysis quality score no longer exposes cross-agent comparison as a detail component",
    passed: /id:\s*"same_agent_conflicts"/.test(files.serviceKnowledge)
      && /label:\s*"Same-agent conflicts"/.test(files.serviceKnowledge)
      && !/id:\s*"conflict_and_overlap"/.test(files.serviceKnowledge)
      && !/Compare cross-agent overlap/.test(files.serviceLLMPromptHelpers)
      && !/cross-agent overlap currently involves this skill/.test(files.serviceLLMPromptHelpers),
  },
  {
    label: "smart analysis copy focuses on quality, task fit, and routing",
    passed: /Use focused smart analysis panels for quality scoring, task fit, and routing\./.test(files.detailSection)
      && /"detail\.section\.analysis\.summary"\s*=\s*"Use focused smart analysis panels for quality scoring, task fit, and routing\."/.test(files.localizable)
      && !/"detail\.section\.analysis\.summary"\s*=\s*".*cross-agent comparison/.test(files.localizable),
  },
  {
    label: "safe batch lives behind the skill-list batch operation sheet",
    passed: !/SafeBatchTogglePanel|BatchTogglePreviewSummary/.test(files.sidebar)
      && /SkillListSectionHeader\([\s\S]*?store\.resetBatchToggleSelectionToVisibleSkills\(\)[\s\S]*?isBatchOperationPresented\s*=\s*true/.test(files.sidebar)
      && /BatchSkillOperationSheet\(\)/.test(files.sidebar)
      && /Toggle\(isOn:\s*selectionBinding\)/.test(files.batchSkillOperation)
      && /store\.selectAllVisibleBatchToggleSkills\(\)/.test(files.batchSkillOperation)
      && /store\.clearBatchToggleSelection\(\)/.test(files.batchSkillOperation)
      && /await store\.previewVisibleBatchToggle\(\)/.test(files.batchSkillOperation)
      && /await store\.applyVisibleBatchTogglePreview\(confirmingPreviewID:\s*previewID\)/.test(files.batchSkillOperation),
  },
  {
    label: "Provider Observability settings presents chart summaries before detailed evidence rows",
    passed: /ProviderObservabilityChartsPanel\(result:\s*result\)/.test(files.providerObservabilitySettings)
      && /struct ProviderObservabilityChartCard/.test(files.detailProviderObservability)
      && /providerObservabilityChartModelTokens/.test(files.detailProviderObservability)
      && /providerObservabilityChartDestinationCost/.test(files.detailProviderObservability)
      && /ProviderObservabilityDimensionList/.test(files.detailProviderObservability),
  },
  {
    label: "sidebar and retired agent profile omit adapter capability content",
    passed: !/SidebarAgentStatusPanel|AdapterCapabilityCard|RefreshStatusView/.test(files.sidebar)
      && !/AgentCapabilitySummaryCard/.test(files.agentCopilotOverview)
      && !/capabilityReminders\(from:\s*store\.selectedAdapterCapability\)/.test(files.agentCopilotOverview)
      && !/AgentProfileInfoRow/.test(files.agentCopilotOverview),
  },
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
  ...checks.filter((check) => {
    if (check.pattern) {
      return !check.pattern.test(check.text);
    }
    return !check.passed;
  }),
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
  return uniqueSorted([...block[1].matchAll(/"([A-Za-z][A-Za-z0-9]*\.[A-Za-z][A-Za-z0-9]*)"/g)].map((match) => match[1]));
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
