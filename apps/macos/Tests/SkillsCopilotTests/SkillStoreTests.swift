import Foundation
@testable import SkillsCopilot

@MainActor
struct SkillStoreTests {
    func run() async throws {
        try await reloadKeepsSelectedSkillWhenItStillExists()
        try await reloadFallsBackToFirstSkillWhenSelectionIsMissing()
        try await emptyCatalogKeepsFriendlyEmptyModel()
        try await serviceErrorClearsLoadingAndKeepsReadableError()
        try await reloadUsesStateSnapshotForCollectionRefresh()
        try await stateSnapshotRefreshesDoNotReuseStaleFindingsOrPermissions()
        try await selectedDetailDataIsScopedToCurrentAgentAndSkill()
        try await scanAllUsesGenericCatalogMethod()
        try await searchAndFilterChangesNormalizeSelectionAndDetail()
        try await agentConfigTimelineFollowsSelectedAgentFilterOnly()
        try await previewRollbackShowsDiffWithoutCallingRollback()
        try await rollbackSnapshotRequiresVisibleAgentTimelineRecord()
        try await refreshOperationsIgnoreReentryWhileBusy()
        try await agentFilterLimitsVisibleSkillsAndSelection()
        try await allAgentFilterDoesNotFetchMixedConfigHistory()
        try await toggleSelectedSkillExposesWritingStateAndRefreshesSelection()
        try await writeOperationsIgnoreReentryWhileBusy()
        try await codexToggleAddsRestartRequiredNotice()
        try await opencodeToggleCallsServiceAndRefreshesSelection()
        try await toolGlobalToggleIsPreviewOnlyAndDoesNotCallService()
        try await batchTogglePreviewFiltersReadOnlyAndNoopSkills()
        try await batchToggleApplyUsesBatchServiceAndRefreshes()
        try await batchToggleApplyRequiresCurrentPreviewConfirmation()
        try await localReportExportUsesUserTriggeredServiceContract()
        try await localReportExportUnavailableDoesNotPretendFileWasWritten()
        try await reloadLoadsProjectContext()
        try await setProjectStoresContextAndScans()
        try await clearProjectClearsContextAndScans()
        try await projectValidationErrorSkipsScanAndSurfacesMessage()
        try await reloadFallsBackToDisabledLLMWhenOldServiceDoesNotSupportMethods()
        try await prepareLLMActionStoresEstimateWithoutProviderCall()
        try await prepareSkillAnalysisUsesReadOnlyPrepareContract()
        try await prepareSkillAnalysisFallsBackWhenMethodUnavailable()
        try await scoreSkillQualityUsesReadOnlyAnalysisContract()
        try await taskReadinessUsesReadOnlyCheckContract()
        try await taskReadinessPromptSendRequiresConfiguredProvider()
        try await routingConfidenceUsesReadOnlyRankContract()
        try await routingConfidencePromptSendRequiresConfiguredProvider()
        try await taskBenchmarkUsesLocalServiceContract()
        try await taskBenchmarkFallsBackWhenMethodUnavailable()
        try await routingRegressionUsesLocalBenchmarkServiceContract()
        try await routingRegressionFallsBackWhenMethodUnavailable()
        try await agentTraceImportUsesLocalServiceContract()
        try await agentTraceImportFallsBackWhenMethodUnavailable()
        try await routingAccuracyDashboardUsesReadOnlyServiceContract()
        try await staleDriftDetectionUsesReadOnlyServiceContract()
        try await knowledgeSearchUsesReadOnlyServiceContract()
        try await localSkillMapUsesReadOnlyServiceContract()
        try await localSkillMapFallsBackWhenMethodUnavailable()
        try await skillLifecycleTimelineUsesReadOnlyServiceContract()
        try await skillLifecycleTimelineFallsBackWhenMethodUnavailable()
        try await providerObservabilityUsesReadOnlyServiceContract()
        try await providerObservabilityFallsBackWhenMethodUnavailable()
        try await taskCockpitUsesReadOnlyServiceContract()
        try await taskCockpitFallsBackWhenMethodUnavailable()
        try await similarSkillGroupingUsesReadOnlyServiceContract()
        try await similarSkillGroupingFallsBackWhenMethodUnavailable()
        try await capabilityTaxonomyUsesReadOnlyServiceContract()
        try await capabilityTaxonomyFallsBackWhenMethodUnavailable()
        try await workspaceReadinessUsesReadOnlyServiceContract()
        try await workspaceReadinessFallsBackWhenMethodUnavailable()
        try await remediationPlanUsesReadOnlyServiceContract()
        try await remediationPlanFallsBackWhenMethodUnavailable()
        try await remediationPreviewDraftsUsesCopyOnlyServiceContract()
        try await remediationPreviewDraftsFallsBackWhenMethodUnavailable()
        try await remediationImpactPreviewUsesReadOnlyServiceContract()
        try await remediationImpactPreviewFallsBackWhenMethodUnavailable()
        try await remediationBatchReviewUsesReadOnlyServiceContract()
        try await remediationBatchReviewFallsBackWhenMethodUnavailable()
        try await remediationHistoryUsesLocalServiceContract()
        try await remediationHistoryFallsBackWhenMethodUnavailable()
        try await guidedCleanupFlowUsesLocalServiceContract()
        try await guidedCleanupFlowFallsBackWhenMethodUnavailable()
        try await crossAgentReadinessUsesReadOnlyServiceContract()
        try await routingConfidenceClearsStaleSelection()
        try await llmPreparePreviewIsScopedToSelectedSkillAndReadOnly()
        try await promptPreviewRequiresConfiguredProviderAndExplicitSend()
        try await previewScriptExecutionSafetyStoresBlockedPreviewWithoutExecute()
    }

