import Foundation

enum UIStrings {
    static let appTitle = text("app.title", "Skills Copilot")
    static let searchPrompt = text("search.prompt", "Search")
    static let scan = text("action.scan", "Scan")
    static let reload = text("action.reload", "Reload")
    static let save = text("action.save", "Save")
    static let done = text("action.done", "Done")
    static let cancel = text("action.cancel", "Cancel")
    static let enable = text("action.enable", "Enable")
    static let disable = text("action.disable", "Disable")
    static let preview = text("action.preview", "Preview")
    static let previewGate = text("action.previewGate", "Preview Gate")
    static let executionBlocked = text("action.executionBlocked", "Execution Blocked")
    static let rollback = text("action.rollback", "Rollback")
    static let installToAgent = text("action.installToAgent", "Install to Agent...")
    static let confirmInstall = text("action.confirmInstall", "Confirm Install")
    static let llmAnalyze = text("llm.action.analyze", "Analyze")
    static let llmRecommend = text("llm.action.recommend", "Recommend")
    static let llmExplainConflict = text("llm.action.explainConflict", "Explain Same-agent Conflict")
    static let llmDraftFrontmatter = text("llm.action.draftFrontmatter", "Draft Frontmatter")
    static let chooseProject = text("action.chooseProject", "Choose Project")
    static let clearProject = text("action.clearProject", "Clear Project")
    static let revealInFinder = text("action.revealInFinder", "Reveal in Finder")
    static let skills = text("nav.skills", "Skills")
    static let project = text("nav.project", "Project")
    static let view = text("nav.view", "View")
    static let agent = text("filter.agent", "Agent")
    static let state = text("filter.state", "State")
    static let sort = text("filter.sort", "Sort")
    static let claudeCode = text("agent.claudeCode", "Claude Code")
    static let codex = text("agent.codex", "Codex")
    static let opencode = text("agent.opencode", "opencode")
    static let pi = text("agent.pi", "Pi")
    static let hermes = text("agent.hermes", "Hermes")
    static let openclaw = text("agent.openclaw", "OpenClaw")
    static let detailSection = text("detail.section", "Detail Section")
    static let overview = text("detail.overview", "Overview")
    static let findings = text("detail.findings", "Findings")
    static let conflicts = text("detail.conflicts", "Conflicts")
    static let cleanupQueue = text("cleanup.queue", "Cleanup Queue")
    static let cleanupKindFinding = text("cleanup.kind.finding", "Findings")
    static let cleanupKindIntegrity = text("cleanup.kind.integrity", "Integrity")
    static let cleanupKindConflict = text("cleanup.kind.conflict", "Same-agent conflicts")
    static let cleanupKindAnalysis = text("cleanup.kind.analysis", "Analysis insights")
    static let cleanupPriorityCritical = text("cleanup.priority.critical", "Critical")
    static let cleanupPriorityHigh = text("cleanup.priority.high", "High")
    static let cleanupPriorityMedium = text("cleanup.priority.medium", "Medium")
    static let cleanupPriorityLow = text("cleanup.priority.low", "Low")
    static let cleanupPriorityInfo = text("cleanup.priority.info", "Info")
    static let cleanupFilterKind = text("cleanup.filter.kind", "Kind")
    static let cleanupFilterPriority = text("cleanup.filter.priority", "Priority")
    static let cleanupFilterAllKinds = text("cleanup.filter.allKinds", "All kinds")
    static let cleanupFilterAllPriorities = text("cleanup.filter.allPriorities", "All priorities")
    static let cleanupFilterCriticalHigh = text("cleanup.filter.criticalHigh", "Critical / High")
    static let cleanupFilterLowInfo = text("cleanup.filter.lowInfo", "Low / Info")
    static let cleanupUntitledItem = text("cleanup.item.untitled", "Cleanup item")
    static let cleanupDefaultNextAction = text("cleanup.item.nextAction", "Open detail")
    static let cleanupUnavailableFallback = text("cleanup.unavailableFallback", "Cleanup Queue is unavailable in this service build. Showing a local empty read-only fallback; no writes, scripts, AI provider calls, or credentials are used.")
    static let cleanupQueueReadOnlyBoundary = text("cleanup.readOnlyBoundary", "Work through open findings, integrity issues, same-agent conflicts, and analysis insights from one read-only queue. Actions only open existing detail views; they do not write agent config, edit skills, execute scripts, call an AI provider, or store credentials.")
    static let cleanupEmptyTitle = text("cleanup.empty.title", "No Cleanup Queue items")
    static let cleanupEmptyMessage = text("cleanup.empty.message", "There are no open cleanup items for the current service response.")
    static let cleanupNoFilteredItems = text("cleanup.empty.filtered", "No queue items match the selected kind, priority, and agent filters.")
    static let cleanupAIBlocked = text("cleanup.safety.aiBlocked", "AI blocked")
    static let cleanupCredentialsBlocked = text("cleanup.safety.credentialsBlocked", "Credentials blocked")
    static let cleanupOpenExistingDetailHelp = text("cleanup.action.openExistingDetail.help", "Open the existing read-only detail section for this item.")
    static let crossAgentComparisonTitle = text("comparison.crossAgent.title", "Cross-agent Comparison")
    static let crossAgentComparisonBoundary = text("comparison.crossAgent.boundary", "Compare same-name or similar skills across Claude Code, Codex, opencode, Pi, Hermes, and OpenClaw by state, source, scope/root, findings, writable capability, and differences. This view is read-only: it cannot write config, edit skills, create snapshots, execute scripts, call an AI provider, or read credentials.")
    static let crossAgentComparisonGroups = text("comparison.crossAgent.groups", "Groups")
    static let crossAgentComparisonAgents = text("comparison.crossAgent.agents", "Agents")
    static let crossAgentComparisonRiskGroups = text("comparison.crossAgent.riskGroups", "Risk groups")
    static let crossAgentComparisonWritableMismatch = text("comparison.crossAgent.writableMismatch", "Writable mismatch")
    static let crossAgentComparisonDifferences = text("comparison.crossAgent.differences", "Differences")
    static let crossAgentComparisonWritable = text("comparison.crossAgent.writable", "Writable verified")
    static let crossAgentComparisonUntitled = text("comparison.crossAgent.untitled", "Comparison group")
    static let crossAgentComparisonMatchName = text("comparison.crossAgent.match.name", "Same or similar name")
    static let crossAgentComparisonMatchSimilarName = text("comparison.crossAgent.match.similarName", "Similar name with definition differences")
    static let crossAgentComparisonNoSelectedGroup = text("comparison.crossAgent.empty.selected", "No selected-skill comparison group")
    static let crossAgentComparisonNoSelectedGroupMessage = text("comparison.crossAgent.empty.selected.message", "The selected skill does not currently share a same-name or similar cross-agent group in this catalog/filter context.")
    static let crossAgentComparisonLocalFallback = text("comparison.crossAgent.localFallback", "Comparison service is unavailable in this build. Showing a local read-only catalog comparison fallback.")
    static let crossAgentComparisonDifferenceEnabled = text("comparison.crossAgent.difference.enabled", "Enabled state differs")
    static let crossAgentComparisonDifferenceWritable = text("comparison.crossAgent.difference.writable", "Writable capability differs")
    static let crossAgentComparisonDifferenceSource = text("comparison.crossAgent.difference.source", "Source/root differs")
    static let crossAgentComparisonDifferenceFindings = text("comparison.crossAgent.difference.findings", "Finding counts differ")
    static let crossAgentComparisonDifferenceDefinition = text("comparison.crossAgent.difference.definition", "Definition IDs differ")
    static let batchToggleTitle = text("batchToggle.title", "Safe Batch")
    static let batchToggleBoundary = text("batchToggle.boundary", "Preview-first enable/disable for visible skills only. Read-only adapters and unverified writable roots are skipped; no scripts, AI provider calls, credentials, skill-content writes, or public release actions are available.")
    static let batchToggleTarget = text("batchToggle.target", "Batch target")
    static let batchToggleSelected = text("batchToggle.selected", "Selected")
    static let batchToggleWritable = text("batchToggle.writable", "Writable")
    static let batchToggleSkipped = text("batchToggle.skipped", "Skipped")
    static let batchToggleApply = text("batchToggle.apply", "Apply")
    static let batchTogglePreviewing = text("batchToggle.previewing", "Preparing batch preview...")
    static let batchToggleSnapshotPlan = text("batchToggle.snapshotPlan", "Snapshot / rollback plan")
    static let batchToggleSnapshotPlanDefault = text("batchToggle.snapshotPlan.default", "Service will create agent-config snapshots for writable adapter targets before applying, then use existing rollback support for those config files.")
    static let batchToggleSnapshotPlanUnavailable = text("batchToggle.snapshotPlan.unavailable", "Service batch preview is unavailable, so apply is disabled. No files were written.")
    static let batchToggleServicePreviewUnavailable = text("batchToggle.servicePreviewUnavailable", "Service batch preview method is unavailable. This is a local read-only eligibility estimate; apply is disabled until batch.applySkillToggles or batch.applyToggle is available.")
    static let batchToggleApplyUnavailable = text("batchToggle.applyUnavailable", "Batch apply is unavailable until a service preview/apply pair confirms the snapshot plan.")
    static let batchToggleNoWritableChanges = text("batchToggle.noWritableChanges", "No writable skill changes are available in this preview.")
    static let batchToggleNoAffectedSkills = text("batchToggle.noAffectedSkills", "No writable affected skills in this preview.")
    static let batchToggleNoSkippedSkills = text("batchToggle.noSkippedSkills", "No skipped skills in this preview.")
    static let batchTogglePreviewChanged = text("batchToggle.previewChanged", "Batch preview changed before confirmation. Preview again before applying.")
    static let noSkillsInCatalog = text("empty.noSkillsInCatalog", "No skills in catalog")
    static let noSkillsMatchSearch = text("empty.noSkillsMatchSearch", "No skills match this search")
    static let noProjectSelected = text("project.none", "No Project")
    static let projectChoosePrompt = text("project.choosePrompt", "Choose a project directory to scan project-scoped Claude, Codex, and opencode skills.")
    static let projectSelectedSource = text("project.source.selected", "Selected project")
    static let projectGlobalRootsOnly = text("project.source.globalOnly", "No project: global roots only")
    static let recentProjects = text("project.recent", "Recent Projects")
    static let noRecentProjects = text("project.noRecent", "No Recent Projects")
    static let projectValidation = text("project.validation", "Project Validation")
    static let noProjectSkillsMessage = text("empty.noProjectSkills.message", "No skills were found in global roots. Choose a project to include project-scoped skills, then scan.")
    static let noCodexProjectMessage = text("empty.noCodexProject.message", "No Codex skills match the current global roots. Choose a project to include project-scoped Codex skills.")
    static let noCodexSkillsMessage = text("empty.noCodexSkills.message", "No Codex skills match the current search or filters.")
    static let adapterCapabilities = text("sidebar.adapterCapabilities", "Adapter Capabilities")
    static let adapterScan = text("adapter.capability.scan", "Scan")
    static let adapterToggle = text("adapter.capability.toggle", "Toggle")
    static let adapterInstall = text("adapter.capability.install", "Install")
    static let loading = text("state.loading", "Loading...")
    static let stateEnabled = text("state.enabled", "Enabled")
    static let stateDisabled = text("state.disabled", "Disabled")
    static let stateBroken = text("state.broken", "Broken")
    static let stateMissing = text("state.missing", "Missing")
    static let stateShadowed = text("state.shadowed", "Shadowed")
    static let stateUnknown = text("state.unknown", "Unknown")
    static let retryRefresh = text("action.retryRefresh", "Retry Refresh")
    static let refreshLog = text("refresh.log", "Refresh Log")
    static let refreshIdle = text("refresh.idle", "Ready to refresh")
    static let refreshReloading = text("refresh.reloading", "Reloading catalog collections...")
    static let refreshScanning = text("refresh.scanning", "Scanning skills across supported adapters and refreshing catalog...")
    static let refreshWatcherManual = text("refresh.watcherManual", "Automatic watcher events are not active in this native sidecar yet. Use Reload or Scan to refresh.")
    static let catalogNotLoaded = text("state.catalogNotLoaded", "Catalog not loaded")
    static let noSkillSelected = text("empty.noSkillSelected", "No Skill Selected")
    static let noSkillSelectedMessage = text("empty.noSkillSelected.message", "Reload the catalog or select a skill from the sidebar.")
    static let noFindings = text("empty.noFindings", "No Findings")
    static let noFindingsMessage = text("empty.noFindings.message", "No rule findings are associated with this skill.")
    static let noMatchingFindings = text("empty.noMatchingFindings", "No Matching Findings")
    static let noMatchingFindingsMessage = text("empty.noMatchingFindings.message", "Adjust the triage, severity, or rule filter to show findings.")
    static let noConflicts = text("empty.noConflicts", "No Conflicts")
    static let noConflictsMessage = text("empty.noConflicts.message", "No same-agent conflict currently references this skill in the current agent. Cross-agent duplicates are not shown as conflicts.")
    static let noSnapshots = text("empty.noSnapshots", "No Agent Config History")
    static let noSnapshotsMessage = text("empty.noSnapshots.message", "No agent config snapshots have been recorded for this agent yet.")
    static let snapshotPreview = text("snapshot.preview", "Agent Config Preview")
    static let rollbackSnapshotQuestion = text("snapshot.rollback.question", "Rollback Agent Config?")
    static let current = text("snapshot.current", "Current Agent Config")
    static let snapshot = text("snapshot.snapshot", "Snapshot Agent Config")
    static let agentConfigHistory = text("sidebar.agentConfigHistory", "Agent Config History")
    static let agentConfigHistorySummary = text("sidebar.agentConfigHistory.summary", "Preview or roll back saved configuration snapshots for the selected agent.")
    static let agentConfigTimeline = text("sidebar.agentConfigTimeline", "Agent Config Timeline")
    static let agentConfigTimelineBoundary = text("sidebar.agentConfigTimeline.boundary", "Config-level only: these rollback points capture agent configuration files, not SKILL.md content, and they do not mean every skill has its own snapshot.")
    static let agentConfigTimelineSelectAgent = text("sidebar.agentConfigTimeline.selectAgent", "Choose one agent to view its config timeline. All Agents never mixes rollback points.")
    static let agentConfigTimelineDefaultAction = text("sidebar.agentConfigTimeline.defaultAction", "Config snapshot")
    static let agentConfigTimelineStatus = text("sidebar.agentConfigTimeline.status", "Rollback point")
    static let previewDiff = text("action.previewDiff", "Preview diff")
    static let recentActivity = text("detail.recentActivity", "Recent Activity")
    static let noRecentActivity = text("detail.recentActivity.empty", "No enable or disable activity has been recorded for this skill yet.")
    static let loadingRecentActivity = text("detail.recentActivity.loading", "Loading activity...")
    static let activityPayload = text("detail.activity.payload", "Payload")
    static let emptyPlaceholder = text("value.empty", "<empty>")
    static let definition = text("metadata.definition", "Definition")
    static let catalogID = text("metadata.catalogId", "Catalog ID")
    static let source = text("metadata.source", "Source")
    static let provenanceRoot = text("metadata.provenanceRoot", "Root")
    static let provenanceKind = text("metadata.provenanceKind", "Kind")
    static let provenanceNativeKind = text("metadata.provenance.kind.native", "Native")
    static let provenanceCompatibilityKind = text("metadata.provenance.kind.compatibility", "Compatibility")
    static let provenanceInferredKind = text("metadata.provenance.kind.inferred", "Inferred")
    static let provenanceToolGlobalKind = text("metadata.provenance.kind.toolGlobal", "Tool-global")
    static let provenanceReadOnlyKind = text("metadata.provenance.kind.readOnly", "Read-only")
    static let provenanceExternalKind = text("metadata.provenance.kind.external", "External")
    static let provenanceNativeRoot = text("metadata.provenance.root.native", "native root")
    static let provenanceNativeOpencodeRoot = text("metadata.provenance.root.nativeOpencode", "Native opencode root")
    static let provenanceClaudeCompatibilityRoot = text("metadata.provenance.root.claudeCompatibility", "Claude compatibility root")
    static let provenanceAgentsCompatibilityRoot = text("metadata.provenance.root.agentsCompatibility", "Agents compatibility root")
    static let provenanceToolGlobalRoot = text("metadata.provenance.root.toolGlobal", "Tool-global staging")
    static let provenanceReadOnlyRoot = text("metadata.provenance.root.readOnly", "read-only root")
    static let provenanceExternalRoot = text("metadata.provenance.root.external", "External root")
    static let provenanceUnclassifiedRoot = text("metadata.provenance.root.unclassified", "Unclassified root")
    static let fingerprint = text("metadata.fingerprint", "Fingerprint")
    static let description = text("metadata.description", "Description")
    static let noDescription = text("metadata.noDescription", "No description")
    static let frontmatter = text("metadata.frontmatter", "Frontmatter")
    static let body = text("metadata.body", "Body")
    static let permissions = text("metadata.permissions", "Permissions")
    static let winner = text("metadata.winner", "Winner")
    static let none = text("value.none", "None")
    static let findingSeverityFilter = text("findings.filter.severity", "Severity")
    static let findingRuleFilter = text("findings.filter.rule", "Rule ID")
    static let findingTriageFilter = text("findings.filter.triage", "Triage")
    static let allSeverities = text("findings.filter.allSeverities", "All Severities")
    static let allRuleIDs = text("findings.filter.allRules", "All Rule IDs")
    static let findingTriageOpen = text("findings.triage.open", "Open")
    static let findingTriageReviewed = text("findings.triage.reviewed", "Reviewed")
    static let findingTriageIgnored = text("findings.triage.ignored", "Ignored")
    static let findingTriageNeedsFollowUp = text("findings.triage.needsFollowUp", "Needs follow-up")
    static let findingTriageFilterActive = text("findings.triage.filter.active", "Active")
    static let findingTriageFilterAll = text("findings.triage.filter.all", "All triage")
    static let findingTriageNoticeTitle = text("findings.triage.notice.title", "Local finding triage")
    static let findingTriageNoticeBody = text("findings.triage.notice.body", "Triage labels are stored only in SkillsCopilot app data. They do not write agent config, skill content, toggle snapshots, scripts, or AI output. If a finding changes after rescan, it reopens as Open.")
    static let findingTriageActionReviewed = text("findings.triage.action.reviewed", "Mark reviewed")
    static let findingTriageActionIgnored = text("findings.triage.action.ignored", "Ignore")
    static let findingTriageActionFollowUp = text("findings.triage.action.followUp", "Needs follow-up")
    static let findingTriageActionReopen = text("findings.triage.action.reopen", "Reopen")
    static let ruleTuningTitle = text("rules.tuning.title", "Rule Tuning / Suppression")
    static let ruleTuningBoundary = text("rules.tuning.boundary", "App-local review state only. These controls never edit skill files, write agent config, create snapshots, execute scripts, call an AI provider, or store credentials.")
    static let ruleTuningEffectiveState = text("rules.tuning.effectiveState", "Effective rule state")
    static let ruleTuningSeverityOverride = text("rules.tuning.severityOverride", "Severity override")
    static let ruleTuningClearSeverity = text("rules.tuning.clearSeverity", "Clear override")
    static let ruleTuningSuppressGroup = text("rules.tuning.suppressGroup", "Suppress group")
    static let ruleTuningUnsuppressGroup = text("rules.tuning.unsuppressGroup", "Unsuppress group")
    static let ruleTuningSuppressRule = text("rules.tuning.suppressRule", "Suppress rule")
    static let ruleTuningUnsuppressRule = text("rules.tuning.unsuppressRule", "Unsuppress rule")
    static let ruleTuningSuppressed = text("rules.tuning.suppressed", "Suppressed locally")
    static let ruleTuningRuleWide = text("rules.tuning.ruleWide", "Rule-wide")
    static let ruleTuningFindingGroup = text("rules.tuning.findingGroup", "Finding group")
    static let ruleTuningNoOverride = text("rules.tuning.noOverride", "No local override")
    static let findingExplanation = text("findings.explanation", "Why this appears")
    static let findingRuleID = text("findings.ruleId", "Rule ID")
    static let findingRuleSource = text("findings.ruleSource", "Rule source")
    static let findingCatalogTarget = text("findings.catalogTarget", "Catalog target")
    static let findingTrigger = text("findings.trigger", "Trigger")
    static let findingImpact = text("findings.impact", "Impact")
    static let findingRiskRelated = text("findings.riskRelated", "Risk-related")
    static let findingRiskRelatedHelp = text("findings.riskRelated.help", "This rule is part of the permission, script, dependency, or tool-risk subset.")
    static let findingRemediation = text("findings.remediation", "Suggested remediation")
    static let currentAgentConflictsOnly = text("conflicts.currentAgentOnly", "Current agent only. Cross-agent duplicates are omitted from conflicts.")
    static let findingSourceFrontmatter = text("findings.source.frontmatter", "Frontmatter validation")
    static let findingSourcePermission = text("findings.source.permission", "Permission analysis")
    static let findingSourceScript = text("findings.source.script", "Script safety analysis")
    static let findingSourceDependency = text("findings.source.dependency", "Dependency analysis")
    static let findingSourcePath = text("findings.source.path", "Catalog path check")
    static let findingSourceFingerprint = text("findings.source.fingerprint", "Catalog fingerprint check")
    static let findingSourceCatalog = text("findings.source.catalog", "Catalog rule")
    static let findingNoCatalogTarget = text("findings.catalogTarget.none", "No definition or instance ID reported")
    static let remediationFrontmatterRequired = text("findings.remediation.frontmatterRequired", "Add the required frontmatter fields in SKILL.md, then rescan.")
    static let remediationToolsNotEmpty = text("findings.remediation.toolsNotEmpty", "Declare the allowed tools the skill needs, or remove tool-dependent instructions.")
    static let remediationPathExists = text("findings.remediation.pathExists", "Restore the source file or remove the stale catalog entry, then scan again.")
    static let remediationFingerprintChanged = text("findings.remediation.fingerprintChanged", "Review the changed skill content and rescan once the catalog should trust the new fingerprint.")
    static let remediationNetworkDeclared = text("findings.remediation.networkDeclared", "Declare the intended network access explicitly, or keep it undeclared only if the skill does not use network access.")
    static let remediationExecNeedsHuman = text("findings.remediation.execNeedsHuman", "Require human confirmation for execution-capable behavior, or remove the execution request.")
    static let remediationDependencyUnknown = text("findings.remediation.dependencyUnknown", "Replace or document the unknown dependency, then rescan.")
    static let instances = text("metadata.instances", "Instances")
    static let target = text("metadata.target", "Target")
    static let scope = text("metadata.scope", "Scope")
    static let access = text("metadata.access", "Access")
    static let permissionTools = text("permissions.tools", "Tools")
    static let permissionFiles = text("permissions.files", "Files")
    static let permissionNetwork = text("permissions.network", "Network")
    static let permissionExec = text("permissions.exec", "Execution")
    static let permissionHumanReview = text("permissions.humanReview", "Human review")
    static let permissionRaw = text("permissions.raw", "Raw permissions")
    static let permissionUndeclared = text("permissions.undeclared", "Undeclared / unknown")
    static let permissionNoneDeclared = text("permissions.noneDeclared", "None declared")
    static let permissionUnknownPayload = text("permissions.unknownPayload", "Unknown payload")
    static let permissionNetworkReadOnly = text("permissions.network.readOnly", "Read-only declared")
    static let permissionNetworkFull = text("permissions.network.full", "Full declared")
    static let permissionRequested = text("permissions.requested", "Requested")
    static let permissionNotRequested = text("permissions.notRequested", "Not requested")
    static let permissionRequired = text("permissions.required", "Required")
    static let permissionNotDeclaredRequired = text("permissions.notDeclaredRequired", "Not declared as required")
    static let permissionUndeclaredNote = text("permissions.undeclaredNote", "Permissions are undeclared or unavailable in the catalog payload; this is not a safe or unsafe verdict.")
    static let permissionDeclarationNote = text("permissions.declarationNote", "These values are permission declarations from the catalog payload, not a safety verdict.")
    static let service = text("settings.service", "Service")
    static let version = text("settings.version", "Version")
    static let protocolLabel = text("settings.protocol", "Protocol")
    static let catalog = text("settings.catalog", "Catalog")
    static let userHome = text("settings.userHome", "User Home")
    static let methods = text("settings.methods", "Methods")
    static let unknown = text("value.unknown", "Unknown")
    static let notLoaded = text("value.notLoaded", "Not loaded")
    static let claudeSettings = text("settings.claudeSettings", "Claude Settings")
    static let existingFile = text("settings.existingFile", "Existing file")
    static let willCreateFile = text("settings.willCreateFile", "Will create file")
    static let settingsInvalidUTF8 = text("settings.invalidUtf8", "Settings content is not valid UTF-8.")
    static let jsonValidSettingsWrite = text("settings.jsonValid", "JSON is valid. Save will create an agent config snapshot, write atomically, verify, and rescan.")
    static let connectedProtocolNote = text("detail.protocolNote", "This native macOS shell is connected through the Rust service protocol. Scan, toggle, and agent config rollback actions use verified write paths with snapshots.")
    static let loadingSkillDetail = text("detail.loading", "Loading skill detail...")
    static let readOnlyPreview = text("detail.readOnlyPreview", "Read-only preview")
    static let toolGlobalPreviewTitle = text("detail.toolGlobal.previewTitle", "Tool-global Preview")
    static let toolGlobalPreviewNote = text("detail.toolGlobal.previewNote", "Tool-global skills are staged for review. They cannot be toggled here and must be copied into a specific agent after an explicit confirmation.")
    static let toolGlobalTargetAgent = text("detail.toolGlobal.targetAgent", "Target Agent")
    static let toolGlobalInstallPreviewTitle = text("detail.toolGlobal.installPreviewTitle", "Install Preview")
    static let toolGlobalInstallReady = text("detail.toolGlobal.installReady", "Confirmed install writes through the target adapter verified path with snapshot and read-back verification.")
    static let llmSkillAnalysis = text("llm.skillAnalysis", "AI Skill Analysis")
    static let llmSkillAnalysisSelectedScope = text("llm.skillAnalysis.scope.selected", "Selected skill")
    static let llmSkillAnalysisVisibleScope = text("llm.skillAnalysis.scope.visible", "Visible skills")
    static let llmSkillAnalysisSafetyTitle = text("llm.skillAnalysis.safetyTitle", "Read-only prepare only")
    static let llmSkillAnalysisSafetyCopy = text("llm.skillAnalysis.safetyCopy", "No provider call is made by default. This preview cannot write skill files or agent config, cannot execute scripts, and does not save credentials.")
    static let llmSkillAnalysisPrepareSelected = text("llm.skillAnalysis.prepareSelected", "Prepare Selected")
    static let llmSkillAnalysisPrepareVisible = text("llm.skillAnalysis.prepareVisible", "Prepare Visible")
    static let llmSkillAnalysisUnavailable = text("llm.skillAnalysis.unavailable", "AI skill analysis prepare is unavailable in this service build; preview remains disabled and read-only.")
    static let llmSkillAnalysisUnavailablePrompt = text("llm.skillAnalysis.unavailablePrompt", "Service method llm.prepareSkillAnalysis is unavailable. No provider request was prepared.")
    static let llmSkillAnalysisUnavailableSummary = text("llm.skillAnalysis.unavailableSummary", "Disabled fallback preview only. No writes, no scripts, no credentials, and no provider call.")
    static let llmSkillAnalysisPromptDraft = text("llm.skillAnalysis.promptDraft", "Prepared prompt draft")
    static let llmSkillAnalysisSummaryDraft = text("llm.skillAnalysis.summaryDraft", "Summary draft")
    static let llmSkillAnalysisIncludedSkills = text("llm.skillAnalysis.includedSkills", "Included skills")
    static let llmSkillAnalysisExcludedMissing = text("llm.skillAnalysis.excludedMissing", "Excluded / missing")
    static let llmSkillAnalysisNoDraft = text("llm.skillAnalysis.noDraft", "No draft text returned by the service.")
    static let llmSkillAnalysisNoIncludedSkills = text("llm.skillAnalysis.noIncludedSkills", "No included skills returned.")
    static let llmSkillAnalysisWriteBack = text("llm.skillAnalysis.writeBack", "Write-back")
    static let llmSkillAnalysisScriptExecution = text("llm.skillAnalysis.scriptExecution", "Script execution")
    static let llmSkillAnalysisCredentialStorage = text("llm.skillAnalysis.credentialStorage", "Credential storage")
    static let llmSkillAnalysisConfirmation = text("llm.skillAnalysis.confirmation", "Confirmation")
    static let llmSkillAnalysisBlocked = text("llm.skillAnalysis.blocked", "Blocked")
    static let llmSkillAnalysisRequired = text("llm.skillAnalysis.required", "Required")
    static let llmSkillAnalysisEnabledUnsafe = text("llm.skillAnalysis.enabledUnsafe", "Enabled by service")
    static let llmAssist = text("llm.assist", "LLM Assist")
    static let llmEnabled = text("llm.enabled", "Enabled")
    static let llmDisabled = text("llm.disabled", "Disabled")
    static let llmPreparing = text("llm.preparing", "Preparing...")
    static let llmPreparePrompt = text("llm.preparePrompt", "Choose an action to preview tokens and cost.")
    static let llmDisabledFallback = text("llm.disabledFallback", "LLM assist is unavailable in this build.")
    static let llmProvider = text("llm.provider", "Provider")
    static let llmModel = text("llm.model", "Model")
    static let llmTokens = text("llm.tokens", "Tokens")
    static let llmCost = text("llm.cost", "Cost")
    static let llmConfirmationRequired = text("llm.confirmationRequired", "Confirmation required before any LLM call.")
    static let llmDraftCopyRequired = text("llm.draftCopyRequired", "Draft output requires user confirmation and copy.")
    static let llmReviewPreview = text("llm.reviewPreview", "Read-only review preview")
    static let llmReviewPurpose = text("llm.reviewPurpose", "Purpose")
    static let llmReviewRisk = text("llm.reviewRisk", "Risk")
    static let llmReviewSignals = text("llm.reviewSignals", "Signals")
    static let llmReviewFindings = text("llm.reviewFindings", "Finding explanations")
    static let llmReviewCrossAgentFit = text("llm.reviewCrossAgentFit", "Cross-agent fit")
    static let llmReviewRedaction = text("llm.reviewRedaction", "Redaction")
    static let llmReviewNoFindings = text("llm.reviewNoFindings", "No finding explanations in this preview.")
    static let llmReviewNoSignals = text("llm.reviewNoSignals", "No risk signals in this preview.")
    static let llmReviewNoActions = text("llm.reviewNoActions", "No provider request, write action, or execution action is available from this preview.")
    static let scriptExecutionSafety = text("scriptExecution.safety", "Script Execution Safety")
    static let scriptExecutionPreviewOnly = text("scriptExecution.previewOnly", "Preview-only")
    static let scriptExecutionUnavailable = text("scriptExecution.unavailable", "Script execution preflight is unavailable in this service build. Scripts remain non-executable from the native UI.")
    static let scriptExecutionBlockedNote = text("scriptExecution.blockedNote", "The native UI does not execute scripts. Use this panel only to inspect the safety gate data returned by the service.")
    static let scriptExecutionPreviewSummary = text("scriptExecution.previewSummary", "Script execution is blocked by default until a separate confirmed service path is available.")
    static let scriptExecutionNoCommand = text("scriptExecution.noCommand", "No command preview is available.")
    static let scriptExecutionNoRisks = text("scriptExecution.noRisks", "No service risks were reported.")
    static let scriptExecutionNoAudit = text("scriptExecution.noAudit", "No audit identifier reported.")
    static let scriptExecutionAuditStatus = text("scriptExecution.auditStatus", "Audit status")
    static let scriptExecutionAuditID = text("scriptExecution.auditId", "Audit ID")
    static let scriptExecutionCommand = text("scriptExecution.command", "Command preview")
    static let scriptExecutionCWD = text("scriptExecution.cwd", "CWD")
    static let scriptExecutionEnv = text("scriptExecution.env", "Environment")
    static let scriptExecutionNetwork = text("scriptExecution.network", "Network")
    static let scriptExecutionFiles = text("scriptExecution.files", "Files")
    static let scriptExecutionRisks = text("scriptExecution.risks", "Risks")
    static let scriptExecutionConfirmationRequired = text("scriptExecution.confirmationRequired", "Human confirmation is required before any future execution service path.")
    static let scriptExecutionEnvEmpty = text("scriptExecution.envEmpty", "No environment overrides")
    static let scriptExecutionFilesEmpty = text("scriptExecution.filesEmpty", "No file scope declared")
    static let toggleUnavailableBusy = text("detail.toggleUnavailable.busy", "A write is already in progress.")
    static let toggleUnavailableBroken = text("detail.toggleUnavailable.broken", "Broken skills cannot be toggled until their SKILL.md can be parsed.")
    static let toggleUnavailableMissing = text("detail.toggleUnavailable.missing", "Missing skills cannot be toggled because the source file was not found during the last scan.")
    static let toggleUnavailableShadowed = text("detail.toggleUnavailable.shadowed", "Shadowed skills are read-only here; resolve the active copy before toggling.")
    static let toggleUnavailableUnknown = text("detail.toggleUnavailable.unknown", "This skill has an unknown catalog state and is read-only in this build.")
    static let toggleUnavailableToolGlobal = text("detail.toggleUnavailable.toolGlobal", "Tool-global skills are read-only previews. Install or copy to an agent requires a separate confirmed action.")
    static let operationUnavailableBusy = text("detail.operationUnavailable.busy", "Another catalog operation is already in progress.")
    static let readOnly = text("detail.readOnly", "Read-only")
    static let currentMatchesSnapshot = text("snapshot.matches", "Current agent config already matches this snapshot.")
    static let currentDiffersFromSnapshot = text("snapshot.differs", "Current agent config differs from this snapshot.")
    static let menuScanSkills = text("menu.scanSkills", "Scan Skills")
    static let menuReloadSkills = text("menu.reloadSkills", "Reload Skills")
    static let menuSkills = text("menu.skills", "Skills")
    static let menuShowOverview = text("menu.showOverview", "Show Overview")
    static let menuShowFindings = text("menu.showFindings", "Show Findings")
    static let menuShowConflicts = text("menu.showConflicts", "Show Same-agent Conflicts")
    static let menuClearSearch = text("menu.clearSearch", "Clear Search")

