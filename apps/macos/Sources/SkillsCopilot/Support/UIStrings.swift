import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    static let storageKey = "app.language"
    static let defaultLanguage = AppLanguage.english

    var id: String { rawValue }

    var localeIdentifier: String { rawValue }

    var title: String {
        switch self {
        case .english:
            return UIStrings.languageEnglish
        case .simplifiedChinese:
            return UIStrings.languageSimplifiedChinese
        }
    }

    static func fromStorage(_ rawValue: String?) -> AppLanguage {
        guard let rawValue, let language = AppLanguage(rawValue: rawValue) else {
            return defaultLanguage
        }
        return language
    }
}

enum UIStrings {
    static var appTitle: String { text("app.title", "Skills Copilot") }
    static var appWindowTitle: String { text("app.windowTitle", "SkillsCopilot") }
    static var searchPrompt: String { text("search.prompt", "Search") }
    static var scan: String { text("action.scan", "Scan") }
    static var reload: String { text("action.reload", "Reload") }
    static var save: String { text("action.save", "Save") }
    static var done: String { text("action.done", "Done") }
    static var cancel: String { text("action.cancel", "Cancel") }
    static var enable: String { text("action.enable", "Enable") }
    static var disable: String { text("action.disable", "Disable") }
    static var preview: String { text("action.preview", "Preview") }
    static var previewGate: String { text("action.previewGate", "Preview Gate") }
    static var executionBlocked: String { text("action.executionBlocked", "Execution Blocked") }
    static var rollback: String { text("action.rollback", "Rollback") }
    static var installToAgent: String { text("action.installToAgent", "Install to Agent...") }
    static var confirmInstall: String { text("action.confirmInstall", "Confirm Install") }
    static var llmAnalyze: String { text("llm.action.analyze", "Analyze") }
    static var llmRecommend: String { text("llm.action.recommend", "Recommend") }
    static var llmExplainConflict: String { text("llm.action.explainConflict", "Explain Same-agent Conflict") }
    static var llmDraftFrontmatter: String { text("llm.action.draftFrontmatter", "Draft Frontmatter") }
    static var chooseProject: String { text("action.chooseProject", "Choose Project") }
    static var clearProject: String { text("action.clearProject", "Clear Project") }
    static var revealInFinder: String { text("action.revealInFinder", "Reveal in Finder") }
    static var skills: String { text("nav.skills", "Skills") }
    static var project: String { text("nav.project", "Project") }
    static var view: String { text("nav.view", "View") }
    static var agent: String { text("filter.agent", "Agent") }
    static var state: String { text("filter.state", "State") }
    static var sort: String { text("filter.sort", "Sort") }
    static var claudeCode: String { text("agent.claudeCode", "Claude Code") }
    static var codex: String { text("agent.codex", "Codex") }
    static var opencode: String { text("agent.opencode", "opencode") }
    static var pi: String { text("agent.pi", "Pi") }
    static var hermes: String { text("agent.hermes", "Hermes") }
    static var openclaw: String { text("agent.openclaw", "OpenClaw") }
    static var detailSection: String { text("detail.section", "Detail Section") }
    static var overview: String { text("detail.overview", "Overview") }
    static var findings: String { text("detail.findings", "Findings") }
    static var conflicts: String { text("detail.conflicts", "Conflicts") }
    static var cleanupQueue: String { text("cleanup.queue", "Cleanup Queue") }
    static var cleanupKindFinding: String { text("cleanup.kind.finding", "Findings") }
    static var cleanupKindIntegrity: String { text("cleanup.kind.integrity", "Integrity") }
    static var cleanupKindConflict: String { text("cleanup.kind.conflict", "Same-agent conflicts") }
    static var cleanupKindAnalysis: String { text("cleanup.kind.analysis", "Analysis insights") }
    static var cleanupPriorityCritical: String { text("cleanup.priority.critical", "Critical") }
    static var cleanupPriorityHigh: String { text("cleanup.priority.high", "High") }
    static var cleanupPriorityMedium: String { text("cleanup.priority.medium", "Medium") }
    static var cleanupPriorityLow: String { text("cleanup.priority.low", "Low") }
    static var cleanupPriorityInfo: String { text("cleanup.priority.info", "Info") }
    static var cleanupFilterKind: String { text("cleanup.filter.kind", "Kind") }
    static var cleanupFilterPriority: String { text("cleanup.filter.priority", "Priority") }
    static var cleanupFilterAllKinds: String { text("cleanup.filter.allKinds", "All kinds") }
    static var cleanupFilterAllPriorities: String { text("cleanup.filter.allPriorities", "All priorities") }
    static var cleanupFilterCriticalHigh: String { text("cleanup.filter.criticalHigh", "Critical / High") }
    static var cleanupFilterLowInfo: String { text("cleanup.filter.lowInfo", "Low / Info") }
    static var cleanupUntitledItem: String { text("cleanup.item.untitled", "Cleanup item") }
    static var cleanupDefaultNextAction: String { text("cleanup.item.nextAction", "Open detail") }
    static var cleanupUnavailableFallback: String { text("cleanup.unavailableFallback", "Cleanup Queue is unavailable in this service build. Showing a local empty read-only fallback; no writes, scripts, AI provider calls, or credentials are used.") }
    static var cleanupQueueReadOnlyBoundary: String { text("cleanup.readOnlyBoundary", "Work through open findings, integrity issues, same-agent conflicts, and analysis insights from one read-only queue. Actions only open existing detail views; they do not write agent config, edit skills, execute scripts, call an AI provider, or store credentials.") }
    static var cleanupEmptyTitle: String { text("cleanup.empty.title", "No Cleanup Queue items") }
    static var cleanupEmptyMessage: String { text("cleanup.empty.message", "There are no open cleanup items for the current service response.") }
    static var cleanupNoFilteredItems: String { text("cleanup.empty.filtered", "No queue items match the selected kind, priority, and agent filters.") }
    static var cleanupAIBlocked: String { text("cleanup.safety.aiBlocked", "AI blocked") }
    static var cleanupCredentialsBlocked: String { text("cleanup.safety.credentialsBlocked", "Credentials blocked") }
    static var cleanupOpenExistingDetailHelp: String { text("cleanup.action.openExistingDetail.help", "Open the existing read-only detail section for this item.") }
    static var crossAgentComparisonTitle: String { text("comparison.crossAgent.title", "Cross-agent Comparison") }
    static var crossAgentComparisonBoundary: String { text("comparison.crossAgent.boundary", "Compare same-name or similar skills across Claude Code, Codex, opencode, Pi, Hermes, and OpenClaw by state, source, scope/root, findings, writable capability, and differences. This view is read-only: it cannot write config, edit skills, create snapshots, execute scripts, call an AI provider, or read credentials.") }
    static var crossAgentComparisonGroups: String { text("comparison.crossAgent.groups", "Groups") }
    static var crossAgentComparisonAgents: String { text("comparison.crossAgent.agents", "Agents") }
    static var crossAgentComparisonRiskGroups: String { text("comparison.crossAgent.riskGroups", "Risk groups") }
    static var crossAgentComparisonWritableMismatch: String { text("comparison.crossAgent.writableMismatch", "Writable mismatch") }
    static var crossAgentComparisonDifferences: String { text("comparison.crossAgent.differences", "Differences") }
    static var crossAgentComparisonWritable: String { text("comparison.crossAgent.writable", "Writable verified") }
    static var crossAgentComparisonUntitled: String { text("comparison.crossAgent.untitled", "Comparison group") }
    static var crossAgentComparisonMatchName: String { text("comparison.crossAgent.match.name", "Same or similar name") }
    static var crossAgentComparisonMatchSimilarName: String { text("comparison.crossAgent.match.similarName", "Similar name with definition differences") }
    static var crossAgentComparisonNoSelectedGroup: String { text("comparison.crossAgent.empty.selected", "No selected-skill comparison group") }
    static var crossAgentComparisonNoSelectedGroupMessage: String { text("comparison.crossAgent.empty.selected.message", "The selected skill does not currently share a same-name or similar cross-agent group in this catalog/filter context.") }
    static var crossAgentComparisonLocalFallback: String { text("comparison.crossAgent.localFallback", "Comparison service is unavailable in this build. Showing a local read-only catalog comparison fallback.") }
    static var crossAgentComparisonDifferenceEnabled: String { text("comparison.crossAgent.difference.enabled", "Enabled state differs") }
    static var crossAgentComparisonDifferenceWritable: String { text("comparison.crossAgent.difference.writable", "Writable capability differs") }
    static var crossAgentComparisonDifferenceSource: String { text("comparison.crossAgent.difference.source", "Source/root differs") }
    static var crossAgentComparisonDifferenceFindings: String { text("comparison.crossAgent.difference.findings", "Finding counts differ") }
    static var crossAgentComparisonDifferenceDefinition: String { text("comparison.crossAgent.difference.definition", "Definition IDs differ") }
    static var batchToggleTitle: String { text("batchToggle.title", "Safe Batch") }
    static var batchToggleBoundary: String { text("batchToggle.boundary", "Preview-first enable/disable for visible skills only. Read-only adapters and unverified writable roots are skipped; no scripts, AI provider calls, credentials, skill-content writes, or public release actions are available.") }
    static var batchToggleTarget: String { text("batchToggle.target", "Batch target") }
    static var batchToggleSelected: String { text("batchToggle.selected", "Selected") }
    static var batchToggleWritable: String { text("batchToggle.writable", "Writable") }
    static var batchToggleSkipped: String { text("batchToggle.skipped", "Skipped") }
    static var batchToggleApply: String { text("batchToggle.apply", "Apply") }
    static var batchTogglePreviewing: String { text("batchToggle.previewing", "Preparing batch preview...") }
    static var batchToggleSnapshotPlan: String { text("batchToggle.snapshotPlan", "Snapshot / rollback plan") }
    static var batchToggleSnapshotPlanDefault: String { text("batchToggle.snapshotPlan.default", "Service will create agent-config snapshots for writable adapter targets before applying, then use existing rollback support for those config files.") }
    static var batchToggleSnapshotPlanUnavailable: String { text("batchToggle.snapshotPlan.unavailable", "Service batch preview is unavailable, so apply is disabled. No files were written.") }
    static var batchToggleServicePreviewUnavailable: String { text("batchToggle.servicePreviewUnavailable", "Service batch preview method is unavailable. This is a local read-only eligibility estimate; apply is disabled until batch.applySkillToggles or batch.applyToggle is available.") }
    static var batchToggleApplyUnavailable: String { text("batchToggle.applyUnavailable", "Batch apply is unavailable until a service preview/apply pair confirms the snapshot plan.") }
    static var batchToggleNoWritableChanges: String { text("batchToggle.noWritableChanges", "No writable skill changes are available in this preview.") }
    static var batchToggleNoAffectedSkills: String { text("batchToggle.noAffectedSkills", "No writable affected skills in this preview.") }
    static var batchToggleNoSkippedSkills: String { text("batchToggle.noSkippedSkills", "No skipped skills in this preview.") }
    static var batchTogglePreviewChanged: String { text("batchToggle.previewChanged", "Batch preview changed before confirmation. Preview again before applying.") }
    static var localReportTitle: String { text("localReport.title", "Local Report Export") }
    static var localReportBoundary: String { text("localReport.boundary", "User-triggered local redacted audit export only. No public distribution, provider calls, credentials, script execution, config mutation, or background sync.") }
    static var localReportFormat: String { text("localReport.format", "Format") }
    static var localReportFormatMarkdown: String { text("localReport.format.markdown", "Markdown") }
    static var localReportFormatJSON: String { text("localReport.format.json", "JSON") }
    static var localReportExport: String { text("localReport.export", "Export") }
    static var localReportExporting: String { text("localReport.exporting", "Exporting local report...") }
    static var localReportUnavailableFallback: String { text("localReport.unavailableFallback", "Local report export is unavailable in this service build. No file was written.") }
    static var localReportNoFile: String { text("localReport.noFile", "No local file") }
    static var localReportNoSections: String { text("localReport.noSections", "No section list returned") }
    static var localReportExportedSummary: String { text("localReport.exportedSummary", "Local redacted report exported.") }
    static var localReportSections: String { text("localReport.sections", "Sections") }
    static var localReportRedacted: String { text("localReport.redacted", "Redacted") }
    static var localReportNotRedactedWarning: String { text("localReport.notRedactedWarning", "Service did not mark this report as redacted. Review before sharing.") }
    static var noSkillsInCatalog: String { text("empty.noSkillsInCatalog", "No skills in catalog") }
    static var noSkillsMatchSearch: String { text("empty.noSkillsMatchSearch", "No skills match this search") }
    static var noProjectSelected: String { text("project.none", "No Project") }
    static var projectChoosePrompt: String { text("project.choosePrompt", "Choose a project or OpenClaw workspace directory to scan project-scoped Claude, Codex, opencode, and workspace-scoped OpenClaw skills.") }
    static var projectSelectedSource: String { text("project.source.selected", "Selected project") }
    static var projectGlobalRootsOnly: String { text("project.source.globalOnly", "No project: global roots only") }
    static var recentProjects: String { text("project.recent", "Recent Projects") }
    static var noRecentProjects: String { text("project.noRecent", "No Recent Projects") }
    static var projectValidation: String { text("project.validation", "Project Validation") }
    static var noProjectSkillsMessage: String { text("empty.noProjectSkills.message", "No skills were found in global roots. Choose a project to include project-scoped skills, then scan.") }
    static var noCodexProjectMessage: String { text("empty.noCodexProject.message", "No Codex skills match the current global roots. Choose a project to include project-scoped Codex skills.") }
    static var noCodexSkillsMessage: String { text("empty.noCodexSkills.message", "No Codex skills match the current search or filters.") }
    static var noOpenClawWorkspaceSkillsMessage: String { text("empty.noOpenClawWorkspace.message", "No OpenClaw workspace skills match this view. OpenClaw only scans confirmed workspace roots: <workspace>/skills and <workspace>/.agents/skills; generic repo roots are skipped rather than treated as missing skills.") }
    static var adapterCapabilities: String { text("sidebar.adapterCapabilities", "Adapter Capabilities") }
    static var adapterScan: String { text("adapter.capability.scan", "Scan") }
    static var adapterToggle: String { text("adapter.capability.toggle", "Toggle") }
    static var adapterInstall: String { text("adapter.capability.install", "Install") }
    static var loading: String { text("state.loading", "Loading...") }
    static var stateEnabled: String { text("state.enabled", "Enabled") }
    static var stateDisabled: String { text("state.disabled", "Disabled") }
    static var stateBroken: String { text("state.broken", "Broken") }
    static var stateMissing: String { text("state.missing", "Missing") }
    static var stateShadowed: String { text("state.shadowed", "Shadowed") }
    static var stateUnknown: String { text("state.unknown", "Unknown") }
    static var retryRefresh: String { text("action.retryRefresh", "Retry Refresh") }
    static var refreshLog: String { text("refresh.log", "Refresh Log") }
    static var refreshIdle: String { text("refresh.idle", "Ready to refresh") }
    static var refreshReloading: String { text("refresh.reloading", "Reloading catalog collections...") }
    static var refreshScanning: String { text("refresh.scanning", "Scanning skills across supported adapters and refreshing catalog...") }
    static var refreshWatcherManual: String { text("refresh.watcherManual", "Automatic watcher events are not active in this native sidecar yet. Use Reload or Scan to refresh.") }
    static var catalogNotLoaded: String { text("state.catalogNotLoaded", "Catalog not loaded") }
    static var noSkillSelected: String { text("empty.noSkillSelected", "No Skill Selected") }
    static var noSkillSelectedMessage: String { text("empty.noSkillSelected.message", "Reload the catalog or select a skill from the sidebar.") }
    static var noFindings: String { text("empty.noFindings", "No Findings") }
    static var noFindingsMessage: String { text("empty.noFindings.message", "No rule findings are associated with this skill.") }
    static var noMatchingFindings: String { text("empty.noMatchingFindings", "No Matching Findings") }
    static var noMatchingFindingsMessage: String { text("empty.noMatchingFindings.message", "Adjust the triage, severity, or rule filter to show findings.") }
    static var noConflicts: String { text("empty.noConflicts", "No Conflicts") }
    static var noConflictsMessage: String { text("empty.noConflicts.message", "No same-agent conflict currently references this skill in the current agent. Cross-agent duplicates are not shown as conflicts.") }
    static var noSnapshots: String { text("empty.noSnapshots", "No Agent Config History") }
    static var noSnapshotsMessage: String { text("empty.noSnapshots.message", "No agent config snapshots have been recorded for this agent yet.") }
    static var snapshotPreview: String { text("snapshot.preview", "Agent Config Preview") }
    static var rollbackSnapshotQuestion: String { text("snapshot.rollback.question", "Rollback Agent Config?") }
    static var current: String { text("snapshot.current", "Current Agent Config") }
    static var snapshot: String { text("snapshot.snapshot", "Snapshot Agent Config") }
    static var agentConfigHistory: String { text("sidebar.agentConfigHistory", "Agent Config History") }
    static var agentConfigHistorySummary: String { text("sidebar.agentConfigHistory.summary", "Preview or roll back saved configuration snapshots for the selected agent.") }
    static var agentConfigTimeline: String { text("sidebar.agentConfigTimeline", "Agent Config Timeline") }
    static var agentConfigTimelineBoundary: String { text("sidebar.agentConfigTimeline.boundary", "Config-level only: these rollback points capture agent configuration files, not SKILL.md content, and they do not mean every skill has its own snapshot.") }
    static var agentConfigTimelineSelectAgent: String { text("sidebar.agentConfigTimeline.selectAgent", "Choose one agent to view its config timeline. All Agents never mixes rollback points.") }
    static var agentConfigTimelineDefaultAction: String { text("sidebar.agentConfigTimeline.defaultAction", "Config snapshot") }
    static var agentConfigTimelineStatus: String { text("sidebar.agentConfigTimeline.status", "Rollback point") }
    static var previewDiff: String { text("action.previewDiff", "Preview diff") }
    static var recentActivity: String { text("detail.recentActivity", "Recent Activity") }
    static var noRecentActivity: String { text("detail.recentActivity.empty", "No enable or disable activity has been recorded for this skill yet.") }
    static var loadingRecentActivity: String { text("detail.recentActivity.loading", "Loading activity...") }
    static var activityPayload: String { text("detail.activity.payload", "Payload") }
    static var emptyPlaceholder: String { text("value.empty", "<empty>") }
    static var definition: String { text("metadata.definition", "Definition") }
    static var catalogID: String { text("metadata.catalogId", "Catalog ID") }
    static var source: String { text("metadata.source", "Source") }
    static var provenanceRoot: String { text("metadata.provenanceRoot", "Root") }
    static var provenanceKind: String { text("metadata.provenanceKind", "Kind") }
    static var provenanceNativeKind: String { text("metadata.provenance.kind.native", "Native") }
    static var provenanceCompatibilityKind: String { text("metadata.provenance.kind.compatibility", "Compatibility") }
    static var provenanceInferredKind: String { text("metadata.provenance.kind.inferred", "Inferred") }
    static var provenanceToolGlobalKind: String { text("metadata.provenance.kind.toolGlobal", "Tool-global") }
    static var provenanceReadOnlyKind: String { text("metadata.provenance.kind.readOnly", "Read-only") }
    static var provenanceExternalKind: String { text("metadata.provenance.kind.external", "External") }
    static var provenanceNativeRoot: String { text("metadata.provenance.root.native", "native root") }
    static var provenanceNativeOpencodeRoot: String { text("metadata.provenance.root.nativeOpencode", "Native opencode root") }
    static var provenanceClaudeCompatibilityRoot: String { text("metadata.provenance.root.claudeCompatibility", "Claude compatibility root") }
    static var provenanceAgentsCompatibilityRoot: String { text("metadata.provenance.root.agentsCompatibility", "Agents compatibility root") }
    static var provenanceToolGlobalRoot: String { text("metadata.provenance.root.toolGlobal", "Tool-global staging") }
    static var provenanceReadOnlyRoot: String { text("metadata.provenance.root.readOnly", "read-only root") }
    static var provenanceExternalRoot: String { text("metadata.provenance.root.external", "External root") }
    static var provenanceHermesHomeProfileRoot: String { text("metadata.provenance.root.hermesHomeProfile", "Hermes home/profile root") }
    static var provenanceHermesExternalRoot: String { text("metadata.provenance.root.hermesExternal", "Hermes explicit external root") }
    static var provenanceOpenClawWorkspaceRoot: String { text("metadata.provenance.root.openClawWorkspace", "OpenClaw workspace root") }
    static var provenanceOpenClawReadOnlyRoot: String { text("metadata.provenance.root.openClawReadOnly", "OpenClaw read-only root") }
    static var provenanceUnclassifiedRoot: String { text("metadata.provenance.root.unclassified", "Unclassified root") }
    static var fingerprint: String { text("metadata.fingerprint", "Fingerprint") }
    static var description: String { text("metadata.description", "Description") }
    static var noDescription: String { text("metadata.noDescription", "No description") }
    static var frontmatter: String { text("metadata.frontmatter", "Frontmatter") }
    static var body: String { text("metadata.body", "Body") }
    static var permissions: String { text("metadata.permissions", "Permissions") }
    static var winner: String { text("metadata.winner", "Winner") }
    static var none: String { text("value.none", "None") }
    static var findingSeverityFilter: String { text("findings.filter.severity", "Severity") }
    static var findingRuleFilter: String { text("findings.filter.rule", "Rule ID") }
    static var findingTriageFilter: String { text("findings.filter.triage", "Triage") }
    static var allSeverities: String { text("findings.filter.allSeverities", "All Severities") }
    static var allRuleIDs: String { text("findings.filter.allRules", "All Rule IDs") }
    static var findingTriageOpen: String { text("findings.triage.open", "Open") }
    static var findingTriageReviewed: String { text("findings.triage.reviewed", "Reviewed") }
    static var findingTriageIgnored: String { text("findings.triage.ignored", "Ignored") }
    static var findingTriageNeedsFollowUp: String { text("findings.triage.needsFollowUp", "Needs follow-up") }
    static var findingTriageFilterActive: String { text("findings.triage.filter.active", "Active") }
    static var findingTriageFilterAll: String { text("findings.triage.filter.all", "All triage") }
    static var findingTriageNoticeTitle: String { text("findings.triage.notice.title", "Local finding triage") }
    static var findingTriageNoticeBody: String { text("findings.triage.notice.body", "Triage labels are stored only in SkillsCopilot app data. They do not write agent config, skill content, toggle snapshots, scripts, or AI output. If a finding changes after rescan, it reopens as Open.") }
    static var findingTriageActionReviewed: String { text("findings.triage.action.reviewed", "Mark reviewed") }
    static var findingTriageActionIgnored: String { text("findings.triage.action.ignored", "Ignore") }
    static var findingTriageActionFollowUp: String { text("findings.triage.action.followUp", "Needs follow-up") }
    static var findingTriageActionReopen: String { text("findings.triage.action.reopen", "Reopen") }
    static var ruleTuningTitle: String { text("rules.tuning.title", "Rule Tuning / Suppression") }
    static var ruleTuningBoundary: String { text("rules.tuning.boundary", "App-local review state only. These controls never edit skill files, write agent config, create snapshots, execute scripts, call an AI provider, or store credentials.") }
    static var ruleTuningEffectiveState: String { text("rules.tuning.effectiveState", "Effective rule state") }
    static var ruleTuningSeverityOverride: String { text("rules.tuning.severityOverride", "Severity override") }
    static var ruleTuningClearSeverity: String { text("rules.tuning.clearSeverity", "Clear override") }
    static var ruleTuningSuppressGroup: String { text("rules.tuning.suppressGroup", "Suppress group") }
    static var ruleTuningUnsuppressGroup: String { text("rules.tuning.unsuppressGroup", "Unsuppress group") }
    static var ruleTuningSuppressRule: String { text("rules.tuning.suppressRule", "Suppress rule") }
    static var ruleTuningUnsuppressRule: String { text("rules.tuning.unsuppressRule", "Unsuppress rule") }
    static var ruleTuningSuppressed: String { text("rules.tuning.suppressed", "Suppressed locally") }
    static var ruleTuningRuleWide: String { text("rules.tuning.ruleWide", "Rule-wide") }
    static var ruleTuningFindingGroup: String { text("rules.tuning.findingGroup", "Finding group") }
    static var ruleTuningNoOverride: String { text("rules.tuning.noOverride", "No local override") }
    static var findingExplanation: String { text("findings.explanation", "Why this appears") }
    static var findingRuleID: String { text("findings.ruleId", "Rule ID") }
    static var findingRuleSource: String { text("findings.ruleSource", "Rule source") }
    static var findingCatalogTarget: String { text("findings.catalogTarget", "Catalog target") }
    static var findingTrigger: String { text("findings.trigger", "Trigger") }
    static var findingImpact: String { text("findings.impact", "Impact") }
    static var findingRiskRelated: String { text("findings.riskRelated", "Risk-related") }
    static var findingRiskRelatedHelp: String { text("findings.riskRelated.help", "This rule is part of the permission, script, dependency, or tool-risk subset.") }
    static var findingRemediation: String { text("findings.remediation", "Suggested remediation") }
    static var currentAgentConflictsOnly: String { text("conflicts.currentAgentOnly", "Current agent only. Cross-agent duplicates are omitted from conflicts.") }
    static var findingSourceFrontmatter: String { text("findings.source.frontmatter", "Frontmatter validation") }
    static var findingSourcePermission: String { text("findings.source.permission", "Permission analysis") }
    static var findingSourceScript: String { text("findings.source.script", "Script safety analysis") }
    static var findingSourceDependency: String { text("findings.source.dependency", "Dependency analysis") }
    static var findingSourcePath: String { text("findings.source.path", "Catalog path check") }
    static var findingSourceFingerprint: String { text("findings.source.fingerprint", "Catalog fingerprint check") }
    static var findingSourceCatalog: String { text("findings.source.catalog", "Catalog rule") }
    static var findingNoCatalogTarget: String { text("findings.catalogTarget.none", "No definition or instance ID reported") }
    static var remediationFrontmatterRequired: String { text("findings.remediation.frontmatterRequired", "Add the required frontmatter fields in SKILL.md, then rescan.") }
    static var remediationToolsNotEmpty: String { text("findings.remediation.toolsNotEmpty", "Declare the allowed tools the skill needs, or remove tool-dependent instructions.") }
    static var remediationPathExists: String { text("findings.remediation.pathExists", "Restore the source file or remove the stale catalog entry, then scan again.") }
    static var remediationFingerprintChanged: String { text("findings.remediation.fingerprintChanged", "Review the changed skill content and rescan once the catalog should trust the new fingerprint.") }
    static var remediationNetworkDeclared: String { text("findings.remediation.networkDeclared", "Declare the intended network access explicitly, or keep it undeclared only if the skill does not use network access.") }
    static var remediationExecNeedsHuman: String { text("findings.remediation.execNeedsHuman", "Require human confirmation for execution-capable behavior, or remove the execution request.") }
    static var remediationDependencyUnknown: String { text("findings.remediation.dependencyUnknown", "Replace or document the unknown dependency, then rescan.") }
    static var instances: String { text("metadata.instances", "Instances") }
    static var target: String { text("metadata.target", "Target") }
    static var scope: String { text("metadata.scope", "Scope") }
    static var access: String { text("metadata.access", "Access") }
    static var permissionTools: String { text("permissions.tools", "Tools") }
    static var permissionFiles: String { text("permissions.files", "Files") }
    static var permissionNetwork: String { text("permissions.network", "Network") }
    static var permissionExec: String { text("permissions.exec", "Execution") }
    static var permissionHumanReview: String { text("permissions.humanReview", "Human review") }
    static var permissionRaw: String { text("permissions.raw", "Raw permissions") }
    static var permissionUndeclared: String { text("permissions.undeclared", "Undeclared / unknown") }
    static var permissionNoneDeclared: String { text("permissions.noneDeclared", "None declared") }
    static var permissionUnknownPayload: String { text("permissions.unknownPayload", "Unknown payload") }
    static var permissionNetworkReadOnly: String { text("permissions.network.readOnly", "Read-only declared") }
    static var permissionNetworkFull: String { text("permissions.network.full", "Full declared") }
    static var permissionRequested: String { text("permissions.requested", "Requested") }
    static var permissionNotRequested: String { text("permissions.notRequested", "Not requested") }
    static var permissionRequired: String { text("permissions.required", "Required") }
    static var permissionNotDeclaredRequired: String { text("permissions.notDeclaredRequired", "Not declared as required") }
    static var permissionUndeclaredNote: String { text("permissions.undeclaredNote", "Permissions are undeclared or unavailable in the catalog payload; this is not a safe or unsafe verdict.") }
    static var permissionDeclarationNote: String { text("permissions.declarationNote", "These values are permission declarations from the catalog payload, not a safety verdict.") }
    static var service: String { text("settings.service", "Service") }
    static var languageSettings: String { text("settings.language.title", "Language") }
    static var languageSelection: String { text("settings.language.selection", "App language") }
    static var languageEnglish: String { text("settings.language.english", "English") }
    static var languageSimplifiedChinese: String { text("settings.language.simplifiedChinese", "Simplified Chinese") }
    static var languageBoundary: String { text("settings.language.boundary", "Language is stored as an app-local preference. It does not write agent config, skill files, provider settings, credentials, reports, or prompts.") }
    static var languageAppliesImmediately: String { text("settings.language.appliesImmediately", "The main window and Settings update immediately after selection.") }
    static var version: String { text("settings.version", "Version") }
    static var protocolLabel: String { text("settings.protocol", "Protocol") }
    static var catalog: String { text("settings.catalog", "Catalog") }
    static var userHome: String { text("settings.userHome", "User Home") }
    static var methods: String { text("settings.methods", "Methods") }
    static var unknown: String { text("value.unknown", "Unknown") }
    static var notLoaded: String { text("value.notLoaded", "Not loaded") }
    static var aiProviderSettings: String { text("settings.aiProvider.title", "AI Provider") }
    static var aiProviderBoundary: String { text("settings.aiProvider.boundary", "Configure a user-owned provider profile for explicit AI requests. No analysis runs in the background, Test Connection is manual, and provider output cannot write skills, agent config, snapshots, or scripts.") }
    static var aiProviderUnavailable: String { text("settings.aiProvider.unavailable", "AI provider settings are unavailable in this service build.") }
    static var aiProviderOpenAICompatible: String { text("settings.aiProvider.kind.openai", "OpenAI-compatible") }
    static var aiProviderClaudeCompatible: String { text("settings.aiProvider.kind.claude", "Claude-compatible") }
    static var aiProviderEndpoint: String { text("settings.aiProvider.endpoint", "Endpoint") }
    static var aiProviderEndpointPlaceholder: String { text("settings.aiProvider.endpoint.placeholder", "https://api.example.com/v1") }
    static var aiProviderModel: String { text("settings.aiProvider.model", "Model") }
    static var aiProviderModelPlaceholder: String { text("settings.aiProvider.model.placeholder", "model") }
    static var aiProviderAPIVersion: String { text("settings.aiProvider.apiVersion", "API version") }
    static var aiProviderOptionalPlaceholder: String { text("settings.aiProvider.optional.placeholder", "optional") }
    static var aiProviderAPIKey: String { text("settings.aiProvider.apiKey", "API key") }
    static var aiProviderAPIKeyPlaceholder: String { text("settings.aiProvider.apiKey.placeholder", "Leave blank to keep existing Keychain item") }
    static var aiProviderKeychainFirst: String { text("settings.aiProvider.keychainFirst", "API keys are sent only to the service on Save or Test Connection. The service should store secrets in Keychain first; the native UI clears this field after each action and never displays saved keys.") }
    static var aiProviderBudget: String { text("settings.aiProvider.budget", "Budget") }
    static var aiProviderMonthlyBudget: String { text("settings.aiProvider.monthlyBudget", "Monthly budget") }
    static var aiProviderTokenLimit: String { text("settings.aiProvider.tokenLimit", "Single-request token limit") }
    static var aiProviderStorage: String { text("settings.aiProvider.storage", "Credential storage") }
    static var aiProviderConfigured: String { text("settings.aiProvider.configured", "Configured") }
    static var aiProviderUnconfigured: String { text("settings.aiProvider.unconfigured", "Unconfigured") }
    static var aiProviderSave: String { text("settings.aiProvider.save", "Save Provider") }
    static var aiProviderTest: String { text("settings.aiProvider.test", "Test Connection") }
    static var aiProviderSaving: String { text("settings.aiProvider.saving", "Saving provider...") }
    static var aiProviderTesting: String { text("settings.aiProvider.testing", "Testing connection...") }
    static var aiProviderSaved: String { text("settings.aiProvider.saved", "Provider settings saved. API key draft cleared.") }
    static var aiProviderTestResult: String { text("settings.aiProvider.testResult", "Test result") }
    static var aiProviderTestSucceeded: String { text("settings.aiProvider.testSucceeded", "Provider connection test succeeded.") }
    static var aiProviderTestFailed: String { text("settings.aiProvider.testFailed", "Provider connection test failed.") }
    static var aiProviderAuditMetadata: String { text("settings.aiProvider.audit", "Audit metadata") }
    static var aiProviderNoAudit: String { text("settings.aiProvider.noAudit", "No audit metadata returned.") }
    static var aiProviderAuditDuration: String { text("settings.aiProvider.audit.duration", "Duration") }
    static var aiProviderAuditRedaction: String { text("settings.aiProvider.audit.redaction", "Redaction") }
    static var aiProviderAuditPromptStored: String { text("settings.aiProvider.audit.promptStored", "Prompt stored") }
    static var aiProviderAuditResponseStored: String { text("settings.aiProvider.audit.responseStored", "Response stored") }
    static var aiProviderAuditErrorCode: String { text("settings.aiProvider.audit.errorCode", "Error code") }
    static var aiProviderEndpointRequired: String { text("settings.aiProvider.validation.endpointRequired", "Endpoint is required.") }
    static var aiProviderEndpointInvalid: String { text("settings.aiProvider.validation.endpointInvalid", "Endpoint must include a URL scheme such as https://.") }
    static var aiProviderModelRequired: String { text("settings.aiProvider.validation.modelRequired", "Model is required.") }
    static var aiProviderBudgetInvalid: String { text("settings.aiProvider.validation.budgetInvalid", "Monthly budget must be a number.") }
    static var aiProviderTokenLimitInvalid: String { text("settings.aiProvider.validation.tokenLimitInvalid", "Single-request token limit must be a whole number.") }
    static var claudeSettings: String { text("settings.claudeSettings", "Claude Settings") }
    static var existingFile: String { text("settings.existingFile", "Existing file") }
    static var willCreateFile: String { text("settings.willCreateFile", "Will create file") }
    static var settingsInvalidUTF8: String { text("settings.invalidUtf8", "Settings content is not valid UTF-8.") }
    static var jsonValidSettingsWrite: String { text("settings.jsonValid", "JSON is valid. Save will create an agent config snapshot, write atomically, verify, and rescan.") }
    static var connectedProtocolNote: String { text("detail.protocolNote", "This native macOS shell is connected through the Rust service protocol. Scan, toggle, and agent config rollback actions use verified write paths with snapshots.") }
    static var loadingSkillDetail: String { text("detail.loading", "Loading skill detail...") }
    static var readOnlyPreview: String { text("detail.readOnlyPreview", "Read-only preview") }
    static var toolGlobalPreviewTitle: String { text("detail.toolGlobal.previewTitle", "Tool-global Preview") }
    static var toolGlobalPreviewNote: String { text("detail.toolGlobal.previewNote", "Tool-global skills are staged for review. They cannot be toggled here and must be copied into a specific agent after an explicit confirmation.") }
    static var toolGlobalTargetAgent: String { text("detail.toolGlobal.targetAgent", "Target Agent") }
    static var toolGlobalInstallPreviewTitle: String { text("detail.toolGlobal.installPreviewTitle", "Install Preview") }
    static var toolGlobalInstallReady: String { text("detail.toolGlobal.installReady", "Confirmed install writes through the target adapter verified path with snapshot and read-back verification.") }
    static var llmSkillAnalysis: String { text("llm.skillAnalysis", "AI Skill Analysis") }
    static var llmSkillAnalysisSelectedScope: String { text("llm.skillAnalysis.scope.selected", "Selected skill") }
    static var llmSkillAnalysisVisibleScope: String { text("llm.skillAnalysis.scope.visible", "Visible skills") }
    static var llmSkillAnalysisSafetyTitle: String { text("llm.skillAnalysis.safetyTitle", "Read-only prepare only") }
    static var llmSkillAnalysisSafetyCopy: String { text("llm.skillAnalysis.safetyCopy", "No provider call is made by default. This preview cannot write skill files or agent config, cannot execute scripts, and does not save credentials.") }
    static var llmSkillAnalysisPrepareSelected: String { text("llm.skillAnalysis.prepareSelected", "Prepare Selected") }
    static var llmSkillAnalysisPrepareVisible: String { text("llm.skillAnalysis.prepareVisible", "Prepare Visible") }
    static var llmSkillAnalysisUnavailable: String { text("llm.skillAnalysis.unavailable", "AI skill analysis prepare is unavailable in this service build; preview remains disabled and read-only.") }
    static var llmSkillAnalysisUnavailablePrompt: String { text("llm.skillAnalysis.unavailablePrompt", "Service method llm.prepareSkillAnalysis is unavailable. No provider request was prepared.") }
    static var llmSkillAnalysisUnavailableSummary: String { text("llm.skillAnalysis.unavailableSummary", "Disabled fallback preview only. No writes, no scripts, no credentials, and no provider call.") }
    static var llmSkillAnalysisPromptDraft: String { text("llm.skillAnalysis.promptDraft", "Prepared prompt draft") }
    static var llmSkillAnalysisSummaryDraft: String { text("llm.skillAnalysis.summaryDraft", "Summary draft") }
    static var llmSkillAnalysisIncludedSkills: String { text("llm.skillAnalysis.includedSkills", "Included skills") }
    static var llmSkillAnalysisExcludedMissing: String { text("llm.skillAnalysis.excludedMissing", "Excluded / missing") }
    static var llmSkillAnalysisNoDraft: String { text("llm.skillAnalysis.noDraft", "No draft text returned by the service.") }
    static var llmSkillAnalysisNoIncludedSkills: String { text("llm.skillAnalysis.noIncludedSkills", "No included skills returned.") }
    static var llmSkillAnalysisWriteBack: String { text("llm.skillAnalysis.writeBack", "Write-back") }
    static var llmSkillAnalysisScriptExecution: String { text("llm.skillAnalysis.scriptExecution", "Script execution") }
    static var llmSkillAnalysisCredentialStorage: String { text("llm.skillAnalysis.credentialStorage", "Credential storage") }
    static var llmSkillAnalysisConfirmation: String { text("llm.skillAnalysis.confirmation", "Confirmation") }
    static var llmSkillAnalysisBlocked: String { text("llm.skillAnalysis.blocked", "Blocked") }
    static var llmSkillAnalysisRequired: String { text("llm.skillAnalysis.required", "Required") }
    static var llmSkillAnalysisEnabledUnsafe: String { text("llm.skillAnalysis.enabledUnsafe", "Enabled by service") }
    static var skillQualityTitle: String { text("quality.title", "AI Skill Quality Score") }
    static var skillQualityBoundary: String { text("quality.boundary", "User-triggered, read-only scoring from local evidence. The score cannot write skill files, mutate agent config, create snapshots, change triage, execute scripts, or read credentials.") }
    static var skillQualityScoreAction: String { text("quality.action.score", "Score Quality") }
    static var skillQualityUnavailable: String { text("quality.unavailable", "Quality scoring is unavailable in this service build.") }
    static var skillQualityPromptUnavailable: String { text("quality.promptUnavailable", "Quality prompt preview is unavailable in this service build; no provider request was prepared.") }
    static var skillQualityScore: String { text("quality.score", "Score") }
    static var skillQualityBand: String { text("quality.band", "Band") }
    static var skillQualityComponents: String { text("quality.components", "Components") }
    static var skillQualityEvidence: String { text("quality.evidence", "Evidence") }
    static var skillQualityRiskNotes: String { text("quality.riskNotes", "Risk notes") }
    static var skillQualitySuggestions: String { text("quality.suggestions", "Suggested improvements") }
    static var skillQualityNoComponents: String { text("quality.empty.components", "No component scores returned.") }
    static var skillQualityNoEvidence: String { text("quality.empty.evidence", "No evidence items returned.") }
    static var skillQualityNoRisks: String { text("quality.empty.risks", "No risk notes returned.") }
    static var skillQualityNoSuggestions: String { text("quality.empty.suggestions", "No suggestions returned.") }
    static var skillQualitySafety: String { text("quality.safety", "Safety flags") }
    static var skillQualityProviderNotSent: String { text("quality.safety.providerNotSent", "Provider not sent") }
    static var skillQualityWritesBlocked: String { text("quality.safety.writesBlocked", "Writes blocked") }
    static var skillQualityScriptsBlocked: String { text("quality.safety.scriptsBlocked", "Scripts blocked") }
    static var skillQualityMutationsBlocked: String { text("quality.safety.mutationsBlocked", "Config/triage mutations blocked") }
    static var skillQualityCredentialsBlocked: String { text("quality.safety.credentialsBlocked", "Credentials blocked") }
    static var taskReadinessTitle: String { text("taskReadiness.title", "AI Task Readiness Check") }
    static var taskReadinessBoundary: String { text("taskReadiness.boundary", "User-triggered, read-only task fit check from local evidence. It cannot write skill files, mutate agent config, create snapshots, change triage, execute scripts, or read credentials.") }
    static var taskReadinessTask: String { text("taskReadiness.task", "Task") }
    static var taskReadinessTaskPlaceholder: String { text("taskReadiness.task.placeholder", "Describe the task to test against this skill") }
    static var taskReadinessCheckAction: String { text("taskReadiness.action.check", "Check Readiness") }
    static var taskReadinessTaskRequired: String { text("taskReadiness.taskRequired", "Enter a task before checking readiness.") }
    static var taskReadinessUnavailable: String { text("taskReadiness.unavailable", "Task readiness check is unavailable in this service build.") }
    static var taskReadinessPromptUnavailable: String { text("taskReadiness.promptUnavailable", "Task readiness prompt preview is unavailable in this service build; no provider request was prepared.") }
    static var taskReadinessScore: String { text("taskReadiness.score", "Readiness") }
    static var taskReadinessBand: String { text("taskReadiness.band", "Band") }
    static var taskReadinessCandidates: String { text("taskReadiness.candidates", "Candidate skills") }
    static var taskReadinessGaps: String { text("taskReadiness.gaps", "Gaps / missing capabilities") }
    static var taskReadinessBlockers: String { text("taskReadiness.blockers", "Blockers") }
    static var taskReadinessRiskNotes: String { text("taskReadiness.riskNotes", "Risk notes") }
    static var taskReadinessEvidence: String { text("taskReadiness.evidence", "Evidence") }
    static var taskReadinessNoCandidates: String { text("taskReadiness.empty.candidates", "No candidate skills returned.") }
    static var taskReadinessNoGaps: String { text("taskReadiness.empty.gaps", "No gaps returned.") }
    static var taskReadinessNoBlockers: String { text("taskReadiness.empty.blockers", "No blockers returned.") }
    static var taskReadinessNoRisks: String { text("taskReadiness.empty.risks", "No risk notes returned.") }
    static var taskReadinessNoEvidence: String { text("taskReadiness.empty.evidence", "No evidence items returned.") }
    static var crossAgentReadinessTitle: String { text("crossAgentReadiness.title", "Cross-agent Task Readiness") }
    static var crossAgentReadinessBoundary: String { text("crossAgentReadiness.boundary", "User-triggered, read-only cross-agent task fit comparison from local readiness, routing, benchmark, regression, and accuracy evidence. It cannot call a provider, write skill files, mutate agent config, create snapshots, change triage, execute scripts, read credentials, persist raw prompts/responses/traces, sync cloud data, or emit telemetry.") }
    static var crossAgentReadinessTaskPlaceholder: String { text("crossAgentReadiness.task.placeholder", "Describe a task, or reuse the current readiness/routing task") }
    static var crossAgentReadinessCompareAction: String { text("crossAgentReadiness.action.compare", "Compare Agents") }
    static var crossAgentReadinessTaskRequired: String { text("crossAgentReadiness.taskRequired", "Enter a task before comparing agents.") }
    static var crossAgentReadinessUnavailable: String { text("crossAgentReadiness.unavailable", "Cross-agent task readiness is unavailable in this service build.") }
    static var crossAgentReadinessRecommendedAgent: String { text("crossAgentReadiness.recommendedAgent", "Recommended agent") }
    static var crossAgentReadinessNoRecommendation: String { text("crossAgentReadiness.empty.recommendation", "No recommended agent returned.") }
    static var crossAgentReadinessAgents: String { text("crossAgentReadiness.agents", "Per-agent readiness") }
    static var crossAgentReadinessNoAgents: String { text("crossAgentReadiness.empty.agents", "No agent readiness rows returned.") }
    static var crossAgentReadinessReadinessScore: String { text("crossAgentReadiness.readinessScore", "Readiness") }
    static var crossAgentReadinessComparisonScore: String { text("crossAgentReadiness.comparisonScore", "Comparison") }
    static var crossAgentReadinessRoutingScore: String { text("crossAgentReadiness.routingScore", "Routing") }
    static var crossAgentReadinessBestSkill: String { text("crossAgentReadiness.bestSkill", "Best skill") }
    static var crossAgentReadinessCandidateCount: String { text("crossAgentReadiness.candidateCount", "Candidates") }
    static var crossAgentReadinessEnabledState: String { text("crossAgentReadiness.enabledState", "Enabled state") }
    static var crossAgentReadinessScopeState: String { text("crossAgentReadiness.scopeState", "Scope state") }
    static var crossAgentReadinessRiskState: String { text("crossAgentReadiness.riskState", "Risk state") }
    static var crossAgentReadinessAccuracy: String { text("crossAgentReadiness.accuracy", "Accuracy context") }
    static var crossAgentReadinessRegression: String { text("crossAgentReadiness.regression", "Regression context") }
    static var crossAgentReadinessReasons: String { text("crossAgentReadiness.reasons", "Reasons") }
    static var crossAgentReadinessNoReasons: String { text("crossAgentReadiness.empty.reasons", "No reasons returned.") }
    static var crossAgentReadinessEvidence: String { text("crossAgentReadiness.evidence", "Evidence") }
    static var crossAgentReadinessNoEvidence: String { text("crossAgentReadiness.empty.evidence", "No evidence returned.") }
    static var crossAgentReadinessGapsIssues: String { text("crossAgentReadiness.gapsIssues", "Gaps / issues") }
    static var crossAgentReadinessNoGapsIssues: String { text("crossAgentReadiness.empty.gapsIssues", "No gaps or issues returned.") }
    static var crossAgentReadinessSafetyFlags: String { text("crossAgentReadiness.safetyFlags", "Safety flags") }
    static var crossAgentReadinessNoResult: String { text("crossAgentReadiness.empty.result", "No cross-agent readiness comparison loaded.") }
    static var routingConfidenceTitle: String { text("routingConfidence.title", "AI Routing Confidence") }
    static var routingConfidenceBoundary: String { text("routingConfidence.boundary", "User-triggered, read-only route ranking from local evidence. It cannot write skill files, mutate agent config, create snapshots, change triage, execute scripts, or read credentials.") }
    static var routingConfidenceTaskPlaceholder: String { text("routingConfidence.task.placeholder", "Describe the task to rank route fit") }
    static var routingConfidenceAction: String { text("routingConfidence.action.rank", "Rank Routes") }
    static var routingConfidenceTaskRequired: String { text("routingConfidence.taskRequired", "Enter a task before ranking routes.") }
    static var routingConfidenceUnavailable: String { text("routingConfidence.unavailable", "Routing confidence is unavailable in this service build.") }
    static var routingConfidencePromptUnavailable: String { text("routingConfidence.promptUnavailable", "Routing confidence prompt preview is unavailable in this service build; no provider request was prepared.") }
    static var routingConfidenceScore: String { text("routingConfidence.score", "Confidence") }
    static var routingConfidenceBand: String { text("routingConfidence.band", "Band") }
    static var routingConfidenceRoutes: String { text("routingConfidence.routes", "Candidate routes") }
    static var routingConfidenceMatchReasons: String { text("routingConfidence.matchReasons", "Match reasons") }
    static var routingConfidenceAmbiguity: String { text("routingConfidence.ambiguity", "Ambiguity / collision warnings") }
    static var routingConfidenceWrongPick: String { text("routingConfidence.wrongPick", "Wrong-pick / miss risks") }
    static var routingConfidenceEvidence: String { text("routingConfidence.evidence", "Evidence") }
    static var routingConfidenceNoRoutes: String { text("routingConfidence.empty.routes", "No candidate routes returned.") }
    static var routingConfidenceNoReasons: String { text("routingConfidence.empty.reasons", "No match reasons returned.") }
    static var routingConfidenceNoAmbiguity: String { text("routingConfidence.empty.ambiguity", "No ambiguity warnings returned.") }
    static var routingConfidenceNoWrongPick: String { text("routingConfidence.empty.wrongPick", "No wrong-pick or miss risks returned.") }
    static var routingConfidenceNoEvidence: String { text("routingConfidence.empty.evidence", "No evidence items returned.") }
    static var routingAccuracyTitle: String { text("routingAccuracy.title", "Routing Accuracy Dashboard") }
    static var routingAccuracyBoundary: String { text("routingAccuracy.boundary", "User-triggered local trace, benchmark, and regression accuracy view. It cannot call a provider, write skill files, mutate agent config, create snapshots, change triage, execute scripts, read credentials, persist raw prompts/responses/traces, sync cloud data, or emit telemetry.") }
    static var routingAccuracyLoadAction: String { text("routingAccuracy.action.load", "Load Dashboard") }
    static var routingAccuracyUnavailable: String { text("routingAccuracy.unavailable", "Routing accuracy dashboard is unavailable in this service build.") }
    static var routingAccuracyGeneratedBy: String { text("routingAccuracy.generatedBy", "Generated by") }
    static var routingAccuracyCatalog: String { text("routingAccuracy.catalog", "Catalog") }
    static var routingAccuracyWindow: String { text("routingAccuracy.window", "Window") }
    static var routingAccuracyAvailable: String { text("routingAccuracy.available", "Available") }
    static var routingAccuracyUnavailableShort: String { text("routingAccuracy.unavailable.short", "Unavailable") }
    static var routingAccuracyHitRate: String { text("routingAccuracy.hitRate", "Hit rate") }
    static var routingAccuracyAccuracyRate: String { text("routingAccuracy.accuracyRate", "Accuracy rate") }
    static var routingAccuracyKnownOutcomeRate: String { text("routingAccuracy.knownOutcomeRate", "Known-outcome rate") }
    static var routingAccuracyMissRate: String { text("routingAccuracy.missRate", "Miss rate") }
    static var routingAccuracyWrongPickRate: String { text("routingAccuracy.wrongPickRate", "Wrong-pick rate") }
    static var routingAccuracyAmbiguousRate: String { text("routingAccuracy.ambiguousRate", "Ambiguous rate") }
    static var routingAccuracyUnknownRate: String { text("routingAccuracy.unknownRate", "Unknown rate") }
    static var routingAccuracyImports: String { text("routingAccuracy.imports", "Imports") }
    static var routingAccuracyBenchmarks: String { text("routingAccuracy.benchmarks", "Benchmarks") }
    static var routingAccuracyBenchmarkMatched: String { text("routingAccuracy.benchmarkMatched", "Benchmark matched") }
    static var routingAccuracyBenchmarkGaps: String { text("routingAccuracy.benchmarkGaps", "Benchmark gaps") }
    static var routingAccuracyMissingBenchmarks: String { text("routingAccuracy.missingBenchmarks", "Missing benchmarks") }
    static var routingAccuracyRegressions: String { text("routingAccuracy.regressions", "Regressions") }
    static var routingAccuracyAvgConfidence: String { text("routingAccuracy.avgConfidence", "Avg confidence") }
    static var routingAccuracyGaps: String { text("routingAccuracy.gaps", "Gaps") }
    static var routingAccuracyBlockers: String { text("routingAccuracy.blockers", "Blockers") }
    static var routingAccuracyAgents: String { text("routingAccuracy.agents", "Per-agent accuracy") }
    static var routingAccuracyNoAgents: String { text("routingAccuracy.empty.agents", "No agent rows returned.") }
    static var routingAccuracyHistory: String { text("routingAccuracy.history", "History") }
    static var routingAccuracyNoHistory: String { text("routingAccuracy.empty.history", "No history returned.") }
    static var routingAccuracyRecentEvidence: String { text("routingAccuracy.recentEvidence", "Recent evidence") }
    static var routingAccuracyNoEvidence: String { text("routingAccuracy.empty.evidence", "No recent evidence returned.") }
    static var routingAccuracyNoGaps: String { text("routingAccuracy.empty.gaps", "No gaps returned.") }
    static var routingAccuracyBlockerNotes: String { text("routingAccuracy.blockerNotes", "Blocker notes") }
    static var routingAccuracyNoBlockers: String { text("routingAccuracy.empty.blockers", "No blocker notes returned.") }
    static var routingAccuracySafetyFlags: String { text("routingAccuracy.safetyFlags", "Safety flags") }
    static var routingAccuracySafetyClear: String { text("routingAccuracy.safety.clear", "Read-only flags clear") }
    static var routingAccuracyRawTraceStored: String { text("routingAccuracy.safety.rawTraceStored", "Raw trace stored") }
    static var routingAccuracyCloudSync: String { text("routingAccuracy.safety.cloudSync", "Cloud sync") }
    static var routingAccuracyTelemetry: String { text("routingAccuracy.safety.telemetry", "Telemetry") }
    static var routingAccuracyPromptRequest: String { text("routingAccuracy.promptRequest", "Prompt request") }
    static var routingAccuracyNoDashboard: String { text("routingAccuracy.empty.dashboard", "No routing accuracy dashboard loaded.") }
    static var routingAccuracyDays: String { text("routingAccuracy.days", "%d days") }
    static var staleDriftTitle: String { text("staleDrift.title", "Stale / Drift Detection") }
    static var staleDriftBoundary: String { text("staleDrift.boundary", "User-triggered local stale and drift review from catalog, readiness, routing, benchmark, regression, and accuracy evidence. It cannot call a provider, write skill files, mutate agent config, create snapshots, change triage, execute scripts, read credentials, persist raw prompts/responses/traces, sync cloud data, or emit telemetry.") }
    static var staleDriftDetectAction: String { text("staleDrift.action.detect", "Detect Stale / Drift") }
    static var staleDriftUnavailable: String { text("staleDrift.unavailable", "Stale / drift detection is unavailable in this service build.") }
    static var staleDriftNoResult: String { text("staleDrift.empty.result", "No stale / drift detection loaded.") }
    static var staleDriftStale: String { text("staleDrift.stale", "Stale") }
    static var staleDriftDrift: String { text("staleDrift.drift", "Drift") }
    static var staleDriftCandidates: String { text("staleDrift.candidates", "Candidates") }
    static var staleDriftCandidate: String { text("staleDrift.candidate", "Stale / drift candidate") }
    static var staleDriftAffectedAgents: String { text("staleDrift.affectedAgents", "Affected agents") }
    static var staleDriftReadinessImpact: String { text("staleDrift.readinessImpact", "Readiness impact") }
    static var staleDriftHighRisk: String { text("staleDrift.highRisk", "High risk") }
    static var staleDriftLastSeen: String { text("staleDrift.lastSeen", "Last seen") }
    static var staleDriftReasons: String { text("staleDrift.reasons", "Reasons") }
    static var staleDriftSignals: String { text("staleDrift.signals", "Signals") }
    static var staleDriftNoCandidates: String { text("staleDrift.empty.candidates", "No stale or drift candidates returned.") }
    static var staleDriftNoReadinessImpact: String { text("staleDrift.empty.readinessImpact", "No readiness impact rows returned.") }
    static var staleDriftNoReasons: String { text("staleDrift.empty.reasons", "No reasons returned.") }
    static var staleDriftNoSignals: String { text("staleDrift.empty.signals", "No signals returned.") }
    static var staleDriftSafetyFlags: String { text("staleDrift.safetyFlags", "Safety flags") }
    static var knowledgeTitle: String { text("knowledge.title", "Local Knowledge Index") }
    static var knowledgeBoundary: String { text("knowledge.boundary", "User-triggered, read-only local search across skill purpose, metadata, tags, rules, tools, and evidence. It cannot call a provider, write skill files, mutate agent config, create snapshots, change triage, execute scripts, read credentials, sync cloud data, or emit telemetry.") }
    static var knowledgeQuery: String { text("knowledge.query", "Knowledge query") }
    static var knowledgeQueryPlaceholder: String { text("knowledge.query.placeholder", "Search purpose, tools, rules, tags, or evidence") }
    static var knowledgeSearchAction: String { text("knowledge.action.search", "Search Knowledge") }
    static var knowledgeQueryRequired: String { text("knowledge.queryRequired", "Enter a query before searching the local knowledge index.") }
    static var knowledgeUnavailable: String { text("knowledge.unavailable", "Local knowledge search is unavailable in this service build.") }
    static var knowledgeNoResult: String { text("knowledge.empty.result", "No knowledge search loaded.") }
    static var knowledgeNoRows: String { text("knowledge.empty.rows", "No knowledge rows returned.") }
    static var knowledgeRows: String { text("knowledge.rows", "Knowledge rows") }
    static var knowledgeMatches: String { text("knowledge.matches", "Matches") }
    static var knowledgeMatchedFields: String { text("knowledge.matchedFields", "Matched fields") }
    static var knowledgeKeywords: String { text("knowledge.keywords", "Keywords") }
    static var knowledgeTools: String { text("knowledge.tools", "Tools") }
    static var knowledgeRules: String { text("knowledge.rules", "Rules") }
    static var knowledgeCapabilities: String { text("knowledge.capabilities", "Capabilities") }
    static var knowledgeRisks: String { text("knowledge.risks", "Risk tags") }
    static var knowledgeFacets: String { text("knowledge.facets", "Facets") }
    static var knowledgeFacet: String { text("knowledge.facet", "Facet") }
    static var knowledgeNoFacets: String { text("knowledge.empty.facets", "No facets returned.") }
    static var knowledgeGapNotes: String { text("knowledge.gapNotes", "Gap notes") }
    static var knowledgeBlockerNotes: String { text("knowledge.blockerNotes", "Blocker notes") }
    static var knowledgeSafetyFlags: String { text("knowledge.safetyFlags", "Safety flags") }
    static var similarGroupingTitle: String { text("similarGrouping.title", "Similar Skill Grouping") }
    static var similarGroupingBoundary: String { text("similarGrouping.boundary", "User-triggered, read-only local grouping for duplicate, similar, and confusable skills across catalog evidence. It cannot call a provider, write skill files, mutate agent config, create snapshots, change triage, execute scripts, read credentials, persist raw prompts/responses/traces, sync cloud data, or emit telemetry.") }
    static var similarGroupingAction: String { text("similarGrouping.action.group", "Group Similar Skills") }
    static var similarGroupingUnavailable: String { text("similarGrouping.unavailable", "Similar skill grouping is unavailable in this service build.") }
    static var similarGroupingNoResult: String { text("similarGrouping.empty.result", "No similar skill grouping loaded.") }
    static var similarGroupingNoGroups: String { text("similarGrouping.empty.groups", "No similar skill groups returned.") }
    static var similarGroupingGroups: String { text("similarGrouping.groups", "Groups") }
    static var similarGroupingGroup: String { text("similarGrouping.group", "Similar group") }
    static var similarGroupingMembers: String { text("similarGrouping.members", "Members") }
    static var similarGroupingDuplicate: String { text("similarGrouping.type.duplicate", "Duplicate") }
    static var similarGroupingSimilar: String { text("similarGrouping.type.similar", "Similar") }
    static var similarGroupingConfusable: String { text("similarGrouping.type.confusable", "Confusable") }
    static var similarGroupingHighAmbiguity: String { text("similarGrouping.highAmbiguity", "High ambiguity") }
    static var similarGroupingCoverageRedundancy: String { text("similarGrouping.coverageRedundancy", "Coverage redundancy") }
    static var similarGroupingRoutingAmbiguity: String { text("similarGrouping.routingAmbiguity", "Routing ambiguity") }
    static var similarGroupingWhyGrouped: String { text("similarGrouping.whyGrouped", "Why grouped") }
    static var similarGroupingSharedTerms: String { text("similarGrouping.sharedTerms", "Shared terms") }
    static var similarGroupingSourceSignals: String { text("similarGrouping.sourceSignals", "Source signals") }
    static var similarGroupingQuality: String { text("similarGrouping.quality", "Quality") }
    static var similarGroupingReadiness: String { text("similarGrouping.readiness", "Readiness") }
    static var similarGroupingStaleDrift: String { text("similarGrouping.staleDrift", "Stale / drift") }
    static var capabilityTaxonomyTitle: String { text("capabilityTaxonomy.title", "Capability Taxonomy") }
    static var capabilityTaxonomyBoundary: String { text("capabilityTaxonomy.boundary", "User-triggered, read-only local taxonomy for capability domains, coverage, gaps, blockers, representative skills, and evidence. It cannot call a provider, write skill files, mutate agent config, create snapshots, change triage, execute scripts, read credentials, persist raw prompts/responses/traces, sync cloud data, or emit telemetry.") }
    static var capabilityTaxonomyAction: String { text("capabilityTaxonomy.action.build", "Build Taxonomy") }
    static var capabilityTaxonomyUnavailable: String { text("capabilityTaxonomy.unavailable", "Capability taxonomy is unavailable in this service build.") }
    static var capabilityTaxonomyNoResult: String { text("capabilityTaxonomy.empty.result", "No capability taxonomy loaded.") }
    static var capabilityTaxonomyNoDomains: String { text("capabilityTaxonomy.empty.domains", "No capability domains returned.") }
    static var capabilityTaxonomyDomains: String { text("capabilityTaxonomy.domains", "Domains") }
    static var capabilityTaxonomyDomain: String { text("capabilityTaxonomy.domain", "Capability domain") }
    static var capabilityTaxonomyCapability: String { text("capabilityTaxonomy.capability", "Capability") }
    static var capabilityTaxonomyCoverage: String { text("capabilityTaxonomy.coverage", "Coverage") }
    static var capabilityTaxonomyAgentCoverage: String { text("capabilityTaxonomy.agentCoverage", "Agent coverage") }
    static var capabilityTaxonomyRepresentativeSkills: String { text("capabilityTaxonomy.representativeSkills", "Representative skills") }
    static var workspaceReadinessTitle: String { text("workspaceReadiness.title", "Workspace Readiness") }
    static var workspaceReadinessBoundary: String { text("workspaceReadiness.boundary", "User-triggered, read-only local workspace readiness check for expected work, enabled/scoped skills, agent coverage, capability gaps, blockers, and evidence. It cannot call a provider, write skill files, mutate agent config, create snapshots, change triage, execute scripts, read credentials, persist raw prompts/responses/traces, sync cloud data, or emit telemetry.") }
    static var workspaceReadinessAction: String { text("workspaceReadiness.action.check", "Check Workspace") }
    static var workspaceReadinessUnavailable: String { text("workspaceReadiness.unavailable", "Workspace readiness is unavailable in this service build.") }
    static var workspaceReadinessNoResult: String { text("workspaceReadiness.empty.result", "No workspace readiness check loaded.") }
    static var workspaceReadinessChecklist: String { text("workspaceReadiness.checklist", "Readiness checklist") }
    static var workspaceReadinessNoChecklist: String { text("workspaceReadiness.empty.checklist", "No checklist rows returned.") }
    static var workspaceReadinessChecklistItem: String { text("workspaceReadiness.checklist.item", "Readiness check") }
    static var workspaceReadinessAgentRows: String { text("workspaceReadiness.agents", "Agent readiness") }
    static var workspaceReadinessNoAgentRows: String { text("workspaceReadiness.empty.agents", "No agent readiness rows returned.") }
    static var workspaceReadinessCapabilityRows: String { text("workspaceReadiness.capabilities", "Capability readiness") }
    static var workspaceReadinessNoCapabilityRows: String { text("workspaceReadiness.empty.capabilities", "No capability readiness rows returned.") }
    static var workspaceReadinessOverall: String { text("workspaceReadiness.overall", "Overall") }
    static var workspaceReadinessReady: String { text("workspaceReadiness.ready", "Ready") }
    static var workspaceReadinessPartial: String { text("workspaceReadiness.partial", "Partial") }
    static var workspaceReadinessBlocked: String { text("workspaceReadiness.blocked", "Blocked") }
    static var workspaceReadinessRequired: String { text("workspaceReadiness.required", "Required") }
    static var workspaceReadinessMatched: String { text("workspaceReadiness.matched", "Matched") }
    static var workspaceReadinessEnabled: String { text("workspaceReadiness.enabled", "Enabled") }
    static var remediationPlanTitle: String { text("remediationPlan.title", "AI Remediation Planner") }
    static var remediationPlanBoundary: String { text("remediationPlan.boundary", "User-triggered, local-only, deterministic remediation planning from findings, gaps, routing ambiguity, stale/drift, readiness, taxonomy, workspace, and evidence signals. It is guidance-only: it cannot call a provider, write skill files, mutate agent config, create snapshots, change triage, execute scripts, read credentials, persist raw prompts/responses/traces, sync cloud data, or emit telemetry.") }
    static var remediationPlanAction: String { text("remediationPlan.action.plan", "Plan Remediation") }
    static var remediationPlanUnavailable: String { text("remediationPlan.unavailable", "Remediation planning is unavailable in this service build.") }
    static var remediationPlanNoResult: String { text("remediationPlan.empty.result", "No remediation plan loaded.") }
    static var remediationPlanItem: String { text("remediationPlan.item", "Remediation item") }
    static var remediationPlanItems: String { text("remediationPlan.items", "Plan items") }
    static var remediationPlanNoItems: String { text("remediationPlan.empty.items", "No remediation plan items returned.") }
    static var remediationPlanPriorities: String { text("remediationPlan.priorities", "Priority rows") }
    static var remediationPlanNoPriorities: String { text("remediationPlan.empty.priorities", "No priority rows returned.") }
    static var remediationPlanCritical: String { text("remediationPlan.critical", "Critical") }
    static var remediationPlanQuickWins: String { text("remediationPlan.quickWins", "Quick wins") }
    static var remediationPlanAmbiguity: String { text("remediationPlan.ambiguity", "Ambiguity") }
    static var remediationPlanDrift: String { text("remediationPlan.drift", "Stale / drift") }
    static var remediationPlanCategory: String { text("remediationPlan.category", "Category") }
    static var remediationPlanGuidanceOnly: String { text("remediationPlan.guidanceOnly", "Guidance only") }
    static var remediationPlanNextArea: String { text("remediationPlan.nextArea", "Review area") }
    static var remediationPlanReviewGuidance: String { text("remediationPlan.reviewGuidance", "Review the supporting evidence in existing safe UI areas; no direct write action is available from this plan.") }
    static var fixPreviewTitle: String { text("fixPreview.title", "Fix Preview Drafts") }
    static var fixPreviewBoundary: String { text("fixPreview.boundary", "User-triggered, local-only draft previews for likely skill fixes. Drafts are copy-only guidance: this panel cannot call a provider, write skill files, mutate agent config, create snapshots, change triage, execute scripts, read credentials, persist raw prompts/responses/traces, sync cloud data, or emit telemetry.") }
    static var fixPreviewCopyOnlyBoundary: String { text("fixPreview.copyOnlyBoundary", "Copy proposed text into an existing safe edit flow if you choose to use it. No Apply or Write action is exposed here.") }
    static var fixPreviewAction: String { text("fixPreview.action.preview", "Preview Drafts") }
    static var fixPreviewUnavailable: String { text("fixPreview.unavailable", "Fix preview drafts are unavailable in this service build.") }
    static var fixPreviewNoResult: String { text("fixPreview.empty.result", "No fix preview drafts loaded.") }
    static var fixPreviewDraft: String { text("fixPreview.draft", "Fix draft") }
    static var fixPreviewDrafts: String { text("fixPreview.drafts", "Drafts") }
    static var fixPreviewNoDrafts: String { text("fixPreview.empty.drafts", "No fix preview drafts returned.") }
    static var fixPreviewFrontmatter: String { text("fixPreview.type.frontmatter", "Frontmatter") }
    static var fixPreviewDescription: String { text("fixPreview.type.description", "Description") }
    static var fixPreviewPermissions: String { text("fixPreview.type.permissions", "Permissions") }
    static var fixPreviewDependency: String { text("fixPreview.type.dependency", "Dependency") }
    static var fixPreviewPolicy: String { text("fixPreview.type.policy", "Policy") }
    static var fixPreviewDraftType: String { text("fixPreview.draftType", "Draft type") }
    static var fixPreviewFinding: String { text("fixPreview.finding", "Finding") }
    static var fixPreviewCurrentSnippet: String { text("fixPreview.currentSnippet", "Current snippet") }
    static var fixPreviewProposedSnippet: String { text("fixPreview.proposedSnippet", "Proposed draft") }
    static var fixPreviewCopyDraft: String { text("fixPreview.copyDraft", "Copy Draft") }
    static var fixPreviewEditGuidanceFallback: String { text("fixPreview.editGuidance.fallback", "Review this draft in the relevant existing editor or source file; this preview does not apply changes.") }
    static var taskBenchmarkTitle: String { text("taskBenchmark.title", "Task Benchmark Set") }
    static var taskBenchmarkBoundary: String { text("taskBenchmark.boundary", "User-triggered, local benchmark evaluation for task routing. Local evaluation does not call a provider and cannot write skill files, mutate agent config, create snapshots, change triage, execute scripts, or read credentials.") }
    static var taskBenchmarkTaskPlaceholder: String { text("taskBenchmark.task.placeholder", "Optional benchmark task text; otherwise the current readiness/routing task is used") }
    static var taskBenchmarkSaveAction: String { text("taskBenchmark.action.save", "Save Benchmark") }
    static var taskBenchmarkLoadAction: String { text("taskBenchmark.action.load", "Load Benchmarks") }
    static var taskBenchmarkEvaluateAction: String { text("taskBenchmark.action.evaluate", "Evaluate Set") }
    static var taskBenchmarkDeleteAction: String { text("taskBenchmark.action.delete", "Delete benchmark") }
    static var taskBenchmarkTaskRequired: String { text("taskBenchmark.taskRequired", "Enter a task before saving a benchmark.") }
    static var taskBenchmarkUnavailable: String { text("taskBenchmark.unavailable", "Task benchmark set is unavailable in this service build.") }
    static var taskBenchmarkDeleteUnavailable: String { text("taskBenchmark.deleteUnavailable", "Deleting benchmarks is unavailable in this service build.") }
    static var taskBenchmarkSuccessCriterion: String { text("taskBenchmark.successCriterion", "Top route should match the selected expected skill or an acceptable local agent/scope route.") }
    static var taskBenchmarkListTitle: String { text("taskBenchmark.list", "Benchmarks") }
    static var taskBenchmarkNoBenchmarks: String { text("taskBenchmark.empty.benchmarks", "No benchmarks returned.") }
    static var taskBenchmarkEvaluationTitle: String { text("taskBenchmark.evaluation", "Benchmark evaluation") }
    static var taskBenchmarkAverageScore: String { text("taskBenchmark.averageScore", "Average") }
    static var taskBenchmarkEvaluated: String { text("taskBenchmark.evaluated", "Evaluated") }
    static var taskBenchmarkMatched: String { text("taskBenchmark.matched", "Expected matched") }
    static var taskBenchmarkAcceptableMatched: String { text("taskBenchmark.acceptableMatched", "Acceptable matched") }
    static var taskBenchmarkPerBenchmark: String { text("taskBenchmark.perBenchmark", "Per-benchmark results") }
    static var taskBenchmarkNoEvaluations: String { text("taskBenchmark.empty.evaluations", "No benchmark evaluations returned.") }
    static var taskBenchmarkTopRoute: String { text("taskBenchmark.topRoute", "Top route") }
    static var taskBenchmarkExpected: String { text("taskBenchmark.expected", "Expected") }
    static var taskBenchmarkAcceptable: String { text("taskBenchmark.acceptable", "Acceptable") }
    static var taskBenchmarkExpectedCovered: String { text("taskBenchmark.expected.covered", "Expected covered") }
    static var taskBenchmarkExpectedMissed: String { text("taskBenchmark.expected.missed", "Expected missed") }
    static var taskBenchmarkAcceptableCovered: String { text("taskBenchmark.acceptable.covered", "Acceptable covered") }
    static var taskBenchmarkAcceptableMissed: String { text("taskBenchmark.acceptable.missed", "Acceptable missed") }
    static var taskBenchmarkBlockers: String { text("taskBenchmark.blockers", "Blockers") }
    static var taskBenchmarkGaps: String { text("taskBenchmark.gaps", "Gaps") }
    static var taskBenchmarkSafetyFlags: String { text("taskBenchmark.safetyFlags", "Safety flags") }
    static var taskBenchmarkNoBlockers: String { text("taskBenchmark.empty.blockers", "No blockers returned.") }
    static var taskBenchmarkNoGaps: String { text("taskBenchmark.empty.gaps", "No gaps returned.") }
    static var taskBenchmarkNoSafetyFlags: String { text("taskBenchmark.empty.safetyFlags", "No safety flags returned.") }
    static var routingRegressionTitle: String { text("routingRegression.title", "Routing Regression") }
    static var routingRegressionBoundary: String { text("routingRegression.boundary", "User-triggered, app-local regression detection from saved benchmark baselines. Detection is deterministic and cannot call a provider, write skill files, mutate agent config, create snapshots, change triage, execute scripts, or read credentials.") }
    static var routingRegressionSaveBaselineAction: String { text("routingRegression.action.saveBaseline", "Save Baseline") }
    static var routingRegressionDetectAction: String { text("routingRegression.action.detect", "Detect Regressions") }
    static var routingRegressionUnavailable: String { text("routingRegression.unavailable", "Routing regression detection is unavailable in this service build.") }
    static var routingRegressionNoBaseline: String { text("routingRegression.empty.baseline", "No routing baseline shown yet.") }
    static var routingRegressionBaselineStatus: String { text("routingRegression.baselineStatus", "Baseline status") }
    static var routingRegressionDetectionTitle: String { text("routingRegression.detection", "Regression detection") }
    static var routingRegressionCount: String { text("routingRegression.count", "Regressions") }
    static var routingRegressionImproved: String { text("routingRegression.improved", "Improved") }
    static var routingRegressionUnchanged: String { text("routingRegression.unchanged", "Unchanged") }
    static var routingRegressionAverageScoreDelta: String { text("routingRegression.averageScoreDelta", "Average delta") }
    static var routingRegressionMatchChanges: String { text("routingRegression.matchChanges", "Match changes") }
    static var routingRegressionTopRouteChanges: String { text("routingRegression.topRouteChanges", "Top-route changes") }
    static var routingRegressionItems: String { text("routingRegression.items", "Regression items") }
    static var routingRegressionNoItems: String { text("routingRegression.empty.items", "No regressions returned.") }
    static var routingRegressionNewBlockers: String { text("routingRegression.newBlockers", "New blockers") }
    static var routingRegressionNoNewBlockers: String { text("routingRegression.empty.newBlockers", "No new blockers returned.") }
    static var routingRegressionNewGaps: String { text("routingRegression.newGaps", "New gaps") }
    static var routingRegressionNoNewGaps: String { text("routingRegression.empty.newGaps", "No new gaps returned.") }
    static var routingRegressionTopRouteChanged: String { text("routingRegression.topRouteChanged", "Top route changed") }
    static var routingRegressionMatchStatus: String { text("routingRegression.matchStatus", "Match status") }
    static var routingRegressionTopRouteChange: String { text("routingRegression.topRouteChange", "Top route") }
    static var traceImportTitle: String { text("traceImport.title", "Agent Behavior Trace Import") }
    static var traceImportBoundary: String { text("traceImport.boundary", "User-triggered local trace import for routing behavior review. Results show redacted excerpts and metadata only; local import cannot call a provider, write skill files, mutate agent config, create snapshots, change triage, execute scripts, or read credentials.") }
    static var traceImportProviderBoundary: String { text("traceImport.providerBoundary", "Provider explanations remain copy-only and must use prompt preview, redaction, and confirmation; this import panel does not send provider requests.") }
    static var traceImportTextPlaceholder: String { text("traceImport.placeholder.text", "Paste local transcript or log text to import") }
    static var traceImportTitlePlaceholder: String { text("traceImport.placeholder.title", "Optional title") }
    static var traceImportTaskPlaceholder: String { text("traceImport.placeholder.task", "Optional task text") }
    static var traceImportExpectedPlaceholder: String { text("traceImport.placeholder.expected", "Optional expected skill names, separated by commas") }
    static var traceImportImportAction: String { text("traceImport.action.import", "Import Trace") }
    static var traceImportLoadAction: String { text("traceImport.action.load", "Load Imports") }
    static var traceImportDeleteAction: String { text("traceImport.action.delete", "Delete import") }
    static var traceImportInputRequired: String { text("traceImport.inputRequired", "Paste trace text before importing.") }
    static var traceImportUnavailable: String { text("traceImport.unavailable", "Trace import is unavailable in this service build.") }
    static var traceImportDeleteUnavailable: String { text("traceImport.deleteUnavailable", "Deleting trace imports is unavailable in this service build.") }
    static var traceImportLatest: String { text("traceImport.latest", "Latest trace outcome") }
    static var traceImportImports: String { text("traceImport.imports", "Trace imports") }
    static var traceImportNoImports: String { text("traceImport.empty.imports", "No trace imports returned.") }
    static var traceImportOutcome: String { text("traceImport.outcome", "Outcome") }
    static var traceImportDetectedSkills: String { text("traceImport.detectedSkills", "Detected skills") }
    static var traceImportExpectedSkills: String { text("traceImport.expectedSkills", "Expected skills") }
    static var traceImportRedactedExcerpt: String { text("traceImport.redactedExcerpt", "Redacted excerpt") }
    static var traceImportRedactionSummary: String { text("traceImport.redactionSummary", "Redaction summary") }
    static var traceImportReasons: String { text("traceImport.reasons", "Reasons") }
    static var traceImportEvidence: String { text("traceImport.evidence", "Evidence") }
    static var traceImportNoSkills: String { text("traceImport.empty.skills", "No skills returned.") }
    static var traceImportNoExcerpt: String { text("traceImport.empty.excerpt", "No redacted excerpt returned.") }
    static var traceImportNoReasons: String { text("traceImport.empty.reasons", "No reasons returned.") }
    static var llmAssist: String { text("llm.assist", "LLM Assist") }
    static var llmEnabled: String { text("llm.enabled", "Enabled") }
    static var llmDisabled: String { text("llm.disabled", "Disabled") }
    static var llmPreparing: String { text("llm.preparing", "Preparing...") }
    static var llmPreparePrompt: String { text("llm.preparePrompt", "Choose an action to preview tokens and cost.") }
    static var llmDisabledFallback: String { text("llm.disabledFallback", "LLM assist is unavailable in this build.") }
    static var llmProvider: String { text("llm.provider", "Provider") }
    static var llmModel: String { text("llm.model", "Model") }
    static var llmTokens: String { text("llm.tokens", "Tokens") }
    static var llmCost: String { text("llm.cost", "Cost") }
    static var llmConfirmationRequired: String { text("llm.confirmationRequired", "Confirmation required before any LLM call.") }
    static var llmDraftCopyRequired: String { text("llm.draftCopyRequired", "Draft output requires user confirmation and copy.") }
    static var llmReviewPreview: String { text("llm.reviewPreview", "Read-only review preview") }
    static var llmReviewPurpose: String { text("llm.reviewPurpose", "Purpose") }
    static var llmReviewRisk: String { text("llm.reviewRisk", "Risk") }
    static var llmReviewSignals: String { text("llm.reviewSignals", "Signals") }
    static var llmReviewFindings: String { text("llm.reviewFindings", "Finding explanations") }
    static var llmReviewCrossAgentFit: String { text("llm.reviewCrossAgentFit", "Cross-agent fit") }
    static var llmReviewRedaction: String { text("llm.reviewRedaction", "Redaction") }
    static var llmReviewNoFindings: String { text("llm.reviewNoFindings", "No finding explanations in this preview.") }
    static var llmReviewNoSignals: String { text("llm.reviewNoSignals", "No risk signals in this preview.") }
    static var llmReviewNoActions: String { text("llm.reviewNoActions", "No provider request, write action, or execution action is available from this preview.") }
    static var llmPromptPreviewTitle: String { text("llm.promptPreview.title", "Prompt Preview") }
    static var llmPromptPreviewAction: String { text("llm.promptPreview.action", "Preview Prompt") }
    static var llmPromptConfirmSend: String { text("llm.promptPreview.confirmSend", "Confirm & Send") }
    static var llmPromptSending: String { text("llm.promptPreview.sending", "Sending provider request...") }
    static var llmPromptProviderRequired: String { text("llm.promptPreview.providerRequired", "Configure and save an AI provider before sending.") }
    static var llmPromptPreviewRequired: String { text("llm.promptPreview.previewRequired", "Preview the current prompt before sending.") }
    static var llmPromptSendSucceeded: String { text("llm.promptPreview.sendSucceeded", "Provider response received.") }
    static var llmPromptSendFailed: String { text("llm.promptPreview.sendFailed", "Provider request failed.") }
    static var llmPromptScope: String { text("llm.promptPreview.scope", "Prompt scope") }
    static var llmPromptDestination: String { text("llm.promptPreview.destination", "Destination") }
    static var llmPromptIncludedFields: String { text("llm.promptPreview.includedFields", "Included fields") }
    static var llmPromptExcludedFields: String { text("llm.promptPreview.excludedFields", "Excluded fields") }
    static var llmPromptRedactedPrompt: String { text("llm.promptPreview.redactedPrompt", "Redacted prompt") }
    static var llmPromptNoFields: String { text("llm.promptPreview.noFields", "No fields reported.") }
    static var llmPromptRawPromptStored: String { text("llm.promptPreview.rawPromptStored", "Raw prompt stored") }
    static var llmPromptRawResponseStored: String { text("llm.promptPreview.rawResponseStored", "Raw response stored") }
    static var llmPromptCopyOnly: String { text("llm.promptPreview.copyOnly", "Copy-only output") }
    static var llmPromptOutput: String { text("llm.promptPreview.output", "Provider output") }
    static var llmPromptCopyOutput: String { text("llm.promptPreview.copyOutput", "Copy Output") }
    static var scriptExecutionSafety: String { text("scriptExecution.safety", "Script Execution Safety") }
    static var scriptExecutionPreviewOnly: String { text("scriptExecution.previewOnly", "Preview-only") }
    static var scriptExecutionUnavailable: String { text("scriptExecution.unavailable", "Script execution preflight is unavailable in this service build. Scripts remain non-executable from the native UI.") }
    static var scriptExecutionBlockedNote: String { text("scriptExecution.blockedNote", "The native UI does not execute scripts. Use this panel only to inspect the safety gate data returned by the service.") }
    static var scriptExecutionPreviewSummary: String { text("scriptExecution.previewSummary", "Script execution is blocked by default until a separate confirmed service path is available.") }
    static var scriptExecutionNoCommand: String { text("scriptExecution.noCommand", "No command preview is available.") }
    static var scriptExecutionNoRisks: String { text("scriptExecution.noRisks", "No service risks were reported.") }
    static var scriptExecutionNoAudit: String { text("scriptExecution.noAudit", "No audit identifier reported.") }
    static var scriptExecutionAuditStatus: String { text("scriptExecution.auditStatus", "Audit status") }
    static var scriptExecutionAuditID: String { text("scriptExecution.auditId", "Audit ID") }
    static var scriptExecutionCommand: String { text("scriptExecution.command", "Command preview") }
    static var scriptExecutionCWD: String { text("scriptExecution.cwd", "CWD") }
    static var scriptExecutionEnv: String { text("scriptExecution.env", "Environment") }
    static var scriptExecutionNetwork: String { text("scriptExecution.network", "Network") }
    static var scriptExecutionFiles: String { text("scriptExecution.files", "Files") }
    static var scriptExecutionRisks: String { text("scriptExecution.risks", "Risks") }
    static var scriptExecutionConfirmationRequired: String { text("scriptExecution.confirmationRequired", "Human confirmation is required before any future execution service path.") }
    static var scriptExecutionEnvEmpty: String { text("scriptExecution.envEmpty", "No environment overrides") }
    static var scriptExecutionFilesEmpty: String { text("scriptExecution.filesEmpty", "No file scope declared") }
    static var toggleUnavailableBusy: String { text("detail.toggleUnavailable.busy", "A write is already in progress.") }
    static var toggleUnavailableBroken: String { text("detail.toggleUnavailable.broken", "Broken skills cannot be toggled until their SKILL.md can be parsed.") }
    static var toggleUnavailableMissing: String { text("detail.toggleUnavailable.missing", "Missing skills cannot be toggled because the source file was not found during the last scan.") }
    static var toggleUnavailableShadowed: String { text("detail.toggleUnavailable.shadowed", "Shadowed skills are read-only here; resolve the active copy before toggling.") }
    static var toggleUnavailableUnknown: String { text("detail.toggleUnavailable.unknown", "This skill has an unknown catalog state and is read-only in this build.") }
    static var toggleUnavailableToolGlobal: String { text("detail.toggleUnavailable.toolGlobal", "Tool-global skills are read-only previews. Install or copy to an agent requires a separate confirmed action.") }
    static var piGuardedToggle: String { text("detail.pi.guardedToggle", "Guarded toggle") }
    static var piGuardedToggleBoundary: String { text("detail.pi.guardedToggle.boundary", "Pi toggle is experimental and guarded by preview, config snapshot, and rollback. Install stays blocked; no AI, scripts, or credentials are used.") }
    static var operationUnavailableBusy: String { text("detail.operationUnavailable.busy", "Another catalog operation is already in progress.") }
    static var readOnly: String { text("detail.readOnly", "Read-only") }
    static var hermesHomeProfileAccess: String { text("detail.hermes.homeProfileAccess", "Hermes home/profile skills are read-only in this build. Toggle and install stay blocked.") }
    static var hermesExternalAccess: String { text("detail.hermes.externalAccess", "Hermes external dirs are explicit read-only roots, not project roots. Toggle and install stay blocked.") }
    static var openClawWorkspaceScope: String { text("scope.openClawWorkspace", "Workspace") }
    static var openClawWorkspaceBoundary: String { text("openClaw.workspace.boundary", "OpenClaw scans only workspace skill roots (<workspace>/skills and <workspace>/.agents/skills). Generic repository roots are skipped rather than shown as missing skills.") }
    static var openClawReadOnlyAccess: String { text("detail.openClaw.readOnlyAccess", "OpenClaw skills are read-only and workspace-scoped in this build. Toggle and install stay blocked; generic repo roots are skipped, not treated as missing skills.") }
    static var openClawToggleBlocked: String { text("detail.openClaw.toggleBlocked", "OpenClaw workspace skills are read-only in this build. Toggle and install remain blocked.") }
    static var currentMatchesSnapshot: String { text("snapshot.matches", "Current agent config already matches this snapshot.") }
    static var currentDiffersFromSnapshot: String { text("snapshot.differs", "Current agent config differs from this snapshot.") }
    static var menuScanSkills: String { text("menu.scanSkills", "Scan Skills") }
    static var menuReloadSkills: String { text("menu.reloadSkills", "Reload Skills") }
    static var menuSkills: String { text("menu.skills", "Skills") }
    static var menuShowOverview: String { text("menu.showOverview", "Show Overview") }
    static var menuShowFindings: String { text("menu.showFindings", "Show Findings") }
    static var menuShowConflicts: String { text("menu.showConflicts", "Show Same-agent Conflicts") }
    static var menuClearSearch: String { text("menu.clearSearch", "Clear Search") }

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

