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
    static let llmExplainConflict = text("llm.action.explainConflict", "Explain Conflict")
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
    static let noMatchingFindingsMessage = text("empty.noMatchingFindings.message", "Adjust the severity or rule filter to show findings.")
    static let noConflicts = text("empty.noConflicts", "No Conflicts")
    static let noConflictsMessage = text("empty.noConflicts.message", "No conflict group currently references this skill.")
    static let noSnapshots = text("empty.noSnapshots", "No Agent Config History")
    static let noSnapshotsMessage = text("empty.noSnapshots.message", "No agent config snapshots have been recorded for this agent yet.")
    static let snapshotPreview = text("snapshot.preview", "Agent Config Preview")
    static let rollbackSnapshotQuestion = text("snapshot.rollback.question", "Rollback Agent Config?")
    static let current = text("snapshot.current", "Current Agent Config")
    static let snapshot = text("snapshot.snapshot", "Snapshot Agent Config")
    static let agentConfigHistory = text("sidebar.agentConfigHistory", "Agent Config History")
    static let agentConfigHistorySummary = text("sidebar.agentConfigHistory.summary", "Preview or roll back saved configuration snapshots for the selected agent.")
    static let recentActivity = text("detail.recentActivity", "Recent Activity")
    static let noRecentActivity = text("detail.recentActivity.empty", "No enable or disable activity has been recorded for this skill yet.")
    static let loadingRecentActivity = text("detail.recentActivity.loading", "Loading activity...")
    static let activityPayload = text("detail.activity.payload", "Payload")
    static let emptyPlaceholder = text("value.empty", "<empty>")
    static let definition = text("metadata.definition", "Definition")
    static let catalogID = text("metadata.catalogId", "Catalog ID")
    static let source = text("metadata.source", "Source")
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
    static let allSeverities = text("findings.filter.allSeverities", "All Severities")
    static let allRuleIDs = text("findings.filter.allRules", "All Rule IDs")
    static let findingRemediation = text("findings.remediation", "Suggested remediation")
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
    static let menuShowConflicts = text("menu.showConflicts", "Show Conflicts")
    static let menuClearSearch = text("menu.clearSearch", "Clear Search")

    static func enabledSummary(enabled: Int, total: Int) -> String {
        format("sidebar.enabledSummary", "%d of %d enabled", enabled, total)
    }

    static func visibleSummary(_ count: Int) -> String {
        format("sidebar.visibleSummary", "%d visible", count)
    }

    static func visibleFindingsSummary(_ visible: Int, _ total: Int) -> String {
        format("findings.visibleSummary", "%d of %d findings", visible, total)
    }

    static func findingGroupCount(_ count: Int) -> String {
        format("findings.groupCount", "%d findings", count)
    }

    static func noFindingsForSkillMessage(_ agent: String) -> String {
        format("empty.noFindingsForSkill.message", "No rule findings are associated with this %@ skill.", agent)
    }

    static func findingScopeSummary(_ skill: String, _ agent: String) -> String {
        format("findings.scopeSummary", "%@ · %@", skill, agent)
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
        format("refresh.reloaded", "Reloaded %d skills, %d findings, and %d conflicts.", skills, findings, conflicts)
    }

    static func refreshScanComplete(_ scanned: Int, _ skills: Int, _ findings: Int, _ conflicts: Int) -> String {
        format("refresh.scanComplete", "Scan complete: %d scanned, %d in catalog, %d findings, %d conflicts.", scanned, skills, findings, conflicts)
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

    static func text(_ key: String, _ defaultValue: String) -> String {
        NSLocalizedString(key, tableName: nil, bundle: .main, value: defaultValue, comment: "")
    }

    private static func format(_ key: String, _ defaultValue: String, _ arguments: CVarArg...) -> String {
        String(format: text(key, defaultValue), arguments: arguments)
    }
}