    static func enabledSummary(enabled: Int, total: Int) -> String {
        format("sidebar.enabledSummary", "%d of %d enabled", enabled, total)
    }

    static func visibleSummary(_ count: Int) -> String {
        format("sidebar.visibleSummary", "%d visible", count)
    }

    static func crossAgentComparisonFilterContext(_ agent: String) -> String {
        format("comparison.crossAgent.filterContext", "Context: %@ filter. Service data is preferred when available; otherwise this panel uses local catalog-only comparison.", agent)
    }

    static func agentConfigTimelineSummary(_ agent: String, _ count: Int) -> String {
        format("sidebar.agentConfigTimeline.summary", "%@ config snapshots · %d rollback points", agent, count)
    }

    static func agentConfigTimelineEmptySummary(_ agent: String) -> String {
        format("sidebar.agentConfigTimeline.emptySummary", "No %@ config snapshots yet", agent)
    }

    static func agentConfigTimelineMore(_ count: Int) -> String {
        format("sidebar.agentConfigTimeline.more", "%d older rollback points hidden to keep the sidebar quiet.", count)
    }

    static func agentConfigTimelineRollbackConfirm(_ target: String) -> String {
        format("sidebar.agentConfigTimeline.rollbackConfirm", "Rollback restores this agent config file only after confirmation. Skill content snapshots are not included. Target: %@", target)
    }