    static func taskBenchmarkExpectedCurrentSkill(_ skill: String, _ agent: String) -> String {
        format("taskBenchmark.expectedCurrentSkill", "Expected and acceptable route: %@ (%@)", skill, agent)
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

    static var findingTriageReopened: String { text("findings.triage.reopened", "Reopened finding locally. No agent config or skill files were changed.") }

    static func ruleTuningSetSeverity(_ severity: String) -> String {
        format("rules.tuning.setSeverity", "Set %@", severity)
    }

    static func ruleTuningSeverityUpdated(_ severity: String) -> String {
        format("rules.tuning.updated.severity", "Set app-local rule severity override to %@. No skill files, agent config, snapshots, scripts, AI provider calls, or credentials were touched.", severity)
    }

    static var ruleTuningSeverityCleared: String { text("rules.tuning.cleared.severity", "Cleared app-local rule severity override. No skill files or agent config were changed.") }
    static var ruleTuningSuppressionUpdated: String { text("rules.tuning.updated.suppression", "Updated app-local rule suppression. No skill files, agent config, snapshots, scripts, AI provider calls, or credentials were touched.") }
    static var ruleTuningSuppressionCleared: String { text("rules.tuning.cleared.suppression", "Cleared app-local rule suppression. No skill files or agent config were changed.") }

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

    static func localReportExported(_ filename: String) -> String {
        format("localReport.exported", "Exported local redacted report: %@.", filename)
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

    static var codexRestartRequired: String { text("message.codexRestartRequired", "Codex runtime may need restart to read config.toml changes.") }

    static func rollbackRescanned(_ count: Int) -> String {
        format("message.rollbackRescanned", "Rolled back agent config snapshot and rescanned %d skills.", count)
    }

    static var refreshAfterWrite: String { text("refresh.afterWrite", "Catalog refreshed after the settings write.") }

    static func refreshAfterRollback(_ count: Int) -> String {
        format("refresh.afterRollback", "Catalog refreshed after agent config rollback with %d scanned skills.", count)
    }

    static var refreshAfterSettingsSave: String { text("refresh.afterSettingsSave", "Catalog refreshed after saving settings.") }

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

    static var savedSettings: String { text("message.savedSettings", "Saved settings and refreshed catalog.") }

    static func projectSelectedAndScanned(_ name: String) -> String {
        format("message.projectSelectedAndScanned", "Selected %@ and refreshed catalog.", name)
    }

    static var projectClearedAndScanned: String { text("message.projectClearedAndScanned", "Cleared project context and refreshed catalog.") }
    static var projectScanSkippedValidation: String { text("refresh.projectValidationSkipped", "Project context needs attention before scanning.") }

    static func projectValidationFailed(_ reason: String) -> String {
        format("project.validationFailed", "Project validation failed: %@.", reason)
    }

    static func cleanupAgentFilterNote(_ agent: String) -> String {
        format("cleanup.filter.agentNote", "Agent filter: %@", agent)
    }

    private static var activeLanguage = AppLanguage.fromStorage(UserDefaults.standard.string(forKey: AppLanguage.storageKey))
    private static var cachedLocalizedStrings: (language: AppLanguage, strings: [String: String])?

    @discardableResult
    static func use(_ language: AppLanguage) -> AppLanguage {
        activeLanguage = language
        if cachedLocalizedStrings?.language != language {
            cachedLocalizedStrings = nil
        }
        return language
    }

    static var currentLanguage: AppLanguage {
        activeLanguage
    }

    static func text(_ key: String, _ defaultValue: String) -> String {
        localizedStrings()[key] ?? defaultValue
    }

    private static func format(_ key: String, _ defaultValue: String, _ arguments: CVarArg...) -> String {
        String(format: text(key, defaultValue), arguments: arguments)
    }

    private static func localizedStrings() -> [String: String] {
        if let cachedLocalizedStrings, cachedLocalizedStrings.language == activeLanguage {
            return cachedLocalizedStrings.strings
        }

        #if SWIFT_PACKAGE
        let strings = strings(for: activeLanguage, in: .module) ?? strings(for: activeLanguage, in: .main) ?? [:]
        #else
        let strings = strings(for: activeLanguage, in: .main) ?? [:]
        #endif
        cachedLocalizedStrings = (activeLanguage, strings)
        return strings
    }

    private static func strings(for language: AppLanguage, in parent: Bundle) -> [String: String]? {
        let resourceNames = [language.rawValue, language.rawValue.lowercased()]
        guard
            let path = resourceNames.lazy.compactMap({ parent.path(forResource: "Localizable", ofType: "strings", inDirectory: "\($0).lproj") }).first,
            let dictionary = NSDictionary(contentsOfFile: path) as? [String: String]
        else {
            return nil
        }
        return dictionary
    }

    #if DEBUG
    static func localizationResourceDiagnostics(for language: AppLanguage) -> (paths: [String], count: Int) {
        let resourceNames = [language.rawValue, language.rawValue.lowercased()]
        #if SWIFT_PACKAGE
        let parents: [Bundle] = [.module, .main]
        #else
        let parents: [Bundle] = [.main]
        #endif
        let paths = parents.flatMap { parent in
            resourceNames.compactMap { parent.path(forResource: "Localizable", ofType: "strings", inDirectory: "\($0).lproj") }
        }
        #if SWIFT_PACKAGE
        let count = strings(for: language, in: .module)?.count ?? strings(for: language, in: .main)?.count ?? 0
        #else
        let count = strings(for: language, in: .main)?.count ?? 0
        #endif
        return (paths, count)
    }
    #endif
}
