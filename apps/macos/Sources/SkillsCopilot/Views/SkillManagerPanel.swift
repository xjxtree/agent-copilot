import SwiftUI

struct SkillManagerPanel: View {
    @EnvironmentObject private var store: SkillStore
    var showsHeader = true
    @State private var pendingConfirmation: SkillManagerWriteConfirmation?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if showsHeader {
                header
            }
            targetControls
            searchAndInstall
            operationPreview
            installedSection
            removeSkillSection
            localLibrary
        }
        .task {
            if store.skillManagerTools.isEmpty {
                await store.loadSkillManagerTools()
            }
            if store.skillManagerInstalled == nil {
                await store.listSkillManagerInstalled()
            }
        }
        .alert(confirmationTitle, isPresented: confirmationBinding) {
            if let confirmation = pendingConfirmation {
                Button(confirmation.confirmButtonTitle, role: confirmation.role) {
                    let confirmed = confirmation
                    pendingConfirmation = nil
                    Task { await applyConfirmed(confirmed) }
                }
            }
            Button(UIStrings.cancel, role: .cancel) {
                pendingConfirmation = nil
            }
        } message: {
            if let confirmation = pendingConfirmation {
                Text(confirmation.message)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label(UIStrings.text("skillManager.title", "Skill Package Manager"), systemImage: "shippingbox.and.arrow.backward")
                    .font(.title3.bold())
                Spacer()
                Button {
                    Task {
                        await store.loadSkillManagerTools()
                        await store.listSkillManagerInstalled()
                    }
                } label: {
                    Label(UIStrings.text("action.refresh", "Refresh"), systemImage: "arrow.clockwise")
                }
                .controlSize(.small)
                .disabled(store.isLoadingSkillManagerTools || store.isListingSkillManagerInstalled)
            }

            DetailMetricGrid(maxColumns: 4, minColumnWidth: 150) {
                SummaryChip(
                    title: UIStrings.text("skillManager.defaultTool", "Tool"),
                    value: primaryTool?.displayName ?? UIStrings.notLoaded,
                    systemImage: "terminal"
                )
                SummaryChip(
                    title: UIStrings.text("skillManager.toolStatus", "Status"),
                    value: primaryTool?.status ?? UIStrings.notLoaded,
                    systemImage: "checkmark.seal"
                )
                SummaryChip(
                    title: UIStrings.text("skillManager.targets", "Targets"),
                    value: "\(store.skillManagerSelectedAgents.count)",
                    systemImage: "person.3"
                )
                SummaryChip(
                    title: UIStrings.text("skillManager.localLibrary", "Local Library"),
                    value: "\(store.localSkillLibrarySkills.count)",
                    systemImage: "folder"
                )
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }

    private var targetControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(UIStrings.text("skillManager.targets", "Targets"), systemImage: "person.3")
                    .font(.headline)
                Spacer()
                Button(UIStrings.text("selection.all", "All")) {
                    store.selectAllSkillManagerAgents()
                }
                .controlSize(.small)
                Button(UIStrings.text("selection.none", "None")) {
                    store.clearSkillManagerAgents()
                }
                .controlSize(.small)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 126), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(SkillManagerAgent.defaultTargets) { agent in
                    Toggle(isOn: Binding(
                        get: { store.skillManagerSelectedAgentIDs.contains(agent.rawValue) },
                        set: { store.setSkillManagerAgent(agent.rawValue, selected: $0) }
                    )) {
                        Text(agent.title)
                            .lineLimit(1)
                    }
                    .toggleStyle(.checkbox)
                    .controlSize(.small)
                }
            }

            HStack(spacing: 12) {
                Picker(UIStrings.scope, selection: $store.skillManagerScope) {
                    ForEach(SkillManagerScope.allCases) { scope in
                        Text(scope.title).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)

                Picker(UIStrings.text("skillManager.distribution", "Distribution"), selection: $store.skillManagerDistribution) {
                    ForEach(SkillManagerDistribution.allCases) { distribution in
                        Text(distribution.title).tag(distribution)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 240)

                Toggle(UIStrings.text("skillManager.network", "Network"), isOn: $store.skillManagerNetworkAllowed)
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }

    private var searchAndInstall: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(UIStrings.text("skillManager.searchInstall", "Search & Install"), systemImage: "magnifyingglass")
                .font(.headline)

            HStack(spacing: 10) {
                TextField(UIStrings.text("skillManager.query", "Search skills"), text: $store.skillManagerSearchQuery)
                    .textFieldStyle(.roundedBorder)
                TextField(UIStrings.text("skillManager.owner", "Owner"), text: $store.skillManagerOwner)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 180)
                Button {
                    Task { await store.searchSkillManager() }
                } label: {
                    Label(UIStrings.text("action.search", "Search"), systemImage: "magnifyingglass")
                }
                .disabled(store.isSearchingSkillManager)
            }

            HStack(spacing: 10) {
                TextField(UIStrings.text("skillManager.source", "Source"), text: $store.skillManagerSource)
                    .textFieldStyle(.roundedBorder)
                TextField(UIStrings.text("skillManager.skillName", "Skill name"), text: $store.skillManagerSkillName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 220)
                Button {
                    Task { await store.previewSkillManagerInstall() }
                } label: {
                    Label(UIStrings.text("skillManager.previewInstall", "Preview Install"), systemImage: "plus.circle")
                }
                .disabled(store.isPreviewingSkillManagerMutation)
            }

            if let search = store.skillManagerSearchResult {
                commandPreviewLine(search.preview)
                if search.results.isEmpty {
                    Text(UIStrings.text("skillManager.search.noResults", "No search results returned."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 8) {
                        ForEach(search.results.prefix(8)) { result in
                            SearchResultRow(result: result) {
                                Task {
                                    await store.previewSkillManagerInstall(
                                        source: result.source ?? result.name,
                                        skillName: result.name
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }

    @ViewBuilder
    private var operationPreview: some View {
        if store.skillManagerMutationPreview != nil
            || store.skillManagerLocalCreatePreview != nil
            || store.skillManagerLocalDeletePreview != nil {
            VStack(alignment: .leading, spacing: 12) {
                Label(UIStrings.text("skillManager.preview", "Preview"), systemImage: "doc.text.magnifyingglass")
                    .font(.headline)

                if let preview = store.skillManagerMutationPreview {
                    mutationPreview(preview)
                }
                if let preview = store.skillManagerLocalCreatePreview {
                    localCreatePreview(preview)
                }
                if let preview = store.skillManagerLocalDeletePreview {
                    localDeletePreview(preview)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .adaptiveMaterialSurface()
        }
    }

    private var installedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(UIStrings.text("skillManager.installed", "Installed"), systemImage: "list.bullet.rectangle")
                    .font(.headline)
                Spacer()
                Button {
                    Task { await store.listSkillManagerInstalled() }
                } label: {
                    Label(UIStrings.text("action.refresh", "Refresh"), systemImage: "arrow.clockwise")
                }
                .controlSize(.small)
                .disabled(store.isListingSkillManagerInstalled)
            }

            if let installed = store.skillManagerInstalled {
                commandPreviewLine(installed.preview)
                if installed.installed.isEmpty {
                    Text(UIStrings.text("skillManager.installed.empty", "No manager-installed skills returned."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 8) {
                        ForEach(installed.installed.prefix(12)) { record in
                            InstalledSkillRow(record: record)
                        }
                    }
                }
            } else {
                Text(UIStrings.notLoaded)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }

    private var removeSkillSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(UIStrings.text("skillManager.removeSelected", "Remove from Selected Agents"), systemImage: "minus.circle")
                    .font(.headline)
                Spacer()
                Text(selectedAgentSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                TextField(UIStrings.text("skillManager.skillToRemove", "Skill to remove"), text: $store.skillManagerSkillName)
                    .textFieldStyle(.roundedBorder)
                Button(role: .destructive) {
                    Task { await store.previewSkillManagerRemove() }
                } label: {
                    Label(UIStrings.text("skillManager.previewRemove", "Preview Remove"), systemImage: "minus.circle")
                }
                .disabled(store.isPreviewingSkillManagerMutation || store.skillManagerSelectedAgents.isEmpty)
            }

            Text(UIStrings.text(
                "skillManager.removeSelected.summary",
                "Removes manager-installed skill links for the selected agents above. Per-agent enablement remains controlled by agent configuration."
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }

    private var localLibrary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(UIStrings.text("skillManager.localLibrary", "Local Library"), systemImage: "folder")
                .font(.headline)

            HStack(spacing: 10) {
                TextField(UIStrings.text("skillManager.localName", "Local skill name"), text: $store.skillManagerLocalSkillName)
                    .textFieldStyle(.roundedBorder)
                Button {
                    Task { await store.previewSkillManagerLocalCreate() }
                } label: {
                    Label(UIStrings.text("skillManager.previewCreate", "Preview Create"), systemImage: "doc.badge.plus")
                }
                .disabled(store.isPreviewingSkillManagerMutation)
            }

            if store.localSkillLibrarySkills.isEmpty {
                Text(UIStrings.text("skillManager.local.empty", "No app-owned local skills in the library."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(store.localSkillLibrarySkills.prefix(12)) { skill in
                        LocalSkillLibraryRow(skill: skill)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }

    private func mutationPreview(_ preview: SkillManagerMutationRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            commandPreviewBlock(preview.preview)
            if let output = preview.output {
                commandOutput(output)
            }
            HStack {
                Spacer()
                Button {
                    pendingConfirmation = .mutation(preview.preview)
                } label: {
                    Label(applyTitle(for: preview.preview.operation), systemImage: "checkmark.circle")
                }
                .disabled(!canApply(preview.preview))
            }
        }
    }

    private func localCreatePreview(_ preview: SkillManagerLocalCreateRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            commandPreviewBlock(preview.preview)
            MetadataLine(label: UIStrings.source, value: preview.sourcePath)
            if let output = preview.output {
                commandOutput(output)
            }
            HStack {
                Spacer()
                Button {
                    pendingConfirmation = .localCreate(preview.preview, sourcePath: preview.sourcePath)
                } label: {
                    Label(UIStrings.text("skillManager.applyCreate", "Create"), systemImage: "checkmark.circle")
                }
                .disabled(!canApply(preview.preview))
            }
        }
    }

    private func localDeletePreview(_ preview: SkillManagerLocalDeleteRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MetadataLine(label: UIStrings.text("metadata.skill", "Skill"), value: preview.skillName)
            MetadataLine(label: UIStrings.source, value: preview.path)
            Text(preview.summary)
                .font(.caption)
                .foregroundStyle(preview.physicalDeleteAllowed ? Color.secondary : Color.orange)
            if !preview.blockedByReferences.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Text(UIStrings.text("skillManager.delete.blockedRefs", "Agent references"))
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    ForEach(preview.blockedByReferences) { reference in
                        MetadataLine(label: DisplayText.agent(reference.agent), value: reference.path)
                    }
                }
            }
            HStack {
                Spacer()
                Button(role: .destructive) {
                    pendingConfirmation = .localDelete(preview)
                } label: {
                    Label(UIStrings.text("action.delete", "Delete"), systemImage: "trash")
                }
                .disabled(!preview.physicalDeleteAllowed || store.isApplyingSkillManagerMutation)
            }
        }
    }

    private func commandPreviewLine(_ preview: SkillManagerCommandPreview) -> some View {
        HStack(spacing: 8) {
            Image(systemName: preview.willRun ? "play.circle" : "doc.text.magnifyingglass")
                .foregroundStyle(.secondary)
            Text(preview.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer()
            Text(preview.networkRequired ? UIStrings.text("skillManager.network.required", "Network") : UIStrings.text("skillManager.network.local", "Local"))
                .font(.caption2.bold())
                .foregroundStyle(preview.networkRequired && !preview.networkAllowed ? .orange : .secondary)
        }
    }

    private func commandPreviewBlock(_ preview: SkillManagerCommandPreview) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            commandPreviewLine(preview)
            Text(preview.displayCommand)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
            DetailMetricGrid(maxColumns: 4, minColumnWidth: 120) {
                SummaryChip(title: UIStrings.text("skillManager.cwd", "CWD"), value: preview.cwd, systemImage: "folder", valueLineLimit: 1)
                SummaryChip(title: UIStrings.text("skillManager.confirmed", "Confirmed"), value: preview.confirmed ? UIStrings.text("value.yes", "Yes") : UIStrings.text("value.no", "No"), systemImage: "checkmark.circle")
                SummaryChip(title: UIStrings.text("skillManager.network", "Network"), value: preview.networkAllowed ? UIStrings.text("value.yes", "Yes") : UIStrings.text("value.no", "No"), systemImage: "network")
                SummaryChip(title: UIStrings.text("skillManager.token", "Token"), value: preview.previewToken, systemImage: "key", valueLineLimit: 1)
            }
            if !preview.risks.isEmpty {
                DenseDisclosureList(preview.risks, visibleLimit: 3) { risk in
                    Label(risk, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func commandOutput(_ output: SkillManagerCommandOutput) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            MetadataLine(label: UIStrings.text("metadata.status", "Status"), value: output.status)
            if !output.stdout.isEmpty {
                Text(output.stdout)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .lineLimit(6)
            }
            if !output.stderr.isEmpty {
                Text(output.stderr)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.orange)
                    .textSelection(.enabled)
                    .lineLimit(6)
            }
        }
    }

    private var confirmationBinding: Binding<Bool> {
        Binding(
            get: { pendingConfirmation != nil },
            set: { isPresented in
                if !isPresented {
                    pendingConfirmation = nil
                }
            }
        )
    }

    private var confirmationTitle: String {
        pendingConfirmation?.title ?? UIStrings.text("skillManager.confirm.title", "Confirm Skill Manager Operation")
    }

    private var selectedAgentSummary: String {
        let selected = store.skillManagerSelectedAgents.map(DisplayText.agent)
        guard !selected.isEmpty else {
            return UIStrings.text("skillManager.agents.none", "No target agents selected")
        }
        return selected.joined(separator: ", ")
    }

    private func canApply(_ preview: SkillManagerCommandPreview) -> Bool {
        preview.requiresConfirmation
            && (!preview.networkRequired || preview.networkAllowed)
            && !store.isApplyingSkillManagerMutation
    }

    private func applyTitle(for operation: String) -> String {
        switch operation {
        case "install":
            return UIStrings.text("skillManager.applyInstall", "Install")
        case "remove":
            return UIStrings.text("skillManager.applyRemove", "Remove")
        case "update":
            return UIStrings.text("skillManager.applyUpdate", "Update")
        default:
            return UIStrings.text("action.apply", "Apply")
        }
    }

    private func applyCurrentMutation(_ operation: String) async {
        switch operation {
        case "install":
            await store.applySkillManagerInstall()
        case "remove":
            await store.applySkillManagerRemove()
        case "update":
            await store.applySkillManagerUpdate()
        default:
            break
        }
    }

    private func applyConfirmed(_ confirmation: SkillManagerWriteConfirmation) async {
        switch confirmation {
        case .mutation(let preview):
            await applyCurrentMutation(preview.operation)
        case .localCreate:
            await store.applySkillManagerLocalCreate()
        case .localDelete:
            await store.applySkillManagerLocalDelete()
        }
    }

    private var primaryTool: SkillManagerToolRecord? {
        store.skillManagerTools.first { $0.id == "npx-skills" } ?? store.skillManagerTools.first
    }
}

private enum SkillManagerWriteConfirmation {
    case mutation(SkillManagerCommandPreview)
    case localCreate(SkillManagerCommandPreview, sourcePath: String)
    case localDelete(SkillManagerLocalDeleteRecord)

    var title: String {
        switch self {
        case .mutation(let preview):
            switch preview.operation {
            case "install":
                return UIStrings.text("skillManager.confirm.install.title", "Confirm Skill Install")
            case "remove":
                return UIStrings.text("skillManager.confirm.remove.title", "Confirm Skill Removal")
            case "update":
                return UIStrings.text("skillManager.confirm.update.title", "Confirm Skill Update")
            default:
                return UIStrings.text("skillManager.confirm.title", "Confirm Skill Manager Operation")
            }
        case .localCreate:
            return UIStrings.text("skillManager.confirm.localCreate.title", "Confirm Local Skill Creation")
        case .localDelete:
            return UIStrings.text("skillManager.confirm.localDelete.title", "Confirm Local Skill Delete")
        }
    }

    var confirmButtonTitle: String {
        switch self {
        case .mutation(let preview):
            switch preview.operation {
            case "install":
                return UIStrings.text("skillManager.applyInstall", "Install")
            case "remove":
                return UIStrings.text("skillManager.applyRemove", "Remove")
            case "update":
                return UIStrings.text("skillManager.applyUpdate", "Update")
            default:
                return UIStrings.text("action.apply", "Apply")
            }
        case .localCreate:
            return UIStrings.text("skillManager.applyCreate", "Create")
        case .localDelete:
            return UIStrings.text("action.delete", "Delete")
        }
    }

    var role: ButtonRole? {
        switch self {
        case .mutation(let preview) where preview.operation == "remove":
            return .destructive
        case .localDelete:
            return .destructive
        default:
            return nil
        }
    }

    var message: String {
        switch self {
        case .mutation(let preview):
            return [
                preview.summary,
                "\(UIStrings.text("skillManager.confirm.targets", "Targets")): \(targetSummary(from: preview.command))",
                "\(UIStrings.text("skillManager.cwd", "CWD")): \(preview.cwd)",
                "\(UIStrings.text("skillManager.confirm.command", "Command")): \(preview.displayCommand)"
            ].joined(separator: "\n\n")
        case .localCreate(let preview, let sourcePath):
            return [
                preview.summary,
                "\(UIStrings.source): \(sourcePath)",
                "\(UIStrings.text("skillManager.cwd", "CWD")): \(preview.cwd)",
                "\(UIStrings.text("skillManager.confirm.command", "Command")): \(preview.displayCommand)"
            ].joined(separator: "\n\n")
        case .localDelete(let preview):
            return [
                preview.summary,
                "\(UIStrings.text("metadata.skill", "Skill")): \(preview.skillName)",
                "\(UIStrings.source): \(preview.path)"
            ].joined(separator: "\n\n")
        }
    }

    private func targetSummary(from command: [String]) -> String {
        var agents: [String] = []
        var index = command.startIndex
        while index < command.endIndex {
            if command[index] == "--agent" {
                let valueIndex = command.index(after: index)
                if valueIndex < command.endIndex {
                    agents.append(DisplayText.agent(command[valueIndex]))
                    index = command.index(after: valueIndex)
                } else {
                    index = valueIndex
                }
            } else {
                index = command.index(after: index)
            }
        }
        return agents.isEmpty ? UIStrings.text("skillManager.agents.unknown", "unknown agents") : agents.joined(separator: ", ")
    }
}

private struct SearchResultRow: View {
    let result: SkillManagerSearchResult
    let onPreviewInstall: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(result.name)
                    .font(.callout.bold())
                    .lineLimit(1)
                Text(result.description ?? result.source ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Button(action: onPreviewInstall) {
                Label(UIStrings.text("skillManager.previewInstall", "Preview Install"), systemImage: "plus.circle")
            }
            .controlSize(.small)
        }
        .padding(10)
        .background(.quaternary.opacity(0.22), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct InstalledSkillRow: View {
    @EnvironmentObject private var store: SkillStore
    let record: SkillManagerInstalledRecord

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(record.name)
                    .font(.callout.bold())
                    .lineLimit(1)
                Text(installedSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Button {
                Task { await store.previewSkillManagerUpdate(skillName: record.name) }
            } label: {
                Label(UIStrings.text("skillManager.previewUpdate", "Preview Update"), systemImage: "arrow.triangle.2.circlepath")
            }
            .controlSize(.small)
            Button(role: .destructive) {
                Task { await store.previewSkillManagerRemove(skillName: record.name) }
            } label: {
                Label(UIStrings.text("skillManager.previewRemove", "Preview Remove"), systemImage: "minus.circle")
            }
            .controlSize(.small)
        }
        .padding(10)
        .background(.quaternary.opacity(0.22), in: RoundedRectangle(cornerRadius: 8))
    }

    private var installedSummary: String {
        let agents = record.agents.isEmpty ? UIStrings.text("skillManager.agents.unknown", "unknown agents") : record.agents.map(DisplayText.agent).joined(separator: ", ")
        return [record.source, record.scope, agents].compactMap { $0 }.joined(separator: " · ")
    }
}

private struct LocalSkillLibraryRow: View {
    @EnvironmentObject private var store: SkillStore
    let skill: SkillRecord

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(skill.name)
                    .font(.callout.bold())
                    .lineLimit(1)
                Text(skill.displayPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Button {
                Task {
                    await store.previewSkillManagerInstall(
                        source: store.skillManagerSourcePath(for: skill),
                        skillName: skill.name
                    )
                }
            } label: {
                Label(UIStrings.text("skillManager.previewInstall", "Preview Install"), systemImage: "plus.circle")
            }
            .controlSize(.small)
            Button(role: .destructive) {
                Task { await store.previewSkillManagerLocalDelete(skill: skill) }
            } label: {
                Label(UIStrings.text("skillManager.previewDelete", "Preview Delete"), systemImage: "trash")
            }
            .controlSize(.small)
        }
        .padding(10)
        .background(.quaternary.opacity(0.22), in: RoundedRectangle(cornerRadius: 8))
    }
}
