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
        try await reloadLoadsProjectContext()
        try await setProjectStoresContextAndScans()
        try await clearProjectClearsContextAndScans()
        try await projectValidationErrorSkipsScanAndSurfacesMessage()
        try await reloadFallsBackToDisabledLLMWhenOldServiceDoesNotSupportMethods()
        try await prepareLLMActionStoresEstimateWithoutProviderCall()
        try await prepareSkillAnalysisUsesReadOnlyPrepareContract()
        try await prepareSkillAnalysisFallsBackWhenMethodUnavailable()
        try await llmPreparePreviewIsScopedToSelectedSkillAndReadOnly()
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
            elif [ "$scenario" = "llm-ready" ]; then
              respond '{"id":"test","ok":true,"result":{"enabled":true,"provider":"openai","model":"gpt-5","disabled_reason":null,"supported_actions":["analyze","recommend","explain_conflict","draft_frontmatter"]}}'
            else
              respond '{"id":"test","ok":true,"result":{"enabled":false,"provider":null,"model":null,"disabled_reason":"LLM is disabled.","supported_actions":["analyze","recommend","explain_conflict","draft_frontmatter"]}}'
            fi
            ;;
          *\\"llm.prepareSkillAnalysis\\"*)
            if [ "$scenario" = "old-service" ]; then
              respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: llm.prepareSkillAnalysis"}}'
            elif [ "$scenario" = "llm-ready" ]; then
              if printf '%s' "$input" | grep -q '\\"analysis_kind\\":\\"risk\\"'; then
                respond '{"id":"test","ok":true,"result":{"enabled":false,"disabled_reason":"AI analysis is disabled by default.","analysis_kind":"risk","selected_skill_count":1,"included_skills":[{"instance_id":"beta","name":"Beta","agent":"claude-code"}],"excluded_count":0,"missing_count":0,"prompt_draft":"Risk prompt for Beta.","summary_draft":"Risk summary for Beta.","write_back_enabled":false,"script_execution_enabled":false,"credential_storage_enabled":false,"confirmation_required":true}}'
              else
                respond '{"id":"test","ok":true,"result":{"enabled":false,"disabled_reason":"AI analysis is disabled by default.","analysis_kind":"overview","selected_skill_count":2,"included_skills":[{"instance_id":"alpha","name":"Alpha","agent":"claude-code"},{"instance_id":"beta","name":"Beta","agent":"claude-code"}],"excluded_count":0,"missing_count":0,"prompt_draft":"Overview prompt for visible skills.","summary_draft":"Overview summary for visible skills.","safety":{"write_back_enabled":false,"script_execution_enabled":false,"credential_storage_enabled":false,"confirmation_required":true}}}'
              fi
            else
              respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: llm.prepareSkillAnalysis"}}'
            fi
            ;;
          *\\"llm.prepareAction\\"*)
            if [ "$scenario" = "old-service" ]; then
              respond '{"id":"test","ok":false,"result":null,"error":{"code":"unknown_method","message":"unknown method: llm.prepareAction"}}'
            elif [ "$scenario" = "llm-ready" ]; then
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
            respond '{"id":"test","ok":true,"result":{"scanned_count":3,"skills":'"$scan_skills"',"activity":{"operation":"scan","status":"ok","started_at":1,"finished_at":2,"scanned_count":3,"skill_count":3,"finding_count":'"$scan_finding_count"',"conflict_count":0,"snapshot_count":0,"roots":["/tmp/global","/tmp/codex"],"log_entries":[],"recovery_actions":[]}}}'
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