    static func visibleFindingsSummary(_ visible: Int, _ total: Int) -> String {
        format("findings.visibleSummary", "%d of %d findings", visible, total)
    }

    static func visibleFindingGroupsSummary(_ visibleGroups: Int, _ totalGroups: Int, _ visibleEntries: Int) -> String {
        format("findings.visibleGroupSummary", "%d of %d issue groups · %d scan entries", visibleGroups, totalGroups, visibleEntries)
    }

    static func findingSeverityGroupCount(_ count: Int) -> String {
        format("findings.severityGroupCount", "%d issue groups", count)
    }

    static func findingIssueImpact(_ instances: Int, _ entries: Int) -> String {
        format("findings.issueImpact", "Impacted instances: %d · Scan entries: %d", instances, entries)
    }

    static func findingTriageUpdated(_ status: String) -> String {
        format("findings.triage.updated", "Set local finding triage to %@. No agent config or skill files were changed.", status)
    }

    static let findingTriageReopened = text("findings.triage.reopened", "Reopened finding locally. No agent config or skill files were changed.")

    static func ruleTuningSetSeverity(_ severity: String) -> String {
        format("rules.tuning.setSeverity", "Set %@", severity)
    }

    static func ruleTuningSeverityUpdated(_ severity: String) -> String {
        format("rules.tuning.updated.severity", "Set app-local rule severity override to %@. No skill files, agent config, snapshots, scripts, AI provider calls, or credentials were touched.", severity)
    }

