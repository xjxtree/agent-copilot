import Foundation

enum SkillManagerAgent: String, CaseIterable, Identifiable, Hashable {
    case claudeCode = "claude-code"
    case pi
    case opencode
    case codex
    case hermesAgent = "hermes-agent"
    case openclaw

    var id: String { rawValue }

    static let defaultTargets: [SkillManagerAgent] = [
        .claudeCode,
        .pi,
        .opencode,
        .codex,
        .hermesAgent,
        .openclaw
    ]

    var title: String {
        switch self {
        case .claudeCode:
            return UIStrings.claudeCode
        case .pi:
            return UIStrings.pi
        case .opencode:
            return UIStrings.opencode
        case .codex:
            return UIStrings.codex
        case .hermesAgent:
            return UIStrings.hermes
        case .openclaw:
            return UIStrings.openclaw
        }
    }
}

enum SkillManagerScope: String, CaseIterable, Identifiable, Codable, Hashable {
    case project
    case global

    var id: String { rawValue }

    var title: String {
        switch self {
        case .project:
            return UIStrings.text("skillManager.scope.project", "Project")
        case .global:
            return UIStrings.text("skillManager.scope.global", "Global")
        }
    }
}

enum SkillManagerDistribution: String, CaseIterable, Identifiable, Codable, Hashable {
    case symlink
    case copy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .symlink:
            return UIStrings.text("skillManager.distribution.symlink", "Symlink")
        case .copy:
            return UIStrings.text("skillManager.distribution.copy", "Copy")
        }
    }
}

enum SkillManagerWorkflow: String, CaseIterable, Identifiable, Hashable {
    case searchInstall = "search-install"
    case installedUpdates = "installed-updates"
    case localLibrary = "local-library"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .searchInstall:
            return UIStrings.text("skillManager.workflow.searchInstall", "Search & Install")
        case .installedUpdates:
            return UIStrings.text("skillManager.workflow.installedUpdates", "Installed & Updates")
        case .localLibrary:
            return UIStrings.text("skillManager.workflow.localLibrary", "Local Library")
        }
    }

    var systemImage: String {
        switch self {
        case .searchInstall:
            return "magnifyingglass"
        case .installedUpdates:
            return "list.bullet.rectangle"
        case .localLibrary:
            return "folder"
        }
    }

    var allowsExternalManagerMutation: Bool {
        switch self {
        case .searchInstall, .installedUpdates:
            return true
        case .localLibrary:
            return false
        }
    }
}

struct SkillManagerToolRecord: Codable, Identifiable, Hashable {
    let id: String
    let displayName: String
    let status: String
    let executable: String?
    let operations: [String]
    let defaultAgents: [String]
    let notes: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case status
        case executable
        case operations
        case defaultAgents = "default_agents"
        case notes
    }
}

struct SkillManagerEnvPreview: Codable, Hashable {
    let key: String
    let value: String
}

struct SkillManagerCommandPreview: Codable, Hashable {
    let toolId: String
    let operation: String
    let command: [String]
    let cwd: String
    let env: [SkillManagerEnvPreview]
    let requiresConfirmation: Bool
    let confirmed: Bool
    let networkRequired: Bool
    let networkAllowed: Bool
    let willRun: Bool
    let previewToken: String
    let summary: String
    let risks: [String]
    let source: String?
    let skills: [String]?

    enum CodingKeys: String, CodingKey {
        case toolId = "tool_id"
        case operation
        case command
        case cwd
        case env
        case requiresConfirmation = "requires_confirmation"
        case confirmed
        case networkRequired = "network_required"
        case networkAllowed = "network_allowed"
        case willRun = "will_run"
        case previewToken = "preview_token"
        case summary
        case risks
        case source
        case skills
    }

    var displayCommand: String {
        command.map(Self.shellDisplay).joined(separator: " ")
    }

    var localizedSummary: String {
        switch operation {
        case "search":
            return UIStrings.text("skillManager.previewSummary.search", summary)
        case "listInstalled":
            return UIStrings.text("skillManager.previewSummary.listInstalled", summary)
        case "install":
            return String(
                format: UIStrings.text(
                    "skillManager.previewSummary.install",
                    "Preview install of %@ for selected targets."
                ),
                source ?? UIStrings.text("skillManager.source", "Source")
            )
        case "remove":
            return String(
                format: UIStrings.text(
                    "skillManager.previewSummary.remove",
                    "Preview removal of %@ from selected targets."
                ),
                skills?.first ?? UIStrings.text("skillManager.skillName", "Skill name")
            )
        case "update":
            return UIStrings.text("skillManager.previewSummary.update", summary)
        case "localCreate":
            return String(
                format: UIStrings.text(
                    "skillManager.previewSummary.localCreate",
                    "Preview local skill template creation for %@."
                ),
                skills?.first ?? UIStrings.text("skillManager.localName", "Local skill name")
            )
        default:
            return summary
        }
    }

    private static func shellDisplay(_ value: String) -> String {
        guard value.rangeOfCharacter(from: .whitespacesAndNewlines) != nil else {
            return value
        }
        return "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    var compactMetadataRows: [CompactMetadataRow] {
        [
            CompactMetadataRow(label: "CWD", value: cwd, systemImage: "folder", isCopyable: true),
            CompactMetadataRow(
                label: UIStrings.text("skillManager.confirmed", "Confirmed"),
                value: confirmed ? UIStrings.text("value.yes", "Yes") : UIStrings.text("value.no", "No"),
                systemImage: "checkmark.circle"
            ),
            CompactMetadataRow(
                label: UIStrings.text("skillManager.network", "Network"),
                value: networkAllowed ? UIStrings.text("value.yes", "Yes") : UIStrings.text("value.no", "No"),
                systemImage: "network"
            ),
            CompactMetadataRow(label: UIStrings.text("skillManager.token", "Token"), value: previewToken, systemImage: "key", isCopyable: true)
        ]
    }