    private func reloadKeepsSelectedSkillWhenItStillExists() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "normal")

        let store = SkillStore(service: ServiceClient())
        store.selectedSkillID = "beta"
        await store.reload()

        try expectEqual(store.selectedSkillID, "beta", "Reload should keep an existing selected skill ID.")
        try expectEqual(store.selectedSkill?.id, "beta", "Reload should keep the selected skill model stable.")
        try expectEqual(store.selectedSkillDetail?.id, "beta", "Reload should load detail for the stable selection.")
        try expectFalse(store.isLoading, "Reload should reset loading state.")
        try expectNil(store.errorMessage, "Reload should not set an error on success.")
    }

    private func reloadFallsBackToFirstSkillWhenSelectionIsMissing() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "normal")

        let store = SkillStore(service: ServiceClient())
        store.selectedSkillID = "missing"
        await store.reload()

        try expectEqual(store.selectedSkillID, "alpha", "Reload should select the first skill when the previous selection disappears.")
        try expectEqual(store.selectedSkill?.id, "alpha", "Fallback selection should expose the first skill model.")
        try expectEqual(store.selectedSkillDetail?.id, "alpha", "Fallback selection should load matching detail.")
    }

    private func emptyCatalogKeepsFriendlyEmptyModel() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "empty")

        let store = SkillStore(service: ServiceClient())
        store.selectedSkillID = "missing"
        await store.reload()

        try expectEqual(store.skills.count, 0, "Empty catalog should expose no skills.")
        try expectEqual(store.filteredSkills.count, 0, "Empty catalog should expose no filtered skills.")
        try expectEqual(store.enabledCount, 0, "Empty catalog should expose zero enabled skills.")
        try expectNil(store.selectedSkillID, "Empty catalog should clear a stale selection.")
        try expectNil(store.selectedSkill, "Empty catalog should not synthesize a selected skill.")
        try expectNil(store.selectedSkillDetail, "Empty catalog should not synthesize detail.")
        try expectNil(store.errorMessage, "Empty catalog should not be treated as an error.")
        try expectFalse(store.isLoading, "Empty catalog reload should reset loading state.")
    }

    private func serviceErrorClearsLoadingAndKeepsReadableError() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "error")

        let store = SkillStore(service: ServiceClient())
        await store.reload()

        try expectFalse(store.isLoading, "Failed reload should reset loading state.")
        try expectContains(store.errorMessage, "test.error: boom", "Failed reload should surface the service error.")
        try expectEqual(store.skills.count, 0, "Failed reload should not invent skills.")
        try expectNil(store.selectedSkillID, "Failed reload should not invent selection.")
    }

    private func reloadUsesStateSnapshotForCollectionRefresh() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "normal")

        let store = SkillStore(service: ServiceClient())
        await store.reload()

        let calls = fake.calls()
        try expectEqual(countOccurrences("app.stateSnapshot", in: calls), 1, "Reload should refresh status and collections with one app state snapshot call.")
        try expectEqual(countOccurrences("service.status", in: calls), 0, "Reload collection refresh should not launch a separate status sidecar.")
        try expectEqual(countOccurrences("catalog.listSkills", in: calls), 0, "Reload collection refresh should not launch a separate skills list sidecar.")
        try expectEqual(countOccurrences("catalog.listFindings", in: calls), 0, "Reload collection refresh should not launch a separate findings list sidecar.")
        try expectEqual(countOccurrences("catalog.listConflicts", in: calls), 0, "Reload collection refresh should not launch a separate conflicts list sidecar.")
        try expectEqual(countMethodCalls("snapshot.list", in: calls), 0, "Reload collection refresh should not launch a global snapshots list sidecar.")
        try expectEqual(countMethodCalls("snapshot.listAgentConfig", in: calls), 1, "Reload should refresh the selected agent config history.")
        try expectContains(calls, "llm.status", "Reload should preserve the separate LLM status behavior.")
        try expectContains(calls, "project.getContext", "Reload should preserve the separate project context behavior.")
    }

    private func stateSnapshotRefreshesDoNotReuseStaleFindingsOrPermissions() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "stale-before")

        let store = SkillStore(service: ServiceClient())
        store.selectedSkillID = "beta"
        await store.reload()

        try expectEqual(store.selectedFindings.map(\.id), ["finding-stale-before"], "Initial reload should expose the stale-before finding fixture.")
        try expectEqual(permissionMarker(store.selectedSkillDetail), "before", "Initial reload should load the before permissions fixture.")

        store.searchText = "alpha"
        try await waitUntil("Search filter should move selection away from beta.") {
            store.selectedSkillID == "alpha"
        }
        try expectEqual(store.selectedFindings.map(\.id), [], "Filter changes should not keep findings from the previous selected skill.")

        store.searchText = ""
        store.selectedSkillID = "beta"
        fake.setScenario("stale-after-scan")
        await store.scanAll()

        try expectEqual(store.findings.map(\.id), ["finding-fresh-scan", "finding-fresh-codex"], "Scan refresh should replace stale findings from the prior snapshot.")
        try expectEqual(store.selectedFindings.map(\.id), ["finding-fresh-scan"], "Scan refresh should expose findings for the current selection only.")
        try expectEqual(permissionMarker(store.selectedSkillDetail), "scan", "Scan refresh should reload selected detail permissions.")

        store.agentFilter = .codex
        try await waitUntil("Agent filter should move selection to the Codex fixture.") {
            store.selectedSkillID == "gamma" && store.selectedSkillDetail?.id == "gamma"
        }
        try expectEqual(store.selectedFindings.map(\.id), ["finding-fresh-codex"], "Agent filter should not show findings from a previously selected adapter.")
        try expectEqual(permissionMarker(store.selectedSkillDetail), "codex-scan", "Agent filter should load detail permissions for the newly selected adapter.")

        fake.setScenario("stale-after-project")
        await store.setProject(rootPath: "/tmp/project", currentCWD: "/tmp/project", name: "Fixture Project")

        try expectEqual(store.findings.map(\.id), ["finding-project"], "Project context scan should replace findings from the previous adapter state.")
        try expectEqual(store.selectedFindings.map(\.id), ["finding-project"], "Project context scan should expose the fresh selected finding.")
        try expectEqual(permissionMarker(store.selectedSkillDetail), "project", "Project context scan should reload selected detail permissions.")

        store.agentFilter = .all
        store.selectedSkillID = "beta"
        fake.setScenario("stale-after-toggle")
        await store.toggleSelectedSkill(on: false)

        try expectEqual(store.findings.map(\.id), ["finding-toggle"], "Adapter state changes should replace stale findings.")
        try expectEqual(store.selectedFindings.map(\.id), ["finding-toggle"], "Adapter state changes should keep selected findings fresh.")
        try expectEqual(permissionMarker(store.selectedSkillDetail), "toggle", "Adapter state changes should reload selected detail permissions.")
    }

    private func selectedDetailDataIsScopedToCurrentAgentAndSkill() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "detail-scope")

        let store = SkillStore(service: ServiceClient())
        store.selectedSkillID = "beta"
        await store.reload()

        try expectEqual(store.selectedSkill?.id, "beta", "Fixture should select the Claude beta skill.")
        try expectEqual(store.selectedFindings.map(\.id), ["finding-beta-instance"], "Selected findings must use the selected instance, not a shared definition or another agent.")
        try expectEqual(store.selectedConflicts.map(\.id), ["conflict-beta-alpha"], "Selected conflicts should include only same-agent runtime conflicts for the selected skill.")
        try expectEqual(store.selectedSkillEvents.map(\.id), [1001], "Selected history should show only toggle activity for the current skill.")

        store.agentFilter = .codex
        try await waitUntil("Agent filter should move detail selection to the Codex skill and load its events.") {
            store.selectedSkillID == "gamma" && store.selectedSkillEvents.map(\.id) == [2001]
        }

        try expectEqual(store.selectedSkill?.agent, "codex", "Selection should now be scoped to the Codex agent.")
        try expectEqual(store.selectedFindings.map(\.id), ["finding-gamma-instance"], "Changing agents must not keep Claude findings on the detail page.")
        try expectEqual(store.selectedConflicts.map(\.id), [], "Cross-agent duplicate/source overlap must not appear as a detail conflict.")
        try expectContains(fake.calls(), "\"instance_id\":\"beta\"", "Skill event fetch should request the selected beta instance.")
        try expectContains(fake.calls(), "\"instance_id\":\"gamma\"", "Skill event fetch should request the selected gamma instance after agent change.")
    }

    private func scanAllUsesGenericCatalogMethod() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "normal")

        let store = SkillStore(service: ServiceClient())
        await store.scanAll()

        try expectFalse(store.isScanning, "Scan should reset scanning state.")
        try expectNil(store.errorMessage, "Generic scan should not set an error on success.")
        try expectEqual(store.skills.count, 3, "Generic scan should refresh the catalog collections.")
        try expectEqual(store.skills.first { $0.id == "gamma" }?.agent, "codex", "Scan fixtures should exercise a Codex skill record.")
        try expectEqual(store.lastMutationMessage, UIStrings.scannedSkills(3), "Generic scan should expose adapter-neutral copy.")
        try expectEqual(store.refreshStatusMessage, UIStrings.refreshScanComplete(3, 3, 0, 0), "Generic scan should use refresh activity counts.")
        try expectEqual(store.lastScanActivity?.agentSummaries?.count, 2, "Scan should retain per-agent adapter diagnostics when the service provides them.")
        try expectEqual(store.lastScanActivity?.agentSummaries?.first { $0.agent == "claude-code" }?.rootsSkipped, ["/tmp/missing-claude"], "Scan diagnostics should decode skipped roots.")
        store.agentFilter = .codex
        try expectEqual(store.selectedAgentRefreshSummary?.rootsScanned, ["/tmp/codex"], "Selected adapter diagnostics should follow the agent filter.")
        try expectEqual(countOccurrences("app.stateSnapshot", in: fake.calls()), 1, "Scan should refresh collections with one app state snapshot call.")
        try expectEqual(countOccurrences("catalog.listSkills", in: fake.calls()), 0, "Scan refresh should not launch a separate skills list sidecar.")
        try expectEqual(countOccurrences("catalog.listFindings", in: fake.calls()), 0, "Scan refresh should not launch a separate findings list sidecar.")
        try expectEqual(countOccurrences("catalog.listConflicts", in: fake.calls()), 0, "Scan refresh should not launch a separate conflicts list sidecar.")
        try expectEqual(countMethodCalls("snapshot.list", in: fake.calls()), 0, "Scan refresh should not launch a global snapshots list sidecar.")
        try expectFalse(countMethodCalls("snapshot.listAgentConfig", in: fake.calls()) == 0, "Scan refresh should refresh at least one writable agent config history.")
    }

    private func searchAndFilterChangesNormalizeSelectionAndDetail() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "toggle-disabled")

        let store = SkillStore(service: ServiceClient())
        store.selectedSkillID = "gamma"
        await store.reload()

        store.searchText = "beta"
        try await waitUntil("Search should move selection to the visible matching skill.") {
            store.selectedSkillID == "beta" && store.selectedSkillDetail?.id == "beta"
        }

        store.searchText = ""
        try await waitUntil("Clearing search should keep the normalized visible selection and matching detail.") {
            store.selectedSkillID == "beta" && store.selectedSkillDetail?.id == "beta"
        }

        store.stateFilter = .enabled
        try await waitUntil("State filter should move selection to a visible enabled skill and load matching detail.") {
            store.selectedSkillID == "alpha" && store.selectedSkillDetail?.id == "alpha"
        }
    }

    private func refreshOperationsIgnoreReentryWhileBusy() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "scan-slow")

        let store = SkillStore(service: ServiceClient())
        let task = Task {
            await store.scanAll()
        }

        try await waitUntil("Scan should expose scanning state while the service request is in flight.") {
            store.isScanning
        }

        await store.scanAll()
        await store.reload()
        await store.setProject(rootPath: "/tmp/project", currentCWD: "/tmp/project", name: "Fixture Project")
        await store.clearProject()
        await task.value

        try expectEqual(countOccurrences("catalog.scanAll", in: fake.calls()), 1, "Busy scan should ignore nested scan/reload/project update attempts.")
        try expectFalse(fake.calls().contains("project.setContext"), "Busy scan should guard project set reentry.")
        try expectFalse(fake.calls().contains("project.clearContext"), "Busy scan should guard project clear reentry.")
    }

    private func agentConfigTimelineFollowsSelectedAgentFilterOnly() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "timeline")

        let store = SkillStore(service: ServiceClient())
        store.selectedSkillID = "beta"
        await store.reload()

        try expectEqual(store.selectedAgentConfigTimelineAgent, "claude-code", "Default timeline should use the selected agent filter.")
        try expectEqual(store.agentConfigSnapshots.map(\.id), ["snap-claude-new", "snap-claude-old"], "Claude filter should show only Claude config snapshots.")
        try expectEqual(Set(store.agentConfigSnapshots.map(\.agent)), Set(["claude-code"]), "Claude timeline should not include other agents.")

        let callsAfterReload = countMethodCalls("snapshot.listAgentConfig", in: fake.calls())
        store.selectedSkillID = "alpha"
        await store.loadSelectedDetail()
        try expectEqual(store.agentConfigSnapshots.map(\.id), ["snap-claude-new", "snap-claude-old"], "Changing skill selection within an agent must not turn config snapshots into per-skill history.")
        try expectEqual(countMethodCalls("snapshot.listAgentConfig", in: fake.calls()), callsAfterReload, "Skill detail changes should not reload agent config history.")

        store.agentFilter = .codex
        try await waitUntil("Codex filter should load only Codex config snapshots.") {
            store.agentConfigSnapshots.map(\.id) == ["snap-codex"]
        }
        try expectEqual(store.selectedAgentConfigTimelineAgent, "codex", "Codex timeline should use the selected agent filter.")
        try expectEqual(Set(store.agentConfigSnapshots.map(\.agent)), Set(["codex"]), "Codex timeline should not include Claude snapshots.")
        try expectContains(fake.calls(), "\"agent\":\"codex\"", "Timeline fetch should request the selected Codex agent.")

        store.agentFilter = .all
        try await waitUntil("All filter should not merge every agent config timeline.") {
            store.agentConfigSnapshots.isEmpty
        }
        try expectNil(store.selectedAgentConfigTimelineAgent, "All filter has no single selected agent timeline.")
    }

    private func previewRollbackShowsDiffWithoutCallingRollback() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "timeline")

        let store = SkillStore(service: ServiceClient())
        await store.reload()

        let preview = try await store.previewRollback(snapshotID: "snap-claude-new")

        try expectEqual(preview.snapshot.id, "snap-claude-new", "Preview should return the selected snapshot.")
        try expectEqual(preview.snapshot.agent, "claude-code", "Preview should keep the snapshot agent.")
        try expectContains(preview.currentContent, "skillOverrides", "Preview diff should include current config content.")
        try expectEqual(preview.changed, true, "Preview should report that current config differs from the snapshot.")
        try expectEqual(preview.rollbackSupported, true, "Preview should expose rollback support without performing it.")
        try expectContains(fake.calls(), "snapshot.previewRollback", "Preview should call only the preview method.")
        try expectEqual(countMethodCalls("snapshot.rollback", in: fake.calls()), 0, "Preview must not call rollback or write automatically.")
    }

    private func rollbackSnapshotRequiresVisibleAgentTimelineRecord() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "timeline")

        let store = SkillStore(service: ServiceClient())
        await store.reload()

        await store.rollbackSnapshot(snapshotID: "snap-codex")

        try expectContains(store.errorMessage, "selected agent config timeline", "Rollback should reject snapshots outside the selected agent timeline.")
        try expectEqual(countMethodCalls("snapshot.rollback", in: fake.calls()), 0, "Rollback guard should not call the write API for hidden agent snapshots.")
    }

    private func agentFilterLimitsVisibleSkillsAndSelection() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "normal")

        let store = SkillStore(service: ServiceClient())
        store.selectedSkillID = "beta"
        await store.reload()

        store.agentFilter = .codex

        try expectEqual(store.filteredSkills.map(\.id), ["gamma"], "Codex filter should expose only Codex skills.")
        try expectEqual(store.filteredSkillGroups.map(\.title), [UIStrings.codex], "Codex filter should group under the Codex display name.")
        try expectEqual(store.selectedSkillID, "gamma", "Agent filter should move selection to a visible skill.")
        try expectEqual(store.selectedSkill?.agent, "codex", "Selected skill should respect the active agent filter.")
    }

    private func allAgentFilterDoesNotFetchMixedConfigHistory() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "normal")

        let store = SkillStore(service: ServiceClient())
        store.agentFilter = .all
        await store.reload()

        try expectEqual(store.agentConfigSnapshots.count, 0, "All Agents should not expose a mixed agent-config history.")
    }

    private func toggleSelectedSkillExposesWritingStateAndRefreshesSelection() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "normal")

        let store = SkillStore(service: ServiceClient())
        store.selectedSkillID = "beta"
        await store.reload()

        fake.setScenario("toggle-disabled")
        let task = Task {
            await store.toggleSelectedSkill(on: false)
        }

        try await waitUntil("Toggle should expose writing state while the service request is in flight.") {
            store.isWriting
        }
        await task.value

        try expectFalse(store.isWriting, "Toggle should reset writing state.")
        try expectNil(store.errorMessage, "Toggle should not set an error on success.")
        try expectEqual(store.selectedSkillID, "beta", "Toggle refresh should keep the selected skill stable.")
        try expectEqual(store.selectedSkill?.enabled, false, "Toggle refresh should expose the updated enabled state.")
        try expectEqual(store.selectedSkillDetail?.enabled, false, "Toggle refresh should reload detail for the updated skill.")
        try expectEqual(store.lastMutationMessage, UIStrings.toggledSkill(on: false, name: "Beta"), "Toggle should expose a success message.")
    }

    private func writeOperationsIgnoreReentryWhileBusy() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "normal")

        let store = SkillStore(service: ServiceClient())
        store.selectedSkillID = "beta"
        await store.reload()

        fake.setScenario("toggle-disabled")
        let task = Task {
            await store.toggleSelectedSkill(on: false)
        }

        try await waitUntil("Toggle should expose writing state while the service request is in flight.") {
            store.isWriting
        }
        await store.toggleSelectedSkill(on: true)
        await task.value

        try expectEqual(countOccurrences("config.toggleSkill", in: fake.calls()), 1, "Busy write should ignore reentrant write attempts.")
    }

    private func codexToggleAddsRestartRequiredNotice() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "normal")

        let store = SkillStore(service: ServiceClient())
        store.agentFilter = .codex
        store.selectedSkillID = "gamma"
        await store.reload()

        fake.setScenario("toggle-codex-disabled")
        await store.toggleSelectedSkill(on: false)

        try expectFalse(store.isWriting, "Codex toggle should reset writing state.")
        try expectNil(store.errorMessage, "Codex toggle should not set an error on success.")
        try expectEqual(store.selectedSkillID, "gamma", "Codex toggle refresh should keep the selected skill stable.")
        try expectEqual(store.selectedSkill?.enabled, false, "Codex toggle refresh should expose the updated enabled state.")
        try expectEqual(store.selectedSkillDetail?.enabled, false, "Codex toggle refresh should reload detail for the updated skill.")
        try expectEqual(
            store.lastMutationMessage,
            UIStrings.toggledSkill(on: false, name: "Gamma", agent: "codex"),
            "Codex toggle should add the restart-required note."
        )
        try expectContains(store.lastMutationMessage, UIStrings.codexRestartRequired, "Codex toggle should mention restart.")
    }

    private func opencodeToggleCallsServiceAndRefreshesSelection() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "opencode")

        let store = SkillStore(service: ServiceClient())
        store.agentFilter = .opencode
        store.selectedSkillID = "omega"
        await store.reload()

        guard let selectedSkill = store.selectedSkill else {
            throw NativeModelTestFailure(description: "Fixture should select an opencode skill.")
        }
        try expectEqual(store.selectedSkill?.agent, "opencode", "Fixture should select an opencode skill.")
        try expectNil(
            DisplayText.toggleDisabledReason(for: selectedSkill, isWriting: false),
            "opencode toggle should be available in V2.12."
        )

        await store.toggleSelectedSkill(on: false)

        try expectFalse(store.isWriting, "opencode toggle should finish writing state.")
        try expectNil(store.errorMessage, "opencode toggle should not surface a read-only error.")
        try expectContains(fake.calls(), "config.toggleSkill", "opencode toggle should call the write API.")
        try expectEqual(store.selectedSkill?.enabled, false, "opencode toggle refresh should expose the updated enabled state.")
        try expectEqual(store.selectedSkillDetail?.enabled, false, "opencode toggle refresh should reload detail for the updated skill.")
    }

    private func toolGlobalToggleIsPreviewOnlyAndDoesNotCallService() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "tool-global")

        let store = SkillStore(service: ServiceClient())
        store.agentFilter = .all
        store.selectedSkillID = "tool-alpha"
        await store.reload()

        let expectedReason = UIStrings.toggleUnavailableToolGlobal
        guard let selectedSkill = store.selectedSkill else {
            throw NativeModelTestFailure(description: "Fixture should select a tool-global skill.")
        }
        try expectEqual(store.selectedSkill?.scope, "tool-global", "Fixture should select a tool-global skill.")
        try expectEqual(
            DisplayText.toggleDisabledReason(for: selectedSkill, isWriting: false),
            expectedReason,
            "Tool-global toggle should explain the read-only preview and confirmed install path."
        )

        await store.toggleSelectedSkill(on: false)

        try expectFalse(store.isWriting, "Tool-global toggle should not enter writing state.")
        try expectEqual(store.errorMessage, expectedReason, "Tool-global toggle should surface the disabled reason.")
        try expectFalse(fake.calls().contains("config.toggleSkill"), "Tool-global toggle should not call the write API.")
    }

    private func batchTogglePreviewFiltersReadOnlyAndNoopSkills() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "batch-mixed")

        let store = SkillStore(service: ServiceClient())
        store.agentFilter = .all
        store.batchToggleAction = .disable
        await store.reload()
        await store.previewVisibleBatchToggle()

        guard let preview = store.batchTogglePreview else {
            throw NativeModelTestFailure(description: "Batch preview should be stored.")
        }
        try expectEqual(preview.action, .disable, "Batch preview should preserve the selected action.")
        try expectEqual(preview.selectedCount, 4, "Batch preview should include the visible filtered skills.")
        try expectEqual(preview.writableCount, 2, "Batch preview should include only writable affected skills.")
        try expectEqual(preview.skippedCount, 2, "Batch preview should skip read-only and no-op skills.")
        try expectEqual(preview.affectedSkills.map(\.instanceID), ["alpha", "gamma"], "Batch preview should affect writable enabled skills.")
        try expectEqual(preview.skippedItems.map(\.instanceID), ["beta", "pi-one"], "Batch preview should report skipped skills.")
        try expectContains(preview.skippedItems.first { $0.instanceID == "pi-one" }?.reason, "read-only", "Read-only agent skip reason should be visible.")
        try expectContains(fake.calls(), "batch.previewSkillToggles", "Batch preview should use the service preview method.")
        try expectFalse(fake.calls().contains("batch.applySkillToggles"), "Preview must not apply.")
        try expectFalse(fake.calls().contains("config.toggleSkill"), "Batch preview must not use the single-toggle write path.")
    }

    private func batchToggleApplyUsesBatchServiceAndRefreshes() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "batch-mixed")

        let store = SkillStore(service: ServiceClient())
        store.agentFilter = .all
        store.batchToggleAction = .disable
        await store.reload()
        await store.previewVisibleBatchToggle()
        await store.applyVisibleBatchTogglePreview()

        try expectNil(store.batchTogglePreview, "Batch preview should clear after apply and refresh.")
        try expectContains(store.lastMutationMessage, "Disable batch applied", "Batch apply should surface an explicit success message.")
        try expectContains(fake.calls(), "batch.applySkillToggles", "Batch apply should use the service batch apply method.")
        try expectFalse(fake.calls().contains("config.toggleSkill"), "Batch apply must not silently loop over single-toggle writes.")
        try expectEqual(store.skills.first { $0.id == "alpha" }?.enabled, false, "Batch apply refresh should pick up changed alpha state.")
        try expectEqual(store.skills.first { $0.id == "gamma" }?.enabled, false, "Batch apply refresh should pick up changed gamma state.")
        try expectEqual(store.skills.first { $0.id == "pi-one" }?.enabled, true, "Batch apply should not mutate read-only Pi skills.")
    }

    private func batchToggleApplyRequiresCurrentPreviewConfirmation() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "batch-mixed")

        let store = SkillStore(service: ServiceClient())
        store.agentFilter = .all
        store.batchToggleAction = .disable
        await store.reload()
        await store.previewVisibleBatchToggle()

        guard store.batchTogglePreview != nil else {
            throw NativeModelTestFailure(description: "Batch preview should be stored before confirmation.")
        }

        await store.applyVisibleBatchTogglePreview(confirmingPreviewID: "stale-preview-token")

        guard store.batchTogglePreview != nil else {
            throw NativeModelTestFailure(description: "Stale confirmation must not clear the active preview.")
        }
        try expectContains(store.errorMessage, "Preview again", "Stale confirmation should explain that a fresh preview is required.")
        try expectFalse(fake.calls().contains("batch.applySkillToggles"), "Stale confirmation must not call the batch apply service.")
    }

    private func localReportExportUsesUserTriggeredServiceContract() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "report-export")

        let store = SkillStore(service: ServiceClient())
        store.agentFilter = .all
        store.localReportFormat = .json
        await store.reload()
        await store.exportLocalReport()

        guard let result = store.localReportExportResult else {
            throw NativeModelTestFailure(description: "Local report export should store the service result.")
        }
        try expectFalse(result.isUnavailable, "Successful export should not use the unavailable fallback.")
        try expectEqual(result.format, .json, "Export result should preserve the selected JSON format.")
        try expectEqual(result.filename, "report.json", "Export should expose the local filename from the exported files list.")
        try expectEqual(result.path, "<app-data-dir>/report-exports/local-report-test/report.json", "Export should expose the redacted local path.")
        try expectEqual(result.redacted, true, "Local report export should surface the redaction flag.")
        try expectEqual(result.sections.map(\.name), ["cleanup_item_count", "comparison_group_count", "finding_count", "open_finding_count", "skill_count", "triage_count"], "Export should derive section counts from the service summary object.")
        try expectContains(result.summary, "redacted", "Export summary should be user-visible and redaction-explicit.")
        try expectContains(store.lastMutationMessage, "report.json", "Successful export should show the filename.")
        try expectContains(fake.calls(), "report.exportLocal", "Export must use the V2.35 report.exportLocal service method.")
        try expectContains(fake.calls(), #""formats":["json"]"#, "Export must send the selected format using the service formats array.")
        try expectFalse(fake.calls().contains("llm.prepare"), "Export must not trigger AI provider preparation.")
        try expectFalse(fake.calls().contains("script.previewExecution"), "Export must not trigger script execution preview.")
        try expectFalse(fake.calls().contains("config.toggleSkill"), "Export must not mutate agent config.")
    }

    private func localReportExportUnavailableDoesNotPretendFileWasWritten() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "normal")

        let store = SkillStore(service: ServiceClient())
        store.localReportFormat = .markdown
        await store.reload()
        await store.exportLocalReport()

        guard let result = store.localReportExportResult else {
            throw NativeModelTestFailure(description: "Unavailable export should store a visible fallback result.")
        }
        try expectEqual(result.isUnavailable, true, "Unknown report method should expose an unavailable result.")
        try expectNil(result.path, "Unavailable export must not fake a local file path.")
        try expectNil(store.lastMutationMessage, "Unavailable export must not show a success mutation message.")
        try expectContains(result.summary, "unavailable", "Unavailable result should explain that no file was written.")
        try expectContains(fake.calls(), "report.exportLocal", "Unavailable path should still attempt the explicit user-triggered export method.")
    }

    private func reloadLoadsProjectContext() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "project-set")

        let store = SkillStore(service: ServiceClient())
        await store.reload()

        try expectEqual(store.activeProjectContext?.name, "Fixture Project", "Reload should load active project context.")
        try expectEqual(store.activeProjectContext?.rootPath, "/tmp/project", "Reload should expose the active project root.")
        try expectEqual(store.recentProjectContexts.count, 2, "Reload should expose recent project contexts.")
        try expectNil(store.projectValidationMessage, "Valid context should not expose a validation error.")
    }

    private func setProjectStoresContextAndScans() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "project-set")

        let store = SkillStore(service: ServiceClient())
        await store.setProject(rootPath: "/tmp/project", currentCWD: "/tmp/project", name: "Fixture Project")

        try expectFalse(store.isProjectUpdating, "Project set should reset updating state.")
        try expectNil(store.errorMessage, "Project set should not set an error on success.")
        try expectEqual(store.activeProjectContext?.name, "Fixture Project", "Project set should store returned active context.")
        try expectEqual(store.skills.count, 3, "Project set should scan and refresh catalog collections.")
        try expectContains(fake.calls(), "project.setContext", "Project set should call the service project method.")
        try expectContains(fake.calls(), "catalog.scanAll", "Project set should scan after a valid context is selected.")
        try expectEqual(store.lastMutationMessage, UIStrings.projectSelectedAndScanned("Fixture Project"), "Project set should expose a context refresh message.")
    }

    private func clearProjectClearsContextAndScans() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "project-clear")

        let store = SkillStore(service: ServiceClient())
        await store.clearProject()

        try expectFalse(store.isProjectUpdating, "Project clear should reset updating state.")
        try expectNil(store.errorMessage, "Project clear should not set an error on success.")
        try expectNil(store.activeProjectContext, "Project clear should remove the active context.")
        try expectEqual(store.skills.count, 3, "Project clear should scan and refresh catalog collections.")
        try expectContains(fake.calls(), "project.clearContext", "Project clear should call the service project method.")
        try expectContains(fake.calls(), "catalog.scanAll", "Project clear should scan after clearing context.")
        try expectEqual(store.lastMutationMessage, UIStrings.projectClearedAndScanned, "Project clear should expose a context refresh message.")
    }

    private func projectValidationErrorSkipsScanAndSurfacesMessage() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "project-validation-error")

        let store = SkillStore(service: ServiceClient())
        await store.setProject(rootPath: "/tmp/missing", currentCWD: "/tmp/missing", name: "Missing Project")

        try expectFalse(store.isProjectUpdating, "Invalid project set should reset updating state.")
        try expectEqual(store.activeProjectContext?.name, "Missing Project", "Invalid project set should keep returned context for user repair.")
        try expectEqual(store.projectValidationMessage, "Project root does not exist.", "Invalid project set should expose validation details.")
        try expectContains(store.errorMessage, "Project validation failed", "Invalid project set should surface a readable error.")
        try expectFalse(fake.calls().contains("catalog.scanAll"), "Invalid project set should not scan.")
    }

    private func reloadFallsBackToDisabledLLMWhenOldServiceDoesNotSupportMethods() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "old-service")

        let store = SkillStore(service: ServiceClient())
        await store.reload()

        try expectNil(store.errorMessage, "Old service LLM fallback should not fail reload.")
        try expectFalse(store.llmStatus.enabled, "Old service LLM fallback should be disabled.")
        try expectEqual(store.llmStatus.disabledReason, UIStrings.llmDisabledFallback, "Old service LLM fallback should expose a stable reason.")
        try expectContains(fake.calls(), "llm.status", "Reload should ask the service for LLM status.")
    }

    private func prepareLLMActionStoresEstimateWithoutProviderCall() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "llm-ready")

        let store = SkillStore(service: ServiceClient())
        store.selectedSkillID = "beta"
        await store.reload()
        await store.prepareAnalyzeLLM()
        await store.prepareDraftFrontmatterLLM()

        let analyze = store.llmPrepareResult(for: .analyze)
        try expectEqual(analyze?.enabled, true, "Analyze prepare should be enabled when LLM status is ready.")
        try expectEqual(analyze?.provider, "openai", "Analyze prepare should expose provider.")
        try expectEqual(analyze?.model, "gpt-5", "Analyze prepare should expose model.")
        try expectEqual(analyze?.estimate?.inputTokens, 240, "Analyze prepare should expose input token estimate.")
        try expectEqual(analyze?.estimate?.estimatedCostUSD, 0.0042, "Analyze prepare should expose cost estimate.")
        try expectEqual(analyze?.confirmationRequired, true, "Analyze prepare should require confirmation.")

        let draft = store.llmPrepareResult(for: .draftFrontmatter)
        try expectEqual(draft?.action, .draftFrontmatter, "Draft prepare should be stored under the draft action.")
        try expectEqual(draft?.confirmationRequired, true, "Draft prepare should require confirmation.")
        try expectContains(fake.calls(), "llm.prepareAction", "LLM action should use prepare preflight.")
        try expectFalse(fake.calls().contains("llm.complete"), "LLM prepare should not call a provider completion method.")
    }


    private func prepareSkillAnalysisUsesReadOnlyPrepareContract() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "llm-ready")

        let store = SkillStore(service: ServiceClient())
        store.selectedSkillID = "beta"
        await store.reload()
        await store.prepareSelectedSkillAnalysis(kind: .risk)
        await store.prepareVisibleSkillAnalysis(kind: .overview)

        let selected = store.skillAnalysisPrepareResult(kind: .risk, scope: .selected)
        try expectEqual(selected?.enabled, false, "Skill analysis prepare should stay disabled by default.")
        try expectEqual(selected?.analysisKind, .risk, "Selected skill analysis should preserve requested kind.")
        try expectEqual(selected?.selectedSkillCount, 1, "Selected skill analysis should include one skill.")
        try expectEqual(selected?.includedSkills.map(\.name), ["Beta"], "Selected skill analysis should expose included skill names.")
        try expectFalse(selected?.safety.writeBackEnabled ?? true, "Skill analysis prepare must not enable write-back.")
        try expectFalse(selected?.safety.scriptExecutionEnabled ?? true, "Skill analysis prepare must not enable script execution.")
        try expectFalse(selected?.safety.credentialStorageEnabled ?? true, "Skill analysis prepare must not enable credential storage.")
        try expectEqual(selected?.safety.confirmationRequired, true, "Skill analysis prepare should require confirmation.")

        let visible = store.skillAnalysisPrepareResult(kind: .overview, scope: .visible)
        try expectEqual(visible?.selectedSkillCount, 2, "Visible skill analysis should include current visible filtered skills.")
        let calls = fake.calls()
        try expectContains(calls, "llm.prepareSkillAnalysis", "Skill analysis should use the V2.30 prepare method.")
        try expectContains(calls, "\"analysis_kind\":\"risk\"", "Skill analysis should send requested risk kind.")
        try expectContains(calls, "\"instance_ids\":[\"beta\"]", "Selected skill analysis should send selected instance IDs only.")
        try expectFalse(calls.contains("llm.complete"), "Skill analysis prepare must not call provider completion.")
        try expectFalse(calls.contains("config.toggleSkill"), "Skill analysis prepare must not call write paths.")
        try expectFalse(calls.contains("script.execute"), "Skill analysis prepare must not call execution paths.")
    }

    private func prepareSkillAnalysisFallsBackWhenMethodUnavailable() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "old-service")

        let store = SkillStore(service: ServiceClient())
        store.selectedSkillID = "beta"
        await store.reload()
        await store.prepareSelectedSkillAnalysis(kind: .cleanup)

        let result = store.skillAnalysisPrepareResult(kind: .cleanup, scope: .selected)
        try expectEqual(result?.enabled, false, "Unavailable skill analysis should be disabled.")
        try expectEqual(result?.disabledReason, UIStrings.llmSkillAnalysisUnavailable, "Unavailable skill analysis should expose quiet fallback reason.")
        try expectContains(result?.summaryDraft, "Disabled fallback preview only", "Unavailable skill analysis should provide read-only preview copy.")
    }

    private func scoreSkillQualityUsesReadOnlyAnalysisContract() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "prompt-ready")

        let store = SkillStore(service: ServiceClient())
        store.selectedSkillID = "beta"
        await store.reload()
        await store.scoreSelectedSkillQuality()

        guard let skill = store.selectedSkill else {
            throw NativeModelTestFailure(description: "Fixture should select beta for quality scoring.")
        }
        let result = store.skillQualityScore(for: skill)
        try expectEqual(result?.score, 82, "Quality score should store the service score for the selected skill.")
        try expectEqual(result?.displayBand, "Good", "Quality score should expose the band/grade.")
        try expectEqual(result?.components.map(\.key), ["metadata", "permissions"], "Quality score should expose component keys.")
        try expectFalse(result?.safety.providerRequestSent ?? true, "Local quality score must not send a provider request.")
        try expectFalse(result?.safety.writeBackAllowed ?? true, "Quality score must not allow write-back.")
        try expectFalse(result?.safety.scriptExecutionAllowed ?? true, "Quality score must not allow script execution.")
        try expectFalse(result?.safety.configMutationAllowed ?? true, "Quality score must not allow config mutation.")
        try expectFalse(result?.safety.credentialAccessed ?? true, "Quality score must not access credentials.")

        await store.previewPromptForSelectedSkillQuality()
        let preview = store.skillQualityPromptPreview(for: skill)
        try expectEqual(preview?.previewID, "quality-preview-beta", "Quality prompt preview should be stored for the selected skill.")
        try expectEqual(store.canSendSkillQualityPrompt(for: skill), true, "Configured provider and current quality preview should allow explicit send.")

        await store.confirmPromptForSelectedSkillQuality()
        let sendResult = store.skillQualityPromptSendResult(for: skill)
        try expectEqual(sendResult?.success, true, "Confirmed quality prompt should store provider result.")
        try expectFalse(sendResult?.writeBackAllowed ?? true, "Quality prompt output must not enable write-back.")
        try expectFalse(sendResult?.scriptExecutionAllowed ?? true, "Quality prompt output must not enable script execution.")

        let calls = fake.calls()
        try expectContains(calls, "analysis.scoreSkillQuality", "Quality score should use the V2.43 analysis method.")
        try expectContains(calls, "\"request_kind\":\"quality_score\"", "Quality prompt preview should identify the quality_score prompt action.")
        try expectContains(calls, "\"preview_id\":\"quality-preview-beta\"", "Quality confirm should send the quality preview id.")
        try expectContains(calls, "llm.confirmPromptAndSend", "Quality provider path should require explicit confirmation.")
        try expectFalse(calls.contains("config.toggleSkill"), "Quality scoring must not call write paths.")
        try expectFalse(calls.contains("script.execute"), "Quality scoring must not call execution paths.")
    }

    private func taskReadinessUsesReadOnlyCheckContract() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "prompt-ready")

        let store = SkillStore(service: ServiceClient())
        store.selectedSkillID = "beta"
        store.taskReadinessText = "Audit local skills for a release note."
        await store.reload()
        await store.checkSelectedTaskReadiness()

        guard let skill = store.selectedSkill else {
            throw NativeModelTestFailure(description: "Fixture should select beta for task readiness.")
        }
        let result = store.taskReadiness(for: skill)
        try expectEqual(result?.score, 74, "Task readiness should store the service score for the selected task.")
        try expectEqual(result?.band, "Partial", "Task readiness should expose the readiness band.")
        try expectEqual(result?.candidateSkills.map(\.name), ["Beta"], "Task readiness should expose candidate skills.")
        try expectEqual(result?.gaps, ["No release-note-specific examples."], "Task readiness should expose missing capabilities.")
        try expectFalse(result?.safety.providerRequestSent ?? true, "Local readiness check must not send a provider request.")
        try expectFalse(result?.safety.writeBackAllowed ?? true, "Readiness check must not allow write-back.")
        try expectFalse(result?.safety.scriptExecutionAllowed ?? true, "Readiness check must not allow script execution.")
        try expectFalse(result?.safety.configMutationAllowed ?? true, "Readiness check must not allow config mutation.")
        try expectFalse(result?.safety.credentialAccessed ?? true, "Readiness check must not access credentials.")

        await store.previewPromptForSelectedTaskReadiness()
        let preview = store.taskReadinessPromptPreview(for: skill)
        try expectEqual(preview?.previewID, "readiness-preview-beta", "Task readiness prompt preview should be scoped to the selected task.")
        try expectEqual(store.canSendTaskReadinessPrompt(for: skill), true, "Configured provider and current readiness preview should allow explicit send.")

        await store.confirmPromptForSelectedTaskReadiness()
        let sendResult = store.taskReadinessPromptSendResult(for: skill)
        try expectEqual(sendResult?.success, true, "Confirmed task readiness prompt should store provider result.")
        try expectFalse(sendResult?.writeBackAllowed ?? true, "Task readiness prompt output must not enable write-back.")
        try expectFalse(sendResult?.scriptExecutionAllowed ?? true, "Task readiness prompt output must not enable script execution.")

        let calls = fake.calls()
        try expectContains(calls, "task.checkReadiness", "Task readiness should use the V2.44 task.checkReadiness method.")
        try expectContains(calls, "\"task\":\"Audit local skills for a release note.\"", "Task readiness should send task text.")
        try expectContains(calls, "\"candidate_instance_ids\":[\"beta\"]", "Task readiness should constrain candidate filters to the selected skill.")
        try expectContains(calls, "\"request_kind\":\"task_readiness\"", "Task readiness prompt preview should identify the task_readiness request kind.")
        try expectContains(calls, "\"preview_id\":\"readiness-preview-beta\"", "Task readiness confirm should send the readiness preview id.")
        try expectContains(calls, "llm.confirmPromptAndSend", "Configured task readiness provider path should require explicit confirmation.")
        try expectFalse(calls.contains("config.toggleSkill"), "Task readiness must not call write paths.")
        try expectFalse(calls.contains("script.execute"), "Task readiness must not call execution paths.")
    }

    private func taskReadinessPromptSendRequiresConfiguredProvider() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "llm-ready")

        let store = SkillStore(service: ServiceClient())
        store.selectedSkillID = "beta"
        store.taskReadinessText = "Audit local skills for a release note."
        await store.reload()
        await store.checkSelectedTaskReadiness()

        guard let skill = store.selectedSkill else {
            throw NativeModelTestFailure(description: "Fixture should select beta for task readiness gating.")
        }

        await store.previewPromptForSelectedTaskReadiness()
        try expectEqual(store.canSendTaskReadinessPrompt(for: skill), false, "Unconfigured provider should keep Confirm & Send disabled.")

        await store.confirmPromptForSelectedTaskReadiness()
        let sendResult = store.taskReadinessPromptSendResult(for: skill)
        try expectEqual(sendResult?.success, false, "Blocked task readiness send should store an unavailable result, not throw.")
        try expectContains(sendResult?.message, "Configure and save", "Blocked task readiness send should explain provider setup.")

        let calls = fake.calls()
        try expectContains(calls, "task.checkReadiness", "No-provider path should still allow local readiness check.")
        try expectContains(calls, "llm.previewPrompt", "No-provider path may ask for a blocked preview.")
        try expectFalse(calls.contains("llm.confirmPromptAndSend"), "No-provider path must not send to provider.")
        try expectFalse(calls.contains("config.toggleSkill"), "No-provider readiness path must not call write paths.")
        try expectFalse(calls.contains("script.execute"), "No-provider readiness path must not call execution paths.")
    }

    private func routingConfidenceUsesReadOnlyRankContract() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "prompt-ready")

        let store = SkillStore(service: ServiceClient())
        store.selectedSkillID = "beta"
        store.routingConfidenceText = "Route a local audit release note task."
        await store.reload()
        await store.rankSelectedSkillRoutes()

        guard let skill = store.selectedSkill else {
            throw NativeModelTestFailure(description: "Fixture should select beta for routing confidence.")
        }
        let result = store.routingConfidence(for: skill)
        try expectEqual(result?.score, 88, "Routing confidence should store the service score for the selected task.")
        try expectEqual(result?.band, "High", "Routing confidence should expose the confidence band.")
        try expectEqual(result?.routes.map(\.name), ["Beta", "Alpha"], "Routing confidence should expose ordered candidate routes.")
        try expectEqual(result?.routes.first?.matchReasons, ["Description matches local audit.", "Selected skill is enabled."], "Routing confidence should expose match reasons.")
        try expectEqual(result?.ambiguityWarnings, ["Alpha has overlapping audit wording."], "Routing confidence should expose ambiguity warnings.")
        try expectEqual(result?.wrongPickRisks, ["Choosing Alpha may miss project-scoped evidence."], "Routing confidence should expose likely wrong-pick risks.")
        try expectFalse(result?.safety.providerRequestSent ?? true, "Local route ranking must not send a provider request.")
        try expectFalse(result?.safety.writeBackAllowed ?? true, "Route ranking must not allow write-back.")
        try expectFalse(result?.safety.scriptExecutionAllowed ?? true, "Route ranking must not allow script execution.")
        try expectFalse(result?.safety.configMutationAllowed ?? true, "Route ranking must not allow config mutation.")
        try expectFalse(result?.safety.credentialAccessed ?? true, "Route ranking must not access credentials.")
        let localRankingCalls = fake.calls()
        try expectContains(localRankingCalls, "task.rankSkillRoutes", "Routing confidence should use the V2.45 task.rankSkillRoutes method.")
        try expectContains(localRankingCalls, "\"task\":\"Route a local audit release note task.\"", "Routing confidence should send canonical task text.")
        try expectContains(localRankingCalls, "\"agent\":\"claude-code\"", "Routing confidence should send selected skill agent.")
        try expectContains(localRankingCalls, "\"candidate_instance_ids\":[\"beta\"]", "Routing confidence should constrain candidate filters to the selected skill.")
        try expectContains(localRankingCalls, "\"limit\":6", "Routing confidence should send a route limit.")
        try expectFalse(localRankingCalls.contains("\"task_text\":\"Route a local audit release note task.\""), "Local route ranking must not send duplicate task_text aliases.")
        try expectFalse(localRankingCalls.contains("\"user_intent\":\"Route a local audit release note task.\""), "Local route ranking must not send duplicate user_intent aliases.")

        await store.previewPromptForSelectedRoutingConfidence()
        let preview = store.routingConfidencePromptPreview(for: skill)
        try expectEqual(preview?.previewID, "routing-preview-beta", "Routing prompt preview should be scoped to the selected task.")
        try expectEqual(store.canSendRoutingConfidencePrompt(for: skill), true, "Configured provider and current routing preview should allow explicit send.")

        await store.confirmPromptForSelectedRoutingConfidence()
        let sendResult = store.routingConfidencePromptSendResult(for: skill)
        try expectEqual(sendResult?.success, true, "Confirmed routing prompt should store provider result.")
        try expectFalse(sendResult?.writeBackAllowed ?? true, "Routing prompt output must not enable write-back.")
        try expectFalse(sendResult?.scriptExecutionAllowed ?? true, "Routing prompt output must not enable script execution.")

        let calls = fake.calls()
        try expectContains(calls, "\"request_kind\":\"routing_confidence\"", "Routing prompt preview should identify the routing_confidence request kind.")
        try expectContains(calls, "\"task_text\":\"Route a local audit release note task.\"", "Routing prompt preview/confirm should include the selected task text.")
        try expectContains(calls, "\"user_intent\":\"Route a local audit release note task.\"", "Routing prompt preview/confirm should include the user intent required by the service.")
        try expectFalse(countOccurrences("\"request_kind\":\"routing_confidence\"", in: calls) < 2, "Routing preview and confirmation should both carry the routing request kind.")
        try expectFalse(countOccurrences("\"user_intent\":\"Route a local audit release note task.\"", in: calls) < 2, "Routing preview and confirmation should both carry user intent.")
        try expectContains(calls, "\"preview_id\":\"routing-preview-beta\"", "Routing confirm should send the routing preview id.")
        try expectContains(calls, "llm.confirmPromptAndSend", "Configured routing provider path should require explicit confirmation.")
        try expectFalse(calls.contains("config.toggleSkill"), "Routing confidence must not call write paths.")
        try expectFalse(calls.contains("script.execute"), "Routing confidence must not call execution paths.")
    }

    private func routingConfidencePromptSendRequiresConfiguredProvider() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "llm-ready")

        let store = SkillStore(service: ServiceClient())
        store.selectedSkillID = "beta"
        store.routingConfidenceText = "Route a local audit release note task."
        await store.reload()
        await store.rankSelectedSkillRoutes()

        guard let skill = store.selectedSkill else {
            throw NativeModelTestFailure(description: "Fixture should select beta for routing confidence gating.")
        }

        await store.previewPromptForSelectedRoutingConfidence()
        try expectEqual(store.canSendRoutingConfidencePrompt(for: skill), false, "Unconfigured provider should keep routing Confirm & Send disabled.")

        await store.confirmPromptForSelectedRoutingConfidence()
        let sendResult = store.routingConfidencePromptSendResult(for: skill)
        try expectEqual(sendResult?.success, false, "Blocked routing send should store an unavailable result, not throw.")
        try expectContains(sendResult?.message, "Configure and save", "Blocked routing send should explain provider setup.")

        let calls = fake.calls()
        try expectContains(calls, "task.rankSkillRoutes", "No-provider path should still allow local route ranking.")
        try expectContains(calls, "llm.previewPrompt", "No-provider path may ask for a blocked routing preview.")
        try expectFalse(calls.contains("llm.confirmPromptAndSend"), "No-provider routing path must not send to provider.")
        try expectFalse(calls.contains("config.toggleSkill"), "No-provider routing path must not call write paths.")
        try expectFalse(calls.contains("script.execute"), "No-provider routing path must not call execution paths.")
    }

    private func taskBenchmarkUsesLocalServiceContract() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "prompt-ready")

        let store = SkillStore(service: ServiceClient())
        store.selectedSkillID = "beta"
        store.routingConfidenceText = "Route a local audit release note task."
        await store.reload()
        await store.loadTaskBenchmarks()
        await store.saveSelectedTaskBenchmark()
        await store.evaluateTaskBenchmarks()

        try expectEqual(store.taskBenchmarkList.benchmarks.first?.id, "bench-2", "Saved benchmark should be inserted at the front of the local list.")
        try expectEqual(store.taskBenchmarkList.benchmarks.first?.expectedSkill?.name, "Beta", "Saved benchmark should retain selected expected skill context.")
        try expectEqual(store.taskBenchmarkEvaluation?.evaluatedCount, 2, "Benchmark evaluation should expose evaluated count.")
        try expectEqual(store.taskBenchmarkEvaluation?.matchedCount, 1, "Benchmark evaluation should expose expected matches.")
        try expectEqual(store.taskBenchmarkEvaluation?.acceptableCount, 2, "Benchmark evaluation should expose acceptable matches.")
        try expectEqual(store.taskBenchmarkEvaluation?.evaluations.first?.topRoute?.name, "Beta", "Benchmark evaluation should expose top route.")
        try expectFalse(store.taskBenchmarkEvaluation?.safety.providerRequestSent ?? true, "Local benchmark evaluation must not send a provider request.")
        try expectFalse(store.taskBenchmarkEvaluation?.safety.writeBackAllowed ?? true, "Benchmark evaluation must not allow write-back.")
        try expectFalse(store.taskBenchmarkEvaluation?.safety.scriptExecutionAllowed ?? true, "Benchmark evaluation must not allow script execution.")
        try expectFalse(store.taskBenchmarkEvaluation?.safety.configMutationAllowed ?? true, "Benchmark evaluation must not mutate config.")
        try expectFalse(store.taskBenchmarkEvaluation?.safety.credentialAccessed ?? true, "Benchmark evaluation must not access credentials.")

        let calls = fake.calls()
        try expectContains(calls, "task.listBenchmarks", "Benchmark UI should list benchmarks through the V2.46 task list method.")
        try expectContains(calls, "task.saveBenchmark", "Benchmark UI should save benchmarks through the V2.46 task save method.")
        try expectContains(calls, "task.evaluateBenchmarks", "Benchmark UI should evaluate benchmarks through the V2.46 task evaluation method.")
        try expectContains(calls, "\"task\":\"Route a local audit release note task.\"", "Benchmark save should use the current routing/readiness task text.")
        try expectContains(calls, "\"expected_skill_refs\":[\"beta\",\"def.beta\"]", "Benchmark save should carry selected expected skill references.")
        try expectContains(calls, "\"expected_skill_names\":[\"Beta\"]", "Benchmark save should carry selected expected skill name.")
        try expectContains(calls, "\"acceptable_agents\":[\"claude-code\"]", "Benchmark save should carry acceptable agent context.")
        try expectContains(calls, "\"acceptable_scopes\":[\"agent-project\"]", "Benchmark save should carry acceptable scope context.")
        try expectFalse(calls.contains("llm.previewPrompt"), "Local benchmark evaluation must not prepare provider prompts.")
        try expectFalse(calls.contains("llm.confirmPromptAndSend"), "Local benchmark evaluation must not send to provider.")
        try expectFalse(calls.contains("config.toggleSkill"), "Benchmark flow must not call config write paths.")
        try expectFalse(calls.contains("script.execute"), "Benchmark flow must not call execution paths.")
    }

    private func taskBenchmarkFallsBackWhenMethodUnavailable() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "old-service")

        let store = SkillStore(service: ServiceClient())
        store.selectedSkillID = "beta"
        store.taskBenchmarkText = "Route a local audit release note task."
        await store.reload()
        await store.loadTaskBenchmarks()
        await store.saveSelectedTaskBenchmark()
        await store.evaluateTaskBenchmarks()

        try expectEqual(store.taskBenchmarkList.isUnavailable, true, "Unknown benchmark methods should expose an unavailable benchmark list.")
        try expectEqual(store.taskBenchmarkEvaluation?.isUnavailable, true, "Unknown benchmark evaluation should expose an unavailable result.")
        try expectContains(store.taskBenchmarkList.fallbackReason, "unavailable", "Unavailable benchmark list should expose quiet fallback reason.")

        let calls = fake.calls()
        try expectContains(calls, "task.listBenchmarks", "Fallback test should still attempt the V2.46 list method.")
        try expectContains(calls, "task.saveBenchmark", "Fallback test should still attempt the V2.46 save method.")
        try expectContains(calls, "task.evaluateBenchmarks", "Fallback test should still attempt the V2.46 evaluate method.")
        try expectFalse(calls.contains("llm.previewPrompt"), "Unavailable benchmark flow must not fall back to provider prompt preview.")
        try expectFalse(calls.contains("llm.confirmPromptAndSend"), "Unavailable benchmark flow must not send to provider.")
        try expectFalse(calls.contains("config.toggleSkill"), "Unavailable benchmark flow must not call config write paths.")
        try expectFalse(calls.contains("script.execute"), "Unavailable benchmark flow must not call execution paths.")
    }

    private func routingRegressionUsesLocalBenchmarkServiceContract() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "prompt-ready")

        let store = SkillStore(service: ServiceClient())
        store.selectedSkillID = "beta"
        await store.reload()
        await store.loadTaskBenchmarks()
        let snapshotCallsBeforeRegression = countOccurrences("snapshot.", in: fake.calls())
        await store.saveRoutingBaseline()
        await store.detectRoutingRegression()

        try expectEqual(store.routingRegressionBaseline?.baselineID, "baseline-1", "Routing regression baseline should expose saved baseline id.")
        try expectEqual(store.routingRegressionBaseline?.benchmarkCount, 1, "Routing baseline should use loaded benchmark scope.")
        try expectEqual(store.routingRegressionDetection?.regressionCount, 1, "Routing regression detection should expose regression count.")
        try expectEqual(store.routingRegressionDetection?.regressions.first?.currentTopRoute?.name, "Alpha", "Routing regression should expose changed top route.")
        try expectEqual(store.routingRegressionDetection?.regressions.first?.scoreDelta, -16, "Routing regression should expose score delta.")
        try expectFalse(store.routingRegressionDetection?.safety.providerRequestSent ?? true, "Local regression detection must not send a provider request.")
        try expectFalse(store.routingRegressionDetection?.safety.writeBackAllowed ?? true, "Regression detection must not allow write-back.")
        try expectFalse(store.routingRegressionDetection?.safety.scriptExecutionAllowed ?? true, "Regression detection must not allow script execution.")
        try expectFalse(store.routingRegressionDetection?.safety.configMutationAllowed ?? true, "Regression detection must not mutate config.")
        try expectFalse(store.routingRegressionDetection?.safety.snapshotCreated ?? true, "Regression detection must not create snapshots.")
        try expectFalse(store.routingRegressionDetection?.safety.credentialAccessed ?? true, "Regression detection must not access credentials.")

        let calls = fake.calls()
        try expectContains(calls, "task.listBenchmarks", "Regression flow may load the app-local benchmark set.")
        try expectContains(calls, "task.saveRoutingBaseline", "Regression flow should save baseline through the V2.47 baseline method.")
        try expectContains(calls, "task.detectRoutingRegression", "Regression flow should detect regressions through the V2.47 detection method.")
        try expectContains(calls, "\"benchmark_ids\":[\"bench-1\"]", "Regression flow should pass loaded benchmark ids to local regression methods.")
        try expectFalse(calls.contains("task.evaluateBenchmarks"), "Regression flow should not need benchmark evaluation service calls unless the user asks.")
        try expectFalse(calls.contains("llm.previewPrompt"), "Local regression detection must not prepare provider prompts.")
        try expectFalse(calls.contains("llm.confirmPromptAndSend"), "Local regression detection must not send to provider.")
        try expectFalse(calls.contains("config.toggleSkill"), "Regression flow must not call config write paths.")
        try expectFalse(calls.contains("script.execute"), "Regression flow must not call execution paths.")
        try expectEqual(countOccurrences("snapshot.", in: calls), snapshotCallsBeforeRegression, "Regression flow must not call snapshot paths.")
        try expectFalse(calls.contains("credential"), "Regression flow must not call credential paths.")
    }

    private func routingRegressionFallsBackWhenMethodUnavailable() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "old-service")

        let store = SkillStore(service: ServiceClient())
        store.selectedSkillID = "beta"
        await store.reload()
        let snapshotCallsBeforeRegression = countOccurrences("snapshot.", in: fake.calls())
        await store.saveRoutingBaseline()
        await store.detectRoutingRegression()

        try expectEqual(store.routingRegressionBaseline?.isUnavailable, true, "Unknown baseline method should expose unavailable baseline status.")
        try expectEqual(store.routingRegressionDetection?.isUnavailable, true, "Unknown detection method should expose unavailable detection status.")
        try expectContains(store.routingRegressionDetection?.fallbackReason, "unavailable", "Unavailable regression detection should expose quiet fallback reason.")

        let calls = fake.calls()
        try expectContains(calls, "task.saveRoutingBaseline", "Fallback test should still attempt the V2.47 baseline method.")
        try expectContains(calls, "task.detectRoutingRegression", "Fallback test should still attempt the V2.47 detection method.")
        try expectFalse(calls.contains("llm.previewPrompt"), "Unavailable regression flow must not fall back to provider prompt preview.")
        try expectFalse(calls.contains("llm.confirmPromptAndSend"), "Unavailable regression flow must not send to provider.")
        try expectFalse(calls.contains("config.toggleSkill"), "Unavailable regression flow must not call config write paths.")
        try expectFalse(calls.contains("script.execute"), "Unavailable regression flow must not call execution paths.")
        try expectEqual(countOccurrences("snapshot.", in: calls), snapshotCallsBeforeRegression, "Unavailable regression flow must not call snapshot paths.")
        try expectFalse(calls.contains("credential"), "Unavailable regression flow must not call credential paths.")
    }

    private func agentTraceImportUsesLocalServiceContract() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "prompt-ready")

        let store = SkillStore(service: ServiceClient())
        store.selectedSkillID = "beta"
        store.traceImportTitle = "Local trace"
        store.traceImportTask = "Route a local audit release note task."
        store.traceImportExpectedSkills = "Beta, Alpha"
        store.traceImportText = "raw local transcript should be sent once"
        await store.reload()
        await store.loadTraceImports()
        await store.importLocalTrace()

        try expectEqual(store.traceImportList.imports.first?.id, "trace-2", "Imported trace should be inserted at the front of the trace list.")
        try expectEqual(store.traceImportResult?.record?.outcome, "wrong_pick", "Trace import should expose imported outcome.")
        try expectEqual(store.latestTraceImportRecord?.redactedExcerpt, "User asked for <project-root> release notes. Assistant selected Alpha.", "Trace result should expose redacted excerpt metadata.")
        try expectEqual(store.traceImportText, "", "Successful import should clear raw pasted trace text from UI state.")
        try expectFalse(store.traceImportResult?.record?.safety.providerRequestSent ?? true, "Local trace import must not send a provider request.")
        try expectFalse(store.traceImportResult?.record?.safety.writeBackAllowed ?? true, "Trace import must not allow write-back.")
        try expectFalse(store.traceImportResult?.record?.safety.scriptExecutionAllowed ?? true, "Trace import must not allow script execution.")
        try expectFalse(store.traceImportResult?.record?.safety.configMutationAllowed ?? true, "Trace import must not mutate config.")
        try expectFalse(store.traceImportResult?.record?.safety.credentialAccessed ?? true, "Trace import must not access credentials.")

        guard let listedRecord = store.traceImportList.imports.last else {
            throw NativeModelTestFailure(description: "Trace list should include the pre-existing trace.")
        }
        await store.deleteTraceImport(listedRecord)
        try expectEqual(store.traceImportDeleteResult?.deleted, true, "Trace delete should expose deletion success.")

        let calls = fake.calls()
        try expectContains(calls, "trace.listImports", "Trace UI should list imports through the V2.48 list method.")
        try expectContains(calls, "trace.importLocal", "Trace UI should import local traces through the V2.48 import method.")
        try expectContains(calls, "trace.deleteImport", "Trace UI should delete imports through the V2.48 delete method.")
        try expectContains(calls, "\"trace_text\":\"raw local transcript should be sent once\"", "Trace import should send the pasted trace text to the local service.")
        try expectContains(calls, "\"title\":\"Local trace\"", "Trace import should send optional title metadata.")
        try expectContains(calls, "\"task\":\"Route a local audit release note task.\"", "Trace import should send optional task metadata.")
        try expectContains(calls, "\"expected_skill_names\":[\"Beta\",\"Alpha\"]", "Trace import should send expected skill names.")
        try expectContains(calls, "\"candidate_instance_ids\":[\"beta\"]", "Trace import should include selected skill context.")
        try expectContains(calls, "\"agent\":\"claude-code\"", "Trace import should include selected agent context.")
        try expectFalse(calls.contains("llm.previewPrompt"), "Local trace import must not prepare provider prompts.")
        try expectFalse(calls.contains("llm.confirmPromptAndSend"), "Local trace import must not send to provider.")
        try expectFalse(calls.contains("config.toggleSkill"), "Trace import flow must not call config write paths.")
        try expectFalse(calls.contains("script.execute"), "Trace import flow must not call execution paths.")
    }

    private func agentTraceImportFallsBackWhenMethodUnavailable() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "old-service")

        let store = SkillStore(service: ServiceClient())
        store.selectedSkillID = "beta"
        store.traceImportText = "raw local transcript"
        await store.reload()
        await store.loadTraceImports()
        await store.importLocalTrace()

        try expectEqual(store.traceImportList.isUnavailable, true, "Unknown trace list method should expose unavailable trace list.")
        try expectEqual(store.traceImportResult?.isUnavailable, true, "Unknown trace import method should expose unavailable trace result.")
        try expectContains(store.traceImportResult?.fallbackReason, "unavailable", "Unavailable trace import should expose quiet fallback reason.")
        try expectEqual(store.traceImportText, "raw local transcript", "Failed import should keep raw pasted input for user correction.")

        let calls = fake.calls()
        try expectContains(calls, "trace.listImports", "Fallback test should still attempt the V2.48 list method.")
        try expectContains(calls, "trace.importLocal", "Fallback test should still attempt the V2.48 import method.")
        try expectFalse(calls.contains("llm.previewPrompt"), "Unavailable trace flow must not fall back to provider prompt preview.")
        try expectFalse(calls.contains("llm.confirmPromptAndSend"), "Unavailable trace flow must not send to provider.")
        try expectFalse(calls.contains("config.toggleSkill"), "Unavailable trace flow must not call config write paths.")
        try expectFalse(calls.contains("script.execute"), "Unavailable trace flow must not call execution paths.")
    }

    private func routingAccuracyDashboardUsesReadOnlyServiceContract() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "prompt-ready")

        let store = SkillStore(service: ServiceClient())
        store.selectedSkillID = "beta"
        await store.reload()
        let snapshotCallsBeforeDashboard = countOccurrences("snapshot.", in: fake.calls())
        await store.loadRoutingAccuracyDashboard()

        let dashboard = store.routingAccuracyDashboard
        try expectEqual(dashboard?.generatedBy, "local-v2.49", "Routing accuracy dashboard should expose generator metadata.")
        try expectEqual(dashboard?.summary.hitCount, 7, "Routing accuracy dashboard should expose hit count.")
        try expectEqual(dashboard?.summary.wrongPickCount, 1, "Routing accuracy dashboard should expose wrong-pick count.")
        try expectEqual(dashboard?.agents.first?.agent, "claude-code", "Routing accuracy dashboard should expose per-agent rows.")
        try expectEqual(dashboard?.gaps.first?.title, "Missing trace coverage", "Routing accuracy dashboard should expose gaps.")
        try expectFalse(dashboard?.safetyFlags.providerRequestSent ?? true, "Routing accuracy must not send provider requests.")
        try expectFalse(dashboard?.safetyFlags.writeBackAllowed ?? true, "Routing accuracy must not allow write-back.")
        try expectFalse(dashboard?.safetyFlags.scriptExecutionAllowed ?? true, "Routing accuracy must not allow script execution.")
        try expectFalse(dashboard?.safetyFlags.configMutationAllowed ?? true, "Routing accuracy must not mutate config.")
        try expectFalse(dashboard?.safetyFlags.snapshotCreated ?? true, "Routing accuracy must not create snapshots.")
        try expectFalse(dashboard?.safetyFlags.triageMutationAllowed ?? true, "Routing accuracy must not mutate triage.")
        try expectFalse(dashboard?.safetyFlags.credentialAccessed ?? true, "Routing accuracy must not access credentials.")
        try expectFalse(dashboard?.safetyFlags.rawPromptPersisted ?? true, "Routing accuracy must not persist raw prompts.")
        try expectFalse(dashboard?.safetyFlags.rawResponsePersisted ?? true, "Routing accuracy must not persist raw responses.")
        try expectFalse(dashboard?.safetyFlags.rawTracePersisted ?? true, "Routing accuracy must not persist raw traces.")
        try expectFalse(dashboard?.safetyFlags.cloudSyncEnabled ?? true, "Routing accuracy must not sync cloud data.")
        try expectFalse(dashboard?.safetyFlags.telemetryEnabled ?? true, "Routing accuracy must not emit telemetry.")
        try expectFalse(store.isLoadingRoutingAccuracyDashboard, "Routing accuracy load should reset loading state.")

        let calls = fake.calls()
        try expectContains(calls, "routing.accuracyDashboard", "Routing accuracy UI should call the V2.49 dashboard method.")
        try expectContains(calls, "\"agent\":\"claude-code\"", "Routing accuracy should pass the current agent filter.")
        try expectContains(calls, "\"window_days\":30", "Routing accuracy should pass the dashboard window.")
        try expectContains(calls, "\"limit\":20", "Routing accuracy should pass the dashboard limit.")
        try expectContains(calls, "\"include_history\":true", "Routing accuracy should request history explicitly.")
        try expectContains(calls, "\"include_recent_evidence\":true", "Routing accuracy should request recent evidence explicitly.")
        try expectFalse(calls.contains("llm.previewPrompt"), "Routing accuracy dashboard must not prepare provider prompts.")
        try expectFalse(calls.contains("llm.confirmPromptAndSend"), "Routing accuracy dashboard must not send to provider.")
        try expectFalse(calls.contains("config.toggleSkill"), "Routing accuracy dashboard must not call config write paths.")
        try expectFalse(calls.contains("script.execute"), "Routing accuracy dashboard must not call execution paths.")
        try expectEqual(countOccurrences("snapshot.", in: calls), snapshotCallsBeforeDashboard, "Routing accuracy dashboard must not call snapshot paths.")
        try expectFalse(calls.contains("credential"), "Routing accuracy dashboard must not call credential paths.")
    }

    private func staleDriftDetectionUsesReadOnlyServiceContract() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "prompt-ready")

        let store = SkillStore(service: ServiceClient())
        store.selectedSkillID = "beta"
        await store.reload()
        let snapshotCallsBeforeDetect = countOccurrences("snapshot.", in: fake.calls())
        await store.detectStaleDrift()

        let result = store.staleDriftDetection
        try expectEqual(result?.generatedBy, "local-v2.51", "Stale drift detection should expose generator metadata.")
        try expectEqual(result?.summary.staleCount, 2, "Stale drift detection should expose stale count.")
        try expectEqual(result?.summary.driftCount, 1, "Stale drift detection should expose drift count.")
        try expectEqual(result?.staleDriftRows.first?.title, "Beta appears stale", "Stale drift detection should expose candidate rows.")
        try expectEqual(result?.staleDriftRows.first?.skill?.name, "Beta", "Stale drift detection should expose row skill refs.")
        try expectEqual(result?.readinessImpactRows.first?.title, "Readiness lowered", "Stale drift detection should expose readiness impact rows.")
        try expectEqual(result?.gapIssueRows.first?.title, "Missing fresh evidence", "Stale drift detection should expose gap rows.")
        try expectEqual(result?.evidenceReferences.first?.title, "Catalog freshness", "Stale drift detection should expose evidence references.")
        try expectFalse(result?.safetyFlags.providerRequestSent ?? true, "Stale drift detection must not send provider requests.")
        try expectFalse(result?.safetyFlags.writeBackAllowed ?? true, "Stale drift detection must not allow write-back.")
        try expectFalse(result?.safetyFlags.writeActionsAvailable ?? true, "Stale drift detection must not expose write actions.")
        try expectFalse(result?.safetyFlags.scriptExecutionAllowed ?? true, "Stale drift detection must not allow script execution.")
        try expectFalse(result?.safetyFlags.executionActionsAvailable ?? true, "Stale drift detection must not expose execution actions.")
        try expectFalse(result?.safetyFlags.configMutationAllowed ?? true, "Stale drift detection must not mutate config.")
        try expectFalse(result?.safetyFlags.snapshotCreated ?? true, "Stale drift detection must not create snapshots.")
        try expectFalse(result?.safetyFlags.triageMutationAllowed ?? true, "Stale drift detection must not mutate triage.")
        try expectFalse(result?.safetyFlags.credentialAccessed ?? true, "Stale drift detection must not access credentials.")
        try expectFalse(result?.safetyFlags.rawPromptPersisted ?? true, "Stale drift detection must not persist raw prompts.")
        try expectFalse(result?.safetyFlags.rawResponsePersisted ?? true, "Stale drift detection must not persist raw responses.")
        try expectFalse(result?.safetyFlags.rawTracePersisted ?? true, "Stale drift detection must not persist raw traces.")
        try expectFalse(result?.safetyFlags.cloudSyncEnabled ?? true, "Stale drift detection must not sync cloud data.")
        try expectFalse(result?.safetyFlags.telemetryEnabled ?? true, "Stale drift detection must not emit telemetry.")
        try expectFalse(store.isDetectingStaleDrift, "Stale drift detection should reset loading state.")

        let calls = fake.calls()
        try expectContains(calls, "analysis.detectStaleDrift", "Stale drift UI should call the V2.51 detection method.")
        try expectContains(calls, "\"agent\":\"claude-code\"", "Stale drift detection should pass the current agent filter.")
        try expectContains(calls, "\"limit\":40", "Stale drift detection should pass the detection limit.")
        try expectContains(calls, "\"include_readiness_impact\":true", "Stale drift detection should request readiness impact explicitly.")
        try expectFalse(calls.contains("llm.previewPrompt"), "Stale drift detection must not prepare provider prompts.")
        try expectFalse(calls.contains("llm.confirmPromptAndSend"), "Stale drift detection must not send to provider.")
        try expectFalse(calls.contains("config.toggleSkill"), "Stale drift detection must not call config write paths.")
        try expectFalse(calls.contains("script.execute"), "Stale drift detection must not call execution paths.")
        try expectEqual(countOccurrences("snapshot.", in: calls), snapshotCallsBeforeDetect, "Stale drift detection must not call snapshot paths.")
        try expectFalse(calls.contains("credential"), "Stale drift detection must not call credential paths.")
    }

    private func knowledgeSearchUsesReadOnlyServiceContract() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "prompt-ready")

        let store = SkillStore(service: ServiceClient())
        store.selectedSkillID = "beta"
        store.knowledgeSearchText = "release audit"
        await store.reload()
        let snapshotCallsBeforeSearch = countOccurrences("snapshot.", in: fake.calls())
        await store.searchKnowledge()

        let result = store.knowledgeSearchResult
        try expectEqual(result?.generatedBy, "local-v2.52", "Knowledge search should expose generator metadata.")
        try expectEqual(result?.summary.resultCount, 1, "Knowledge search should expose result count.")
        try expectEqual(result?.knowledgeRows.first?.skillName, "Beta", "Knowledge search should expose matched skill rows.")
        try expectEqual(result?.knowledgeRows.first?.tools, ["rg"], "Knowledge search should expose tool metadata.")
        try expectEqual(result?.facetRows.first?.value, "claude-code", "Knowledge search should expose facet rows.")
        try expectEqual(result?.gapNotes.first, "No fresh trace confirms the release audit route.", "Knowledge search should expose gap notes.")
        try expectEqual(result?.evidenceReferences.first?.title, "Knowledge index", "Knowledge search should expose evidence references.")
        try expectFalse(result?.safetyFlags.providerRequestSent ?? true, "Knowledge search must not send provider requests.")
        try expectFalse(result?.safetyFlags.writeBackAllowed ?? true, "Knowledge search must not allow write-back.")
        try expectFalse(result?.safetyFlags.writeActionsAvailable ?? true, "Knowledge search must not expose write actions.")
        try expectFalse(result?.safetyFlags.scriptExecutionAllowed ?? true, "Knowledge search must not allow script execution.")
        try expectFalse(result?.safetyFlags.executionActionsAvailable ?? true, "Knowledge search must not expose execution actions.")
        try expectFalse(result?.safetyFlags.configMutationAllowed ?? true, "Knowledge search must not mutate config.")
        try expectFalse(result?.safetyFlags.snapshotCreated ?? true, "Knowledge search must not create snapshots.")
        try expectFalse(result?.safetyFlags.triageMutationAllowed ?? true, "Knowledge search must not mutate triage.")
        try expectFalse(result?.safetyFlags.credentialAccessed ?? true, "Knowledge search must not access credentials.")
        try expectFalse(result?.safetyFlags.rawPromptPersisted ?? true, "Knowledge search must not persist raw prompts.")
        try expectFalse(result?.safetyFlags.rawResponsePersisted ?? true, "Knowledge search must not persist raw responses.")
        try expectFalse(result?.safetyFlags.rawTracePersisted ?? true, "Knowledge search must not persist raw traces.")
        try expectFalse(result?.safetyFlags.cloudSyncEnabled ?? true, "Knowledge search must not sync cloud data.")
        try expectFalse(result?.safetyFlags.telemetryEnabled ?? true, "Knowledge search must not emit telemetry.")
        try expectFalse(store.isSearchingKnowledge, "Knowledge search should reset loading state.")

        let calls = fake.calls()
        try expectContains(calls, "knowledge.search", "Knowledge UI should call the V2.52 search method.")
        try expectContains(calls, "\"query\":\"release audit\"", "Knowledge search should pass the user query.")
        try expectContains(calls, "\"agent\":\"claude-code\"", "Knowledge search should pass the current agent filter.")
        try expectContains(calls, "\"limit\":20", "Knowledge search should pass the search limit.")
        try expectFalse(calls.contains("llm.previewPrompt"), "Knowledge search must not prepare provider prompts.")
        try expectFalse(calls.contains("llm.confirmPromptAndSend"), "Knowledge search must not send to provider.")
        try expectFalse(calls.contains("config.toggleSkill"), "Knowledge search must not call config write paths.")
        try expectFalse(calls.contains("script.execute"), "Knowledge search must not call execution paths.")
        try expectEqual(countOccurrences("snapshot.", in: calls), snapshotCallsBeforeSearch, "Knowledge search must not call snapshot paths.")
        try expectFalse(calls.contains("credential"), "Knowledge search must not call credential paths.")
    }

    private func localSkillMapUsesReadOnlyServiceContract() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "prompt-ready")

        let store = SkillStore(service: ServiceClient())
        store.selectedSkillID = "beta"
        await store.reload()
        let snapshotCallsBeforeMap = countOccurrences("snapshot.", in: fake.calls())
        await store.buildLocalSkillMap()

        let result = store.localSkillMapResult
        try expectEqual(result?.generatedBy, "local-v2.63", "Local skill map should expose generator metadata.")
        try expectEqual(result?.summary.nodeCount, 2, "Local skill map should expose node count.")
        try expectEqual(result?.summary.edgeCount, 1, "Local skill map should expose edge count.")
        try expectEqual(result?.summary.clusterCount, 1, "Local skill map should expose cluster count.")
        try expectEqual(result?.selectedSkill?.skillName, "Beta", "Local skill map should expose selected skill context.")
        try expectEqual(result?.nodes.first?.label, "Beta", "Local skill map should expose key nodes.")
        try expectEqual(result?.edges.first?.relation, "similar-purpose", "Local skill map should expose edge relations.")
        try expectEqual(result?.clusters.first?.title, "Release audit", "Local skill map should expose clusters.")
        try expectEqual(result?.gapRows.first?.detail, "No Codex project route.", "Local skill map should expose gap rows.")
        try expectEqual(result?.evidenceReferences.first?.title, "Local skill map", "Local skill map should expose evidence references.")
        try expectFalse(result?.safetyFlags.providerRequestSent ?? true, "Local skill map must not send provider requests.")
        try expectFalse(result?.safetyFlags.writeBackAllowed ?? true, "Local skill map must not allow write-back.")
        try expectFalse(result?.safetyFlags.writeActionsAvailable ?? true, "Local skill map must not expose write actions.")
        try expectFalse(result?.safetyFlags.scriptExecutionAllowed ?? true, "Local skill map must not allow script execution.")
        try expectFalse(result?.safetyFlags.executionActionsAvailable ?? true, "Local skill map must not expose execution actions.")
        try expectFalse(result?.safetyFlags.configMutationAllowed ?? true, "Local skill map must not mutate config.")
        try expectFalse(result?.safetyFlags.snapshotCreated ?? true, "Local skill map must not create snapshots.")
        try expectFalse(result?.safetyFlags.triageMutationAllowed ?? true, "Local skill map must not mutate triage.")
        try expectFalse(result?.safetyFlags.credentialAccessed ?? true, "Local skill map must not access credentials.")
        try expectFalse(result?.safetyFlags.rawPromptPersisted ?? true, "Local skill map must not persist raw prompts.")
        try expectFalse(result?.safetyFlags.rawResponsePersisted ?? true, "Local skill map must not persist raw responses.")
        try expectFalse(result?.safetyFlags.rawTracePersisted ?? true, "Local skill map must not persist raw traces.")
        try expectFalse(result?.safetyFlags.cloudSyncEnabled ?? true, "Local skill map must not sync cloud data.")
        try expectFalse(result?.safetyFlags.telemetryEnabled ?? true, "Local skill map must not emit telemetry.")
        try expectFalse(store.isBuildingLocalSkillMap, "Local skill map should reset loading state.")

        let calls = fake.calls()
        try expectContains(calls, "knowledge.buildLocalSkillMap", "Local skill map should call the V2.63 map method.")
        try expectContains(calls, "\"agent\":\"claude-code\"", "Local skill map should pass the current agent filter.")
        try expectContains(calls, "\"selected_skill_id\":\"beta\"", "Local skill map should pass selected skill id.")
        try expectContains(calls, "\"selected_skill_name\":\"Beta\"", "Local skill map should pass selected skill name.")
        try expectContains(calls, "\"selected_skill_agent\":\"claude-code\"", "Local skill map should pass selected skill agent.")
        try expectContains(calls, "\"project_root\":\"\\/tmp\\/project\"", "Local skill map should pass active project root.")
        try expectContains(calls, "\"current_cwd\":\"\\/tmp\\/project\"", "Local skill map should pass active project cwd.")
        try expectContains(calls, "\"workspace\":\"Fixture Project\"", "Local skill map should pass active workspace name.")
        try expectContains(calls, "\"limit\":30", "Local skill map should pass map limit.")
        try expectContains(calls, "\"include_edges\":true", "Local skill map should request edges.")
        try expectContains(calls, "\"include_clusters\":true", "Local skill map should request clusters.")
        try expectContains(calls, "\"include_evidence\":true", "Local skill map should request evidence rows.")
        try expectFalse(calls.contains("llm.previewPrompt"), "Local skill map must not prepare provider prompts.")
        try expectFalse(calls.contains("llm.confirmPromptAndSend"), "Local skill map must not send to provider.")
        try expectFalse(calls.contains("config.toggleSkill"), "Local skill map must not call config write paths.")
        try expectFalse(calls.contains("script.execute"), "Local skill map must not call execution paths.")
        try expectEqual(countOccurrences("snapshot.", in: calls), snapshotCallsBeforeMap, "Local skill map must not call snapshot paths.")
        try expectFalse(calls.contains("credential"), "Local skill map must not call credential paths.")
    }

    private func localSkillMapFallsBackWhenMethodUnavailable() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "normal")

        let store = SkillStore(service: ServiceClient())
        store.selectedSkillID = "beta"
        await store.reload()
        await store.buildLocalSkillMap()

        try expectEqual(store.localSkillMapResult?.isUnavailable, true, "Local skill map should expose unavailable fallback for older services.")
        try expectEqual(store.localSkillMapResult?.fallbackReason, UIStrings.localSkillMapUnavailable, "Unknown method fallback should use the localized unavailable copy.")
        try expectFalse(store.isBuildingLocalSkillMap, "Unavailable local skill map should reset loading state.")
        try expectContains(fake.calls(), "knowledge.buildLocalSkillMap", "Fallback should still prove the intended V2.63 method was attempted.")
    }

    private func skillLifecycleTimelineUsesReadOnlyServiceContract() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "prompt-ready")

        let store = SkillStore(service: ServiceClient())
        store.selectedSkillID = "beta"
        await store.reload()
        let snapshotCallsBeforeTimeline = countOccurrences("snapshot.", in: fake.calls())
        await store.loadSkillLifecycleTimeline()

        let result = store.skillLifecycleTimelineResult
        try expectEqual(result?.generatedBy, "local-v2.66", "Skill lifecycle timeline should expose generator metadata.")
        try expectEqual(result?.summary.eventCount, 3, "Skill lifecycle timeline should expose event count.")
        try expectEqual(result?.summary.skillCount, 1, "Skill lifecycle timeline should expose skill aggregate count.")
        try expectEqual(result?.summary.agentCount, 1, "Skill lifecycle timeline should expose agent aggregate count.")
        try expectEqual(result?.timelineRows.first?.title, "Beta loaded from project root", "Skill lifecycle timeline should expose timeline rows.")
        try expectEqual(result?.timelineRows.first?.eventType, "scan.detected", "Skill lifecycle timeline should expose event type.")
        try expectEqual(result?.timelineRows.first?.lifecycleStage, "discovered", "Skill lifecycle timeline should expose lifecycle stage.")
        try expectEqual(result?.skillRows.first?.skillName, "Beta", "Skill lifecycle timeline should expose skill aggregate rows.")
        try expectEqual(result?.skillRows.first?.count, 3, "Skill lifecycle timeline should expose aggregate counts.")
        try expectEqual(result?.agentRows.first?.agent, "claude-code", "Skill lifecycle timeline should expose agent aggregate rows.")
        try expectEqual(result?.gapNotes.first, "No Codex lifecycle evidence for this selected skill.", "Skill lifecycle timeline should expose gap notes.")
        try expectEqual(result?.blockerNotes.first, "Lifecycle timeline is read-only and does not create snapshots.", "Skill lifecycle timeline should expose blocker notes.")
        try expectEqual(result?.evidenceReferences.first?.source, "skill.lifecycleTimeline", "Skill lifecycle timeline should expose evidence references.")
        try expectEqual(result?.promptRequest?.requestKind, "skill_lifecycle_timeline", "Skill lifecycle timeline should expose prompt metadata.")
        try expectFalse(result?.safetyFlags.providerRequestSent ?? true, "Skill lifecycle timeline must not send provider requests.")
        try expectFalse(result?.safetyFlags.writeBackAllowed ?? true, "Skill lifecycle timeline must not allow write-back.")
        try expectFalse(result?.safetyFlags.writeActionsAvailable ?? true, "Skill lifecycle timeline must not expose write actions.")
        try expectFalse(result?.safetyFlags.scriptExecutionAllowed ?? true, "Skill lifecycle timeline must not allow script execution.")
        try expectFalse(result?.safetyFlags.executionActionsAvailable ?? true, "Skill lifecycle timeline must not expose execution actions.")
        try expectFalse(result?.safetyFlags.configMutationAllowed ?? true, "Skill lifecycle timeline must not mutate config.")
        try expectFalse(result?.safetyFlags.snapshotCreated ?? true, "Skill lifecycle timeline must not create snapshots.")
        try expectFalse(result?.safetyFlags.triageMutationAllowed ?? true, "Skill lifecycle timeline must not mutate triage.")
        try expectFalse(result?.safetyFlags.credentialAccessed ?? true, "Skill lifecycle timeline must not access credentials.")
        try expectFalse(result?.safetyFlags.rawPromptPersisted ?? true, "Skill lifecycle timeline must not persist raw prompts.")
        try expectFalse(result?.safetyFlags.rawResponsePersisted ?? true, "Skill lifecycle timeline must not persist raw responses.")
        try expectFalse(result?.safetyFlags.rawTracePersisted ?? true, "Skill lifecycle timeline must not persist raw traces.")
        try expectFalse(result?.safetyFlags.cloudSyncEnabled ?? true, "Skill lifecycle timeline must not sync cloud data.")
        try expectFalse(result?.safetyFlags.telemetryEnabled ?? true, "Skill lifecycle timeline must not emit telemetry.")
        try expectFalse(store.isLoadingSkillLifecycleTimeline, "Skill lifecycle timeline should reset loading state.")

        let calls = fake.calls()
        try expectContains(calls, "skill.lifecycleTimeline", "Skill lifecycle timeline should call the V2.66 lifecycle method.")
        try expectContains(calls, "\"agent\":\"claude-code\"", "Skill lifecycle timeline should pass the current agent filter.")
        try expectContains(calls, "\"selected_skill_id\":\"beta\"", "Skill lifecycle timeline should pass selected skill id.")
        try expectContains(calls, "\"selected_skill_name\":\"Beta\"", "Skill lifecycle timeline should pass selected skill name.")
        try expectContains(calls, "\"selected_skill_agent\":\"claude-code\"", "Skill lifecycle timeline should pass selected skill agent.")
        try expectContains(calls, "\"candidate_instance_ids\":[\"beta\"]", "Skill lifecycle timeline should include selected skill candidate context.")
        try expectContains(calls, "\"project_root\":\"\\/tmp\\/project\"", "Skill lifecycle timeline should pass active project root.")
        try expectContains(calls, "\"current_cwd\":\"\\/tmp\\/project\"", "Skill lifecycle timeline should pass active project cwd.")
        try expectContains(calls, "\"workspace\":\"Fixture Project\"", "Skill lifecycle timeline should pass active workspace name.")
        try expectContains(calls, "\"limit\":20", "Skill lifecycle timeline should pass timeline limit.")
        try expectContains(calls, "\"include_skill_rows\":true", "Skill lifecycle timeline should request skill aggregates.")
        try expectContains(calls, "\"include_agent_rows\":true", "Skill lifecycle timeline should request agent aggregates.")
        try expectContains(calls, "\"include_evidence\":true", "Skill lifecycle timeline should request evidence rows.")
        try expectContains(calls, "\"include_safety_flags\":true", "Skill lifecycle timeline should request safety flags.")
        try expectFalse(calls.contains("llm.previewPrompt"), "Skill lifecycle timeline must not prepare provider prompts.")
        try expectFalse(calls.contains("llm.confirmPromptAndSend"), "Skill lifecycle timeline must not send to provider.")
        try expectFalse(calls.contains("config.toggleSkill"), "Skill lifecycle timeline must not call config write paths.")
        try expectFalse(calls.contains("script.execute"), "Skill lifecycle timeline must not call execution paths.")
        try expectEqual(countOccurrences("snapshot.", in: calls), snapshotCallsBeforeTimeline, "Skill lifecycle timeline must not call snapshot paths.")
        try expectFalse(calls.contains("credential"), "Skill lifecycle timeline must not call credential paths.")
    }

    private func skillLifecycleTimelineFallsBackWhenMethodUnavailable() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "normal")

        let store = SkillStore(service: ServiceClient())
        store.selectedSkillID = "beta"
        await store.reload()
        await store.loadSkillLifecycleTimeline()

        try expectEqual(store.skillLifecycleTimelineResult?.isUnavailable, true, "Skill lifecycle timeline should expose unavailable fallback for older services.")
        try expectEqual(store.skillLifecycleTimelineResult?.fallbackReason, UIStrings.skillLifecycleTimelineUnavailable, "Unknown method fallback should use the localized unavailable copy.")
        try expectFalse(store.isLoadingSkillLifecycleTimeline, "Unavailable lifecycle timeline should reset loading state.")
        try expectContains(fake.calls(), "skill.lifecycleTimeline", "Fallback should still prove the intended V2.66 method was attempted.")
        try expectFalse(fake.calls().contains("llm.previewPrompt"), "Unavailable lifecycle timeline must not fall back to provider prompt preview.")
        try expectFalse(fake.calls().contains("llm.confirmPromptAndSend"), "Unavailable lifecycle timeline must not send to provider.")
        try expectFalse(fake.calls().contains("config.toggleSkill"), "Unavailable lifecycle timeline must not call config write paths.")
        try expectFalse(fake.calls().contains("script.execute"), "Unavailable lifecycle timeline must not call execution paths.")
    }

    private func providerObservabilityUsesReadOnlyServiceContract() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "prompt-ready")

        let store = SkillStore(service: ServiceClient())
        store.selectedSkillID = "beta"
        await store.reload()
        let snapshotCallsBeforeObservability = countOccurrences("snapshot.", in: fake.calls())
        await store.loadProviderObservability()

        let result = store.providerObservabilityResult
        try expectEqual(result?.generatedBy, "local-v2.64", "Provider observability should expose generator metadata.")
        try expectEqual(result?.summary.callCount, 3, "Provider observability should expose call count.")
        try expectEqual(result?.summary.successCount, 1, "Provider observability should expose success count.")
        try expectEqual(result?.summary.failureCount, 1, "Provider observability should expose failure count.")
        try expectEqual(result?.summary.blockedCount, 1, "Provider observability should expose blocked count.")
        try expectEqual(result?.summary.estimatedTotalTokens, 1300, "Provider observability should expose token estimates.")
        try expectEqual(result?.callRows.first?.requestKind, "task_readiness", "Provider observability should expose recent call rows.")
        try expectEqual(result?.providerRows.first?.label, "OpenAI-compatible", "Provider observability should expose provider rows.")
        try expectEqual(result?.modelRows.first?.label, "gpt-5", "Provider observability should expose model rows.")
        try expectEqual(result?.destinationRows.first?.destinationHost, "llm.example.com", "Provider observability should expose destination rows.")
        try expectEqual(result?.errorRows.first?.title, "Timeout", "Provider observability should expose error rows.")
        try expectEqual(result?.budgetHints.first?.title, "Monthly budget healthy", "Provider observability should expose budget hints.")
        try expectEqual(result?.retentionRows.first?.title, "Retain metadata only", "Provider observability should expose retention rows.")
        try expectEqual(result?.cleanupRecommendationRows.first?.title, "No cleanup required", "Provider observability should expose cleanup rows.")
        try expectEqual(result?.evidenceReferences.first?.title, "Prompt run history", "Provider observability should expose evidence references.")
        try expectEqual(result?.promptRequest?.requestKind, "provider_observability", "Provider observability should expose prompt metadata.")
        try expectFalse(result?.safetyFlags.providerRequestSent ?? true, "Provider observability must not send provider requests.")
        try expectFalse(result?.safetyFlags.writeBackAllowed ?? true, "Provider observability must not allow write-back.")
        try expectFalse(result?.safetyFlags.writeActionsAvailable ?? true, "Provider observability must not expose write actions.")
        try expectFalse(result?.safetyFlags.scriptExecutionAllowed ?? true, "Provider observability must not allow script execution.")
        try expectFalse(result?.safetyFlags.executionActionsAvailable ?? true, "Provider observability must not expose execution actions.")
        try expectFalse(result?.safetyFlags.configMutationAllowed ?? true, "Provider observability must not mutate config.")
        try expectFalse(result?.safetyFlags.snapshotCreated ?? true, "Provider observability must not create snapshots.")
        try expectFalse(result?.safetyFlags.triageMutationAllowed ?? true, "Provider observability must not mutate triage.")
        try expectFalse(result?.safetyFlags.credentialAccessed ?? true, "Provider observability must not access credentials.")
        try expectFalse(result?.safetyFlags.rawPromptPersisted ?? true, "Provider observability must not persist raw prompts.")
        try expectFalse(result?.safetyFlags.rawResponsePersisted ?? true, "Provider observability must not persist raw responses.")
        try expectFalse(result?.safetyFlags.rawTracePersisted ?? true, "Provider observability must not persist raw traces.")
        try expectFalse(result?.safetyFlags.cloudSyncEnabled ?? true, "Provider observability must not sync cloud data.")
        try expectFalse(result?.safetyFlags.telemetryEnabled ?? true, "Provider observability must not emit telemetry.")
        try expectFalse(result?.safetyFlags.rawSecretReturned ?? true, "Provider observability must not expose raw secrets.")
        try expectFalse(store.isLoadingProviderObservability, "Provider observability should reset loading state.")

        let calls = fake.calls()
        try expectContains(calls, "llm.providerObservability", "Provider observability should call the V2.64 observability method.")
        try expectContains(calls, "\"window_days\":30", "Provider observability should pass the dashboard window.")
        try expectContains(calls, "\"limit\":30", "Provider observability should pass the dashboard limit.")
        try expectContains(calls, "\"include_history\":true", "Provider observability should request history rows.")
        try expectContains(calls, "\"include_budget_hints\":true", "Provider observability should request budget hints.")
        try expectContains(calls, "\"include_retention_recommendations\":true", "Provider observability should request retention recommendations.")
        try expectContains(calls, "\"include_evidence\":true", "Provider observability should request evidence rows.")
        try expectFalse(calls.contains("llm.previewPrompt"), "Provider observability must not prepare provider prompts.")
        try expectFalse(calls.contains("llm.confirmPromptAndSend"), "Provider observability must not send to provider.")
        try expectFalse(calls.contains("config.toggleSkill"), "Provider observability must not call config write paths.")
        try expectFalse(calls.contains("script.execute"), "Provider observability must not call execution paths.")
        try expectEqual(countOccurrences("snapshot.", in: calls), snapshotCallsBeforeObservability, "Provider observability must not call snapshot paths.")
        try expectFalse(calls.contains("credential"), "Provider observability must not call credential paths.")
    }

    private func providerObservabilityFallsBackWhenMethodUnavailable() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "normal")

        let store = SkillStore(service: ServiceClient())
        store.selectedSkillID = "beta"
        await store.reload()
        await store.loadProviderObservability()

        try expectEqual(store.providerObservabilityResult?.isUnavailable, true, "Provider observability should expose unavailable fallback for older services.")
        try expectEqual(store.providerObservabilityResult?.fallbackReason, UIStrings.providerObservabilityUnavailable, "Unknown method fallback should use the localized unavailable copy.")
        try expectFalse(store.isLoadingProviderObservability, "Unavailable provider observability should reset loading state.")
        try expectContains(fake.calls(), "llm.providerObservability", "Fallback should still prove the intended V2.64 method was attempted.")
    }

    private func taskCockpitUsesReadOnlyServiceContract() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "prompt-ready")

        let store = SkillStore(service: ServiceClient())
        store.selectedSkillID = "beta"
        store.taskCockpitText = "Prepare local release audit work."
        await store.reload()
        let snapshotCallsBeforeCockpit = countOccurrences("snapshot.", in: fake.calls())
        await store.buildTaskCockpit()

        let result = store.taskCockpitResult
        try expectEqual(result?.generatedBy, "local-v2.65", "Task cockpit should expose generator metadata.")
        try expectEqual(result?.summary.recommendedAgent, "claude-code", "Task cockpit should expose recommended agent.")
        try expectEqual(result?.summary.recommendedSkillName, "Beta", "Task cockpit should expose recommended skill.")
        try expectEqual(result?.routeCandidates.first?.title, "Beta", "Task cockpit should expose route candidates.")
        try expectEqual(result?.agentCandidates.first?.agent, "claude-code", "Task cockpit should expose agent candidates.")
        try expectEqual(result?.skillCandidates.first?.skill?.name, "Beta", "Task cockpit should expose skill candidates.")
        try expectEqual(result?.readinessSignals.first?.title, "Readiness partial", "Task cockpit should expose readiness signals.")
        try expectEqual(result?.sessionReviewContext.first?.source, "session.reviewAgentSkillUse", "Task cockpit should expose session context.")
        try expectEqual(result?.providerObservabilityContext.first?.source, "llm.providerObservability", "Task cockpit should expose provider observability context.")
        try expectEqual(result?.remediationContext.first?.source, "remediation.plan", "Task cockpit should expose remediation context.")
        try expectEqual(result?.gapRows.first?.title, "Codex coverage gap", "Task cockpit should expose gaps.")
        try expectEqual(result?.blockerRows.first?.title, "No apply path", "Task cockpit should expose blockers.")
        try expectEqual(result?.evidenceReferences.first?.source, "task.buildCockpit", "Task cockpit should expose evidence references.")
        try expectEqual(result?.promptRequest?.requestKind, "task_cockpit", "Task cockpit should expose prompt metadata.")
        try expectFalse(result?.safetyFlags.providerRequestSent ?? true, "Task cockpit must not send provider requests.")
        try expectFalse(result?.safetyFlags.writeBackAllowed ?? true, "Task cockpit must not allow write-back.")
        try expectFalse(result?.safetyFlags.writeActionsAvailable ?? true, "Task cockpit must not expose write actions.")
        try expectFalse(result?.safetyFlags.scriptExecutionAllowed ?? true, "Task cockpit must not allow script execution.")
        try expectFalse(result?.safetyFlags.executionActionsAvailable ?? true, "Task cockpit must not expose execution actions.")
        try expectFalse(result?.safetyFlags.configMutationAllowed ?? true, "Task cockpit must not mutate config.")
        try expectFalse(result?.safetyFlags.snapshotCreated ?? true, "Task cockpit must not create snapshots.")
        try expectFalse(result?.safetyFlags.triageMutationAllowed ?? true, "Task cockpit must not mutate triage.")
        try expectFalse(result?.safetyFlags.credentialAccessed ?? true, "Task cockpit must not access credentials.")
        try expectFalse(result?.safetyFlags.rawPromptPersisted ?? true, "Task cockpit must not persist raw prompts.")
        try expectFalse(result?.safetyFlags.rawResponsePersisted ?? true, "Task cockpit must not persist raw responses.")
        try expectFalse(result?.safetyFlags.rawTracePersisted ?? true, "Task cockpit must not persist raw traces.")
        try expectFalse(result?.safetyFlags.cloudSyncEnabled ?? true, "Task cockpit must not sync cloud data.")
        try expectFalse(result?.safetyFlags.telemetryEnabled ?? true, "Task cockpit must not emit telemetry.")
        try expectFalse(store.isBuildingTaskCockpit, "Task cockpit should reset loading state.")

        let calls = fake.calls()
        try expectContains(calls, "task.buildCockpit", "Task cockpit should call the V2.65 task.buildCockpit method.")
        try expectContains(calls, "\"task\":\"Prepare local release audit work.\"", "Task cockpit should send task text.")
        try expectContains(calls, "\"agent\":\"claude-code\"", "Task cockpit should pass the current agent filter.")
        try expectContains(calls, "\"selected_skill_id\":\"beta\"", "Task cockpit should pass selected skill id.")
        try expectContains(calls, "\"selected_skill_name\":\"Beta\"", "Task cockpit should pass selected skill name.")
        try expectContains(calls, "\"selected_skill_agent\":\"claude-code\"", "Task cockpit should pass selected skill agent.")
        try expectContains(calls, "\"candidate_instance_ids\":[\"beta\"]", "Task cockpit should include selected skill candidate context.")
        try expectContains(calls, "\"project_root\":\"\\/tmp\\/project\"", "Task cockpit should pass active project root.")
        try expectContains(calls, "\"current_cwd\":\"\\/tmp\\/project\"", "Task cockpit should pass active project cwd.")
        try expectContains(calls, "\"workspace\":\"Fixture Project\"", "Task cockpit should pass active workspace name.")
        try expectContains(calls, "\"limit\":8", "Task cockpit should pass cockpit limit.")
        try expectContains(calls, "\"include_session_review\":true", "Task cockpit should request session-review context.")
        try expectContains(calls, "\"include_provider_observability\":true", "Task cockpit should request provider-observability context.")
        try expectContains(calls, "\"include_remediation_context\":true", "Task cockpit should request remediation context.")
        try expectContains(calls, "\"include_evidence\":true", "Task cockpit should request evidence rows.")
        try expectFalse(calls.contains("llm.previewPrompt"), "Task cockpit must not prepare provider prompts.")
        try expectFalse(calls.contains("llm.confirmPromptAndSend"), "Task cockpit must not send to provider.")
        try expectFalse(calls.contains("config.toggleSkill"), "Task cockpit must not call config write paths.")
        try expectFalse(calls.contains("script.execute"), "Task cockpit must not call execution paths.")
        try expectEqual(countOccurrences("snapshot.", in: calls), snapshotCallsBeforeCockpit, "Task cockpit must not call snapshot paths.")
        try expectFalse(calls.contains("credential"), "Task cockpit must not call credential paths.")
    }

    private func taskCockpitFallsBackWhenMethodUnavailable() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "normal")

        let store = SkillStore(service: ServiceClient())
        store.selectedSkillID = "beta"
        store.routingConfidenceText = "Route a local audit release note task."
        await store.reload()
        await store.buildTaskCockpit()

        try expectEqual(store.taskCockpitResult?.isUnavailable, true, "Task cockpit should expose unavailable fallback for older services.")
        try expectEqual(store.taskCockpitResult?.fallbackReason, UIStrings.taskCockpitUnavailable, "Unknown method fallback should use the localized unavailable copy.")
        try expectFalse(store.isBuildingTaskCockpit, "Unavailable task cockpit should reset loading state.")
        try expectContains(fake.calls(), "task.buildCockpit", "Fallback should still prove the intended V2.65 method was attempted.")
        try expectContains(fake.calls(), "\"task\":\"Route a local audit release note task.\"", "Fallback should reuse existing routing task text when cockpit input is blank.")
        try expectFalse(fake.calls().contains("llm.previewPrompt"), "Unavailable cockpit flow must not fall back to provider prompt preview.")
        try expectFalse(fake.calls().contains("llm.confirmPromptAndSend"), "Unavailable cockpit flow must not send to provider.")
        try expectFalse(fake.calls().contains("config.toggleSkill"), "Unavailable cockpit flow must not call config write paths.")
        try expectFalse(fake.calls().contains("script.execute"), "Unavailable cockpit flow must not call execution paths.")
    }

    private func similarSkillGroupingUsesReadOnlyServiceContract() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "prompt-ready")

        let store = SkillStore(service: ServiceClient())
        store.selectedSkillID = "beta"
        await store.reload()
        let snapshotCallsBeforeGrouping = countOccurrences("snapshot.", in: fake.calls())
        await store.groupSimilarSkills()

        let result = store.similarSkillGroupingResult
        try expectEqual(result?.generatedBy, "local-v2.53", "Similar grouping should expose generator metadata.")
        try expectEqual(result?.summary.groupCount, 1, "Similar grouping should expose group count.")
        try expectEqual(result?.groups.first?.title, "Audit release skills", "Similar grouping should expose group title.")
        try expectEqual(result?.groups.first?.typeLabel, UIStrings.similarGroupingDuplicate, "Similar grouping should expose duplicate type.")
        try expectEqual(result?.groups.first?.members.first?.skillName, "Beta", "Similar grouping should expose member rows.")
        try expectEqual(result?.groups.first?.sharedTools, ["rg"], "Similar grouping should expose shared tools.")
        try expectEqual(result?.gapNotes.first, "No benchmark separates the two skills.", "Similar grouping should expose gap notes.")
        try expectEqual(result?.evidenceReferences.first?.title, "Similar grouping", "Similar grouping should expose evidence references.")
        try expectFalse(result?.safetyFlags.providerRequestSent ?? true, "Similar grouping must not send provider requests.")
        try expectFalse(result?.safetyFlags.writeBackAllowed ?? true, "Similar grouping must not allow write-back.")
        try expectFalse(result?.safetyFlags.writeActionsAvailable ?? true, "Similar grouping must not expose write actions.")
        try expectFalse(result?.safetyFlags.scriptExecutionAllowed ?? true, "Similar grouping must not allow script execution.")
        try expectFalse(result?.safetyFlags.executionActionsAvailable ?? true, "Similar grouping must not expose execution actions.")
        try expectFalse(result?.safetyFlags.configMutationAllowed ?? true, "Similar grouping must not mutate config.")
        try expectFalse(result?.safetyFlags.snapshotCreated ?? true, "Similar grouping must not create snapshots.")
        try expectFalse(result?.safetyFlags.triageMutationAllowed ?? true, "Similar grouping must not mutate triage.")
        try expectFalse(result?.safetyFlags.credentialAccessed ?? true, "Similar grouping must not access credentials.")
        try expectFalse(result?.safetyFlags.rawPromptPersisted ?? true, "Similar grouping must not persist raw prompts.")
        try expectFalse(result?.safetyFlags.rawResponsePersisted ?? true, "Similar grouping must not persist raw responses.")
        try expectFalse(result?.safetyFlags.rawTracePersisted ?? true, "Similar grouping must not persist raw traces.")
        try expectFalse(result?.safetyFlags.cloudSyncEnabled ?? true, "Similar grouping must not sync cloud data.")
        try expectFalse(result?.safetyFlags.telemetryEnabled ?? true, "Similar grouping must not emit telemetry.")
        try expectFalse(store.isGroupingSimilarSkills, "Similar grouping should reset loading state.")

        let calls = fake.calls()
        try expectContains(calls, "knowledge.groupSimilarSkills", "Similar grouping should call the V2.53 grouping method.")
        try expectContains(calls, "\"agent\":\"claude-code\"", "Similar grouping should pass the current agent filter.")
        try expectContains(calls, "\"limit\":20", "Similar grouping should pass the group limit.")
        try expectContains(calls, "\"min_score\":0.62", "Similar grouping should pass the score threshold.")
        try expectContains(calls, "\"include_singletons\":false", "Similar grouping should omit singleton groups by default.")
        try expectFalse(calls.contains("llm.previewPrompt"), "Similar grouping must not prepare provider prompts.")
        try expectFalse(calls.contains("llm.confirmPromptAndSend"), "Similar grouping must not send to provider.")
        try expectFalse(calls.contains("config.toggleSkill"), "Similar grouping must not call config write paths.")
        try expectFalse(calls.contains("script.execute"), "Similar grouping must not call execution paths.")
        try expectEqual(countOccurrences("snapshot.", in: calls), snapshotCallsBeforeGrouping, "Similar grouping must not call snapshot paths.")
        try expectFalse(calls.contains("credential"), "Similar grouping must not call credential paths.")
    }

    private func similarSkillGroupingFallsBackWhenMethodUnavailable() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "normal")

        let store = SkillStore(service: ServiceClient())
        store.selectedSkillID = "beta"
        await store.reload()
        await store.groupSimilarSkills()

        try expectEqual(store.similarSkillGroupingResult?.isUnavailable, true, "Similar grouping should expose unavailable fallback for older services.")
        try expectEqual(store.similarSkillGroupingResult?.fallbackReason, UIStrings.similarGroupingUnavailable, "Unknown method fallback should use the localized unavailable copy.")
        try expectFalse(store.isGroupingSimilarSkills, "Unavailable similar grouping should reset loading state.")
        try expectContains(fake.calls(), "knowledge.groupSimilarSkills", "Fallback should still prove the intended V2.53 method was attempted.")
    }

    private func capabilityTaxonomyUsesReadOnlyServiceContract() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "prompt-ready")

        let store = SkillStore(service: ServiceClient())
        store.selectedSkillID = "beta"
        await store.reload()
        let snapshotCallsBeforeBuild = countOccurrences("snapshot.", in: fake.calls())
        await store.buildCapabilityTaxonomy()

        let result = store.capabilityTaxonomyResult
        try expectEqual(result?.generatedBy, "local-v2.54", "Capability taxonomy should expose generator metadata.")
        try expectEqual(result?.summary.domainCount, 1, "Capability taxonomy should expose domain count.")
        try expectEqual(result?.summary.capabilityCount, 2, "Capability taxonomy should expose capability count.")
        try expectEqual(result?.coverageByAgent.first?.agent, "claude-code", "Capability taxonomy should expose agent coverage.")
        try expectEqual(result?.domains.first?.name, "Audit workflows", "Capability taxonomy should expose domain title.")
        try expectEqual(result?.domains.first?.capabilities.first?.name, "Release audit", "Capability taxonomy should expose capability rows.")
        try expectEqual(result?.domains.first?.capabilities.first?.representativeSkills.first?.skillName, "Beta", "Capability taxonomy should expose representative skills.")
        try expectEqual(result?.gapNotes.first, "Codex has no equivalent audit capability.", "Capability taxonomy should expose gap notes.")
        try expectEqual(result?.evidenceReferences.first?.title, "Capability taxonomy", "Capability taxonomy should expose evidence references.")
        try expectFalse(result?.safetyFlags.providerRequestSent ?? true, "Capability taxonomy must not send provider requests.")
        try expectFalse(result?.safetyFlags.writeBackAllowed ?? true, "Capability taxonomy must not allow write-back.")
        try expectFalse(result?.safetyFlags.writeActionsAvailable ?? true, "Capability taxonomy must not expose write actions.")
        try expectFalse(result?.safetyFlags.scriptExecutionAllowed ?? true, "Capability taxonomy must not allow script execution.")
        try expectFalse(result?.safetyFlags.executionActionsAvailable ?? true, "Capability taxonomy must not expose execution actions.")
        try expectFalse(result?.safetyFlags.configMutationAllowed ?? true, "Capability taxonomy must not mutate config.")
        try expectFalse(result?.safetyFlags.snapshotCreated ?? true, "Capability taxonomy must not create snapshots.")
        try expectFalse(result?.safetyFlags.triageMutationAllowed ?? true, "Capability taxonomy must not mutate triage.")
        try expectFalse(result?.safetyFlags.credentialAccessed ?? true, "Capability taxonomy must not access credentials.")
        try expectFalse(result?.safetyFlags.rawPromptPersisted ?? true, "Capability taxonomy must not persist raw prompts.")
        try expectFalse(result?.safetyFlags.rawResponsePersisted ?? true, "Capability taxonomy must not persist raw responses.")
        try expectFalse(result?.safetyFlags.rawTracePersisted ?? true, "Capability taxonomy must not persist raw traces.")
        try expectFalse(result?.safetyFlags.cloudSyncEnabled ?? true, "Capability taxonomy must not sync cloud data.")
        try expectFalse(result?.safetyFlags.telemetryEnabled ?? true, "Capability taxonomy must not emit telemetry.")
        try expectFalse(store.isBuildingCapabilityTaxonomy, "Capability taxonomy should reset loading state.")

        let calls = fake.calls()
        try expectContains(calls, "knowledge.buildCapabilityTaxonomy", "Capability taxonomy should call the V2.54 taxonomy method.")
        try expectContains(calls, "\"agent\":\"claude-code\"", "Capability taxonomy should pass the current agent filter.")
        try expectContains(calls, "\"limit\":20", "Capability taxonomy should pass the domain limit.")
        try expectContains(calls, "\"include_single_skill_domains\":true", "Capability taxonomy should request single-skill domain coverage.")
        try expectFalse(calls.contains("llm.previewPrompt"), "Capability taxonomy must not prepare provider prompts.")
        try expectFalse(calls.contains("llm.confirmPromptAndSend"), "Capability taxonomy must not send to provider.")
        try expectFalse(calls.contains("config.toggleSkill"), "Capability taxonomy must not call config write paths.")
        try expectFalse(calls.contains("script.execute"), "Capability taxonomy must not call execution paths.")
        try expectEqual(countOccurrences("snapshot.", in: calls), snapshotCallsBeforeBuild, "Capability taxonomy must not call snapshot paths.")
        try expectFalse(calls.contains("credential"), "Capability taxonomy must not call credential paths.")
    }

    private func capabilityTaxonomyFallsBackWhenMethodUnavailable() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "normal")

        let store = SkillStore(service: ServiceClient())
        store.selectedSkillID = "beta"
        await store.reload()
        await store.buildCapabilityTaxonomy()

        try expectEqual(store.capabilityTaxonomyResult?.isUnavailable, true, "Capability taxonomy should expose unavailable fallback for older services.")
        try expectEqual(store.capabilityTaxonomyResult?.fallbackReason, UIStrings.capabilityTaxonomyUnavailable, "Unknown method fallback should use the localized unavailable copy.")
        try expectFalse(store.isBuildingCapabilityTaxonomy, "Unavailable capability taxonomy should reset loading state.")
        try expectContains(fake.calls(), "knowledge.buildCapabilityTaxonomy", "Fallback should still prove the intended V2.54 method was attempted.")
    }

    private func workspaceReadinessUsesReadOnlyServiceContract() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "prompt-ready")

        let store = SkillStore(service: ServiceClient())
        store.selectedSkillID = "beta"
        store.routingConfidenceText = "Prepare local release audit work."
        await store.reload()
        let snapshotCallsBeforeCheck = countOccurrences("snapshot.", in: fake.calls())
        await store.checkWorkspaceReadiness()

        let result = store.workspaceReadinessResult
        try expectEqual(result?.generatedBy, "local-v2.55", "Workspace readiness should expose generator metadata.")
        try expectEqual(result?.summary.overallState, "partial", "Workspace readiness should expose overall state.")
        try expectEqual(result?.summary.readinessScore, 78, "Workspace readiness should expose readiness score.")
        try expectEqual(result?.checklistRows.first?.title, "Release audit skill enabled", "Workspace readiness should expose checklist rows.")
        try expectEqual(result?.checklistRows.first?.matchedSkills.first?.skillName, "Beta", "Workspace readiness should expose matched skills.")
        try expectEqual(result?.agentRows.first?.agent, "claude-code", "Workspace readiness should expose per-agent rows.")
        try expectEqual(result?.capabilityRows.first?.capability, "Release audit", "Workspace readiness should expose capability rows.")
        try expectEqual(result?.gapNotes.first, "Codex lacks a project-scoped release audit skill.", "Workspace readiness should expose gap notes.")
        try expectEqual(result?.evidenceReferences.first?.title, "Workspace readiness", "Workspace readiness should expose evidence references.")
        try expectFalse(result?.safetyFlags.providerRequestSent ?? true, "Workspace readiness must not send provider requests.")
        try expectFalse(result?.safetyFlags.writeBackAllowed ?? true, "Workspace readiness must not allow write-back.")
        try expectFalse(result?.safetyFlags.writeActionsAvailable ?? true, "Workspace readiness must not expose write actions.")
        try expectFalse(result?.safetyFlags.scriptExecutionAllowed ?? true, "Workspace readiness must not allow script execution.")
        try expectFalse(result?.safetyFlags.executionActionsAvailable ?? true, "Workspace readiness must not expose execution actions.")
        try expectFalse(result?.safetyFlags.configMutationAllowed ?? true, "Workspace readiness must not mutate config.")
        try expectFalse(result?.safetyFlags.snapshotCreated ?? true, "Workspace readiness must not create snapshots.")
        try expectFalse(result?.safetyFlags.triageMutationAllowed ?? true, "Workspace readiness must not mutate triage.")
        try expectFalse(result?.safetyFlags.credentialAccessed ?? true, "Workspace readiness must not access credentials.")
        try expectFalse(result?.safetyFlags.rawPromptPersisted ?? true, "Workspace readiness must not persist raw prompts.")
        try expectFalse(result?.safetyFlags.rawResponsePersisted ?? true, "Workspace readiness must not persist raw responses.")
        try expectFalse(result?.safetyFlags.rawTracePersisted ?? true, "Workspace readiness must not persist raw traces.")
        try expectFalse(result?.safetyFlags.cloudSyncEnabled ?? true, "Workspace readiness must not sync cloud data.")
        try expectFalse(result?.safetyFlags.telemetryEnabled ?? true, "Workspace readiness must not emit telemetry.")
        try expectFalse(store.isCheckingWorkspaceReadiness, "Workspace readiness should reset loading state.")

        let calls = fake.calls()
        try expectContains(calls, "workspace.checkReadiness", "Workspace readiness should call the V2.55 workspace method.")
        try expectContains(calls, "\"task\":\"Prepare local release audit work.\"", "Workspace readiness should pass current task context when present.")
        try expectContains(calls, "\"agent\":\"claude-code\"", "Workspace readiness should pass the current agent filter.")
        try expectContains(calls, "\"limit\":40", "Workspace readiness should pass the check limit.")
        try expectContains(calls, "\"include_checklist\":true", "Workspace readiness should request checklist rows.")
        try expectContains(calls, "\"include_capabilities\":true", "Workspace readiness should request capability rows.")
        try expectFalse(calls.contains("llm.previewPrompt"), "Workspace readiness must not prepare provider prompts.")
        try expectFalse(calls.contains("llm.confirmPromptAndSend"), "Workspace readiness must not send to provider.")
        try expectFalse(calls.contains("config.toggleSkill"), "Workspace readiness must not call config write paths.")
        try expectFalse(calls.contains("script.execute"), "Workspace readiness must not call execution paths.")
        try expectEqual(countOccurrences("snapshot.", in: calls), snapshotCallsBeforeCheck, "Workspace readiness must not call snapshot paths.")
        try expectFalse(calls.contains("credential"), "Workspace readiness must not call credential paths.")
    }

    private func workspaceReadinessFallsBackWhenMethodUnavailable() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "normal")

        let store = SkillStore(service: ServiceClient())
        store.selectedSkillID = "beta"
        await store.reload()
        await store.checkWorkspaceReadiness()

        try expectEqual(store.workspaceReadinessResult?.isUnavailable, true, "Workspace readiness should expose unavailable fallback for older services.")
        try expectEqual(store.workspaceReadinessResult?.fallbackReason, UIStrings.workspaceReadinessUnavailable, "Unknown method fallback should use the localized unavailable copy.")
        try expectFalse(store.isCheckingWorkspaceReadiness, "Unavailable workspace readiness should reset loading state.")
        try expectContains(fake.calls(), "workspace.checkReadiness", "Fallback should still prove the intended V2.55 method was attempted.")
    }

    private func remediationPlanUsesReadOnlyServiceContract() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "prompt-ready")

        let store = SkillStore(service: ServiceClient())
        store.selectedSkillID = "beta"
        store.routingConfidenceText = "Prepare local release audit work."
        await store.reload()
        let snapshotCallsBeforePlan = countOccurrences("snapshot.", in: fake.calls())
        await store.planRemediation()

        let result = store.remediationPlanResult
        try expectEqual(result?.generatedBy, "local-v2.56", "Remediation plan should expose generator metadata.")
        try expectEqual(result?.summary.totalCount, 2, "Remediation plan should expose total item count.")
        try expectEqual(result?.summary.highCount, 1, "Remediation plan should expose high-priority count.")
        try expectEqual(result?.priorityRows.first?.title, "High priority", "Remediation plan should expose priority rows.")
        try expectEqual(result?.items.first?.title, "Add Codex release audit coverage", "Remediation plan should expose plan items.")
        try expectEqual(result?.items.first?.skill?.skillName, "Beta", "Remediation plan should expose referenced skill evidence.")
        try expectEqual(result?.items.first?.guidanceOnly, true, "Remediation items must stay guidance-only.")
        try expectEqual(result?.gapNotes.first, "Codex lacks a project-scoped release audit skill.", "Remediation plan should expose gap notes.")
        try expectEqual(result?.blockerNotes.first, "No automatic write/apply path is exposed.", "Remediation plan should expose blocker notes.")
        try expectEqual(result?.evidenceReferences.first?.title, "Remediation planner", "Remediation plan should expose evidence references.")
        try expectFalse(result?.safetyFlags.providerRequestSent ?? true, "Remediation planning must not send provider requests.")
        try expectFalse(result?.safetyFlags.writeBackAllowed ?? true, "Remediation planning must not allow write-back.")
        try expectFalse(result?.safetyFlags.writeActionsAvailable ?? true, "Remediation planning must not expose write actions.")
        try expectFalse(result?.safetyFlags.scriptExecutionAllowed ?? true, "Remediation planning must not allow script execution.")
        try expectFalse(result?.safetyFlags.executionActionsAvailable ?? true, "Remediation planning must not expose execution actions.")
        try expectFalse(result?.safetyFlags.configMutationAllowed ?? true, "Remediation planning must not mutate config.")
        try expectFalse(result?.safetyFlags.snapshotCreated ?? true, "Remediation planning must not create snapshots.")
        try expectFalse(result?.safetyFlags.triageMutationAllowed ?? true, "Remediation planning must not mutate triage.")
        try expectFalse(result?.safetyFlags.credentialAccessed ?? true, "Remediation planning must not access credentials.")
        try expectFalse(result?.safetyFlags.rawPromptPersisted ?? true, "Remediation planning must not persist raw prompts.")
        try expectFalse(result?.safetyFlags.rawResponsePersisted ?? true, "Remediation planning must not persist raw responses.")
        try expectFalse(result?.safetyFlags.rawTracePersisted ?? true, "Remediation planning must not persist raw traces.")
        try expectFalse(result?.safetyFlags.cloudSyncEnabled ?? true, "Remediation planning must not sync cloud data.")
        try expectFalse(result?.safetyFlags.telemetryEnabled ?? true, "Remediation planning must not emit telemetry.")
        try expectFalse(store.isPlanningRemediation, "Remediation planner should reset loading state.")

        let calls = fake.calls()
        try expectContains(calls, "remediation.plan", "Remediation planner should call the V2.56 remediation method.")
        try expectContains(calls, "\"task\":\"Prepare local release audit work.\"", "Remediation planner should pass current task context when present.")
        try expectContains(calls, "\"agent\":\"claude-code\"", "Remediation planner should pass the current agent filter.")
        try expectContains(calls, "\"limit\":20", "Remediation planner should pass the plan limit.")
        try expectContains(calls, "\"include_guidance_only\":true", "Remediation planner should request guidance-only output.")
        try expectFalse(calls.contains("llm.previewPrompt"), "Remediation planning must not prepare provider prompts.")
        try expectFalse(calls.contains("llm.confirmPromptAndSend"), "Remediation planning must not send to provider.")
        try expectFalse(calls.contains("config.toggleSkill"), "Remediation planning must not call config write paths.")
        try expectFalse(calls.contains("script.execute"), "Remediation planning must not call execution paths.")
        try expectEqual(countOccurrences("snapshot.", in: calls), snapshotCallsBeforePlan, "Remediation planning must not call snapshot paths.")
        try expectFalse(calls.contains("credential"), "Remediation planning must not call credential paths.")
    }

    private func remediationPlanFallsBackWhenMethodUnavailable() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "normal")

        let store = SkillStore(service: ServiceClient())
        store.selectedSkillID = "beta"
        await store.reload()
        await store.planRemediation()

        try expectEqual(store.remediationPlanResult?.isUnavailable, true, "Remediation planner should expose unavailable fallback for older services.")
        try expectEqual(store.remediationPlanResult?.fallbackReason, UIStrings.remediationPlanUnavailable, "Unknown method fallback should use the localized unavailable copy.")
        try expectFalse(store.isPlanningRemediation, "Unavailable remediation planner should reset loading state.")
        try expectContains(fake.calls(), "remediation.plan", "Fallback should still prove the intended V2.56 method was attempted.")
    }

    private func remediationPreviewDraftsUsesCopyOnlyServiceContract() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "prompt-ready")

        let store = SkillStore(service: ServiceClient())
        store.selectedSkillID = "beta"
        store.routingConfidenceText = "Prepare local release audit work."
        await store.reload()
        let snapshotCallsBeforePreview = countOccurrences("snapshot.", in: fake.calls())
        await store.previewRemediationDrafts()

        let result = store.remediationPreviewDraftsResult
        try expectEqual(result?.generatedBy, "local-v2.57", "Fix preview drafts should expose generator metadata.")
        try expectEqual(result?.summary.totalCount, 2, "Fix preview drafts should expose total draft count.")
        try expectEqual(result?.summary.frontmatterCount, 1, "Fix preview drafts should expose frontmatter count.")
        try expectEqual(result?.summary.permissionsCount, 1, "Fix preview drafts should expose permissions count.")
        try expectEqual(result?.draftItems.first?.title, "Declare network permission", "Fix preview drafts should expose draft items.")
        try expectEqual(result?.draftItems.first?.draftType, "frontmatter", "Fix preview drafts should expose draft type.")
        try expectEqual(result?.draftItems.first?.affectedSkill?.skillName, "Beta", "Fix preview drafts should expose affected skill evidence.")
        try expectEqual(result?.draftItems.first?.proposedText, "permissions:\n  network: true", "Fix preview drafts should expose proposed copy text.")
        try expectEqual(result?.draftItems.first?.copyLabel, "Copy YAML", "Fix preview drafts should expose copy label.")
        try expectEqual(result?.gapNotes.first, "No dependency draft needed.", "Fix preview drafts should expose gap notes.")
        try expectEqual(result?.blockerNotes.first, "No automatic write/apply path is exposed.", "Fix preview drafts should expose blocker notes.")
        try expectEqual(result?.evidenceReferences.first?.title, "Fix preview", "Fix preview drafts should expose evidence references.")
        try expectEqual(result?.promptRequest?.requestKind, "remediation_preview_drafts", "Fix preview prompt metadata should use V2.57 request kind.")
        try expectFalse(result?.safetyFlags.providerRequestSent ?? true, "Fix preview drafts must not send provider requests.")
        try expectFalse(result?.safetyFlags.writeBackAllowed ?? true, "Fix preview drafts must not allow write-back.")
        try expectFalse(result?.safetyFlags.writeActionsAvailable ?? true, "Fix preview drafts must not expose write actions.")
        try expectFalse(result?.safetyFlags.scriptExecutionAllowed ?? true, "Fix preview drafts must not allow script execution.")
        try expectFalse(result?.safetyFlags.executionActionsAvailable ?? true, "Fix preview drafts must not expose execution actions.")
        try expectFalse(result?.safetyFlags.configMutationAllowed ?? true, "Fix preview drafts must not mutate config.")
        try expectFalse(result?.safetyFlags.snapshotCreated ?? true, "Fix preview drafts must not create snapshots.")
        try expectFalse(result?.safetyFlags.triageMutationAllowed ?? true, "Fix preview drafts must not mutate triage.")
        try expectFalse(result?.safetyFlags.credentialAccessed ?? true, "Fix preview drafts must not access credentials.")
        try expectFalse(result?.safetyFlags.rawPromptPersisted ?? true, "Fix preview drafts must not persist raw prompts.")
        try expectFalse(result?.safetyFlags.rawResponsePersisted ?? true, "Fix preview drafts must not persist raw responses.")
        try expectFalse(result?.safetyFlags.rawTracePersisted ?? true, "Fix preview drafts must not persist raw traces.")
        try expectFalse(result?.safetyFlags.cloudSyncEnabled ?? true, "Fix preview drafts must not sync cloud data.")
        try expectFalse(result?.safetyFlags.telemetryEnabled ?? true, "Fix preview drafts must not emit telemetry.")
        try expectFalse(store.isPreviewingRemediationDrafts, "Fix preview drafts should reset loading state.")

        let calls = fake.calls()
        try expectContains(calls, "remediation.previewDrafts", "Fix preview UI should call the V2.57 drafts method.")
        try expectContains(calls, "\"task\":\"Prepare local release audit work.\"", "Fix preview drafts should pass current task context when present.")
        try expectContains(calls, "\"agent\":\"claude-code\"", "Fix preview drafts should pass the current agent filter.")
        try expectContains(calls, "\"limit\":20", "Fix preview drafts should pass the draft limit.")
        try expectContains(calls, "\"draft_types\":[\"frontmatter\",\"description\",\"permissions\",\"dependency\",\"policy\"]", "Fix preview drafts should request the supported draft kinds.")
        try expectContains(calls, "\"include_blocked\":true", "Fix preview drafts should keep blocked/manual-review drafts visible.")
        try expectFalse(calls.contains("llm.previewPrompt"), "Fix preview drafts must not prepare provider prompts.")
        try expectFalse(calls.contains("llm.confirmPromptAndSend"), "Fix preview drafts must not send to provider.")
        try expectFalse(calls.contains("config.toggleSkill"), "Fix preview drafts must not call config write paths.")
        try expectFalse(calls.contains("script.execute"), "Fix preview drafts must not call execution paths.")
        try expectEqual(countOccurrences("snapshot.", in: calls), snapshotCallsBeforePreview, "Fix preview drafts must not call snapshot paths.")
        try expectFalse(calls.contains("credential"), "Fix preview drafts must not call credential paths.")
    }

    private func remediationPreviewDraftsFallsBackWhenMethodUnavailable() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "normal")

        let store = SkillStore(service: ServiceClient())
        store.selectedSkillID = "beta"
        await store.reload()
        await store.previewRemediationDrafts()

        try expectEqual(store.remediationPreviewDraftsResult?.isUnavailable, true, "Fix preview drafts should expose unavailable fallback for older services.")
        try expectEqual(store.remediationPreviewDraftsResult?.fallbackReason, UIStrings.fixPreviewUnavailable, "Unknown method fallback should use the localized unavailable copy.")
        try expectFalse(store.isPreviewingRemediationDrafts, "Unavailable fix preview drafts should reset loading state.")
        try expectContains(fake.calls(), "remediation.previewDrafts", "Fallback should still prove the intended V2.57 method was attempted.")
    }

    private func remediationImpactPreviewUsesReadOnlyServiceContract() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "prompt-ready")

        let store = SkillStore(service: ServiceClient())
        store.selectedSkillID = "beta"
        store.routingConfidenceText = "Prepare local release audit work."
        await store.reload()
        let snapshotCallsBeforePreview = countOccurrences("snapshot.", in: fake.calls())
        await store.previewRemediationImpact()

        let result = store.remediationImpactPreviewResult
        try expectEqual(result?.generatedBy, "local-v2.58", "Impact preview should expose generator metadata.")
        try expectEqual(result?.summary.totalCount, 6, "Impact preview should expose total impact count.")
        try expectEqual(result?.summary.taskImpactCount, 1, "Impact preview should expose task impact count.")
        try expectEqual(result?.impactRows.first?.title, "Overall readiness improves", "Impact preview should expose general impact rows.")
        try expectEqual(result?.taskImpactRows.first?.delta, "+12 readiness", "Impact preview should expose task deltas.")
        try expectEqual(result?.agentImpactRows.first?.agent, "claude-code", "Impact preview should expose agent rows.")
        try expectEqual(result?.skillImpactRows.first?.skill?.skillName, "Beta", "Impact preview should expose affected skill evidence.")
        try expectEqual(result?.riskDeltaRows.first?.title, "Network declaration risk drops", "Impact preview should expose risk deltas.")
        try expectEqual(result?.snapshotRollbackRows.first?.title, "No snapshot is created", "Impact preview should expose snapshot/rollback plan rows.")
        try expectEqual(result?.gapNotes.first, "Codex still lacks project-scoped coverage.", "Impact preview should expose gap notes.")
        try expectEqual(result?.blockerNotes.first, "No apply/write path is exposed.", "Impact preview should expose blocker notes.")
        try expectEqual(result?.evidenceReferences.first?.title, "Impact preview", "Impact preview should expose evidence references.")
        try expectEqual(result?.promptRequest?.requestKind, "remediation_preview_impact", "Impact preview prompt metadata should use V2.58 request kind.")
        try expectFalse(result?.safetyFlags.providerRequestSent ?? true, "Impact preview must not send provider requests.")
        try expectFalse(result?.safetyFlags.writeBackAllowed ?? true, "Impact preview must not allow write-back.")
        try expectFalse(result?.safetyFlags.writeActionsAvailable ?? true, "Impact preview must not expose write actions.")
        try expectFalse(result?.safetyFlags.scriptExecutionAllowed ?? true, "Impact preview must not allow script execution.")
        try expectFalse(result?.safetyFlags.executionActionsAvailable ?? true, "Impact preview must not expose execution actions.")
        try expectFalse(result?.safetyFlags.configMutationAllowed ?? true, "Impact preview must not mutate config.")
        try expectFalse(result?.safetyFlags.snapshotCreated ?? true, "Impact preview must not create snapshots.")
        try expectFalse(result?.safetyFlags.triageMutationAllowed ?? true, "Impact preview must not mutate triage.")
        try expectFalse(result?.safetyFlags.credentialAccessed ?? true, "Impact preview must not access credentials.")
        try expectFalse(result?.safetyFlags.rawPromptPersisted ?? true, "Impact preview must not persist raw prompts.")
        try expectFalse(result?.safetyFlags.rawResponsePersisted ?? true, "Impact preview must not persist raw responses.")
        try expectFalse(result?.safetyFlags.rawTracePersisted ?? true, "Impact preview must not persist raw traces.")
        try expectFalse(result?.safetyFlags.cloudSyncEnabled ?? true, "Impact preview must not sync cloud data.")
        try expectFalse(result?.safetyFlags.telemetryEnabled ?? true, "Impact preview must not emit telemetry.")
        try expectFalse(store.isPreviewingRemediationImpact, "Impact preview should reset loading state.")

        let calls = fake.calls()
        try expectContains(calls, "remediation.previewImpact", "Impact preview UI should call the V2.58 impact method.")
        try expectContains(calls, "\"task\":\"Prepare local release audit work.\"", "Impact preview should pass current task context when present.")
        try expectContains(calls, "\"agent\":\"claude-code\"", "Impact preview should pass the current agent filter.")
        try expectContains(calls, "\"selected_skill_id\":\"beta\"", "Impact preview should pass selected skill context.")
        try expectContains(calls, "\"selected_skill_name\":\"Beta\"", "Impact preview should pass selected skill name.")
        try expectContains(calls, "\"action\":\"review\"", "Impact preview should default to review action.")
        try expectContains(calls, "\"limit\":20", "Impact preview should pass the impact limit.")
        try expectContains(calls, "\"include_task_impacts\":true", "Impact preview should include task impact rows.")
        try expectContains(calls, "\"include_agent_impacts\":true", "Impact preview should include agent impact rows.")
        try expectContains(calls, "\"include_skill_impacts\":true", "Impact preview should include skill impact rows.")
        try expectContains(calls, "\"include_risk_deltas\":true", "Impact preview should include risk deltas.")
        try expectContains(calls, "\"include_snapshot_rollback\":true", "Impact preview should include snapshot/rollback plan rows.")
        try expectContains(calls, "\"include_blocked\":true", "Impact preview should keep blockers visible.")
        try expectFalse(calls.contains("llm.previewPrompt"), "Impact preview must not prepare provider prompts.")
        try expectFalse(calls.contains("llm.confirmPromptAndSend"), "Impact preview must not send to provider.")
        try expectFalse(calls.contains("config.toggleSkill"), "Impact preview must not call config write paths.")
        try expectFalse(calls.contains("script.execute"), "Impact preview must not call execution paths.")
        try expectEqual(countOccurrences("snapshot.", in: calls), snapshotCallsBeforePreview, "Impact preview must not call snapshot paths.")
        try expectFalse(calls.contains("credential"), "Impact preview must not call credential paths.")
    }

    private func remediationImpactPreviewFallsBackWhenMethodUnavailable() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "normal")

        let store = SkillStore(service: ServiceClient())
        store.selectedSkillID = "beta"
        await store.reload()
        await store.previewRemediationImpact()

        try expectEqual(store.remediationImpactPreviewResult?.isUnavailable, true, "Impact preview should expose unavailable fallback for older services.")
        try expectEqual(store.remediationImpactPreviewResult?.fallbackReason, UIStrings.impactPreviewUnavailable, "Unknown method fallback should use the localized unavailable copy.")
        try expectFalse(store.isPreviewingRemediationImpact, "Unavailable impact preview should reset loading state.")
        try expectContains(fake.calls(), "remediation.previewImpact", "Fallback should still prove the intended V2.58 method was attempted.")
    }

    private func remediationBatchReviewUsesReadOnlyServiceContract() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "prompt-ready")

        let store = SkillStore(service: ServiceClient())
        store.selectedSkillID = "beta"
        store.routingConfidenceText = "Prepare local release audit work."
        await store.reload()
        let snapshotCallsBeforeReview = countOccurrences("snapshot.", in: fake.calls())
        await store.reviewRemediationBatch(
            options: RemediationBatchReviewOptions(
                includeTask: true,
                includeRisk: true,
                includeRule: true,
                includeAgent: true,
                includeWorkspace: true,
                includeBlocked: true
            )
        )

        let result = store.remediationBatchReviewResult
        try expectEqual(result?.generatedBy, "local-v2.59", "Batch review should expose generator metadata.")
        try expectEqual(result?.summary.totalCount, 3, "Batch review should expose total review item count.")
        try expectEqual(result?.summary.groupCount, 2, "Batch review should expose group count.")
        try expectEqual(result?.groups.first?.title, "Risk and rule review", "Batch review should expose review groups.")
        try expectEqual(result?.groups.first?.items.first?.ruleID, "permissions.network-declared", "Batch review should expose nested rule review items.")
        try expectEqual(result?.groups.first?.items.first?.skill?.skillName, "Beta", "Batch review should expose affected skill evidence.")
        try expectEqual(result?.items.first?.reviewArea, "Workspace Readiness", "Batch review should expose safe review area labels.")
        try expectEqual(result?.safeNextStepLabels.first, "Open Remediation Planner", "Batch review should expose top-level safe next steps.")
        try expectEqual(result?.gapNotes.first, "Codex lacks project-scoped release audit coverage.", "Batch review should expose gap notes.")
        try expectEqual(result?.blockerNotes.first, "No batch apply path is available from review.", "Batch review should expose blocker notes.")
        try expectEqual(result?.evidenceReferences.first?.title, "Batch review", "Batch review should expose evidence references.")
        try expectEqual(result?.promptRequest?.requestKind, "remediation_batch_review", "Batch review prompt metadata should use V2.59 request kind.")
        try expectFalse(result?.safetyFlags.providerRequestSent ?? true, "Batch review must not send provider requests.")
        try expectFalse(result?.safetyFlags.writeBackAllowed ?? true, "Batch review must not allow write-back.")
        try expectFalse(result?.safetyFlags.writeActionsAvailable ?? true, "Batch review must not expose write actions.")
        try expectFalse(result?.safetyFlags.scriptExecutionAllowed ?? true, "Batch review must not allow script execution.")
        try expectFalse(result?.safetyFlags.executionActionsAvailable ?? true, "Batch review must not expose execution actions.")
        try expectFalse(result?.safetyFlags.configMutationAllowed ?? true, "Batch review must not mutate config.")
        try expectFalse(result?.safetyFlags.snapshotCreated ?? true, "Batch review must not create snapshots.")
        try expectFalse(result?.safetyFlags.triageMutationAllowed ?? true, "Batch review must not mutate triage.")
        try expectFalse(result?.safetyFlags.credentialAccessed ?? true, "Batch review must not access credentials.")
        try expectFalse(result?.safetyFlags.rawPromptPersisted ?? true, "Batch review must not persist raw prompts.")
        try expectFalse(result?.safetyFlags.rawResponsePersisted ?? true, "Batch review must not persist raw responses.")
        try expectFalse(result?.safetyFlags.rawTracePersisted ?? true, "Batch review must not persist raw traces.")
        try expectFalse(result?.safetyFlags.cloudSyncEnabled ?? true, "Batch review must not sync cloud data.")
        try expectFalse(result?.safetyFlags.telemetryEnabled ?? true, "Batch review must not emit telemetry.")
        try expectFalse(store.isReviewingRemediationBatch, "Batch review should reset loading state.")

        let calls = fake.calls()
        try expectContains(calls, "remediation.batchReview", "Batch review UI should call the V2.59 batch review method.")
        try expectContains(calls, "\"task\":\"Prepare local release audit work.\"", "Batch review should pass current task context when present.")
        try expectContains(calls, "\"agent\":\"claude-code\"", "Batch review should pass the current agent filter.")
        try expectContains(calls, "\"selected_skill_id\":\"beta\"", "Batch review should pass selected skill context.")
        try expectContains(calls, "\"selected_skill_name\":\"Beta\"", "Batch review should pass selected skill name.")
        try expectContains(calls, "\"limit\":30", "Batch review should pass the review limit.")
        try expectContains(calls, "\"review_dimensions\":[\"task\",\"risk\",\"rule\",\"agent\",\"workspace\"]", "Batch review should pass selected review dimensions.")
        try expectContains(calls, "\"include_task\":true", "Batch review should include task rows.")
        try expectContains(calls, "\"include_risk\":true", "Batch review should include risk rows.")
        try expectContains(calls, "\"include_rule\":true", "Batch review should include rule rows.")
        try expectContains(calls, "\"include_agent\":true", "Batch review should include agent rows.")
        try expectContains(calls, "\"include_workspace\":true", "Batch review should include workspace rows.")
        try expectContains(calls, "\"include_blocked\":true", "Batch review should keep blockers visible.")
        try expectFalse(calls.contains("llm.previewPrompt"), "Batch review must not prepare provider prompts.")
        try expectFalse(calls.contains("llm.confirmPromptAndSend"), "Batch review must not send to provider.")
        try expectFalse(calls.contains("config.toggleSkill"), "Batch review must not call config write paths.")
        try expectFalse(calls.contains("script.execute"), "Batch review must not call execution paths.")
        try expectEqual(countOccurrences("snapshot.", in: calls), snapshotCallsBeforeReview, "Batch review must not call snapshot paths.")
        try expectFalse(calls.contains("credential"), "Batch review must not call credential paths.")
    }

    private func remediationBatchReviewFallsBackWhenMethodUnavailable() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "normal")

        let store = SkillStore(service: ServiceClient())
        store.selectedSkillID = "beta"
        await store.reload()
        await store.reviewRemediationBatch()

        try expectEqual(store.remediationBatchReviewResult?.isUnavailable, true, "Batch review should expose unavailable fallback for older services.")
        try expectEqual(store.remediationBatchReviewResult?.fallbackReason, UIStrings.remediationBatchReviewUnavailable, "Unknown method fallback should use the localized unavailable copy.")
        try expectFalse(store.isReviewingRemediationBatch, "Unavailable batch review should reset loading state.")
        try expectContains(fake.calls(), "remediation.batchReview", "Fallback should still prove the intended V2.59 method was attempted.")
    }

    private func remediationHistoryUsesLocalServiceContract() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "prompt-ready")

        let store = SkillStore(service: ServiceClient())
        store.selectedSkillID = "beta"
        store.routingConfidenceText = "Prepare local release audit work."
        await store.reload()
        await store.reviewRemediationBatch()
        let snapshotCallsBeforeHistory = countOccurrences("snapshot.", in: fake.calls())
        await store.loadRemediationHistory()
        await store.recordRemediationHistory()

        let history = store.remediationHistoryResult
        try expectEqual(history?.generatedBy, "local-v2.60", "Remediation history should expose generator metadata.")
        try expectEqual(history?.summary.totalCount, 2, "Remediation history should expose total record count.")
        try expectEqual(history?.summary.recurrenceCount, 1, "Remediation history should expose recurrence count.")
        try expectEqual(history?.summary.reopenedCount, 1, "Remediation history should expose reopened count.")
        try expectEqual(history?.summary.readinessImprovementCount, 1, "Remediation history should expose readiness improvement count.")
        try expectEqual(history?.records.first?.title, "Network permission reviewed", "Remediation history should expose record rows.")
        try expectEqual(history?.records.first?.skill?.skillName, "Beta", "Remediation history should expose affected skill evidence.")
        try expectEqual(history?.records.first?.sourceMethod, "remediation.previewDrafts", "Remediation history should expose source method context.")
        try expectEqual(history?.evidenceReferences.first?.title, "History", "Remediation history should expose evidence references.")
        try expectEqual(history?.promptRequest?.requestKind, "remediation_history", "Remediation history prompt metadata should use V2.60 request kind.")
        try expectFalse(history?.safetyFlags.providerRequestSent ?? true, "Remediation history list must not send provider requests.")
        try expectFalse(history?.safetyFlags.writeBackAllowed ?? true, "Remediation history list must not allow write-back.")
        try expectFalse(history?.safetyFlags.writeActionsAvailable ?? true, "Remediation history list must not expose write actions.")
        try expectFalse(history?.safetyFlags.scriptExecutionAllowed ?? true, "Remediation history list must not allow script execution.")
        try expectFalse(history?.safetyFlags.executionActionsAvailable ?? true, "Remediation history list must not expose execution actions.")
        try expectFalse(history?.safetyFlags.configMutationAllowed ?? true, "Remediation history list must not mutate config.")
        try expectFalse(history?.safetyFlags.snapshotCreated ?? true, "Remediation history list must not create snapshots.")
        try expectFalse(history?.safetyFlags.triageMutationAllowed ?? true, "Remediation history list must not mutate triage.")
        try expectFalse(history?.safetyFlags.credentialAccessed ?? true, "Remediation history list must not access credentials.")
        try expectFalse(history?.safetyFlags.rawPromptPersisted ?? true, "Remediation history list must not persist raw prompts.")
        try expectFalse(history?.safetyFlags.rawResponsePersisted ?? true, "Remediation history list must not persist raw responses.")
        try expectFalse(history?.safetyFlags.rawTracePersisted ?? true, "Remediation history list must not persist raw traces.")
        try expectFalse(history?.safetyFlags.cloudSyncEnabled ?? true, "Remediation history list must not sync cloud data.")
        try expectFalse(history?.safetyFlags.telemetryEnabled ?? true, "Remediation history list must not emit telemetry.")

        let record = store.remediationHistoryRecordResult
        try expectEqual(record?.recorded, true, "Record history should report local audit persistence.")
        try expectEqual(record?.record?.sourceMethod, "analysis.remediationHistory.ui", "Record history should identify the native audit source.")
        try expectFalse(record?.safetyFlags.providerRequestSent ?? true, "Record history must not send provider requests.")
        try expectFalse(record?.safetyFlags.writeActionsAvailable ?? true, "Record history must not expose write actions.")
        try expectFalse(record?.safetyFlags.snapshotCreated ?? true, "Record history must not create snapshots.")
        try expectFalse(record?.safetyFlags.triageMutationAllowed ?? true, "Record history must not mutate triage.")
        try expectFalse(store.isLoadingRemediationHistory, "Remediation history should reset loading state.")
        try expectFalse(store.isRecordingRemediationHistory, "Record history should reset loading state.")

        let calls = fake.calls()
        try expectContains(calls, "remediation.listHistory", "History UI should call the V2.60 list method.")
        try expectContains(calls, "remediation.recordHistory", "History UI should call the V2.60 record method.")
        try expectContains(calls, "\"task\":\"Prepare local release audit work.\"", "History should pass current task context when present.")
        try expectContains(calls, "\"agent\":\"claude-code\"", "History should pass the current agent filter.")
        try expectContains(calls, "\"selected_skill_id\":\"beta\"", "History should pass selected skill context.")
        try expectContains(calls, "\"limit\":30", "History list should pass the history limit.")
        try expectContains(calls, "\"decision\":\"reviewed\"", "Record history should store an audit decision label.")
        try expectContains(calls, "\"status\":\"recorded\"", "Record history should store an audit status label.")
        try expectContains(calls, "\"source_method\":\"analysis.remediationHistory.ui\"", "Record history should identify the native UI source.")
        try expectFalse(calls.contains("llm.previewPrompt"), "Remediation history must not prepare provider prompts.")
        try expectFalse(calls.contains("llm.confirmPromptAndSend"), "Remediation history must not send to provider.")
        try expectFalse(calls.contains("config.toggleSkill"), "Remediation history must not call config write paths.")
        try expectFalse(calls.contains("script.execute"), "Remediation history must not call execution paths.")
        try expectEqual(countOccurrences("snapshot.", in: calls), snapshotCallsBeforeHistory, "Remediation history must not call snapshot paths.")
        try expectFalse(calls.contains("credential"), "Remediation history must not call credential paths.")
    }

    private func remediationHistoryFallsBackWhenMethodUnavailable() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "normal")

        let store = SkillStore(service: ServiceClient())
        store.selectedSkillID = "beta"
        await store.reload()
        await store.loadRemediationHistory()
        await store.recordRemediationHistory()

        try expectEqual(store.remediationHistoryResult?.isUnavailable, true, "Remediation history should expose unavailable fallback for older services.")
        try expectEqual(store.remediationHistoryResult?.fallbackReason, UIStrings.remediationHistoryUnavailable, "Unknown list method fallback should use localized unavailable copy.")
        try expectEqual(store.remediationHistoryRecordResult?.isUnavailable, true, "Record history should expose unavailable fallback for older services.")
        try expectEqual(store.remediationHistoryRecordResult?.fallbackReason, UIStrings.remediationHistoryRecordUnavailable, "Unknown record method fallback should use localized unavailable copy.")
        try expectFalse(store.isLoadingRemediationHistory, "Unavailable history list should reset loading state.")
        try expectFalse(store.isRecordingRemediationHistory, "Unavailable record history should reset loading state.")
        try expectContains(fake.calls(), "remediation.listHistory", "Fallback should still prove the intended V2.60 list method was attempted.")
        try expectContains(fake.calls(), "remediation.recordHistory", "Fallback should still prove the intended V2.60 record method was attempted.")
    }

    private func guidedCleanupFlowUsesLocalServiceContract() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "prompt-ready")

        let store = SkillStore(service: ServiceClient())
        store.selectedSkillID = "beta"
        store.routingConfidenceText = "Prepare local release audit work."
        await store.reload()
        let snapshotCallsBeforeGuided = countOccurrences("snapshot.", in: fake.calls())
        await store.planGuidedCleanupFlow()
        await store.recordGuidedCleanupStep()

        let result = store.guidedCleanupFlowResult
        try expectEqual(result?.generatedBy, "local-v2.67", "Guided cleanup should expose generator metadata.")
        try expectEqual(result?.summary.stepCount, 2, "Guided cleanup should expose step count.")
        try expectEqual(result?.summary.issueGroupCount, 1, "Guided cleanup should expose issue group count.")
        try expectEqual(result?.summary.safeActionCount, 2, "Guided cleanup should expose safe action count.")
        try expectEqual(result?.flowSteps.first?.id, "step-review-permission", "Guided cleanup should expose flow steps.")
        try expectEqual(result?.flowSteps.first?.recommended, true, "Guided cleanup should expose recommended steps.")
        try expectEqual(result?.flowSteps.first?.skill?.skillName, "Beta", "Guided cleanup should expose affected skill evidence.")
        try expectEqual(result?.issueGroups.first?.title, "Permission clarity", "Guided cleanup should expose issue groups.")
        try expectEqual(result?.safeNextActions.first?.canApplyFix, false, "Guided cleanup safe actions should stay non-applying.")
        try expectEqual(result?.recordedSteps.first?.sourceMethod, "cleanup.recordGuidedStep", "Guided cleanup should expose existing recorded metadata.")
        try expectEqual(result?.evidenceReferences.first?.source, "cleanup.planGuidedFlow", "Guided cleanup should expose evidence references.")
        try expectEqual(result?.promptRequest?.requestKind, "guided_cleanup_flow", "Guided cleanup should expose prompt metadata.")
        try expectFalse(result?.safetyFlags.providerRequestSent ?? true, "Guided cleanup planning must not send provider requests.")
        try expectFalse(result?.safetyFlags.writeBackAllowed ?? true, "Guided cleanup planning must not allow write-back.")
        try expectFalse(result?.safetyFlags.writeActionsAvailable ?? true, "Guided cleanup planning must not expose write actions.")
        try expectFalse(result?.safetyFlags.scriptExecutionAllowed ?? true, "Guided cleanup planning must not allow script execution.")
        try expectFalse(result?.safetyFlags.executionActionsAvailable ?? true, "Guided cleanup planning must not expose execution actions.")
        try expectFalse(result?.safetyFlags.configMutationAllowed ?? true, "Guided cleanup planning must not mutate config.")
        try expectFalse(result?.safetyFlags.snapshotCreated ?? true, "Guided cleanup planning must not create snapshots.")
        try expectFalse(result?.safetyFlags.triageMutationAllowed ?? true, "Guided cleanup planning must not mutate triage.")
        try expectFalse(result?.safetyFlags.credentialAccessed ?? true, "Guided cleanup planning must not access credentials.")
        try expectFalse(result?.safetyFlags.rawPromptPersisted ?? true, "Guided cleanup planning must not persist raw prompts.")
        try expectFalse(result?.safetyFlags.rawResponsePersisted ?? true, "Guided cleanup planning must not persist raw responses.")
        try expectFalse(result?.safetyFlags.rawTracePersisted ?? true, "Guided cleanup planning must not persist raw traces.")
        try expectFalse(result?.safetyFlags.cloudSyncEnabled ?? true, "Guided cleanup planning must not sync cloud data.")
        try expectFalse(result?.safetyFlags.telemetryEnabled ?? true, "Guided cleanup planning must not emit telemetry.")

        let record = store.guidedCleanupRecordResult
        try expectEqual(record?.recorded, true, "Guided cleanup record should report local metadata persistence.")
        try expectEqual(record?.record?.sourceMethod, "analysis.guidedCleanupFlow.ui", "Guided cleanup record should identify the native UI source.")
        try expectEqual(record?.record?.appLocalOnly, true, "Guided cleanup record should remain app-local.")
        try expectEqual(record?.metadataRedacted, true, "Guided cleanup record should be marked redacted.")
        try expectFalse(record?.safetyFlags.providerRequestSent ?? true, "Guided cleanup record must not send provider requests.")
        try expectFalse(record?.safetyFlags.writeActionsAvailable ?? true, "Guided cleanup record must not expose write actions.")
        try expectFalse(record?.safetyFlags.snapshotCreated ?? true, "Guided cleanup record must not create snapshots.")
        try expectFalse(record?.safetyFlags.triageMutationAllowed ?? true, "Guided cleanup record must not mutate triage.")
        try expectFalse(store.isPlanningGuidedCleanupFlow, "Guided cleanup planning should reset loading state.")
        try expectFalse(store.isRecordingGuidedCleanupStep, "Guided cleanup recording should reset loading state.")

        let calls = fake.calls()
        try expectContains(calls, "cleanup.planGuidedFlow", "Guided cleanup UI should call the V2.67 plan method.")
        try expectContains(calls, "cleanup.recordGuidedStep", "Guided cleanup UI should call the V2.67 record method.")
        try expectContains(calls, "\"task\":\"Prepare local release audit work.\"", "Guided cleanup should pass current task context when present.")
        try expectContains(calls, "\"agent\":\"claude-code\"", "Guided cleanup should pass the current agent filter.")
        try expectContains(calls, "\"selected_skill_id\":\"beta\"", "Guided cleanup should pass selected skill context.")
        try expectContains(calls, "\"selected_skill_name\":\"Beta\"", "Guided cleanup should pass selected skill name.")
        try expectContains(calls, "\"limit\":12", "Guided cleanup should pass the guided flow limit.")
        try expectContains(calls, "\"include_issue_groups\":true", "Guided cleanup should request issue groups.")
        try expectContains(calls, "\"include_safe_next_actions\":true", "Guided cleanup should request safe next actions.")
        try expectContains(calls, "\"include_recorded_steps\":true", "Guided cleanup should request app-local recorded steps.")
        try expectContains(calls, "\"step_id\":\"step-review-permission\"", "Guided cleanup record should pass selected/recommended step id.")
        try expectContains(calls, "\"source_method\":\"analysis.guidedCleanupFlow.ui\"", "Guided cleanup record should identify the native source.")
        try expectFalse(calls.contains("llm.previewPrompt"), "Guided cleanup must not prepare provider prompts.")
        try expectFalse(calls.contains("llm.confirmPromptAndSend"), "Guided cleanup must not send to provider.")
        try expectFalse(calls.contains("config.toggleSkill"), "Guided cleanup must not call config write paths.")
        try expectFalse(calls.contains("batch.applySkillToggles"), "Guided cleanup must not call batch apply.")
        try expectFalse(calls.contains("script.execute"), "Guided cleanup must not call execution paths.")
        try expectEqual(countOccurrences("snapshot.", in: calls), snapshotCallsBeforeGuided, "Guided cleanup must not call snapshot paths.")
        try expectFalse(calls.contains("credential"), "Guided cleanup must not call credential paths.")
    }

    private func guidedCleanupFlowFallsBackWhenMethodUnavailable() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "normal")

        let store = SkillStore(service: ServiceClient())
        store.selectedSkillID = "beta"
        await store.reload()
        await store.planGuidedCleanupFlow()
        await store.recordGuidedCleanupStep()

        try expectEqual(store.guidedCleanupFlowResult?.isUnavailable, true, "Guided cleanup should expose unavailable fallback for older services.")
        try expectEqual(store.guidedCleanupFlowResult?.fallbackReason, UIStrings.guidedCleanupFlowUnavailable, "Unknown plan method fallback should use localized unavailable copy.")
        try expectEqual(store.guidedCleanupRecordResult?.isUnavailable, true, "Guided cleanup record should expose unavailable fallback when no step exists.")
        try expectEqual(store.guidedCleanupRecordResult?.fallbackReason, UIStrings.guidedCleanupFlowNoSteps, "Missing step fallback should use no-steps copy before attempting record.")
        try expectFalse(store.isPlanningGuidedCleanupFlow, "Unavailable guided cleanup planning should reset loading state.")
        try expectFalse(store.isRecordingGuidedCleanupStep, "Unavailable guided cleanup recording should reset loading state.")
        try expectContains(fake.calls(), "cleanup.planGuidedFlow", "Fallback should still prove the intended V2.67 plan method was attempted.")
        try expectFalse(fake.calls().contains("cleanup.recordGuidedStep"), "Record fallback without a loaded step must not call service record.")
        try expectFalse(fake.calls().contains("llm.confirmPromptAndSend"), "Unavailable guided cleanup must not send to provider.")
        try expectFalse(fake.calls().contains("config.toggleSkill"), "Unavailable guided cleanup must not call config write paths.")
        try expectFalse(fake.calls().contains("script.execute"), "Unavailable guided cleanup must not call execution paths.")
    }

    private func crossAgentReadinessUsesReadOnlyServiceContract() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "prompt-ready")

        let store = SkillStore(service: ServiceClient())
        store.selectedSkillID = "beta"
        store.routingConfidenceText = "Route a local audit release note task."
        await store.reload()
        let snapshotCallsBeforeCompare = countOccurrences("snapshot.", in: fake.calls())
        await store.compareCrossAgentReadiness()

        let result = store.crossAgentReadinessResult
        try expectEqual(result?.generatedBy, "local-v2.50", "Cross-agent readiness should expose generator metadata.")
        try expectEqual(result?.recommendedAgent?.agent, "claude-code", "Cross-agent readiness should expose recommended agent.")
        try expectEqual(result?.recommendedAgent?.comparisonScore, 93, "Cross-agent readiness should expose recommendation comparison score.")
        try expectEqual(result?.recommendedAgent?.skill?.name, "Beta", "Cross-agent readiness should expose recommended skill.")
        try expectEqual(result?.agentRows.map(\.agent), ["claude-code", "codex"], "Cross-agent readiness should expose per-agent rows.")
        try expectEqual(result?.agentRows.first?.rank, 1, "Cross-agent readiness should expose agent rank.")
        try expectEqual(result?.agentRows.first?.comparisonScore, 93, "Cross-agent readiness should expose comparison score.")
        try expectEqual(result?.agentRows.first?.readinessScore, 88, "Cross-agent readiness should expose readiness score.")
        try expectEqual(result?.agentRows.first?.routingScore, 91, "Cross-agent readiness should expose routing score.")
        try expectEqual(result?.agentRows.first?.bestCandidateSkill?.definitionID, "def.beta", "Cross-agent readiness should expose best candidate definition id.")
        try expectEqual(result?.agentRows.first?.enabledState, "Enabled", "Cross-agent readiness should expose nested enabled state.")
        try expectEqual(result?.agentRows.first?.scopeState, "agent-project", "Cross-agent readiness should expose nested scope state.")
        try expectEqual(result?.agentRows.first?.riskState, "low", "Cross-agent readiness should expose nested risk state.")
        try expectEqual(result?.agentRows.first?.accuracyContext, "7 of 8 known traces hit expected route.", "Cross-agent readiness should expose routing accuracy context.")
        try expectEqual(result?.agentRows.first?.benchmarkContext, "Benchmark expected route is covered.", "Cross-agent readiness should expose benchmark context.")
        try expectEqual(result?.gapIssueRows.first?.title, "Missing Codex benchmark", "Cross-agent readiness should expose gap rows.")
        try expectEqual(result?.evidenceReferences.first?.title, "Benchmark", "Cross-agent readiness should expose evidence references.")
        try expectFalse(result?.safetyFlags.providerRequestSent ?? true, "Cross-agent readiness must not send provider requests.")
        try expectFalse(result?.safetyFlags.writeBackAllowed ?? true, "Cross-agent readiness must not allow write-back.")
        try expectFalse(result?.safetyFlags.writeActionsAvailable ?? true, "Cross-agent readiness must not expose write actions.")
        try expectFalse(result?.safetyFlags.scriptExecutionAllowed ?? true, "Cross-agent readiness must not allow script execution.")
        try expectFalse(result?.safetyFlags.executionActionsAvailable ?? true, "Cross-agent readiness must not expose execution actions.")
        try expectFalse(result?.safetyFlags.configMutationAllowed ?? true, "Cross-agent readiness must not mutate config.")
        try expectFalse(result?.safetyFlags.snapshotCreated ?? true, "Cross-agent readiness must not create snapshots.")
        try expectFalse(result?.safetyFlags.triageMutationAllowed ?? true, "Cross-agent readiness must not mutate triage.")
        try expectFalse(result?.safetyFlags.credentialAccessed ?? true, "Cross-agent readiness must not access credentials.")
        try expectFalse(result?.safetyFlags.rawPromptPersisted ?? true, "Cross-agent readiness must not persist raw prompts.")
        try expectFalse(result?.safetyFlags.rawResponsePersisted ?? true, "Cross-agent readiness must not persist raw responses.")
        try expectFalse(result?.safetyFlags.rawTracePersisted ?? true, "Cross-agent readiness must not persist raw traces.")
        try expectFalse(result?.safetyFlags.cloudSyncEnabled ?? true, "Cross-agent readiness must not sync cloud data.")
        try expectFalse(result?.safetyFlags.telemetryEnabled ?? true, "Cross-agent readiness must not emit telemetry.")
        try expectFalse(store.isComparingCrossAgentReadiness, "Cross-agent readiness compare should reset loading state.")

        let calls = fake.calls()
        try expectContains(calls, "task.compareAgentReadiness", "Cross-agent readiness should call the V2.50 compare method.")
        try expectContains(calls, "\"task\":\"Route a local audit release note task.\"", "Cross-agent readiness should send canonical task text.")
        try expectContains(calls, "\"limit_per_agent\":3", "Cross-agent readiness should send the per-agent limit.")
        try expectContains(calls, "\"include_routing_accuracy\":true", "Cross-agent readiness should request accuracy context explicitly.")
        try expectContains(calls, "\"include_benchmarks\":true", "Cross-agent readiness should request benchmark context explicitly.")
        try expectFalse(calls.contains("\"task_text\":\"Route a local audit release note task.\""), "Local compare must not send duplicate task_text aliases.")
        try expectFalse(calls.contains("\"user_intent\":\"Route a local audit release note task.\""), "Local compare must not send duplicate user_intent aliases.")
        try expectFalse(calls.contains("llm.previewPrompt"), "Cross-agent readiness must not prepare provider prompts.")
        try expectFalse(calls.contains("llm.confirmPromptAndSend"), "Cross-agent readiness must not send to provider.")
        try expectFalse(calls.contains("config.toggleSkill"), "Cross-agent readiness must not call config write paths.")
        try expectFalse(calls.contains("script.execute"), "Cross-agent readiness must not call execution paths.")
        try expectEqual(countOccurrences("snapshot.", in: calls), snapshotCallsBeforeCompare, "Cross-agent readiness must not call snapshot paths.")
        try expectFalse(calls.contains("credential"), "Cross-agent readiness must not call credential paths.")
    }

    private func routingConfidenceClearsStaleSelection() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "prompt-ready")

        let store = SkillStore(service: ServiceClient())
        store.selectedSkillID = "beta"
        store.routingConfidenceText = "Route a local audit release note task."
        await store.reload()
        await store.rankSelectedSkillRoutes()

        guard let beta = store.selectedSkill else {
            throw NativeModelTestFailure(description: "Fixture should select beta before stale routing cleanup.")
        }
        guard store.routingConfidence(for: beta) != nil else {
            throw NativeModelTestFailure(description: "Routing result should exist for beta before selection changes.")
        }

        store.agentFilter = .codex
        try await waitUntil("Agent filter should move selection away from beta for route cleanup.") {
            store.selectedSkillID == "gamma"
        }

        guard let gamma = store.selectedSkill else {
            throw NativeModelTestFailure(description: "Fixture should select gamma after agent filter changes.")
        }
        try expectNil(store.routingConfidence(for: gamma), "Routing confidence prepared for beta must not be reused after selecting another agent skill.")
    }

    private func llmPreparePreviewIsScopedToSelectedSkillAndReadOnly() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "llm-ready")

        let store = SkillStore(service: ServiceClient())
        store.selectedSkillID = "beta"
        await store.reload()
        await store.prepareAnalyzeLLM()

        try expectEqual(store.llmPrepareResult(for: .analyze)?.action, .analyze, "Beta analyze preview should be available while beta is selected.")

        store.agentFilter = .codex
        try await waitUntil("Agent filter should move selection away from beta.") {
            store.selectedSkillID == "gamma"
        }

        try expectNil(store.llmPrepareResult(for: .analyze), "LLM preview prepared for beta must not be reused after selecting another agent skill.")
        await store.prepareAnalyzeLLM()

        let calls = fake.calls()
        try expectContains(calls, "\"instance_id\":\"beta\"", "LLM prepare should send the beta instance context.")
        try expectContains(calls, "\"agent\":\"claude-code\"", "LLM prepare should send beta's agent context.")
        try expectContains(calls, "\"instance_id\":\"gamma\"", "LLM prepare should send the gamma instance context after selection changes.")
        try expectContains(calls, "\"agent\":\"codex\"", "LLM prepare should send gamma's agent context.")
        try expectFalse(calls.contains("llm.complete"), "LLM prepare must not call a provider completion method.")
        try expectFalse(calls.contains("config.toggleSkill"), "LLM analysis preview must not call write paths.")
        try expectFalse(calls.contains("script.execute"), "LLM analysis preview must not call execution paths.")
    }

    private func promptPreviewRequiresConfiguredProviderAndExplicitSend() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "prompt-ready")

        let store = SkillStore(service: ServiceClient())
        store.selectedSkillID = "beta"
        await store.reload()
        await store.prepareAnalyzeLLM()
        await store.previewPromptForSelectedLLMAction(.analyze)

        let preview = store.llmPromptPreview(for: .analyze)
        try expectEqual(preview?.previewID, "prompt-preview-beta", "Prompt preview should be stored for the selected skill/action.")
        try expectEqual(preview?.destinationHost, "llm.example.com", "Prompt preview should expose network destination.")
        try expectEqual(preview?.includedFields.map(\.name), ["skill.name", "findings.summary"], "Prompt preview should expose included fields.")
        try expectEqual(store.canSendLLMPrompt(for: .analyze), true, "Configured provider and current preview should allow explicit send.")

        await store.confirmPromptForSelectedLLMAction(.analyze)
        let sendResult = store.llmPromptSendResult(for: .analyze)
        try expectEqual(sendResult?.success, true, "Confirmed prompt should store provider result.")
        try expectEqual(sendResult?.outputText, "Read-only analysis for Beta.", "Provider output should be retained as copy-only text.")
        try expectFalse(sendResult?.writeBackAllowed ?? true, "Provider result must not enable write-back.")
        try expectFalse(sendResult?.scriptExecutionAllowed ?? true, "Provider result must not enable script execution.")

        let calls = fake.calls()
        try expectContains(calls, "llm.previewPrompt", "Prompt preview should use the V2.42 preview method.")
        try expectContains(calls, "\"preview_id\":\"prompt-preview-beta\"", "Confirm should send the preview id.")
        try expectContains(calls, "llm.confirmPromptAndSend", "Explicit send should use the V2.42 confirmation method.")
        try expectFalse(calls.contains("config.toggleSkill"), "Prompt confirmation must not call write paths.")
        try expectFalse(calls.contains("script.execute"), "Prompt confirmation must not call execution paths.")
    }

    private func previewScriptExecutionSafetyStoresBlockedPreviewWithoutExecute() async throws {
        let fake = try FakeServiceScript()
        defer { fake.cleanup() }
        fake.activate(scenario: "script-preview")

        let store = SkillStore(service: ServiceClient())
        store.selectedSkillID = "beta"
        await store.reload()
        guard let skill = store.selectedSkill else {
            throw NativeModelTestFailure(description: "Fixture should select beta for script preview.")
        }

        await store.previewScriptExecutionSafety(for: skill)

        let preview = store.scriptExecutionPreview(for: skill)
        try expectEqual(preview?.skillID, "beta", "Script preview should be stored by skill ID.")
        try expectEqual(preview?.commandPreview, ["bash", "scripts/setup.sh"], "Script preview should expose command preview.")
        try expectEqual(preview?.scope.cwd, "/tmp/project", "Script preview should expose CWD.")
        try expectEqual(preview?.scope.env["SKILLS_SAFE_MODE"], "1", "Script preview should expose env.")
        try expectEqual(preview?.scope.network, "none", "Script preview should expose network scope.")
        try expectEqual(preview?.scope.files, ["/tmp/project/scripts/setup.sh"], "Script preview should expose file scope.")
        try expectEqual(preview?.executionAllowed, false, "Script preview should keep execution blocked.")
        try expectEqual(preview?.confirmationRequired, true, "Script preview should require confirmation.")
        try expectEqual(preview?.auditStatus, .blocked, "Script preview should expose audit status.")
        try expectContains(fake.calls(), "script.previewExecution", "Script safety card should use preview preflight.")
        try expectFalse(fake.calls().contains("script.execute"), "Script safety card must not call an execution method.")
    }

    private func waitUntil(_ label: String, timeout: TimeInterval = 2, predicate: @escaping @MainActor () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !predicate() {
            if Date() > deadline {
                throw NativeModelTestFailure(description: label)
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    private func countOccurrences(_ needle: String, in haystack: String) -> Int {
        haystack.components(separatedBy: needle).count - 1
    }

    private func countMethodCalls(_ method: String, in calls: String) -> Int {
        countOccurrences("\"method\":\"\(method)\"", in: calls)
    }

    private func permissionMarker(_ detail: SkillDetailRecord?) -> String? {
        guard
            case .object(let permissions)? = detail?.permissions,
            case .string(let marker)? = permissions["marker"]
        else {
            return nil
        }
        return marker
    }
}

private final class FakeServiceScript {
    private let directory: URL
    let executableURL: URL
    private let callsURL: URL

    init() throws {
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("skills-copilot-fake-service-\(UUID().uuidString)", isDirectory: true)
        executableURL = directory.appendingPathComponent("fake-service.sh")
        callsURL = directory.appendingPathComponent("calls.log")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: callsURL.path, contents: nil)
        try script.write(to: executableURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: Int16(0o755))],
            ofItemAtPath: executableURL.path
        )
    }

    func activate(scenario: String) {
        setenv("SKILLS_COPILOT_SERVICE_PATH", executableURL.path, 1)
        setenv("SKILLS_COPILOT_FAKE_SERVICE_CALLS", callsURL.path, 1)
        setScenario(scenario)
    }

    func setScenario(_ scenario: String) {
        setenv("SKILLS_COPILOT_FAKE_SERVICE_SCENARIO", scenario, 1)
    }

    func cleanup() {
        unsetenv("SKILLS_COPILOT_SERVICE_PATH")
        unsetenv("SKILLS_COPILOT_FAKE_SERVICE_SCENARIO")
        unsetenv("SKILLS_COPILOT_FAKE_SERVICE_CALLS")
        try? FileManager.default.removeItem(at: directory)
    }

    func calls() -> String {
        (try? String(contentsOf: callsURL, encoding: .utf8)) ?? ""
    }

    private var script: String {
        """
        #!/bin/sh
        input=$(cat)
        scenario=${SKILLS_COPILOT_FAKE_SERVICE_SCENARIO:-normal}

        if [ -n "$SKILLS_COPILOT_FAKE_SERVICE_CALLS" ]; then
          printf '%s\\n' "$input" >> "$SKILLS_COPILOT_FAKE_SERVICE_CALLS"
        fi

        respond() {
          printf '%s' "$1"
          exit 0
        }

        service_error() {
          respond '{"id":"test","ok":false,"result":null,"error":{"code":"test.error","message":"boom"}}'
        }

        status_response() {
          respond '{"id":"test","ok":true,"result":{"protocol_version":1,"version":"test","app_data_dir":"/tmp/skills-copilot","catalog_path":"/tmp/skills-copilot/catalog.sqlite","user_home":"/tmp/home","supported_methods":["app.stateSnapshot","service.status","catalog.listSkills","catalog.scanAll","catalog.getSkill","catalog.listFindings","catalog.listConflicts","skill.listEvents","snapshot.list","snapshot.listAgentConfig","config.toggleSkill","batch.previewSkillToggles","batch.applySkillToggles","project.getContext","project.setContext","project.clearContext","project.validateContext"],"adapter_capabilities":'"$adapter_capabilities"'}}'
        }

        adapter_capabilities='[{"agent":"claude-code","display_name":"Claude Code","status":"verified","scan":{"supported":true,"status":"verified","reason":null},"project_scan":{"supported":true,"status":"verified","reason":null},"config_toggle":{"supported":true,"status":"verified","reason":null},"config_snapshot":{"supported":true,"status":"verified","reason":null},"install":{"supported":true,"status":"verified","reason":null},"writable":{"supported":true,"status":"verified","reason":null},"blockers":[]},{"agent":"codex","display_name":"Codex","status":"verified","scan":{"supported":true,"status":"verified","reason":null},"project_scan":{"supported":true,"status":"verified","reason":null},"config_toggle":{"supported":true,"status":"verified","reason":null},"config_snapshot":{"supported":true,"status":"verified","reason":null},"install":{"supported":false,"status":"planned","reason":"Install is not part of this slice."},"writable":{"supported":true,"status":"verified","reason":null},"blockers":[]},{"agent":"opencode","display_name":"opencode","status":"verified","scan":{"supported":true,"status":"verified","reason":null},"project_scan":{"supported":true,"status":"verified","reason":null},"config_toggle":{"supported":true,"status":"verified","reason":null},"config_snapshot":{"supported":true,"status":"verified","reason":null},"install":{"supported":true,"status":"verified","reason":null},"writable":{"supported":true,"status":"verified","reason":null},"blockers":[]},{"agent":"pi","display_name":"Pi","status":"read-only","scan":{"supported":true,"status":"verified","reason":null},"project_scan":{"supported":true,"status":"verified","reason":null},"config_toggle":{"supported":false,"status":"read-only","reason":"Pi writable support is blocked pending evidence."},"config_snapshot":{"supported":false,"status":"read-only","reason":"Pi is read-only."},"install":{"supported":false,"status":"read-only","reason":"Pi is read-only."},"writable":{"supported":false,"status":"read-only","reason":"Pi is read-only."},"blockers":["Pi writable support is blocked pending evidence."]},{"agent":"hermes","display_name":"Hermes","status":"read-only","scan":{"supported":true,"status":"verified","reason":null},"project_scan":{"supported":false,"status":"read-only","reason":"Hermes project skills are not confirmed."},"config_toggle":{"supported":false,"status":"read-only","reason":"Hermes is read-only."},"config_snapshot":{"supported":false,"status":"read-only","reason":"Hermes is read-only."},"install":{"supported":false,"status":"read-only","reason":"Hermes is read-only."},"writable":{"supported":false,"status":"read-only","reason":"Hermes is read-only."},"blockers":["Hermes is read-only."]},{"agent":"openclaw","display_name":"OpenClaw","status":"read-only","scan":{"supported":true,"status":"verified","reason":null},"project_scan":{"supported":true,"status":"verified","reason":null},"config_toggle":{"supported":false,"status":"read-only","reason":"OpenClaw is read-only."},"config_snapshot":{"supported":false,"status":"read-only","reason":"OpenClaw is read-only."},"install":{"supported":false,"status":"read-only","reason":"OpenClaw is read-only."},"writable":{"supported":false,"status":"read-only","reason":"OpenClaw is read-only."},"blockers":["OpenClaw is read-only."]}]'
        project_active='{"id":"project-1","name":"Fixture Project","root_path":"/tmp/project","current_cwd":"/tmp/project","last_used_at":"2026-06-08T00:00:00Z","is_active":true,"validation_error":null}'
        project_recent='[{"id":"project-1","name":"Fixture Project","root_path":"/tmp/project","current_cwd":"/tmp/project","last_used_at":"2026-06-08T00:00:00Z","is_active":true,"validation_error":null},{"id":"project-2","name":"Other Project","root_path":"/tmp/other","current_cwd":"/tmp/other","last_used_at":"2026-06-07T00:00:00Z","is_active":false,"validation_error":null}]'
        project_invalid='{"id":"project-missing","name":"Missing Project","root_path":"/tmp/missing","current_cwd":"/tmp/missing","last_used_at":"2026-06-08T00:00:00Z","is_active":true,"validation_error":"Project root does not exist."}'

        skills_normal='[{"id":"alpha","agent":"claude-code","scope":"agent-global","path":"/tmp/global/alpha/SKILL.md","display_path":"/tmp/global/alpha/SKILL.md","definition_id":"def.alpha","name":"Alpha","state":"loaded","enabled":true},{"id":"beta","agent":"claude-code","scope":"agent-project","path":"/tmp/project/beta/SKILL.md","display_path":"/tmp/project/beta/SKILL.md","definition_id":"def.beta","name":"Beta","state":"loaded","enabled":true},{"id":"gamma","agent":"codex","scope":"agent-global","path":"/tmp/codex/skills/gamma/SKILL.md","display_path":"~/.codex/skills/gamma/SKILL.md","definition_id":"codex:gamma","name":"Gamma","state":"loaded","enabled":true}]'
        skills_toggled='[{"id":"alpha","agent":"claude-code","scope":"agent-global","path":"/tmp/global/alpha/SKILL.md","display_path":"/tmp/global/alpha/SKILL.md","definition_id":"def.alpha","name":"Alpha","state":"loaded","enabled":true},{"id":"beta","agent":"claude-code","scope":"agent-project","path":"/tmp/project/beta/SKILL.md","display_path":"/tmp/project/beta/SKILL.md","definition_id":"def.beta","name":"Beta","state":"loaded","enabled":false},{"id":"gamma","agent":"codex","scope":"agent-global","path":"/tmp/codex/skills/gamma/SKILL.md","display_path":"~/.codex/skills/gamma/SKILL.md","definition_id":"codex:gamma","name":"Gamma","state":"loaded","enabled":true}]'
        skills_codex_toggled='[{"id":"alpha","agent":"claude-code","scope":"agent-global","path":"/tmp/global/alpha/SKILL.md","display_path":"/tmp/global/alpha/SKILL.md","definition_id":"def.alpha","name":"Alpha","state":"loaded","enabled":true},{"id":"beta","agent":"claude-code","scope":"agent-project","path":"/tmp/project/beta/SKILL.md","display_path":"/tmp/project/beta/SKILL.md","definition_id":"def.beta","name":"Beta","state":"loaded","enabled":true},{"id":"gamma","agent":"codex","scope":"agent-global","path":"/tmp/codex/skills/gamma/SKILL.md","display_path":"~/.codex/skills/gamma/SKILL.md","definition_id":"codex:gamma","name":"Gamma","state":"loaded","enabled":false}]'
        skills_opencode='[{"id":"omega","agent":"opencode","scope":"agent-global","path":"/tmp/opencode/skills/omega/SKILL.md","display_path":"~/.config/opencode/skills/omega/SKILL.md","definition_id":"opencode:omega","name":"Omega","state":"loaded","enabled":true}]'
        skills_opencode_toggled='[{"id":"omega","agent":"opencode","scope":"agent-global","path":"/tmp/opencode/skills/omega/SKILL.md","display_path":"~/.config/opencode/skills/omega/SKILL.md","definition_id":"opencode:omega","name":"Omega","state":"disabled","enabled":false}]'
        skills_toolglobal='[{"id":"tool-alpha","agent":"tool-global","scope":"tool-global","path":"/tmp/skills-copilot/staging/tool-alpha/SKILL.md","display_path":"Tool Pool/tool-alpha/SKILL.md","definition_id":"tool:alpha","name":"Tool Alpha","state":"loaded","enabled":true}]'
        skills_batch_mixed='[{"id":"alpha","agent":"claude-code","scope":"agent-global","path":"/tmp/global/alpha/SKILL.md","display_path":"/tmp/global/alpha/SKILL.md","definition_id":"def.alpha","name":"Alpha","state":"loaded","enabled":true},{"id":"beta","agent":"claude-code","scope":"agent-project","path":"/tmp/project/beta/SKILL.md","display_path":"/tmp/project/beta/SKILL.md","definition_id":"def.beta","name":"Beta","state":"loaded","enabled":false},{"id":"gamma","agent":"codex","scope":"agent-global","path":"/tmp/codex/skills/gamma/SKILL.md","display_path":"~/.codex/skills/gamma/SKILL.md","definition_id":"codex:gamma","name":"Gamma","state":"loaded","enabled":true},{"id":"pi-one","agent":"pi","scope":"agent-global","path":"/tmp/pi/skills/pi-one/SKILL.md","display_path":"~/.pi/skills/pi-one/SKILL.md","definition_id":"pi:one","name":"Pi One","state":"loaded","enabled":true}]'
        skills_batch_applied='[{"id":"alpha","agent":"claude-code","scope":"agent-global","path":"/tmp/global/alpha/SKILL.md","display_path":"/tmp/global/alpha/SKILL.md","definition_id":"def.alpha","name":"Alpha","state":"loaded","enabled":false},{"id":"beta","agent":"claude-code","scope":"agent-project","path":"/tmp/project/beta/SKILL.md","display_path":"/tmp/project/beta/SKILL.md","definition_id":"def.beta","name":"Beta","state":"loaded","enabled":false},{"id":"gamma","agent":"codex","scope":"agent-global","path":"/tmp/codex/skills/gamma/SKILL.md","display_path":"~/.codex/skills/gamma/SKILL.md","definition_id":"codex:gamma","name":"Gamma","state":"loaded","enabled":false},{"id":"pi-one","agent":"pi","scope":"agent-global","path":"/tmp/pi/skills/pi-one/SKILL.md","display_path":"~/.pi/skills/pi-one/SKILL.md","definition_id":"pi:one","name":"Pi One","state":"loaded","enabled":true}]'
        findings_stale_before='[{"id":"finding-stale-before","instance_id":"beta","definition_id":"def.beta","rule_id":"frontmatter.required-fields","severity":"error","message":"before","suggestion":"Add missing metadata.","created_at":1}]'
        findings_stale_after_scan='[{"id":"finding-fresh-scan","instance_id":"beta","definition_id":"def.beta","rule_id":"fingerprint.changed","severity":"info","message":"scan","suggestion":"Review changed content.","created_at":2},{"id":"finding-fresh-codex","instance_id":"gamma","definition_id":"codex:gamma","rule_id":"path.outside-workspace","severity":"error","message":"codex","suggestion":"Move the skill under the project root.","created_at":3}]'
        findings_stale_after_project='[{"id":"finding-project","instance_id":"gamma","definition_id":"codex:gamma","rule_id":"name.collision","severity":"warning","message":"project","suggestion":"Review duplicate names.","created_at":4}]'
        findings_stale_after_toggle='[{"id":"finding-toggle","instance_id":"beta","definition_id":"def.beta","rule_id":"path.outside-workspace","severity":"error","message":"toggle","suggestion":"Move the skill under the project root.","created_at":5}]'
        findings_detail_scope='[{"id":"finding-beta-instance","instance_id":"beta","definition_id":"def.beta","rule_id":"fingerprint.changed","severity":"info","message":"beta instance","suggestion":"Review beta.","created_at":6},{"id":"finding-beta-definition-only","instance_id":"alpha","definition_id":"def.beta","rule_id":"name.collision","severity":"warning","message":"shared definition, wrong skill","suggestion":"Do not show on beta detail.","created_at":7},{"id":"finding-gamma-instance","instance_id":"gamma","definition_id":"codex:gamma","rule_id":"path.outside-workspace","severity":"error","message":"gamma instance","suggestion":"Review gamma.","created_at":8}]'
        conflicts_detail_scope='[{"id":"conflict-beta-alpha","definition_id":"def.beta","reason":"content-drift","winner_id":null,"instance_ids":["beta","alpha"]},{"id":"conflict-beta-gamma-cross-agent","definition_id":"def.beta","reason":"source-overlap","winner_id":null,"instance_ids":["beta","gamma"]},{"id":"conflict-alpha-gamma-no-selected","definition_id":"def.shared","reason":"source-overlap","winner_id":null,"instance_ids":["alpha","gamma"]}]'
        events_beta='[{"id":1001,"instance_id":"beta","kind":"toggle","payload":{"enabled":false,"agent":"claude-code","skill_name":"Beta"},"occurred_at":10},{"id":1000,"instance_id":"beta","kind":"scan","payload":{"summary":"rescan"},"occurred_at":9}]'
        events_gamma='[{"id":2001,"instance_id":"gamma","kind":"toggle","payload":{"enabled":true,"agent":"codex","skill_name":"Gamma"},"occurred_at":11}]'
        snapshots_claude='[{"id":"snap-claude-new","agent":"claude-code","scope":"agent-global","target":"/tmp/home/.claude/settings.json","content":"{}\\n","reason":"pre-toggle","created_at":30},{"id":"snap-claude-old","agent":"claude-code","scope":"agent-project","target":"/tmp/project/.claude/settings.local.json","content":"{}\\n","reason":"pre-config-edit","created_at":20}]'
        snapshots_codex='[{"id":"snap-codex","agent":"codex","scope":"agent-global","target":"/tmp/home/.codex/config.toml","content":"disable_response_storage = true\\n","reason":"pre-toggle","created_at":40}]'
        snapshots_opencode='[{"id":"snap-opencode","agent":"opencode","scope":"agent-global","target":"/tmp/home/.config/opencode/opencode.json","content":"{}\\n","reason":"pre-toggle","created_at":50}]'

        state_snapshot_response() {
          if [ "$scenario" = "error" ]; then service_error; fi
          if [ "$scenario" = "empty" ]; then
            state_skills='[]'
            state_findings='[]'
            state_conflicts='[]'
          elif [ "$scenario" = "toggle-disabled" ]; then
            state_skills=$skills_toggled
            state_findings='[]'
            state_conflicts='[]'
          elif [ "$scenario" = "toggle-codex-disabled" ]; then
            state_skills=$skills_codex_toggled
            state_findings='[]'
            state_conflicts='[]'
          elif [ "$scenario" = "opencode" ]; then
            if grep -q '"method":"config.toggleSkill"' "$SKILLS_COPILOT_FAKE_SERVICE_CALLS"; then
              state_skills=$skills_opencode_toggled
            else
              state_skills=$skills_opencode
            fi
            state_findings='[]'
            state_conflicts='[]'
          elif [ "$scenario" = "tool-global" ]; then
            state_skills=$skills_toolglobal
            state_findings='[]'
            state_conflicts='[]'
          elif [ "$scenario" = "stale-before" ]; then
            state_skills=$skills_normal
            state_findings=$findings_stale_before
            state_conflicts='[]'
          elif [ "$scenario" = "stale-after-scan" ]; then
            state_skills=$skills_normal
            state_findings=$findings_stale_after_scan
            state_conflicts='[]'
          elif [ "$scenario" = "stale-after-project" ]; then
            state_skills=$skills_normal
            state_findings=$findings_stale_after_project
            state_conflicts='[]'
          elif [ "$scenario" = "stale-after-toggle" ]; then
            state_skills=$skills_toggled
            state_findings=$findings_stale_after_toggle
            state_conflicts='[]'
          elif [ "$scenario" = "detail-scope" ]; then
            state_skills=$skills_normal
            state_findings=$findings_detail_scope
            state_conflicts=$conflicts_detail_scope
          elif [ "$scenario" = "batch-mixed" ]; then
            if grep -q '"method":"batch.applySkillToggles"' "$SKILLS_COPILOT_FAKE_SERVICE_CALLS"; then
              state_skills=$skills_batch_applied
            else
              state_skills=$skills_batch_mixed
            fi
            state_findings='[]'
            state_conflicts='[]'
          else
            state_skills=$skills_normal
            state_findings='[]'
            state_conflicts='[]'
          fi
          respond '{"id":"test","ok":true,"result":{"status":{"protocol_version":1,"version":"test","app_data_dir":"/tmp/skills-copilot","catalog_path":"/tmp/skills-copilot/catalog.sqlite","user_home":"/tmp/home","supported_methods":["app.stateSnapshot","service.status","catalog.listSkills","catalog.scanAll","catalog.getSkill","catalog.listFindings","catalog.listConflicts","skill.listEvents","snapshot.list","snapshot.listAgentConfig","config.toggleSkill","batch.previewSkillToggles","batch.applySkillToggles","project.getContext","project.setContext","project.clearContext","project.validateContext"],"adapter_capabilities":'"$adapter_capabilities"'},"skills":'"$state_skills"',"findings":'"$state_findings"',"conflicts":'"$state_conflicts"',"snapshots":[]}}'
        }

        detail_alpha='{"id":"alpha","agent":"claude-code","scope":"agent-global","path":"/tmp/global/alpha/SKILL.md","display_path":"/tmp/global/alpha/SKILL.md","definition_id":"def.alpha","name":"Alpha","description":"Alpha skill","state":"loaded","enabled":true,"frontmatter_raw":"name: Alpha","body":"Alpha body","permissions":{"marker":"alpha"},"fingerprint":"fp-alpha"}'
        detail_beta_enabled='{"id":"beta","agent":"claude-code","scope":"agent-project","path":"/tmp/project/beta/SKILL.md","display_path":"/tmp/project/beta/SKILL.md","definition_id":"def.beta","name":"Beta","description":"Beta skill","state":"loaded","enabled":true,"frontmatter_raw":"name: Beta","body":"Beta body","permissions":{"marker":"default"},"fingerprint":"fp-beta"}'
        detail_beta_disabled='{"id":"beta","agent":"claude-code","scope":"agent-project","path":"/tmp/project/beta/SKILL.md","display_path":"/tmp/project/beta/SKILL.md","definition_id":"def.beta","name":"Beta","description":"Beta skill","state":"loaded","enabled":false,"frontmatter_raw":"name: Beta","body":"Beta body","permissions":{"marker":"toggle-disabled"},"fingerprint":"fp-beta"}'
        detail_gamma='{"id":"gamma","agent":"codex","scope":"agent-global","path":"/tmp/codex/skills/gamma/SKILL.md","display_path":"~/.codex/skills/gamma/SKILL.md","definition_id":"codex:gamma","name":"Gamma","description":"Gamma skill","state":"loaded","enabled":true,"frontmatter_raw":"name: Gamma","body":"Gamma body","permissions":{"marker":"codex"},"fingerprint":"fp-gamma"}'
        detail_gamma_disabled='{"id":"gamma","agent":"codex","scope":"agent-global","path":"/tmp/codex/skills/gamma/SKILL.md","display_path":"~/.codex/skills/gamma/SKILL.md","definition_id":"codex:gamma","name":"Gamma","description":"Gamma skill","state":"loaded","enabled":false,"frontmatter_raw":"name: Gamma","body":"Gamma body","permissions":{"marker":"codex-disabled"},"fingerprint":"fp-gamma"}'
        detail_beta_before='{"id":"beta","agent":"claude-code","scope":"agent-project","path":"/tmp/project/beta/SKILL.md","display_path":"/tmp/project/beta/SKILL.md","definition_id":"def.beta","name":"Beta","description":"Beta skill","state":"loaded","enabled":true,"frontmatter_raw":"name: Beta","body":"Beta body","permissions":{"marker":"before"},"fingerprint":"fp-beta-before"}'
        detail_beta_scan='{"id":"beta","agent":"claude-code","scope":"agent-project","path":"/tmp/project/beta/SKILL.md","display_path":"/tmp/project/beta/SKILL.md","definition_id":"def.beta","name":"Beta","description":"Beta skill","state":"loaded","enabled":true,"frontmatter_raw":"name: Beta","body":"Beta body","permissions":{"marker":"scan"},"fingerprint":"fp-beta-scan"}'
        detail_beta_toggle='{"id":"beta","agent":"claude-code","scope":"agent-project","path":"/tmp/project/beta/SKILL.md","display_path":"/tmp/project/beta/SKILL.md","definition_id":"def.beta","name":"Beta","description":"Beta skill","state":"loaded","enabled":false,"frontmatter_raw":"name: Beta","body":"Beta body","permissions":{"marker":"toggle"},"fingerprint":"fp-beta-toggle"}'
        detail_gamma_scan='{"id":"gamma","agent":"codex","scope":"agent-global","path":"/tmp/codex/skills/gamma/SKILL.md","display_path":"~/.codex/skills/gamma/SKILL.md","definition_id":"codex:gamma","name":"Gamma","description":"Gamma skill","state":"loaded","enabled":true,"frontmatter_raw":"name: Gamma","body":"Gamma body","permissions":{"marker":"codex-scan"},"fingerprint":"fp-gamma-scan"}'
        detail_gamma_project='{"id":"gamma","agent":"codex","scope":"agent-global","path":"/tmp/codex/skills/gamma/SKILL.md","display_path":"~/.codex/skills/gamma/SKILL.md","definition_id":"codex:gamma","name":"Gamma","description":"Gamma skill","state":"loaded","enabled":true,"frontmatter_raw":"name: Gamma","body":"Gamma body","permissions":{"marker":"project"},"fingerprint":"fp-gamma-project"}'
        detail_omega='{"id":"omega","agent":"opencode","scope":"agent-global","path":"/tmp/opencode/skills/omega/SKILL.md","display_path":"~/.config/opencode/skills/omega/SKILL.md","definition_id":"opencode:omega","name":"Omega","description":"Omega skill","state":"loaded","enabled":true,"frontmatter_raw":"name: Omega","body":"Omega body","permissions":{},"fingerprint":"fp-omega"}'
        detail_omega_disabled='{"id":"omega","agent":"opencode","scope":"agent-global","path":"/tmp/opencode/skills/omega/SKILL.md","display_path":"~/.config/opencode/skills/omega/SKILL.md","definition_id":"opencode:omega","name":"Omega","description":"Omega skill","state":"disabled","enabled":false,"frontmatter_raw":"name: Omega","body":"Omega body","permissions":{},"fingerprint":"fp-omega"}'
        detail_toolglobal='{"id":"tool-alpha","agent":"tool-global","scope":"tool-global","path":"/tmp/skills-copilot/staging/tool-alpha/SKILL.md","display_path":"Tool Pool/tool-alpha/SKILL.md","definition_id":"tool:alpha","name":"Tool Alpha","description":"Tool-global staged skill","state":"loaded","enabled":true,"frontmatter_raw":"name: Tool Alpha","body":"Tool Alpha body","permissions":{},"fingerprint":"fp-tool-alpha"}'

        case "$input" in
          *\\"app.stateSnapshot\\"*)
            state_snapshot_response
            ;;
          *\\"service.status\\"*)
            if [ "$scenario" = "error" ]; then service_error; fi
            status_response
            ;;
          *\\"rules.listTuning\\"*)
            respond '{"id":"test","ok":true,"result":[]}'
            ;;
          *\\"llm.status\\"*)
            if [ "$scenario" = "old-service" ]; then
              respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: llm.status"}}'
            elif [ "$scenario" = "llm-ready" ] || [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"enabled":true,"provider":"openai","model":"gpt-5","disabled_reason":null,"supported_actions":["analyze","recommend","explain_conflict","draft_frontmatter"]}}'
            else
              respond '{"id":"test","ok":true,"result":{"enabled":false,"provider":null,"model":null,"disabled_reason":"LLM is disabled.","supported_actions":["analyze","recommend","explain_conflict","draft_frontmatter"]}}'
            fi
            ;;
          *\\"llm.listProviderProfiles\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"service_available":true,"enabled":true,"configured":true,"active_profile_id":"openai-compatible","credential_storage":"keychain","credential_persistence_allowed":true,"profiles":[{"id":"openai-compatible","kind":"openai-compatible","endpoint":"https://llm.example.com/v1","model":"gpt-5","enabled":true,"configured":true,"has_api_key":true}]}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: llm.listProviderProfiles"}}'
            ;;
          *\\"llm.prepareSkillAnalysis\\"*)
            if [ "$scenario" = "old-service" ]; then
              respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: llm.prepareSkillAnalysis"}}'
            elif [ "$scenario" = "llm-ready" ] || [ "$scenario" = "prompt-ready" ]; then
              if printf '%s' "$input" | grep -q '\\"analysis_kind\\":\\"risk\\"'; then
                respond '{"id":"test","ok":true,"result":{"enabled":false,"disabled_reason":"AI analysis is disabled by default.","analysis_kind":"risk","selected_skill_count":1,"included_skills":[{"instance_id":"beta","name":"Beta","agent":"claude-code"}],"excluded_count":0,"missing_count":0,"prompt_draft":"Risk prompt for Beta.","summary_draft":"Risk summary for Beta.","write_back_enabled":false,"script_execution_enabled":false,"credential_storage_enabled":false,"confirmation_required":true}}'
              else
                respond '{"id":"test","ok":true,"result":{"enabled":false,"disabled_reason":"AI analysis is disabled by default.","analysis_kind":"overview","selected_skill_count":2,"included_skills":[{"instance_id":"alpha","name":"Alpha","agent":"claude-code"},{"instance_id":"beta","name":"Beta","agent":"claude-code"}],"excluded_count":0,"missing_count":0,"prompt_draft":"Overview prompt for visible skills.","summary_draft":"Overview summary for visible skills.","safety":{"write_back_enabled":false,"script_execution_enabled":false,"credential_storage_enabled":false,"confirmation_required":true}}}'
              fi
            else
              respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: llm.prepareSkillAnalysis"}}'
            fi
            ;;
          *\\"analysis.scoreSkillQuality\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"instance_id":"beta","score":82,"band":"Good","summary":"Beta has usable metadata, one permission clarity gap, and no same-agent conflict.","components":[{"key":"metadata","label":"Metadata completeness","score":92,"summary":"Name and description are present."},{"key":"permissions","label":"Permission clarity","score":70,"summary":"Network access needs explicit declaration."}],"evidence":[{"title":"Metadata","detail":"Description is present.","source":"catalog"},{"title":"Findings","detail":"One permission warning.","source":"permissions.network-declared"}],"risk_notes":["Network access is not declared."],"suggested_improvements":["Declare network access explicitly."],"safety":{"provider_request_sent":false,"write_back_allowed":false,"write_actions_available":false,"script_execution_allowed":false,"execution_actions_available":false,"config_mutation_allowed":false,"snapshot_created":false,"triage_mutation_allowed":false,"credential_accessed":false,"raw_secret_returned":false}}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: analysis.scoreSkillQuality"}}'
            ;;
          *\\"task.checkReadiness\\"*)
            if [ "$scenario" = "prompt-ready" ] || [ "$scenario" = "llm-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"task_text":"Audit local skills for a release note.","score":74,"band":"Partial","summary":"Beta has local audit coverage but lacks release-note-specific examples.","candidate_skills":[{"instance_id":"beta","name":"Beta","agent":"claude-code","score":74,"band":"Partial","rationale":"Best selected-skill fit for local audit work.","evidence":["description match","catalog evidence available"]}],"gaps":["No release-note-specific examples."],"blockers":[],"risk_notes":["Permission clarity should be reviewed before routing."],"evidence":[{"title":"Metadata","detail":"Description mentions local audit.","source":"catalog"},{"title":"Findings","detail":"One permission warning remains.","source":"permissions.network-declared"}],"safety_flags":{"provider_request_sent":false,"write_back_allowed":false,"write_actions_available":false,"script_execution_allowed":false,"execution_actions_available":false,"config_mutation_allowed":false,"snapshot_created":false,"triage_mutation_allowed":false,"credential_accessed":false,"raw_secret_returned":false}}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: task.checkReadiness"}}'
            ;;
          *\\"task.rankSkillRoutes\\"*)
            if [ "$scenario" = "prompt-ready" ] || [ "$scenario" = "llm-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"task":"Route a local audit release note task.","confidence_score":88,"band":"High","summary":"Beta is the strongest selected route; Alpha is a nearby alternate.","candidate_routes":[{"instance_id":"beta","name":"Beta","agent":"claude-code","confidence_score":88,"band":"High","summary":"Best project-scoped local audit fit.","match_reasons":["Description matches local audit.","Selected skill is enabled."],"ambiguity_warnings":["Alpha has overlapping audit wording."],"wrong_pick_risks":["Could miss release-note-specific examples."],"evidence_references":[{"title":"Metadata","detail":"Description mentions local audit.","source":"catalog"}]},{"instance_id":"alpha","name":"Alpha","agent":"claude-code","score":69,"band":"Medium","summary":"Nearby fallback with weaker task wording.","match_reasons":["Same agent and enabled."],"ambiguity_warnings":[],"wrong_pick_risks":["Less project-specific."],"evidence":["Enabled fallback"]}],"ambiguity_warnings":["Alpha has overlapping audit wording."],"wrong_pick_risks":["Choosing Alpha may miss project-scoped evidence."],"evidence_references":[{"title":"Comparison","detail":"Same-agent candidates reviewed.","source":"analysis"}],"safety_flags":{"provider_request_sent":false,"write_back_allowed":false,"write_actions_available":false,"script_execution_allowed":false,"execution_actions_available":false,"config_mutation_allowed":false,"snapshot_created":false,"triage_mutation_allowed":false,"credential_accessed":false,"raw_secret_returned":false}}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: task.rankSkillRoutes"}}'
            ;;
          *\\"task.compareAgentReadiness\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"generated_by":"local-v2.50","catalog_available":true,"filters":{"limit_per_agent":3,"include_routing_accuracy":true,"include_benchmarks":true},"summary":{"agent_count":2,"candidate_count":5,"ready_agent_count":1,"partial_agent_count":1,"blocked_agent_count":0,"gap_issue_count":1,"recommended_agent":"claude-code","summary":"Claude Code is strongest for this task; Codex is usable but lacks benchmark coverage."},"recommended_agent":{"agent":"claude-code","display_name":"Claude Code","comparison_score":93,"readiness_score":88,"routing_confidence_score":91,"skill_name":"Beta","reason":"Best local task fit with benchmark and accuracy context."},"agent_rows":[{"rank":1,"agent":"claude-code","display_name":"Claude Code","comparison_score":93,"readiness_score":88,"readiness_band":"Ready","routing_confidence_score":91,"routing_confidence_band":"High","best_candidate":{"instance_id":"beta","definition_id":"def.beta","skill_name":"Beta","scope":"agent-project","enabled":true,"state":"loaded","readiness_score":88,"readiness_band":"Ready","routing_confidence_score":91,"routing_confidence_band":"High","quality_score":82},"candidate_count":3,"enabled_scope_risk_state":{"enabled":true,"scope":"agent-project","state":"loaded","risk_level":"low","risk_summary":"Low local risk.","writable_status":"verified","adapter_status":"healthy"},"blocker_count":0,"gap_count":0,"reasons":["Description matches local audit.","Benchmark expected route is covered."],"blocker_notes":[],"gap_notes":[],"routing_accuracy_context":{"summary":"7 of 8 known traces hit expected route."},"benchmark_context":{"summary":"Benchmark expected route is covered."},"evidence_refs":["benchmark:bench-1","trace:trace-1"]},{"rank":2,"agent":"codex","display_name":"Codex","comparison_score":72,"readiness_score":74,"readiness_band":"Partial","routing_confidence_score":67,"routing_confidence_band":"Medium","best_candidate":{"instance_id":"gamma","definition_id":"codex:gamma","skill_name":"Gamma","scope":"agent-global","enabled":true,"state":"loaded","readiness_score":74,"readiness_band":"Partial","routing_confidence_score":67,"routing_confidence_band":"Medium","quality_score":76},"candidate_count":2,"enabled_scope_risk_state":{"enabled":true,"scope":"agent-global","state":"loaded","risk_level":"medium","risk_summary":"Benchmark coverage is missing.","writable_status":"verified","adapter_status":"healthy"},"blocker_count":0,"gap_count":1,"reasons":["Documentation wording overlaps."],"blocker_notes":[],"gap_notes":["No benchmark covers the Codex route."],"routing_accuracy_context":{"summary":"No imported traces in window."},"benchmark_context":{"summary":"No baseline saved."},"evidence_refs":["catalog:gamma"]}],"gap_issue_rows":[{"source":"benchmark","severity":"warning","agent":"codex","title":"Missing Codex benchmark","detail":"No benchmark covers the Codex route for this task.","evidence_refs":["benchmark:none"]}],"evidence_references":[{"title":"Benchmark","detail":"Beta benchmark matched expected route.","source":"task.evaluateBenchmarks","agent":"claude-code"},{"title":"Routing accuracy","detail":"Trace evidence favors Claude Code.","source":"routing.accuracyDashboard","agent":"claude-code"}],"prompt_request":{"enabled":false,"request_kind":"cross_agent_task_readiness","summary":"Provider explanation is copy-only and preview-gated.","draft_copy_only":true},"safety_flags":{"provider_request_sent":false,"write_back_allowed":false,"write_actions_available":false,"script_execution_allowed":false,"execution_actions_available":false,"config_mutation_allowed":false,"snapshot_created":false,"triage_mutation_allowed":false,"credential_accessed":false,"raw_prompt_persisted":false,"raw_response_persisted":false,"raw_trace_persisted":false,"cloud_sync_enabled":false,"telemetry_enabled":false,"raw_secret_returned":false,"notes":["provider not sent"]}}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: task.compareAgentReadiness"}}'
            ;;
          *\\"knowledge.search\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"generated_by":"local-v2.52","catalog_available":true,"filters":{"query":"release audit","agent":"claude-code","limit":20},"summary":{"result_count":1,"agent_count":1,"gap_count":1,"blocker_count":0,"summary":"Beta matches local knowledge for release audit work."},"knowledge_rows":[{"rank":1,"instance_id":"beta","definition_id":"def.beta","skill_name":"Beta","agent":"claude-code","scope":"agent-project","enabled":true,"state":"loaded","purpose":"Handles local audit release notes.","matched_fields":["purpose","tools"],"match_reasons":["Purpose mentions audit."],"keywords":["audit","release"],"tools":["rg"],"rules":["permissions.network-declared"],"capability_tags":["analysis"],"risk_tags":["local-only"],"evidence_refs":["catalog:beta"],"safety_flags":["provider not sent"]}],"facet_rows":[{"facet":"agent","value":"claude-code","count":1}],"gap_notes":["No fresh trace confirms the release audit route."],"blocker_notes":[],"evidence_references":[{"title":"Knowledge index","detail":"Beta indexed from local catalog metadata.","source":"knowledge.search","agent":"claude-code"}],"prompt_request":{"enabled":false,"request_kind":"knowledge_search","summary":"Provider explanation is copy-only and preview-gated.","draft_copy_only":true},"safety_flags":{"provider_request_sent":false,"write_back_allowed":false,"write_actions_available":false,"script_execution_allowed":false,"execution_actions_available":false,"config_mutation_allowed":false,"snapshot_created":false,"triage_mutation_allowed":false,"credential_accessed":false,"raw_prompt_persisted":false,"raw_response_persisted":false,"raw_trace_persisted":false,"cloud_sync_enabled":false,"telemetry_enabled":false,"raw_secret_returned":false,"notes":["provider not sent"]}}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: knowledge.search"}}'
            ;;
          *\\"knowledge.buildLocalSkillMap\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"generated_by":"local-v2.63","catalog_available":true,"filters":{"agent":"claude-code","selected_skill_id":"beta","selected_skill_name":"Beta","selected_skill_agent":"claude-code","project_root":"/tmp/project","current_cwd":"/tmp/project","workspace":"Fixture Project","limit":30,"include_edges":true,"include_clusters":true},"summary":{"node_count":2,"edge_count":1,"cluster_count":1,"domain_count":1,"skill_count":2,"agent_count":1,"gap_count":1,"blocker_count":0,"evidence_count":1,"selected_skill_context":"Beta in Claude Code project scope","summary":"Beta anchors the release audit local skill map."},"selected_skill":{"instance_id":"beta","definition_id":"def.beta","skill_name":"Beta","agent":"claude-code","scope":"agent-project","enabled":true,"state":"loaded","quality_score":82,"readiness_score":78,"reasons":["Selected skill anchors this map."],"evidence_refs":["catalog:beta"],"safety_flags":["provider not sent"]},"nodes":[{"node_id":"skill:beta","label":"Beta","kind":"skill","instance_id":"beta","definition_id":"def.beta","skill_name":"Beta","agent":"claude-code","scope":"agent-project","enabled":true,"state":"loaded","domain":"Release audit","cluster_id":"cluster:audit","weight":0.91,"reasons":["Selected skill anchors this map."],"evidence_refs":["catalog:beta"],"safety_flags":["provider not sent"]},{"node_id":"skill:alpha","label":"Alpha","kind":"skill","instance_id":"alpha","definition_id":"def.alpha","skill_name":"Alpha","agent":"claude-code","scope":"agent-global","enabled":true,"state":"loaded","domain":"Release audit","cluster_id":"cluster:audit","weight":0.64,"reasons":["Similar purpose wording."],"evidence_refs":["catalog:alpha"],"safety_flags":["provider not sent"]}],"edges":[{"source_id":"skill:beta","target_id":"skill:alpha","relation_kind":"similar-purpose","label":"Shared audit purpose","strength":0.74,"direction":"undirected","reasons":["Shared audit keywords and rg tool use."],"evidence_refs":["similar:audit"],"safety_flags":["provider not sent"]}],"clusters":[{"cluster_id":"cluster:audit","name":"Release audit","kind":"domain","summary":"Skills that support release audit workflows.","node_ids":["skill:beta","skill:alpha"],"agents":["claude-code"],"capabilities":["release-audit"],"gap_notes":["No Codex project route."],"blocker_notes":[],"evidence_refs":["domain:audit"],"safety_flags":["provider not sent"]}],"gap_rows":[{"title":"Missing Codex route","detail":"No Codex project route.","severity":"warning","agent":"codex","evidence_refs":["workspace:codex-gap"]}],"blocker_rows":[],"evidence_references":[{"title":"Local skill map","detail":"Map derived from local catalog and analysis evidence.","source":"knowledge.buildLocalSkillMap","agent":"claude-code"}],"prompt_request":{"enabled":false,"request_kind":"local_skill_map","summary":"Provider explanation is copy-only and preview-gated.","draft_copy_only":true},"safety_flags":{"provider_request_sent":false,"write_back_allowed":false,"write_actions_available":false,"script_execution_allowed":false,"execution_actions_available":false,"config_mutation_allowed":false,"snapshot_created":false,"triage_mutation_allowed":false,"credential_accessed":false,"raw_prompt_persisted":false,"raw_response_persisted":false,"raw_trace_persisted":false,"cloud_sync_enabled":false,"telemetry_enabled":false,"raw_secret_returned":false,"notes":["provider not sent"]}}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: knowledge.buildLocalSkillMap"}}'
            ;;
          *\\"skill.lifecycleTimeline\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"generated_by":"local-v2.66","catalog_available":true,"filters":{"agent":"claude-code","selected_skill_id":"beta","selected_skill_name":"Beta","selected_skill_agent":"claude-code","project_root":"/tmp/project","current_cwd":"/tmp/project","workspace":"Fixture Project","limit":20,"include_skill_rows":true,"include_agent_rows":true,"include_evidence":true,"include_safety_flags":true},"summary":{"event_count":3,"skill_count":1,"agent_count":1,"event_type_count":3,"stage_count":3,"gap_count":1,"blocker_count":1,"evidence_count":1,"safety_flag_count":1,"first_event_at":"2026-06-10T09:00:00Z","latest_event_at":"2026-06-12T08:00:00Z","summary":"Beta lifecycle was reconstructed from local catalog, scan, routing, and remediation evidence."},"timeline_rows":[{"id":"life-scan-beta","occurred_at":"2026-06-10T09:00:00Z","event_type":"scan.detected","lifecycle_stage":"discovered","title":"Beta loaded from project root","summary":"Catalog scan detected the selected skill.","agent":"claude-code","skill_name":"Beta","instance_id":"beta","definition_id":"def.beta","source":"catalog.scanAll","severity":"info","status":"loaded","evidence_refs":["catalog:beta"],"safety_flags":["provider not sent"]},{"id":"life-route-beta","occurred_at":"2026-06-12T08:00:00Z","event_type":"routing.selected","lifecycle_stage":"in-use","title":"Beta selected for release audit task","summary":"Routing confidence ranked Beta first.","agent":"claude-code","skill_name":"Beta","instance_id":"beta","definition_id":"def.beta","source":"task.rankSkillRoutes","severity":"info","status":"ready","evidence_refs":["route:beta"],"safety_flags":["provider not sent"]}],"skill_rows":[{"id":"skill-beta","event_type":"skill.aggregate","lifecycle_stage":"active","title":"Beta lifecycle","summary":"Three local lifecycle events reference Beta.","agent":"claude-code","skill_name":"Beta","instance_id":"beta","definition_id":"def.beta","source":"skill.lifecycleTimeline","status":"active","count":3,"evidence_refs":["catalog:beta"],"safety_flags":["provider not sent"]}],"agent_rows":[{"id":"agent-claude","event_type":"agent.aggregate","lifecycle_stage":"active","title":"Claude Code lifecycle coverage","summary":"Claude Code has selected skill lifecycle evidence.","agent":"claude-code","source":"skill.lifecycleTimeline","status":"covered","count":3,"evidence_refs":["agent:claude-code"],"safety_flags":["provider not sent"]}],"gap_notes":["No Codex lifecycle evidence for this selected skill."],"blocker_notes":["Lifecycle timeline is read-only and does not create snapshots."],"evidence_references":[{"title":"Lifecycle timeline","detail":"Derived from local catalog and analysis evidence.","source":"skill.lifecycleTimeline","agent":"claude-code"}],"prompt_request":{"enabled":false,"request_kind":"skill_lifecycle_timeline","summary":"No provider request is prepared or sent.","draft_copy_only":true,"redacted":true},"safety_flags":{"provider_request_sent":false,"write_back_allowed":false,"write_actions_available":false,"script_execution_allowed":false,"execution_actions_available":false,"config_mutation_allowed":false,"snapshot_created":false,"triage_mutation_allowed":false,"credential_accessed":false,"raw_prompt_persisted":false,"raw_response_persisted":false,"raw_trace_persisted":false,"cloud_sync_enabled":false,"telemetry_enabled":false,"raw_secret_returned":false,"notes":["provider not sent","read-only timeline"]}}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: skill.lifecycleTimeline"}}'
            ;;
          *\\"llm.providerObservability\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"generated_by":"local-v2.64","app_local_only":true,"metadata_redacted":true,"filters":{"window_days":30,"limit":30,"include_history":true,"include_budget_hints":true,"include_retention_recommendations":true,"include_evidence":true},"summary":{"call_count":3,"success_count":1,"failure_count":1,"blocked_count":1,"provider_count":1,"model_count":2,"destination_count":1,"error_count":1,"estimated_input_tokens":980,"estimated_output_tokens":320,"estimated_total_tokens":1300,"estimated_cost_usd":0.041,"total_duration_ms":1800,"average_duration_ms":600,"budget_hint_count":1,"retention_recommendation_count":2,"summary":"Three redacted provider-call metadata rows were reviewed locally."},"call_rows":[{"id":"call-1","preview_id":"preview-1","confirmation_id":"confirm-1","request_kind":"task_readiness","action":"task_readiness","provider":"openai-compatible","model":"gpt-5","destination_host":"llm.example.com","status":"succeeded","duration_ms":720,"input_tokens":420,"output_tokens":120,"total_tokens":540,"estimated_cost_usd":0.014,"completed_at":1781260000000,"draft_copy_only":true,"provider_request_sent":true,"credential_accessed":false,"raw_prompt_persisted":false,"raw_response_persisted":false,"raw_secret_returned":false,"evidence_refs":["prompt-run:preview-1"],"safety_flags":["copy-only","raw prompt not stored"],"detail":"Provider response metadata was stored without raw prompt or response."},{"id":"call-2","request_kind":"quality_score","provider":"openai-compatible","model":"gpt-5-mini","destination_host":"llm.example.com","status":"failed","error_code":"timeout","error_message":"Provider request timed out.","duration_ms":1080,"input_tokens":560,"output_tokens":0,"total_tokens":560,"estimated_cost_usd":0.027,"draft_copy_only":true,"provider_request_sent":true,"credential_accessed":false,"raw_prompt_persisted":false,"raw_response_persisted":false,"raw_secret_returned":false,"evidence_refs":["prompt-run:timeout"],"safety_flags":["raw response not stored"]}],"provider_rows":[{"kind":"provider","label":"OpenAI-compatible","provider":"openai-compatible","call_count":3,"success_count":1,"failure_count":1,"blocked_count":1,"estimated_tokens":1300,"estimated_cost_usd":0.041,"average_duration_ms":600,"status":"partial","notes":["One timeout and one blocked local preview."],"evidence_refs":["provider:openai-compatible"]}],"model_rows":[{"kind":"model","label":"gpt-5","model":"gpt-5","call_count":1,"success_count":1,"estimated_tokens":540,"status":"ok"},{"kind":"model","label":"gpt-5-mini","model":"gpt-5-mini","call_count":1,"failure_count":1,"estimated_tokens":560,"status":"warning"}],"destination_rows":[{"kind":"destination","label":"llm.example.com","destination_host":"llm.example.com","call_count":2,"status":"partial"}],"status_rows":[{"severity":"info","status":"succeeded","title":"Succeeded","detail":"One call completed.","count":1},{"severity":"warning","status":"blocked","title":"Blocked locally","detail":"One preview never sent a provider request.","count":1}],"error_rows":[{"severity":"warning","status":"failed","title":"Timeout","detail":"Provider request timed out.","count":1,"provider":"openai-compatible","model":"gpt-5-mini","evidence_refs":["prompt-run:timeout"]}],"budget_hints":[{"severity":"info","title":"Monthly budget healthy","detail":"Estimated spend is below the configured budget.","value":"0.041","threshold":"25.00","recommendation":"Keep monitoring prompt-run history."}],"usage_hints":[{"severity":"info","title":"Token usage available","detail":"Estimated token totals are derived from redacted metadata.","value":"1300"}],"retention_rows":[{"severity":"info","title":"Retain metadata only","detail":"Keep redacted prompt-run metadata; do not retain raw prompts.","recommendation":"Review old metadata periodically."}],"cleanup_recommendations":[{"severity":"info","title":"No cleanup required","detail":"No unsafe raw prompt or response payloads were observed."}],"gap_notes":["No raw response bodies are available for observability by design."],"blocker_notes":[],"evidence_references":[{"title":"Prompt run history","detail":"Read from app-local prompt-runs metadata.","source":"llm.providerObservability"}],"prompt_request":{"enabled":false,"request_kind":"provider_observability","summary":"No provider request is prepared or sent by observability.","draft_copy_only":true,"redacted":true},"safety_flags":{"provider_request_sent":false,"write_back_allowed":false,"write_actions_available":false,"script_execution_allowed":false,"execution_actions_available":false,"config_mutation_allowed":false,"snapshot_created":false,"triage_mutation_allowed":false,"credential_accessed":false,"raw_prompt_persisted":false,"raw_response_persisted":false,"raw_trace_persisted":false,"cloud_sync_enabled":false,"telemetry_enabled":false,"raw_secret_returned":false,"notes":["observability did not send a provider request"]}}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: llm.providerObservability"}}'
            ;;
          *\\"task.buildCockpit\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"generated_by":"local-v2.65","catalog_available":true,"filters":{"task":"Prepare local release audit work.","agent":"claude-code","selected_skill_id":"beta","selected_skill_name":"Beta","selected_skill_agent":"claude-code","project_root":"/tmp/project","current_cwd":"/tmp/project","workspace":"Fixture Project","limit":8,"include_session_review":true,"include_provider_observability":true,"include_remediation_context":true},"summary":{"task_text":"Prepare local release audit work.","summary":"Beta is the strongest route; Codex coverage remains a gap.","route_candidate_count":2,"agent_candidate_count":1,"skill_candidate_count":1,"readiness_signal_count":1,"session_review_count":1,"provider_call_count":3,"remediation_item_count":1,"gap_count":1,"blocker_count":1,"evidence_count":1,"safety_flag_count":1,"recommended_agent":"claude-code","recommended_skill_name":"Beta","readiness_score":78,"routing_score":88},"route_candidates":[{"route_id":"route-beta","rank":1,"title":"Beta","agent":"claude-code","skill":{"instance_id":"beta","skill_name":"Beta","agent":"claude-code","definition_id":"def.beta"},"readiness_score":78,"routing_score":88,"band":"High","status":"ready","summary":"Best local match for release audit.","match_reasons":["Description matches audit work."],"evidence_refs":["route:beta"],"safety_flags":["provider not sent"]},{"route_id":"route-alpha","rank":2,"title":"Alpha","agent":"claude-code","routing_score":64,"band":"Medium","summary":"Similar audit wording."}],"agent_candidates":[{"agent_id":"agent-claude","title":"Claude Code","agent":"claude-code","score":82,"reasons":["Selected skill is enabled."]}],"skill_candidates":[{"skill_id":"beta","title":"Beta","agent":"claude-code","skill":{"instance_id":"beta","skill_name":"Beta","agent":"claude-code","definition_id":"def.beta"},"readiness_score":78,"routing_score":88}],"readiness_signals":[{"id":"readiness-beta","title":"Readiness partial","detail":"Ready for local audit, missing release-note examples.","status":"partial","count":1}],"session_review_context":[{"id":"review-1","title":"Recent session matched Beta","detail":"Latest review outcome was hit.","status":"hit","source":"session.reviewAgentSkillUse"}],"provider_observability_context":[{"id":"provider-1","title":"Provider calls observed","detail":"Three redacted call metadata rows.","count":3,"source":"llm.providerObservability"}],"remediation_context":[{"id":"plan-1","title":"Add Codex release audit coverage","detail":"Guidance only; no apply path.","severity":"medium","source":"remediation.plan"}],"gap_rows":[{"title":"Codex coverage gap","detail":"No Codex project route.","severity":"warning","agent":"codex","evidence_refs":["workspace:codex-gap"]}],"blocker_rows":[{"title":"No apply path","detail":"Cockpit only recommends review surfaces.","severity":"info"}],"evidence_references":[{"title":"Task cockpit","detail":"Derived from local readiness, routing, session, provider, and remediation metadata.","source":"task.buildCockpit","agent":"claude-code"}],"prompt_request":{"enabled":false,"request_kind":"task_cockpit","summary":"No provider request is prepared or sent.","draft_copy_only":true,"redacted":true},"safety_flags":{"provider_request_sent":false,"write_back_allowed":false,"write_actions_available":false,"script_execution_allowed":false,"execution_actions_available":false,"config_mutation_allowed":false,"snapshot_created":false,"triage_mutation_allowed":false,"credential_accessed":false,"raw_prompt_persisted":false,"raw_response_persisted":false,"raw_trace_persisted":false,"cloud_sync_enabled":false,"telemetry_enabled":false,"raw_secret_returned":false,"notes":["provider not sent"]}}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: task.buildCockpit"}}'
            ;;
          *\\"knowledge.groupSimilarSkills\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"generated_by":"local-v2.53","catalog_available":true,"filters":{"agent":"claude-code","limit":20,"min_score":0.62,"include_singletons":false},"summary":{"group_count":1,"member_count":2,"duplicate_count":1,"similar_count":0,"confusable_count":0,"high_ambiguity_count":1,"coverage_redundancy_count":1,"routing_ambiguity_count":1,"summary":"Beta and Gamma overlap on audit routing."},"groups":[{"group_id":"grp-1","rank":1,"group_type":"duplicate","similarity_score":0.88,"ambiguity_risk":"high","coverage_redundancy":"substantial overlap","routing_ambiguity":"likely wrong-pick","title":"Audit release skills","summary":"Two skills cover the same audit release workflow.","why_grouped":["Same keywords and tool declarations."],"shared_terms":["audit","release"],"shared_tools":["rg"],"shared_rules":["permissions.network-declared"],"shared_capabilities":["analysis"],"shared_risks":["routing ambiguity"],"source_signals":["same project root"],"members":[{"instance_id":"beta","definition_id":"def.beta","skill_name":"Beta","agent":"claude-code","scope":"agent-project","enabled":true,"state":"loaded","source_kind":"project","source_root":"project","quality_score":82,"quality_band":"Good","readiness_score":74,"readiness_band":"Partial","stale_drift_state":"fresh","reasons":["Name and purpose overlap."],"evidence_refs":["catalog:beta"],"safety_flags":["provider not sent"]}],"evidence_refs":["catalog:beta","catalog:gamma"],"safety_flags":["provider not sent"]}],"gap_notes":["No benchmark separates the two skills."],"blocker_notes":[],"evidence_references":[{"title":"Similar grouping","detail":"Beta and Gamma grouped from local catalog evidence.","source":"knowledge.groupSimilarSkills","agent":"claude-code"}],"prompt_request":{"enabled":false,"request_kind":"similar_skill_grouping","summary":"Provider explanation is copy-only and preview-gated.","draft_copy_only":true},"safety_flags":{"provider_request_sent":false,"write_back_allowed":false,"write_actions_available":false,"script_execution_allowed":false,"execution_actions_available":false,"config_mutation_allowed":false,"snapshot_created":false,"triage_mutation_allowed":false,"credential_accessed":false,"raw_prompt_persisted":false,"raw_response_persisted":false,"raw_trace_persisted":false,"cloud_sync_enabled":false,"telemetry_enabled":false,"raw_secret_returned":false,"notes":["provider not sent"]}}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: knowledge.groupSimilarSkills"}}'
            ;;
          *\\"knowledge.buildCapabilityTaxonomy\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"generated_by":"local-v2.54","catalog_available":true,"filters":{"agent":"claude-code","limit":20,"include_gaps":true},"summary":{"domain_count":1,"capability_count":2,"skill_count":3,"agent_count":1,"gap_count":1,"blocker_count":0,"summary":"Audit capabilities are covered but benchmark evidence is thin."},"coverage_by_agent":[{"agent":"claude-code","skill_count":3,"capability_count":2,"coverage_state":"covered","notes":["Release audit is covered."]}],"domains":[{"domain_id":"audit","name":"Audit workflows","summary":"Local audit and release review skills.","capability_count":2,"skill_count":3,"coverage_by_agent":[{"agent":"claude-code","skill_count":3,"capability_count":2,"coverage_state":"covered"}],"capabilities":[{"capability_id":"release-audit","name":"Release audit","summary":"Prepare local release audit evidence.","keywords":["audit","release"],"tools":["rg"],"rules":["permissions.network-declared"],"risk_tags":["local-only"],"representative_skills":[{"instance_id":"beta","definition_id":"def.beta","skill_name":"Beta","agent":"claude-code","scope":"agent-project","enabled":true,"state":"loaded","quality_score":82,"readiness_score":74,"reasons":["Purpose maps to release audit."],"evidence_refs":["catalog:beta"],"safety_flags":["provider not sent"]}],"evidence_refs":["catalog:beta"],"safety_flags":["provider not sent"]}],"gap_notes":["No imported trace covers release audit."],"blocker_notes":[],"evidence_refs":["domain:audit"],"safety_flags":["provider not sent"]}],"gap_notes":["Codex has no equivalent audit capability."],"blocker_notes":[],"evidence_references":[{"title":"Capability taxonomy","detail":"Capabilities derived from local catalog evidence.","source":"knowledge.buildCapabilityTaxonomy","agent":"claude-code"}],"prompt_request":{"enabled":false,"request_kind":"capability_taxonomy","summary":"Provider explanation is copy-only and preview-gated.","draft_copy_only":true},"safety_flags":{"provider_request_sent":false,"write_back_allowed":false,"write_actions_available":false,"script_execution_allowed":false,"execution_actions_available":false,"config_mutation_allowed":false,"snapshot_created":false,"triage_mutation_allowed":false,"credential_accessed":false,"raw_prompt_persisted":false,"raw_response_persisted":false,"raw_trace_persisted":false,"cloud_sync_enabled":false,"telemetry_enabled":false,"raw_secret_returned":false,"notes":["provider not sent"]}}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: knowledge.buildCapabilityTaxonomy"}}'
            ;;
          *\\"workspace.checkReadiness\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"generated_by":"local-v2.55","catalog_available":true,"filters":{"task":"Prepare local release audit work.","agent":"claude-code","limit":40,"include_checklist":true,"include_capabilities":true},"summary":{"overall_state":"partial","readiness_score":78,"checklist_count":2,"ready_count":1,"partial_count":1,"blocked_count":0,"agent_count":2,"capability_count":2,"gap_count":1,"blocker_count":0,"summary":"Workspace is partially ready for release audit work."},"checklist_rows":[{"check_id":"release-audit","title":"Release audit skill enabled","status":"ready","severity":"info","agent":"claude-code","capability":"Release audit","summary":"Beta is enabled and project scoped.","required_skills":["Beta"],"matched_skills":[{"instance_id":"beta","definition_id":"def.beta","skill_name":"Beta","agent":"claude-code","scope":"agent-project","enabled":true,"state":"loaded","quality_score":82,"readiness_score":78,"reasons":["Project-scoped audit coverage."],"evidence_refs":["catalog:beta"],"safety_flags":["provider not sent"]}],"gaps":[],"blockers":[],"evidence_refs":["catalog:beta"],"safety_flags":["provider not sent"]},{"check_id":"codex-audit","title":"Codex release audit route","status":"partial","severity":"warning","agent":"codex","capability":"Release audit","summary":"Codex lacks project-scoped coverage.","required_skills":["Release audit"],"matched_skills":[],"gaps":["No Codex project-scoped release audit skill."],"blockers":[],"evidence_refs":["catalog:gamma"],"safety_flags":["provider not sent"]}],"agent_rows":[{"agent":"claude-code","display_name":"Claude Code","readiness_score":86,"readiness_state":"ready","enabled_skill_count":3,"required_skill_count":2,"matched_skill_count":2,"gap_count":0,"blocker_count":0,"notes":["Project skills are scoped correctly."],"evidence_refs":["agent:claude-code"]},{"agent":"codex","display_name":"Codex","readiness_score":62,"readiness_state":"partial","enabled_skill_count":1,"required_skill_count":2,"matched_skill_count":1,"gap_count":1,"blocker_count":0,"notes":["No project-scoped Codex release audit skill."],"evidence_refs":["agent:codex"]}],"capability_rows":[{"capability_id":"release-audit","domain":"Release & Validation","capability":"Release audit","readiness_state":"partial","readiness_score":78,"agent_coverage":[{"agent":"claude-code","skill_count":2,"capability_count":1,"coverage_state":"covered"},{"agent":"codex","skill_count":0,"capability_count":1,"coverage_state":"gap"}],"representative_skills":[{"instance_id":"beta","definition_id":"def.beta","skill_name":"Beta","agent":"claude-code","scope":"agent-project","enabled":true,"state":"loaded","readiness_score":78}],"gap_notes":["No Codex route is enabled."],"blocker_notes":[],"evidence_refs":["capability:release-audit"]}],"gap_notes":["Codex lacks a project-scoped release audit skill."],"blocker_notes":[],"evidence_references":[{"title":"Workspace readiness","detail":"Derived from local catalog evidence.","source":"workspace.checkReadiness","agent":"claude-code"}],"prompt_request":{"enabled":false,"request_kind":"workspace_readiness","summary":"Provider explanation is copy-only and preview-gated.","draft_copy_only":true},"safety_flags":{"provider_request_sent":false,"write_back_allowed":false,"write_actions_available":false,"script_execution_allowed":false,"execution_actions_available":false,"config_mutation_allowed":false,"snapshot_created":false,"triage_mutation_allowed":false,"credential_accessed":false,"raw_prompt_persisted":false,"raw_response_persisted":false,"raw_trace_persisted":false,"cloud_sync_enabled":false,"telemetry_enabled":false,"raw_secret_returned":false,"notes":["provider not sent"]}}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: workspace.checkReadiness"}}'
            ;;
          *\\"remediation.plan\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"generated_by":"local-v2.56","catalog_available":true,"filters":{"task":"Prepare local release audit work.","agent":"claude-code","limit":20,"include_guidance_only":true},"summary":{"total_count":2,"critical_count":0,"high_count":1,"medium_count":1,"low_count":0,"quick_win_count":1,"blocker_count":1,"gap_count":1,"ambiguity_count":1,"drift_count":1,"summary":"Review the missing Codex route before tuning duplicate audit skills."},"priority_rows":[{"id":"high","priority":"high","title":"High priority","count":1,"rationale":"Blocks release audit coverage.","evidence_refs":["workspace:codex-gap"]},{"id":"medium","priority":"medium","title":"Medium priority","count":1,"rationale":"Reduces routing ambiguity.","evidence_refs":["similar:audit"]}],"plan_items":[{"item_id":"plan-1","title":"Add Codex release audit coverage","priority":"high","category":"gap","status":"guidance_only","agent":"codex","capability":"Release audit","skill":{"instance_id":"beta","definition_id":"def.beta","skill_name":"Beta","agent":"claude-code","scope":"agent-project","enabled":true,"state":"loaded","readiness_score":78},"rationale":"Workspace readiness reports no Codex project route.","suggested_action":"Open Workspace Readiness and review the Codex gap.","guidance_only":true,"next_area":"Workspace Readiness","expected_impact":"Improves cross-agent readiness for release audit tasks.","gap_notes":["Codex lacks project-scoped audit coverage."],"blocker_notes":[],"evidence_refs":["workspace:codex-gap"],"safety_flags":["provider not sent","guidance only"]},{"item_id":"plan-2","title":"Review duplicate audit wording","priority":"medium","category":"routing_ambiguity","status":"guidance_only","agent":"claude-code","capability":"Release audit","rationale":"Similar grouping found overlapping audit skills.","suggested_action":"Open Similar Skill Grouping and compare the duplicate routes.","guidance_only":true,"next_area":"Similar Skill Grouping","expected_impact":"Clarifies routing confidence without writing files.","gap_notes":[],"blocker_notes":["No automatic write/apply path is exposed."],"evidence_refs":["similar:audit"],"safety_flags":["provider not sent","guidance only"]}],"gap_notes":["Codex lacks a project-scoped release audit skill."],"blocker_notes":["No automatic write/apply path is exposed."],"evidence_references":[{"title":"Remediation planner","detail":"Derived from local workspace readiness.","source":"remediation.plan","agent":"codex"}],"prompt_request":{"enabled":false,"request_kind":"remediation_plan","summary":"Provider explanation is not sent.","draft_copy_only":true},"safety_flags":{"provider_request_sent":false,"write_back_allowed":false,"write_actions_available":false,"script_execution_allowed":false,"execution_actions_available":false,"config_mutation_allowed":false,"snapshot_created":false,"triage_mutation_allowed":false,"credential_accessed":false,"raw_prompt_persisted":false,"raw_response_persisted":false,"raw_trace_persisted":false,"cloud_sync_enabled":false,"telemetry_enabled":false,"raw_secret_returned":false,"notes":["provider not sent","guidance only"]}}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: remediation.plan"}}'
            ;;
          *\\"remediation.previewDrafts\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"generated_by":"local-v2.57","catalog_available":true,"filters":{"task":"Prepare local release audit work.","agent":"claude-code","limit":20},"summary":{"total_count":2,"frontmatter_count":1,"description_count":0,"permissions_count":1,"dependency_count":0,"policy_count":0,"blocker_count":1,"copy_only_count":2,"summary":"Two copy-only remediation drafts are available for review."},"draft_items":[{"draft_id":"draft-frontmatter","title":"Declare network permission","draft_type":"frontmatter","agent":"claude-code","affected_skill":{"instance_id":"beta","definition_id":"def.beta","skill_name":"Beta","agent":"claude-code","scope":"agent-project","enabled":true,"state":"loaded","readiness_score":78},"finding_id":"finding-beta","rule_id":"permissions.network-declared","current_text":"permissions: {}","proposed_text":"permissions:\\n  network: true","rationale":"Finding reports undeclared network access.","confidence_score":82,"confidence_band":"High","copy_label":"Copy YAML","edit_guidance":"Paste into SKILL.md frontmatter after manual review.","evidence_refs":["finding:permissions.network-declared"],"blocker_notes":["Review network intent before editing."],"safety_flags":["copy only","provider not sent"]},{"draft_id":"draft-permissions","title":"Add human confirmation note","draft_type":"permissions","agent":"claude-code","affected_skill":{"instance_id":"beta","definition_id":"def.beta","skill_name":"Beta","agent":"claude-code","scope":"agent-project","enabled":true,"state":"loaded","readiness_score":78},"finding_id":"finding-exec","rule_id":"permissions.exec-needs-human","current_text":"Run local commands as needed.","proposed_text":"Ask the user to confirm before running local commands.","rationale":"Execution-capable guidance must remain explicitly human-confirmed.","confidence_score":76,"confidence_band":"Medium","copy_label":"Copy sentence","edit_guidance":"Review wording in the skill body; this preview does not write files.","evidence_refs":["finding:permissions.exec-needs-human"],"blocker_notes":[],"safety_flags":["copy only","provider not sent"]}],"gap_notes":["No dependency draft needed."],"blocker_notes":["No automatic write/apply path is exposed."],"evidence_references":[{"title":"Fix preview","detail":"Derived from local findings.","source":"remediation.previewDrafts","agent":"claude-code"}],"prompt_request":{"enabled":false,"request_kind":"remediation_preview_drafts","summary":"Provider explanation is not sent.","draft_copy_only":true},"safety_flags":{"provider_request_sent":false,"write_back_allowed":false,"write_actions_available":false,"script_execution_allowed":false,"execution_actions_available":false,"config_mutation_allowed":false,"snapshot_created":false,"triage_mutation_allowed":false,"credential_accessed":false,"raw_prompt_persisted":false,"raw_response_persisted":false,"raw_trace_persisted":false,"cloud_sync_enabled":false,"telemetry_enabled":false,"raw_secret_returned":false,"notes":["provider not sent","copy only"]}}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: remediation.previewDrafts"}}'
            ;;
          *\\"remediation.previewImpact\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"generated_by":"local-v2.58","catalog_available":true,"filters":{"task":"Prepare local release audit work.","agent":"claude-code","limit":20},"summary":{"total_count":6,"task_impact_count":1,"agent_impact_count":1,"skill_impact_count":1,"risk_delta_count":1,"snapshot_rollback_count":1,"blocker_count":1,"gap_count":1,"no_write_count":1,"summary":"Impact preview is read-only and shows where remediation would improve routing confidence."},"impact_rows":[{"row_id":"impact-overall","title":"Overall readiness improves","category":"overall","impact":"Improves release audit readiness without writing files.","rationale":"Derived from remediation plan and workspace readiness.","severity":"info","evidence_refs":["remediation:plan"],"safety_flags":["provider not sent","no write"]}],"task_impact_rows":[{"row_id":"task-release-audit","title":"Release audit route gets clearer","category":"task","before":"Partial","after":"Ready","delta":"+12 readiness","impact":"The selected task has a stronger local route.","rationale":"Routing confidence and workspace readiness both point to Beta.","severity":"medium","evidence_refs":["task:release-audit"]}],"agent_impact_rows":[{"row_id":"agent-claude","title":"Claude Code remains the recommended agent","category":"agent","agent":"claude-code","delta":"+8 comparison","impact":"No cross-agent write path is needed.","severity":"low"}],"skill_impact_rows":[{"row_id":"skill-beta","title":"Beta benefits from clearer permissions","category":"skill","agent":"claude-code","skill":{"instance_id":"beta","definition_id":"def.beta","skill_name":"Beta","agent":"claude-code","scope":"agent-project","enabled":true,"state":"loaded","readiness_score":78},"impact":"The permission finding would become easier to review.","severity":"medium"}],"risk_delta_rows":[{"row_id":"risk-network","title":"Network declaration risk drops","category":"risk_delta","before":"Medium","after":"Low","delta":"-1 risk band","impact":"Manual review remains required.","severity":"warning"}],"snapshot_rollback_rows":[{"row_id":"rollback-none","title":"No snapshot is created","category":"snapshot_rollback","impact":"Rollback remains a plan note only because no write happens.","severity":"info","safety_flags":["snapshot not created"]}],"gap_notes":["Codex still lacks project-scoped coverage."],"blocker_notes":["No apply/write path is exposed."],"evidence_references":[{"title":"Impact preview","detail":"Derived from local remediation evidence.","source":"remediation.previewImpact","agent":"claude-code"}],"prompt_request":{"enabled":false,"request_kind":"remediation_preview_impact","summary":"Provider explanation is not sent.","draft_copy_only":true},"safety_flags":{"provider_request_sent":false,"write_back_allowed":false,"write_actions_available":false,"script_execution_allowed":false,"execution_actions_available":false,"config_mutation_allowed":false,"snapshot_created":false,"triage_mutation_allowed":false,"credential_accessed":false,"raw_prompt_persisted":false,"raw_response_persisted":false,"raw_trace_persisted":false,"cloud_sync_enabled":false,"telemetry_enabled":false,"raw_secret_returned":false,"notes":["provider not sent","preview only","no write"]}}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: remediation.previewImpact"}}'
            ;;
          *\\"cleanup.planGuidedFlow\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"generated_by":"local-v2.67","catalog_available":true,"filters":{"task":"Prepare local release audit work.","agent":"claude-code","selected_skill_id":"beta","selected_skill_name":"Beta","selected_skill_agent":"claude-code","project_root":"/tmp/project","current_cwd":"/tmp/project","workspace":"Fixture Project","limit":12,"include_issue_groups":true,"include_safe_next_actions":true,"include_recorded_steps":true,"include_evidence":true,"include_safety_flags":true},"summary":{"step_count":2,"issue_group_count":1,"safe_action_count":2,"recorded_step_count":1,"recommended_step_count":1,"gap_count":1,"blocker_count":1,"summary":"Review the permission finding, inspect impact, then record local metadata."},"flow_steps":[{"step_id":"step-review-permission","title":"Review network permission finding","kind":"finding_review","status":"preview_only","priority":"high","order":1,"action_label":"Open Findings and Fix Preview Drafts","review_area":"Fix Preview Drafts","agent":"claude-code","skill":{"instance_id":"beta","definition_id":"def.beta","skill_name":"Beta","agent":"claude-code","scope":"agent-project","enabled":true,"state":"loaded","readiness_score":78},"rationale":"Finding and draft preview both point to manual permission review.","detail":"No file write happens from Guided Cleanup.","recommended":true,"app_local_record_only":true,"evidence_refs":["finding:permissions.network-declared"],"gap_notes":["Codex route still lacks equivalent coverage."],"blocker_notes":["No apply/write path is exposed."],"safety_flags":["provider not sent","metadata only","no write"]},{"step_id":"step-impact","title":"Inspect impact preview","kind":"impact_preview","status":"preview_only","priority":"medium","action_label":"Open Impact Preview","recommended":false,"app_local_record_only":true}],"issue_groups":[{"group_id":"group-permissions","title":"Permission clarity","category":"finding","severity":"high","status":"open","count":1,"summary":"One permission finding needs human review.","issue_refs":["finding:permissions.network-declared"],"safe_next_action_ids":["open-fix-preview"],"evidence_refs":["finding:permissions.network-declared"],"safety_flags":["no write"]}],"safe_next_actions":[{"action_id":"open-fix-preview","title":"Open Fix Preview Drafts","kind":"existing_safe_entry","review_area":"Fix Preview Drafts","detail":"Use the existing copy-only draft surface.","requires_existing_safe_entry":true,"app_local_only":true,"can_apply_fix":false,"evidence_refs":["draft:permissions"]},{"action_id":"open-history","title":"Open Remediation History","kind":"app_local_metadata","review_area":"Remediation History","detail":"Record local audit metadata only.","requires_existing_safe_entry":true,"app_local_only":true,"can_apply_fix":false}],"recorded_steps":[{"record_id":"guided-record-1","step_id":"step-review-permission","title":"Permission review recorded","status":"recorded","decision":"reviewed","source_method":"cleanup.recordGuidedStep","recorded_at":"2026-06-12T08:00:00Z","note":"Metadata only.","metadata_redacted":true,"app_local_only":true,"evidence_refs":["guided_step:step-review-permission"],"safety_flags":["app-local metadata only","no write"]}],"gap_notes":["Codex lacks project-scoped release audit coverage."],"blocker_notes":["Actual edits remain in existing preview-first flows."],"evidence_references":[{"title":"Guided cleanup","detail":"Derived from local cleanup/remediation evidence.","source":"cleanup.planGuidedFlow","agent":"claude-code"}],"prompt_request":{"enabled":false,"request_kind":"guided_cleanup_flow","summary":"No provider request is prepared or sent.","draft_copy_only":true,"redacted":true},"safety_flags":{"provider_request_sent":false,"write_back_allowed":false,"write_actions_available":false,"script_execution_allowed":false,"execution_actions_available":false,"config_mutation_allowed":false,"snapshot_created":false,"triage_mutation_allowed":false,"credential_accessed":false,"raw_prompt_persisted":false,"raw_response_persisted":false,"raw_trace_persisted":false,"cloud_sync_enabled":false,"telemetry_enabled":false,"raw_secret_returned":false,"notes":["provider not sent","planning read-only"]}}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: cleanup.planGuidedFlow"}}'
            ;;
          *\\"cleanup.recordGuidedStep\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"recorded":true,"generated_by":"local-v2.67","app_local_only":true,"metadata_redacted":true,"record":{"record_id":"guided-record-native","step_id":"step-review-permission","title":"Native guided cleanup metadata","status":"recorded","decision":"reviewed","source_method":"analysis.guidedCleanupFlow.ui","recorded_at":"2026-06-12T08:05:00Z","note":"Recorded app-local metadata only; no cleanup was applied.","metadata_redacted":true,"app_local_only":true,"evidence_refs":["guided_step:step-review-permission"],"safety_flags":["app-local metadata only","no write","provider not sent"]},"summary":{"recorded_step_count":1,"summary":"Recorded one guided cleanup step."},"message":"Guided cleanup metadata recorded.","evidence_references":[{"title":"Guided record","detail":"Stored app-local metadata only.","source":"cleanup.recordGuidedStep"}],"prompt_request":{"enabled":false,"request_kind":"guided_cleanup_record","summary":"No provider request is sent.","draft_copy_only":true},"safety_flags":{"provider_request_sent":false,"write_back_allowed":false,"write_actions_available":false,"script_execution_allowed":false,"execution_actions_available":false,"config_mutation_allowed":false,"snapshot_created":false,"triage_mutation_allowed":false,"credential_accessed":false,"raw_prompt_persisted":false,"raw_response_persisted":false,"raw_trace_persisted":false,"cloud_sync_enabled":false,"telemetry_enabled":false,"raw_secret_returned":false,"notes":["app-local metadata only","no write"]}}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: cleanup.recordGuidedStep"}}'
            ;;
          *\\"remediation.batchReview\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"generated_by":"local-v2.59","catalog_available":true,"filters":{"task":"Prepare local release audit work.","agent":"claude-code","limit":30,"review_dimensions":["task","risk","rule","agent","workspace"],"risk_levels":["medium","high"],"rule_ids":["permissions.network-declared"],"include_blocked":true},"summary":{"total_count":3,"group_count":2,"task_count":1,"risk_count":1,"rule_count":1,"agent_count":1,"workspace_count":1,"blocker_count":1,"gap_count":1,"safe_next_step_count":2,"summary":"Batch review groups remediation candidates before any write-capable flow."},"review_groups":[{"group_id":"risk-rules","title":"Risk and rule review","category":"risk_rule","priority":"high","summary":"Review permission findings before any manual edit.","safe_next_step_labels":["Open Findings","Open Fix Preview Drafts"],"items":[{"item_id":"rule-network","title":"Network permission declaration","category":"rule","priority":"high","status":"preview_only","agent":"claude-code","workspace":"Fixture Project","rule_id":"permissions.network-declared","risk_level":"medium","task_text":"Prepare local release audit work.","skill":{"instance_id":"beta","definition_id":"def.beta","skill_name":"Beta","agent":"claude-code","scope":"agent-project","enabled":true,"state":"loaded","readiness_score":78},"rationale":"Finding and draft preview both point to manual permission review.","safe_next_step_label":"Open Fix Preview Drafts","review_area":"Fix Preview Drafts","evidence_refs":["finding:permissions.network-declared"],"gap_notes":["Codex route still lacks equivalent coverage."],"blocker_notes":["No apply/write path is exposed."],"safety_flags":["provider not sent","preview only","no write"]}],"evidence_refs":["finding:permissions.network-declared"],"gap_notes":["Codex route still lacks equivalent coverage."],"blocker_notes":["No apply/write path is exposed."],"safety_flags":["preview only"]}],"review_items":[{"item_id":"workspace-codex","title":"Codex workspace gap","category":"workspace","priority":"medium","status":"preview_only","agent":"codex","workspace":"Fixture Project","rationale":"Workspace readiness reports a partial Codex route.","safe_next_step_label":"Open Workspace Readiness","review_area":"Workspace Readiness","evidence_refs":["workspace:codex-gap"]}],"safe_next_step_labels":["Open Remediation Planner","Open Impact Preview"],"gap_notes":["Codex lacks project-scoped release audit coverage."],"blocker_notes":["No batch apply path is available from review."],"evidence_references":[{"title":"Batch review","detail":"Derived from local remediation evidence.","source":"remediation.batchReview","agent":"claude-code"}],"prompt_request":{"enabled":false,"request_kind":"remediation_batch_review","summary":"Provider explanation is not sent.","draft_copy_only":true},"safety_flags":{"provider_request_sent":false,"write_back_allowed":false,"write_actions_available":false,"script_execution_allowed":false,"execution_actions_available":false,"config_mutation_allowed":false,"snapshot_created":false,"triage_mutation_allowed":false,"credential_accessed":false,"raw_prompt_persisted":false,"raw_response_persisted":false,"raw_trace_persisted":false,"cloud_sync_enabled":false,"telemetry_enabled":false,"raw_secret_returned":false,"notes":["provider not sent","preview only","no write"]}}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: remediation.batchReview"}}'
            ;;
          *\\"remediation.listHistory\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"generated_by":"local-v2.60","catalog_available":true,"filters":{"task":"Prepare local release audit work.","agent":"claude-code","limit":30,"rule_ids":["permissions.network-declared"],"risk_levels":["medium"],"decisions":["reviewed"],"statuses":["recorded"]},"summary":{"total_count":2,"recorded_count":2,"recurrence_count":1,"reopened_count":1,"readiness_improvement_count":1,"decision_count":1,"status_count":1,"blocker_count":1,"gap_count":1,"summary":"Local remediation history shows one recurring permission review and one readiness improvement."},"records":[{"record_id":"hist-network","title":"Network permission reviewed","category":"rule","decision":"reviewed","status":"recorded","agent":"claude-code","workspace":"Fixture Project","rule_id":"permissions.network-declared","risk_level":"medium","task_text":"Prepare local release audit work.","review_area":"Fix Preview Drafts","source_method":"remediation.previewDrafts","skill":{"instance_id":"beta","definition_id":"def.beta","skill_name":"Beta","agent":"claude-code","scope":"agent-project","enabled":true,"state":"loaded","readiness_score":78},"recurrence_count":1,"reopened_count":1,"readiness_improvement":"+8 readiness","recorded_at":"2026-06-12T08:00:00Z","rationale":"Finding and copy-only draft were reviewed locally.","note":"Audit-only record; no remediation was applied.","evidence_refs":["finding:permissions.network-declared"],"gap_notes":["Codex route still lacks equivalent coverage."],"blocker_notes":["No apply/write path is exposed."],"safety_flags":["local audit only","no write","provider not sent"]}],"decisions":["reviewed"],"statuses":["recorded"],"gap_notes":["Workspace gap remains visible."],"blocker_notes":["No direct write/apply path is exposed."],"evidence_references":[{"title":"History","detail":"Derived from app-local remediation audit records.","source":"remediation.listHistory","agent":"claude-code"}],"prompt_request":{"enabled":false,"request_kind":"remediation_history","summary":"Provider explanation is not sent.","draft_copy_only":true},"safety_flags":{"provider_request_sent":false,"write_back_allowed":false,"write_actions_available":false,"script_execution_allowed":false,"execution_actions_available":false,"config_mutation_allowed":false,"snapshot_created":false,"triage_mutation_allowed":false,"credential_accessed":false,"raw_prompt_persisted":false,"raw_response_persisted":false,"raw_trace_persisted":false,"cloud_sync_enabled":false,"telemetry_enabled":false,"raw_secret_returned":false,"notes":["app-local history","provider not sent","no write"]}}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: remediation.listHistory"}}'
            ;;
          *\\"remediation.recordHistory\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"recorded":true,"record":{"record_id":"hist-native-audit","title":"Native Analysis local audit","category":"audit","decision":"reviewed","status":"recorded","agent":"claude-code","workspace":"Fixture Project","task_text":"Prepare local release audit work.","review_area":"Remediation History","source_method":"analysis.remediationHistory.ui","skill":{"instance_id":"beta","definition_id":"def.beta","skill_name":"Beta","agent":"claude-code","scope":"agent-project","enabled":true,"state":"loaded","readiness_score":78},"recorded_at":"2026-06-12T08:05:00Z","rationale":"User recorded local remediation audit metadata from native Analysis.","note":"Recorded app-local audit metadata only; no remediation was applied.","evidence_refs":["selected_skill:beta"],"safety_flags":["local audit only","no write","provider not sent"]},"summary":{"total_count":1,"recorded_count":1,"summary":"Recorded one local remediation audit entry."},"message":"Local remediation history recorded.","evidence_references":[{"title":"History record","detail":"Stored app-local audit metadata only.","source":"remediation.recordHistory","agent":"claude-code"}],"prompt_request":{"enabled":false,"request_kind":"remediation_history_record","summary":"Provider explanation is not sent.","draft_copy_only":true},"safety_flags":{"provider_request_sent":false,"write_back_allowed":false,"write_actions_available":false,"script_execution_allowed":false,"execution_actions_available":false,"config_mutation_allowed":false,"snapshot_created":false,"triage_mutation_allowed":false,"credential_accessed":false,"raw_prompt_persisted":false,"raw_response_persisted":false,"raw_trace_persisted":false,"cloud_sync_enabled":false,"telemetry_enabled":false,"raw_secret_returned":false,"notes":["app-local history","provider not sent","no write"]}}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: remediation.recordHistory"}}'
            ;;
          *\\"task.listBenchmarks\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"benchmarks":[{"benchmark_id":"bench-1","task_text":"Route a local audit task.","expected_skill":{"instance_id":"beta","name":"Beta","agent":"claude-code"},"acceptable_skills":[{"instance_id":"beta","name":"Beta","agent":"claude-code"},{"instance_id":"alpha","name":"Alpha","agent":"claude-code"}]}]}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: task.listBenchmarks"}}'
            ;;
          *\\"task.saveBenchmark\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"benchmark":{"benchmark_id":"bench-2","task_text":"Route a local audit release note task.","expected_skill":{"instance_id":"beta","name":"Beta","agent":"claude-code"},"acceptable_skills":[{"instance_id":"beta","name":"Beta","agent":"claude-code"}]}}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: task.saveBenchmark"}}'
            ;;
          *\\"task.evaluateBenchmarks\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"evaluated_count":2,"matched_count":1,"acceptable_count":2,"average_score":82,"evaluations":[{"benchmark_id":"bench-2","task":"Route a local audit release note task.","match_status":"matched","top_route":{"instance_id":"beta","name":"Beta","agent":"claude-code","confidence_score":88,"band":"High","match_reasons":["Description matches local audit."]},"expected_covered":true,"acceptable_covered":true,"blockers":[],"gaps":["No release-note-specific examples."],"safety_flags":["provider not sent"],"evidence_references":[{"title":"Routing","detail":"Beta ranked first.","source":"local"}]},{"benchmark_id":"bench-1","task":"Route a local audit task.","match_status":"acceptable","top_route":{"instance_id":"alpha","name":"Alpha","agent":"claude-code","confidence_score":76,"band":"Medium","match_reasons":["Same-agent fallback."]},"expected_covered":false,"acceptable_covered":true,"blockers":[],"gaps":[],"safety_flags":["provider not sent"],"evidence":["Alpha is acceptable."]}],"blockers":[],"gaps":["One benchmark missed exact expected route."],"evidence_references":[{"title":"Benchmark","detail":"Two local tasks evaluated.","source":"task.evaluateBenchmarks"}],"safety_flags":{"provider_request_sent":false,"write_back_allowed":false,"write_actions_available":false,"script_execution_allowed":false,"execution_actions_available":false,"config_mutation_allowed":false,"snapshot_created":false,"triage_mutation_allowed":false,"credential_accessed":false,"raw_secret_returned":false}}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: task.evaluateBenchmarks"}}'
            ;;
          *\\"task.saveRoutingBaseline\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"baseline_id":"baseline-1","benchmark_count":1,"average_score":88,"matched_count":1,"acceptable_count":1,"summary":"Saved local routing baseline from current benchmarks.","safety_flags":{"provider_request_sent":false,"write_back_allowed":false,"write_actions_available":false,"script_execution_allowed":false,"execution_actions_available":false,"config_mutation_allowed":false,"snapshot_created":false,"triage_mutation_allowed":false,"credential_accessed":false,"raw_secret_returned":false}}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: task.saveRoutingBaseline"}}'
            ;;
          *\\"task.detectRoutingRegression\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"baseline_id":"baseline-1","benchmark_count":1,"regression_count":1,"improved_count":0,"unchanged_count":0,"average_score_delta":-16,"match_status_changed_count":1,"top_route_changed_count":1,"regressions":[{"benchmark_id":"bench-1","task":"Route a local audit task.","regression_type":"expected_to_acceptable","previous_match_status":"matched","current_match_status":"acceptable","previous_score":88,"current_score":72,"score_delta":-16,"previous_top_route":{"instance_id":"beta","name":"Beta","agent":"claude-code","confidence_score":88,"band":"High"},"current_top_route":{"instance_id":"alpha","name":"Alpha","agent":"claude-code","confidence_score":72,"band":"Medium"},"top_route_changed":true,"new_blockers":["Expected route dropped below top rank."],"new_gaps":["Release-note examples still missing."],"safety_flags":["provider not sent"],"evidence_references":[{"title":"Regression","detail":"Top route changed from Beta to Alpha.","source":"task.detectRoutingRegression"}]}],"new_blockers":["Expected route dropped below top rank."],"new_gaps":["Release-note examples still missing."],"evidence_references":[{"title":"Baseline","detail":"Compared against baseline-1.","source":"task.detectRoutingRegression"}],"safety_flags":{"provider_request_sent":false,"write_back_allowed":false,"write_actions_available":false,"script_execution_allowed":false,"execution_actions_available":false,"config_mutation_allowed":false,"snapshot_created":false,"triage_mutation_allowed":false,"credential_accessed":false,"raw_secret_returned":false}}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: task.detectRoutingRegression"}}'
            ;;
          *\\"routing.accuracyDashboard\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"generated_by":"local-v2.49","catalog_available":true,"filters":{"agent":"claude-code","window_days":30,"limit":20,"include_history":true,"include_recent_evidence":true},"summary":{"trace_count":11,"hit_count":7,"miss_count":2,"wrong_pick_count":1,"ambiguous_count":1,"unknown_count":0,"benchmark_count":5,"benchmark_matched_count":4,"benchmark_gap_count":3,"regression_count":1,"missing_benchmark_count":2,"accuracy_rate":0.636,"known_outcome_rate":1.0,"summary":"Seven of eleven imported traces hit the expected route."},"agent_rows":[{"agent":"claude-code","trace_count":11,"outcomes":{"hit":7,"miss":2,"wrong_pick":1,"ambiguous":1,"unknown":0},"accuracy_rate":0.636,"benchmark_count":5,"benchmark_matched_count":4,"benchmark_gap_count":3,"regression_count":1,"recent_evidence_count":2,"notes":["One expected route has no benchmark."]}],"history_rows":[{"unix_day":1781136000,"trace_count":11,"outcomes":{"hit":7,"miss":2,"wrong_pick":1,"ambiguous":1,"unknown":0},"accuracy_rate":0.636}],"gap_issue_rows":[{"source":"trace","severity":"warning","agent":"openclaw","title":"Missing trace coverage","detail":"No OpenClaw traces in the selected window.","evidence_refs":["trace:none"]}],"recent_evidence_rows":[{"source":"trace.importLocal","agent":"claude-code","title":"Trace","outcome":"hit","detail":"Beta matched expected route in trace-1.","evidence_refs":["trace-1"],"observed_at":1781136000000}],"blocker_notes":["One expected route has no benchmark."],"prompt_request":{"enabled":false,"request_kind":"routing_accuracy","summary":"Provider explanation is copy-only and preview-gated.","draft_copy_only":true},"safety_flags":{"provider_request_sent":false,"write_back_allowed":false,"script_execution_allowed":false,"config_mutation_allowed":false,"snapshot_created":false,"triage_mutation_allowed":false,"credential_accessed":false,"raw_prompt_persisted":false,"raw_response_persisted":false,"raw_trace_persisted":false,"cloud_sync_enabled":false,"telemetry_enabled":false,"raw_secret_returned":false,"notes":["provider not sent"]}}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: routing.accuracyDashboard"}}'
            ;;
          *\\"analysis.detectStaleDrift\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"generated_by":"local-v2.51","catalog_available":true,"filters":{"agent":"claude-code","limit":40,"include_readiness_impact":true},"summary":{"stale_count":2,"drift_count":1,"candidate_count":3,"affected_agent_count":2,"readiness_impact_count":1,"gap_issue_count":1,"high_risk_count":1,"summary":"Beta appears stale and Gamma has routing drift evidence."},"stale_drift_rows":[{"id":"stale-beta","kind":"stale","severity":"warning","agent":"claude-code","skill":{"instance_id":"beta","definition_id":"def.beta","skill_name":"Beta","scope":"agent-project","state":"loaded","enabled":true},"title":"Beta appears stale","summary":"Beta has not appeared in recent trace or benchmark evidence.","last_seen":"2026-05-01","current_signal":"No recent trace hits.","expected_signal":"Expected route remains Beta.","confidence":82,"reasons":["No trace hits in the current window."],"signals":["Benchmark age exceeds threshold."],"evidence_refs":["catalog:beta","trace:none"]},{"id":"drift-gamma","kind":"drift","severity":"medium","agent":"codex","skill":{"instance_id":"gamma","definition_id":"codex:gamma","skill_name":"Gamma","scope":"agent-global","state":"loaded","enabled":true},"title":"Gamma routing drift","summary":"Imported trace wording no longer matches benchmark expectations.","current_signal":"Trace selected Gamma for a task that used to route to Beta.","expected_signal":"Benchmark expected Beta.","confidence":74,"reasons":["Top route changed in regression evidence."],"signals":["Regression baseline changed."],"evidence_refs":["regression:bench-1"]}],"readiness_impact_rows":[{"agent":"claude-code","skill_name":"Beta","severity":"warning","title":"Readiness lowered","detail":"Readiness is partial because evidence is stale.","evidence_refs":["readiness:beta"]}],"gap_issue_rows":[{"source":"trace","severity":"warning","agent":"claude-code","title":"Missing fresh evidence","detail":"No fresh trace confirms the expected route.","evidence_refs":["trace:none"]}],"evidence_references":[{"title":"Catalog freshness","detail":"Beta fingerprint is unchanged but not recently exercised.","source":"catalog","agent":"claude-code"}],"prompt_request":{"enabled":false,"request_kind":"stale_drift_detection","summary":"Provider explanation is copy-only and preview-gated.","draft_copy_only":true},"safety_flags":{"provider_request_sent":false,"write_back_allowed":false,"write_actions_available":false,"script_execution_allowed":false,"execution_actions_available":false,"config_mutation_allowed":false,"snapshot_created":false,"triage_mutation_allowed":false,"credential_accessed":false,"raw_prompt_persisted":false,"raw_response_persisted":false,"raw_trace_persisted":false,"cloud_sync_enabled":false,"telemetry_enabled":false,"raw_secret_returned":false,"notes":["provider not sent"]}}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: analysis.detectStaleDrift"}}'
            ;;
          *\\"task.deleteBenchmark\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"deleted":true,"benchmark_id":"bench-1"}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: task.deleteBenchmark"}}'
            ;;
          *\\"trace.listImports\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"records":[{"import_id":"trace-1","title":"Existing local trace","task":"Route a local audit task.","outcome":"hit","detected_skills":[{"instance_id":"beta","name":"Beta","agent":"claude-code"}],"expected_skill_names":["Beta"],"redacted_excerpt":"Assistant selected Beta from <project-root> evidence.","redaction_summary":{"status":"redacted","summary":"Local paths removed.","placeholders":["<project-root>"]},"reasons":["Detected skill matched expected skill."],"evidence_references":[{"title":"Trace","detail":"Beta appeared in route selection.","source":"trace.listImports"}],"safety_flags":["provider not sent"],"safety":{"provider_request_sent":false,"write_back_allowed":false,"write_actions_available":false,"script_execution_allowed":false,"execution_actions_available":false,"config_mutation_allowed":false,"snapshot_created":false,"triage_mutation_allowed":false,"credential_accessed":false,"raw_secret_returned":false}}]}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: trace.listImports"}}'
            ;;
          *\\"trace.importLocal\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"record":{"import_id":"trace-2","title":"Local trace","task":"Route a local audit release note task.","outcome":"wrong_pick","detected_skill_names":["Alpha"],"expected_skills":[{"instance_id":"beta","name":"Beta","agent":"claude-code"}],"redacted_excerpt":"User asked for <project-root> release notes. Assistant selected Alpha.","redaction_summary":{"status":"redacted","summary":"Secrets and local paths removed.","redacted_fields":["path"],"placeholders":["<project-root>"]},"reasons":["Detected route differs from expected skill."],"evidence_references":[{"title":"Trace","detail":"Alpha appeared in route selection.","source":"trace.importLocal"}],"safety_flags":["provider not sent"],"safety":{"provider_request_sent":false,"write_back_allowed":false,"write_actions_available":false,"script_execution_allowed":false,"execution_actions_available":false,"config_mutation_allowed":false,"snapshot_created":false,"triage_mutation_allowed":false,"credential_accessed":false,"raw_secret_returned":false}}}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: trace.importLocal"}}'
            ;;
          *\\"trace.deleteImport\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"deleted":true,"import_id":"trace-1"}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: trace.deleteImport"}}'
            ;;
          *\\"llm.prepareAction\\"*)
            if [ "$scenario" = "old-service" ]; then
              respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: llm.prepareAction"}}'
            elif [ "$scenario" = "llm-ready" ] || [ "$scenario" = "prompt-ready" ]; then
              case "$input" in
                *\\"kind\\":\\"draft_frontmatter\\"*)
                  respond '{"id":"test","ok":true,"result":{"action":"draft_frontmatter","enabled":true,"disabled_reason":null,"provider":"openai","model":"gpt-5","estimate":{"input_tokens":240,"output_tokens":180,"total_tokens":420,"estimated_cost_usd":0.0042},"confirmation_required":true}}'
                  ;;
                *)
                  respond '{"id":"test","ok":true,"result":{"action":"analyze","enabled":true,"disabled_reason":null,"provider":"openai","model":"gpt-5","estimate":{"input_tokens":240,"output_tokens":120,"total_tokens":360,"estimated_cost_usd":0.0042},"confirmation_required":true}}'
                  ;;
              esac
            else
              respond '{"id":"test","ok":true,"result":{"action":"analyze","enabled":false,"disabled_reason":"LLM is disabled.","provider":null,"model":null,"estimate":null,"confirmation_required":true}}'
            fi
            ;;
          *\\"llm.previewPrompt\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              if printf '%s' "$input" | grep -q '\\"request_kind\\":\\"routing_confidence\\"'; then
                respond '{"id":"test","ok":true,"result":{"preview_id":"routing-preview-beta","request_kind":"routing_confidence","action":"routing_confidence","scope":"selected","prompt_scope":"Selected skill routing confidence for Beta","enabled":true,"provider":"openai-compatible","model":"gpt-5","destination_host":"llm.example.com","included_fields":["task.text","skill.metadata","routing.result","analysis.comparison"],"excluded_fields":[{"name":"api_key","reason":"credential redacted"},{"name":"skill.body","reason":"raw body omitted"}],"redaction":{"status":"redacted","summary":"Secrets, raw body, and local paths removed.","redacted_fields":["api_key","path"],"placeholders":["<project-root>"]},"estimate":{"input_tokens":360,"output_tokens":170,"total_tokens":530,"estimated_cost_usd":0.0065},"confirmation_required":true,"raw_prompt_persisted":false,"raw_response_persisted":false,"draft_copy_only":true,"redacted_prompt_preview":"Explain routing confidence for Beta from redacted local evidence."}}'
              fi
              if printf '%s' "$input" | grep -q '\\"request_kind\\":\\"task_readiness\\"'; then
                respond '{"id":"test","ok":true,"result":{"preview_id":"readiness-preview-beta","request_kind":"task_readiness","action":"task_readiness","scope":"selected","prompt_scope":"Selected skill task readiness for Beta","enabled":true,"provider":"openai-compatible","model":"gpt-5","destination_host":"llm.example.com","included_fields":["task.text","skill.metadata","readiness.result","findings.summary"],"excluded_fields":[{"name":"api_key","reason":"credential redacted"},{"name":"skill.body","reason":"raw body omitted"}],"redaction":{"status":"redacted","summary":"Secrets, raw body, and local paths removed.","redacted_fields":["api_key","path"],"placeholders":["<project-root>"]},"estimate":{"input_tokens":340,"output_tokens":160,"total_tokens":500,"estimated_cost_usd":0.006},"confirmation_required":true,"raw_prompt_persisted":false,"raw_response_persisted":false,"draft_copy_only":true,"redacted_prompt_preview":"Explain task readiness for Beta from redacted local evidence."}}'
              fi
              if printf '%s' "$input" | grep -q '\\"request_kind\\":\\"quality_score\\"'; then
                respond '{"id":"test","ok":true,"result":{"preview_id":"quality-preview-beta","request_kind":"quality_score","action":"quality_score","scope":"selected","prompt_scope":"Selected skill quality score for Beta","enabled":true,"provider":"openai-compatible","model":"gpt-5","destination_host":"llm.example.com","included_fields":["skill.metadata","findings.summary","conflicts.summary","adapter.diagnostics"],"excluded_fields":[{"name":"skill.body","reason":"raw body omitted"},{"name":"api_key","reason":"credential redacted"}],"redaction":{"status":"redacted","summary":"Secrets, raw body, and local paths removed.","redacted_fields":["api_key","path"],"placeholders":["<project-root>"]},"estimate":{"input_tokens":300,"output_tokens":140,"total_tokens":440,"estimated_cost_usd":0.005},"confirmation_required":true,"raw_prompt_persisted":false,"raw_response_persisted":false,"draft_copy_only":true,"redacted_prompt_preview":"Score Beta quality from redacted local evidence."}}'
              fi
              respond '{"id":"test","ok":true,"result":{"preview_id":"prompt-preview-beta","request_kind":"action","action":"analyze","scope":"selected","prompt_scope":"Selected skill analysis for Beta","enabled":true,"provider":"openai-compatible","model":"gpt-5","destination_host":"llm.example.com","included_fields":["skill.name","findings.summary"],"excluded_fields":[{"name":"api_key","reason":"credential redacted"}],"redaction":{"status":"redacted","summary":"Secrets and local paths removed.","redacted_fields":["api_key"],"placeholders":["<project-root>"]},"estimate":{"input_tokens":240,"output_tokens":120,"total_tokens":360,"estimated_cost_usd":0.0042},"confirmation_required":true,"raw_prompt_persisted":false,"raw_response_persisted":false,"draft_copy_only":true,"redacted_prompt_preview":"Analyze Beta using catalog metadata and finding summaries only."}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: llm.previewPrompt"}}'
            ;;
          *\\"llm.confirmPromptAndSend\\"*)
            if [ "$scenario" = "prompt-ready" ]; then
              if printf '%s' "$input" | grep -q '\\"request_kind\\":\\"routing_confidence\\"'; then
                respond '{"id":"test","ok":true,"result":{"preview_id":"routing-preview-beta","status":"succeeded","message":"Provider response received.","output_text":"Copy-only routing confidence explanation for Beta.","draft_copy_only":true,"raw_prompt_persisted":false,"raw_response_persisted":false,"write_back_allowed":false,"script_execution_allowed":false,"audit_metadata":{"request_id":"audit-routing-1","status":"succeeded","provider":"openai-compatible","model":"gpt-5","destination_host":"llm.example.com","redaction_applied":true,"raw_prompt_persisted":false,"raw_response_persisted":false,"input_tokens":360,"output_tokens":100}}}'
              fi
              if printf '%s' "$input" | grep -q '\\"request_kind\\":\\"task_readiness\\"'; then
                respond '{"id":"test","ok":true,"result":{"preview_id":"readiness-preview-beta","status":"succeeded","message":"Provider response received.","output_text":"Copy-only task readiness explanation for Beta.","draft_copy_only":true,"raw_prompt_persisted":false,"raw_response_persisted":false,"write_back_allowed":false,"script_execution_allowed":false,"audit_metadata":{"request_id":"audit-readiness-1","status":"succeeded","provider":"openai-compatible","model":"gpt-5","destination_host":"llm.example.com","redaction_applied":true,"raw_prompt_persisted":false,"raw_response_persisted":false,"input_tokens":340,"output_tokens":95}}}'
              fi
              if printf '%s' "$input" | grep -q '\\"request_kind\\":\\"quality_score\\"'; then
                respond '{"id":"test","ok":true,"result":{"preview_id":"quality-preview-beta","status":"succeeded","message":"Provider response received.","output_text":"Copy-only quality explanation for Beta.","draft_copy_only":true,"raw_prompt_persisted":false,"raw_response_persisted":false,"write_back_allowed":false,"script_execution_allowed":false,"audit_metadata":{"request_id":"audit-quality-1","status":"succeeded","provider":"openai-compatible","model":"gpt-5","destination_host":"llm.example.com","redaction_applied":true,"raw_prompt_persisted":false,"raw_response_persisted":false,"input_tokens":300,"output_tokens":90}}}'
              fi
              respond '{"id":"test","ok":true,"result":{"preview_id":"prompt-preview-beta","status":"succeeded","message":"Provider response received.","output_text":"Read-only analysis for Beta.","draft_copy_only":true,"raw_prompt_persisted":false,"raw_response_persisted":false,"write_back_allowed":false,"script_execution_allowed":false,"audit_metadata":{"request_id":"audit-prompt-1","status":"succeeded","provider":"openai-compatible","model":"gpt-5","destination_host":"llm.example.com","redaction_applied":true,"raw_prompt_persisted":false,"raw_response_persisted":false,"input_tokens":240,"output_tokens":80}}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: llm.confirmPromptAndSend"}}'
            ;;
          *\\"script.previewExecution\\"*)
            if [ "$scenario" = "script-preview" ]; then
              respond '{"id":"test","ok":true,"result":{"instance_id":"beta","script_name":"setup","command_preview":["bash","scripts/setup.sh"],"scope":{"current_cwd":"/tmp/project","env":{"SKILLS_SAFE_MODE":"1"},"network":"none","files":["/tmp/project/scripts/setup.sh"]},"risks":["Writes are blocked by default."],"requires_confirmation":true,"execution_allowed":false,"audit_status":"blocked","audit_id":"audit-1","summary":"Blocked until confirmed.","reason":"Native UI is preview-only."}}'
            else
              respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: script.previewExecution"}}'
            fi
            ;;
          *\\"batch.previewSkillToggles\\"*)
            if [ "$scenario" = "batch-mixed" ]; then
              respond '{"id":"test","ok":true,"result":{"preview_id":"batch-preview-1","action":"disable","target_enabled":false,"selected_count":4,"writable_count":2,"skipped_count":2,"affected_skills":[{"instance_id":"alpha","name":"Alpha","agent":"claude-code","scope":"agent-global","display_path":"/tmp/global/alpha/SKILL.md","current_enabled":true,"target_enabled":false},{"instance_id":"gamma","name":"Gamma","agent":"codex","scope":"agent-global","display_path":"~/.codex/skills/gamma/SKILL.md","current_enabled":true,"target_enabled":false}],"skipped_items":[{"instance_id":"beta","name":"Beta","agent":"claude-code","scope":"agent-project","display_path":"/tmp/project/beta/SKILL.md","current_enabled":false,"target_enabled":false,"reason":"Already disabled"},{"instance_id":"pi-one","name":"Pi One","agent":"pi","scope":"agent-global","display_path":"~/.pi/skills/pi-one/SKILL.md","current_enabled":true,"target_enabled":false,"reason":"Pi is read-only."}],"snapshot_plan":{"summary":"Create config snapshots for Claude Code and Codex before applying; rollback uses existing agent-config timeline.","rollback_supported":true,"targets":["/tmp/home/.claude/settings.json","/tmp/home/.codex/config.toml"]},"apply_supported":true}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: batch.previewSkillToggles"}}'
            ;;
          *\\"batch.applySkillToggles\\"*)
            if [ "$scenario" = "batch-mixed" ]; then
              respond '{"id":"test","ok":true,"result":{"updated_count":2,"skipped_count":2,"snapshot_ids":["snap-claude-new","snap-codex"]}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: batch.applySkillToggles"}}'
            ;;
          *\\"report.exportLocal\\"*)
            if [ "$scenario" = "report-export" ]; then
              respond '{"id":"test","ok":true,"result":{"export_id":"local-report-test","generated_at":1780590000000,"output_dir":"<app-data-dir>/report-exports/local-report-test","files":[{"format":"json","path":"<app-data-dir>/report-exports/local-report-test/report.json"}],"catalog_available":true,"summary":{"skill_count":2,"finding_count":1,"open_finding_count":1,"triage_count":0,"cleanup_item_count":1,"comparison_group_count":0},"redaction":{"enabled":true,"placeholders":["$HOME","<project-root>","<project-cwd>","<app-data-dir>"],"path_policy":"Local paths are redacted."},"read_only":true,"writes_allowed":false,"provider_request_sent":false,"script_execution_allowed":false,"credential_accessed":false}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: report.exportLocal"}}'
            ;;
          *\\"catalog.listSkills\\"*)
            if [ "$scenario" = "empty" ]; then
              respond '{"id":"test","ok":true,"result":[]}'
            elif [ "$scenario" = "toggle-disabled" ]; then
              respond '{"id":"test","ok":true,"result":'"$skills_toggled"'}'
            elif [ "$scenario" = "toggle-codex-disabled" ]; then
              respond '{"id":"test","ok":true,"result":'"$skills_codex_toggled"'}'
            elif [ "$scenario" = "opencode" ]; then
              if grep -q '"method":"config.toggleSkill"' "$SKILLS_COPILOT_FAKE_SERVICE_CALLS"; then
                respond '{"id":"test","ok":true,"result":'"$skills_opencode_toggled"'}'
              else
                respond '{"id":"test","ok":true,"result":'"$skills_opencode"'}'
              fi
            elif [ "$scenario" = "tool-global" ]; then
              respond '{"id":"test","ok":true,"result":'"$skills_toolglobal"'}'
            elif [ "$scenario" = "batch-mixed" ]; then
              respond '{"id":"test","ok":true,"result":'"$skills_batch_mixed"'}'
            else
              respond '{"id":"test","ok":true,"result":'"$skills_normal"'}'
            fi
            ;;
          *\\"catalog.scanAll\\"*)
            if [ "$scenario" = "scan-slow" ]; then sleep 1; fi
            if [ "$scenario" = "stale-after-toggle" ]; then
              scan_skills=$skills_toggled
              scan_finding_count=1
            else
              scan_skills=$skills_normal
              scan_finding_count=0
            fi
            respond '{"id":"test","ok":true,"result":{"scanned_count":3,"skills":'"$scan_skills"',"activity":{"operation":"scan","status":"ok","started_at":1,"finished_at":2,"scanned_count":3,"skill_count":3,"finding_count":'"$scan_finding_count"',"conflict_count":0,"snapshot_count":0,"roots":["/tmp/global","/tmp/codex"],"log_entries":[],"recovery_actions":[],"agent_summaries":[{"agent":"claude-code","display_label":"Claude Code","status":"completed","scanned_count":2,"catalog_count":2,"broken_count":0,"roots_considered":["/tmp/global","/tmp/missing-claude"],"roots_scanned":["/tmp/global"],"roots_skipped":["/tmp/missing-claude"],"recovery_actions":["Create missing Claude root."]},{"agent":"codex","display_label":"Codex","status":"completed","scanned_count":1,"catalog_count":1,"broken_count":0,"roots_considered":["/tmp/codex"],"roots_scanned":["/tmp/codex"],"roots_skipped":[],"recovery_actions":[]}]}}}'
            ;;
          *\\"project.getContext\\"*)
            if [ "$scenario" = "project-clear" ] || [ "$scenario" = "empty" ]; then
              respond '{"id":"test","ok":true,"result":{"active":null,"recent":'"$project_recent"'}}'
            elif [ "$scenario" = "project-validation-error" ]; then
              respond '{"id":"test","ok":true,"result":{"active":'"$project_invalid"',"recent":'"$project_recent"'}}'
            else
              respond '{"id":"test","ok":true,"result":{"active":'"$project_active"',"recent":'"$project_recent"'}}'
            fi
            ;;
          *\\"project.setContext\\"*)
            if [ "$scenario" = "project-validation-error" ]; then
              respond '{"id":"test","ok":true,"result":{"active":'"$project_invalid"',"recent":['"$project_invalid"']}}'
            else
              respond '{"id":"test","ok":true,"result":{"active":'"$project_active"',"recent":'"$project_recent"'}}'
            fi
            ;;
          *\\"project.clearContext\\"*)
            respond '{"id":"test","ok":true,"result":{"active":null,"recent":'"$project_recent"'}}'
            ;;
          *\\"project.validateContext\\"*)
            if [ "$scenario" = "project-validation-error" ]; then
              respond '{"id":"test","ok":true,"result":'"$project_invalid"'}'
            else
              respond '{"id":"test","ok":true,"result":'"$project_active"'}'
            fi
            ;;
          *\\"catalog.getSkill\\"*)
            case "$input" in
              *\\"instance_id\\":\\"beta\\"*)
                if [ "$scenario" = "stale-before" ]; then
                  respond '{"id":"test","ok":true,"result":'"$detail_beta_before"'}'
                elif [ "$scenario" = "stale-after-scan" ]; then
                  respond '{"id":"test","ok":true,"result":'"$detail_beta_scan"'}'
                elif [ "$scenario" = "stale-after-toggle" ]; then
                  respond '{"id":"test","ok":true,"result":'"$detail_beta_toggle"'}'
                elif [ "$scenario" = "toggle-disabled" ]; then
                  respond '{"id":"test","ok":true,"result":'"$detail_beta_disabled"'}'
                else
                  respond '{"id":"test","ok":true,"result":'"$detail_beta_enabled"'}'
                fi
                ;;
              *\\"instance_id\\":\\"gamma\\"*)
                if [ "$scenario" = "stale-after-scan" ]; then
                  respond '{"id":"test","ok":true,"result":'"$detail_gamma_scan"'}'
                elif [ "$scenario" = "stale-after-project" ]; then
                  respond '{"id":"test","ok":true,"result":'"$detail_gamma_project"'}'
                elif [ "$scenario" = "toggle-codex-disabled" ]; then
                  respond '{"id":"test","ok":true,"result":'"$detail_gamma_disabled"'}'
                else
                  respond '{"id":"test","ok":true,"result":'"$detail_gamma"'}'
                fi
                ;;
              *\\"instance_id\\":\\"omega\\"*)
                if grep -q '"method":"config.toggleSkill"' "$SKILLS_COPILOT_FAKE_SERVICE_CALLS"; then
                  respond '{"id":"test","ok":true,"result":'"$detail_omega_disabled"'}'
                else
                  respond '{"id":"test","ok":true,"result":'"$detail_omega"'}'
                fi
                ;;
              *\\"instance_id\\":\\"tool-alpha\\"*)
                respond '{"id":"test","ok":true,"result":'"$detail_toolglobal"'}'
                ;;
              *)
                respond '{"id":"test","ok":true,"result":'"$detail_alpha"'}'
                ;;
            esac
            ;;
          *\\"catalog.listFindings\\"*)
            respond '{"id":"test","ok":true,"result":[]}'
            ;;
          *\\"catalog.listConflicts\\"*)
            respond '{"id":"test","ok":true,"result":[]}'
            ;;
          *\\"skill.listEvents\\"*)
            if [ "$scenario" = "detail-scope" ]; then
              case "$input" in
                *\\"instance_id\\":\\"beta\\"*)
                  respond '{"id":"test","ok":true,"result":'"$events_beta"'}'
                  ;;
                *\\"instance_id\\":\\"gamma\\"*)
                  respond '{"id":"test","ok":true,"result":'"$events_gamma"'}'
                  ;;
              esac
            fi
            respond '{"id":"test","ok":true,"result":[]}'
            ;;
          *\\"snapshot.previewRollback\\"*)
            if [ "$scenario" = "timeline" ]; then
              respond '{"id":"test","ok":true,"result":{"snapshot":{"id":"snap-claude-new","agent":"claude-code","scope":"agent-global","target":"/tmp/home/.claude/settings.json","content":"{}\\n","reason":"pre-toggle","created_at":30},"current_content":"{\\"skillOverrides\\":{\\"beta\\":false}}\\n","current_read_error":null,"changed":true,"redacted":false,"rollback_supported":true}}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"test.missing","message":"missing snapshot preview"}}'
            ;;
          *\\"snapshot.rollback\\"*)
            if [ "$scenario" = "timeline" ]; then
              respond '{"id":"test","ok":true,"result":3}'
            fi
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"test.missing","message":"missing snapshot rollback"}}'
            ;;
          *\\"snapshot.listAgentConfig\\"*)
            if [ "$scenario" = "timeline" ]; then
              case "$input" in
                *\\"agent\\":\\"claude-code\\"*)
                  respond '{"id":"test","ok":true,"result":'"$snapshots_claude"'}'
                  ;;
                *\\"agent\\":\\"codex\\"*)
                  respond '{"id":"test","ok":true,"result":'"$snapshots_codex"'}'
                  ;;
                *\\"agent\\":\\"opencode\\"*)
                  respond '{"id":"test","ok":true,"result":'"$snapshots_opencode"'}'
                  ;;
              esac
            fi
            respond '{"id":"test","ok":true,"result":[]}'
            ;;
          *\\"snapshot.list\\"*)
            respond '{"id":"test","ok":true,"result":[]}'
            ;;
          *\\"config.toggleSkill\\"*)
            if [ "$scenario" = "stale-after-toggle" ]; then
              respond '{"id":"test","ok":true,"result":'"$detail_beta_toggle"'}'
            elif [ "$scenario" = "toggle-disabled" ]; then
              sleep 1
              respond '{"id":"test","ok":true,"result":'"$detail_beta_disabled"'}'
            elif [ "$scenario" = "toggle-codex-disabled" ]; then
              respond '{"id":"test","ok":true,"result":'"$detail_gamma_disabled"'}'
            elif [ "$scenario" = "opencode" ]; then
              respond '{"id":"test","ok":true,"result":'"$detail_omega_disabled"'}'
            else
              respond '{"id":"test","ok":true,"result":'"$detail_beta_disabled"'}'
            fi
            ;;
          *)
            respond '{"id":"test","ok":false,"result":null,"error":{"code":"test.unknown","message":"unknown method"}}'
            ;;
        esac
        """
    }
}