    static let ruleTuningSeverityCleared = text("rules.tuning.cleared.severity", "Cleared app-local rule severity override. No skill files or agent config were changed.")
    static let ruleTuningSuppressionUpdated = text("rules.tuning.updated.suppression", "Updated app-local rule suppression. No skill files, agent config, snapshots, scripts, AI provider calls, or credentials were touched.")
    static let ruleTuningSuppressionCleared = text("rules.tuning.cleared.suppression", "Cleared app-local rule suppression. No skill files or agent config were changed.")

    static func noFindingsForSkillMessage(_ agent: String) -> String {
        format("empty.noFindingsForSkill.message", "No rule findings are associated with this %@ skill.", agent)
    }

    static func findingScopeSummary(_ skill: String, _ agent: String) -> String {
        format("findings.scopeSummary", "%@ · %@", skill, agent)
    }

    static func findingCatalogTarget(definition: String, instance: String) -> String {
        format("findings.catalogTarget.definitionInstance", "Definition %@ · Instance %@", definition, instance)
    }

    static func findingCatalogDefinition(_ definition: String) -> String {
        format("findings.catalogTarget.definition", "Definition %@", definition)
    }

    static func findingCatalogInstance(_ instance: String) -> String {
        format("findings.catalogTarget.instance", "Instance %@", instance)
    }