    var requiresExplicitApplyConfirmation: Bool {
        requiresConfirmation && ["install", "remove", "update"].contains(operation)
    }
}

struct SkillManagerCommandOutput: Codable, Hashable {
    let status: String
    let exitCode: Int?
    let stdout: String
    let stderr: String

    enum CodingKeys: String, CodingKey {
        case status
        case exitCode = "exit_code"
        case stdout
        case stderr
    }
}

struct SkillManagerSearchParams: Encodable {
    let query: String
    let owner: String?
    let networkAllowed: Bool

    enum CodingKeys: String, CodingKey {
        case query
        case owner
        case networkAllowed = "network_allowed"
    }
}

struct SkillManagerSearchResult: Codable, Identifiable, Hashable {
    let name: String
    let source: String?
    let description: String?
    let raw: JSONValue

    var id: String {
        [source ?? "", name].joined(separator: "|")
    }
}

struct SkillManagerSearchRecord: Codable, Hashable {
    let preview: SkillManagerCommandPreview
    let output: SkillManagerCommandOutput?
    let results: [SkillManagerSearchResult]

    var isBlockedByNetwork: Bool {
        preview.networkRequired && !preview.networkAllowed && output == nil
    }
}

struct SkillManagerListInstalledParams: Encodable {
    let agents: [String]
    let scope: String?
}

struct SkillManagerInstalledRecord: Codable, Identifiable, Hashable {
    let name: String
    let source: String?
    let agents: [String]
    let scope: String?
    let path: String?
    let raw: JSONValue

    var id: String {
        [source ?? "", name, scope ?? "", path ?? ""].joined(separator: "|")
    }
}

struct SkillManagerInstalledListRecord: Codable, Hashable {
    let preview: SkillManagerCommandPreview
    let output: SkillManagerCommandOutput
    let installed: [SkillManagerInstalledRecord]
}

struct SkillManagerInstallParams: Encodable {
    let source: String
    let skills: [String]
    let agents: [String]
    let scope: String?
    let distribution: String?
    let networkAllowed: Bool
    let confirmed: Bool
    let previewToken: String?

    enum CodingKeys: String, CodingKey {
        case source
        case skills
        case agents
        case scope
        case distribution
        case networkAllowed = "network_allowed"
        case confirmed
        case previewToken = "preview_token"
    }
}

struct SkillManagerRemoveParams: Encodable {
    let skill: String
    let agents: [String]
    let scope: String?
    let confirmed: Bool
    let previewToken: String?

    enum CodingKeys: String, CodingKey {
        case skill
        case agents
        case scope
        case confirmed
        case previewToken = "preview_token"
    }
}

struct SkillManagerUpdateParams: Encodable {
    let skills: [String]
    let agents: [String]
    let scope: String?
    let networkAllowed: Bool
    let confirmed: Bool
    let previewToken: String?

    enum CodingKeys: String, CodingKey {
        case skills
        case agents
        case scope
        case networkAllowed = "network_allowed"
        case confirmed
        case previewToken = "preview_token"
    }
}

struct SkillManagerLocalCreateParams: Encodable {
    let name: String
    let confirmed: Bool
    let previewToken: String?

    enum CodingKeys: String, CodingKey {
        case name
        case confirmed
        case previewToken = "preview_token"
    }
}

struct SkillManagerDeleteLocalParams: Encodable {
    let instanceId: String
    let confirmed: Bool

    enum CodingKeys: String, CodingKey {
        case instanceId = "instance_id"
        case confirmed
    }
}

struct SkillManagerMutationRecord: Codable, Hashable {
    let preview: SkillManagerCommandPreview
    let output: SkillManagerCommandOutput?
    let applied: Bool
    let scannedCount: Int
    let updatedSkills: [SkillRecord]

    enum CodingKeys: String, CodingKey {
        case preview
        case output
        case applied
        case scannedCount = "scanned_count"
        case updatedSkills = "updated_skills"
    }
}

struct SkillManagerLocalCreateRecord: Codable, Hashable {
    let preview: SkillManagerCommandPreview
    let output: SkillManagerCommandOutput?
    let imported: SkillRecord?
    let instanceId: String?
    let sourcePath: String
    let applied: Bool

    enum CodingKeys: String, CodingKey {
        case preview
        case output
        case imported
        case instanceId = "instance_id"
        case sourcePath = "source_path"
        case applied
    }
}

struct SkillManagerReferenceRecord: Codable, Identifiable, Hashable {
    let instanceId: String
    let name: String
    let agent: String
    let scope: String
    let path: String

    var id: String { instanceId }

    enum CodingKeys: String, CodingKey {
        case instanceId = "instance_id"
        case name
        case agent
        case scope
        case path
    }
}

struct SkillManagerLocalDeleteRecord: Codable, Hashable {
    let instanceId: String
    let skillName: String
    let path: String
    let appOwned: Bool
    let physicalDeleteAllowed: Bool
    let blockedByReferences: [SkillManagerReferenceRecord]
    let confirmed: Bool
    let deleted: Bool
    let summary: String

    enum CodingKeys: String, CodingKey {
        case instanceId = "instance_id"
        case skillName = "skill_name"
        case path
        case appOwned = "app_owned"
        case physicalDeleteAllowed = "physical_delete_allowed"
        case blockedByReferences = "blocked_by_references"
        case confirmed
        case deleted
        case summary
    }
}