    static func findingRemediationFallback(_ ruleID: String) -> String {
        format("findings.remediation.fallback", "Review rule %@, update the skill source, then rescan to confirm the finding is resolved.", ruleID)
    }

    static func permissionUnknownValue(_ value: String) -> String {
        format("permissions.unknownValue", "Unknown (%@)", value)
    }

    static func scannedSkills(_ count: Int) -> String {
        format("message.scannedSkills", "Scanned %d skills across supported adapters.", count)
    }

    static func refreshReloaded(_ skills: Int, _ findings: Int, _ conflicts: Int) -> String {
        format("refresh.reloaded", "Reloaded %d skills, %d findings, and %d same-agent conflicts.", skills, findings, conflicts)
    }

    static func refreshScanComplete(_ scanned: Int, _ skills: Int, _ findings: Int, _ conflicts: Int) -> String {
        format("refresh.scanComplete", "Scan complete: %d scanned, %d in catalog, %d findings, %d same-agent conflicts.", scanned, skills, findings, conflicts)
    }

    static func refreshFailed(_ reason: String) -> String {
        format("refresh.failed", "Refresh failed: %@. Retry when the issue is fixed.", reason)
    }

    static func stateUnknownValue(_ value: String) -> String {
        format("state.unknownValue", "Unknown (%@)", value)
    }

    static func toggleUnavailableReadOnlyAdapter(_ agent: String) -> String {
        format("detail.toggleUnavailable.readOnlyAdapter", "%@ skills are read-only in this build.", agent)
    }

    static func adapterNotImplementedMessage(_ agent: String) -> String {
        format("empty.adapterNotImplemented.message", "%@ adapter is not implemented yet. Check the capability status above for the current blocker.", agent)
    }

    static func readOnlyAdapterStatus(_ agent: String) -> String {
        format("detail.readOnlyAdapterStatus", "%@ adapter is read-only in this build.", agent)
    }

    static func toolGlobalAccessStatus(_ agent: String) -> String {
        format("detail.toolGlobal.accessStatus", "%@ tool-global staging is a read-only preview until installed into a specific agent.", agent)
    }

    static func toolGlobalInstallPreviewSummary(_ skill: String, _ agent: String) -> String {
        format("detail.toolGlobal.installPreviewSummary", "Preview copying %@ into %@. No files are written from this preview.", skill, agent)
    }

    static func toolGlobalInstallConfirmation(_ skill: String, _ agent: String) -> String {
        format("detail.toolGlobal.installConfirmation", "Installing %@ into %@ will require confirmation of the target path and adapter write semantics before any copy happens.", skill, agent)
    }

    static func toolGlobalInstalled(_ skill: String, _ agent: String) -> String {
        format("message.toolGlobalInstalled", "Installed %@ into %@.", skill, agent)
    }

    static func batchToggleSelectedCount(_ count: Int) -> String {
        format("batchToggle.selectedCount", "%d visible", count)
    }

    static func batchToggleActionTarget(_ action: String) -> String {
        format("batchToggle.actionTarget", "Target: %@", action)
    }

    static func batchToggleAffectedSkills(_ count: Int) -> String {
        format("batchToggle.affectedSkills", "Affected skills (%d)", count)
    }

    static func batchToggleSkippedSkills(_ count: Int) -> String {
        format("batchToggle.skippedSkills", "Skipped read-only / ineligible (%d)", count)
    }

    static func batchToggleConfirmTitle(action: String, count: Int) -> String {
        format("batchToggle.confirm.title", "Apply %@ to %d writable skills?", action, count)
    }

    static func batchToggleConfirmApply(action: String, count: Int) -> String {
        format("batchToggle.confirm.apply", "Apply %@ to %d skills", action, count)
    }

    static func batchToggleConfirmMessage(action: String, affected: Int, skipped: Int, snapshot: String) -> String {
        format(
            "batchToggle.confirm.message",
            "This will %@ %d writable skills and skip %d read-only, ineligible, or no-op skills. %@",
            action,
            affected,
            skipped,
            snapshot
        )
    }

    static func batchToggleMoreItems(_ count: Int) -> String {
        format("batchToggle.moreItems", "%d more hidden to keep the sidebar compact.", count)
    }

    static func batchToggleAlreadyInTargetState(_ action: String) -> String {
        format("batchToggle.alreadyTarget", "Already %@", action)
    }

    static func batchToggleCapabilityMissing(_ agent: String) -> String {
        format("batchToggle.capabilityMissing", "%@ writable capability is not verified in this service response.", agent)
    }

    static func batchToggleWritableMissing(_ agent: String) -> String {
        format("batchToggle.writableMissing", "%@ root is not verified writable.", agent)
    }

    static func batchToggleApplied(action: String, count: Int) -> String {
        format("batchToggle.applied", "%@ batch applied to %d writable skills after preview confirmation.", action, count)
    }

    static func toggledSkill(on: Bool, name: String) -> String {
        format(on ? "message.enabledSkill" : "message.disabledSkill", on ? "Enabled %@." : "Disabled %@.", name)
    }

    static func toggledSkill(on: Bool, name: String, agent: String) -> String {
        let message = toggledSkill(on: on, name: name)
        if agent == "codex" {
            return "\(message) \(codexRestartRequired)"
        }
        return message
    }

    static let codexRestartRequired = text("message.codexRestartRequired", "Codex runtime may need restart to read config.toml changes.")

    static func rollbackRescanned(_ count: Int) -> String {
        format("message.rollbackRescanned", "Rolled back agent config snapshot and rescanned %d skills.", count)
    }

    static let refreshAfterWrite = text("refresh.afterWrite", "Catalog refreshed after the settings write.")

    static func refreshAfterRollback(_ count: Int) -> String {
        format("refresh.afterRollback", "Catalog refreshed after agent config rollback with %d scanned skills.", count)
    }

    static let refreshAfterSettingsSave = text("refresh.afterSettingsSave", "Catalog refreshed after saving settings.")

    static func charactersCaptured(_ count: Int) -> String {
        format("snapshot.charactersCaptured", "%d characters captured", count)
    }

    static func llmTokenSummary(input: Int, output: Int, total: Int) -> String {
        format("llm.tokenSummary", "%d in / %d out / %d total", input, output, total)
    }

    static func llmEstimatedCost(_ cost: Double) -> String {
        format("llm.estimatedCost", "$%.4f estimated", cost)
    }

    static func activityToggleState(enabled: Bool) -> String {
        format("detail.activity.toggleState", "Set to %@", enabled ? stateEnabled : stateDisabled)
    }

    static func scriptExecutionAuditStatusTitle(_ status: ScriptExecutionAuditStatus) -> String {
        switch status {
        case .unavailable:
            return text("scriptExecution.auditStatus.unavailable", "Unavailable")
        case .previewOnly:
            return text("scriptExecution.auditStatus.previewOnly", "Preview only")
        case .blocked:
            return text("scriptExecution.auditStatus.blocked", "Blocked")
        case .requiresConfirmation:
            return text("scriptExecution.auditStatus.requiresConfirmation", "Requires confirmation")
        case .audited:
            return text("scriptExecution.auditStatus.audited", "Audited")
        case .unknown:
            return text("scriptExecution.auditStatus.unknown", "Unknown")
        }
    }

    static let savedSettings = text("message.savedSettings", "Saved settings and refreshed catalog.")

    static func projectSelectedAndScanned(_ name: String) -> String {
        format("message.projectSelectedAndScanned", "Selected %@ and refreshed catalog.", name)
    }

    static let projectClearedAndScanned = text("message.projectClearedAndScanned", "Cleared project context and refreshed catalog.")
    static let projectScanSkippedValidation = text("refresh.projectValidationSkipped", "Project context needs attention before scanning.")

    static func projectValidationFailed(_ reason: String) -> String {
        format("project.validationFailed", "Project validation failed: %@.", reason)
    }

    static func cleanupAgentFilterNote(_ agent: String) -> String {
        format("cleanup.filter.agentNote", "Agent filter: %@", agent)
    }

    static func text(_ key: String, _ defaultValue: String) -> String {
        NSLocalizedString(key, tableName: nil, bundle: .main, value: defaultValue, comment: "")
    }

    private static func format(_ key: String, _ defaultValue: String, _ arguments: CVarArg...) -> String {
        String(format: text(key, defaultValue), arguments: arguments)
    }
}
