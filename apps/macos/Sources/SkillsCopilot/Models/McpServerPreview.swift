import Foundation

struct McpServerPreviewParams: Encodable {
    let authorizedConfigPaths: [String]
    let limit: Int?

    enum CodingKeys: String, CodingKey {
        case authorizedConfigPaths = "authorized_config_paths"
        case limit
    }
}

struct McpServerPreviewPath: Decodable, Hashable, Identifiable {
    let path: String
    let status: String
    let serverCount: Int
    let blocker: String?

    var id: String { path }

    enum CodingKeys: String, CodingKey {
        case path
        case status
        case serverCount = "server_count"
        case serverCountAlt = "serverCount"
        case blocker
    }

    init(path: String, status: String, serverCount: Int, blocker: String? = nil) {
        self.path = path
        self.status = status
        self.serverCount = serverCount
        self.blocker = blocker
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        path = try container.decodeIfPresent(String.self, forKey: .path) ?? ""
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? UIStrings.unknown
        serverCount = try container.decodeIfPresent(Int.self, forKey: .serverCount)
            ?? container.decodeIfPresent(Int.self, forKey: .serverCountAlt)
            ?? 0
        blocker = try container.decodeIfPresent(String.self, forKey: .blocker)
    }
}

struct McpServerPreviewRow: Decodable, Hashable, Identifiable {
    let id: String
    let name: String
    let sourcePath: String
    let transport: String
    let command: String?
    let argsCount: Int
    let envKeyCount: Int
    let evidenceRefs: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case sourcePath = "source_path"
        case sourcePathAlt = "sourcePath"
        case transport
        case command
        case argsCount = "args_count"
        case argsCountAlt = "argsCount"
        case envKeyCount = "env_key_count"
        case envKeyCountAlt = "envKeyCount"
        case evidenceRefs = "evidence_refs"
        case evidenceRefsAlt = "evidenceRefs"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? id
        sourcePath = try container.decodeIfPresent(String.self, forKey: .sourcePath)
            ?? container.decodeIfPresent(String.self, forKey: .sourcePathAlt)
            ?? ""
        transport = try container.decodeIfPresent(String.self, forKey: .transport) ?? UIStrings.unknown
        command = try container.decodeIfPresent(String.self, forKey: .command)
        argsCount = try container.decodeIfPresent(Int.self, forKey: .argsCount)
            ?? container.decodeIfPresent(Int.self, forKey: .argsCountAlt)
            ?? 0
        envKeyCount = try container.decodeIfPresent(Int.self, forKey: .envKeyCount)
            ?? container.decodeIfPresent(Int.self, forKey: .envKeyCountAlt)
            ?? 0
        evidenceRefs = try container.decodeFlexibleMcpStringArray(keys: [.evidenceRefs, .evidenceRefsAlt])
    }
}

struct McpServerPreviewResult: Decodable, Hashable {
    let generatedBy: String
    let authorized: Bool
    let authorizationRequired: Bool
    let evidenceAvailable: Bool
    let evidenceInsufficient: Bool
    let authorizedPaths: [McpServerPreviewPath]
    let count: Int
    let serverRows: [McpServerPreviewRow]
    let gapNotes: [String]
    let blockerNotes: [String]
    let redactionSummary: LocalSessionPreviewRedactionSummary
    let safetyFlags: CrossAgentReadinessSafety
    let fallbackReason: String?

    var isUnavailable: Bool {
        fallbackReason != nil && serverRows.isEmpty
    }

    enum CodingKeys: String, CodingKey {
        case generatedBy = "generated_by"
        case generatedByAlt = "generatedBy"
        case authorized
        case authorizationRequired = "authorization_required"
        case authorizationRequiredAlt = "authorizationRequired"
        case evidenceAvailable = "evidence_available"
        case evidenceAvailableAlt = "evidenceAvailable"
        case evidenceInsufficient = "evidence_insufficient"
        case evidenceInsufficientAlt = "evidenceInsufficient"
        case authorizedPaths = "authorized_paths"
        case authorizedPathsAlt = "authorizedPaths"
        case count
        case serverRows = "server_rows"
        case serverRowsAlt = "serverRows"
        case rows
        case gapNotes = "gap_notes"
        case gapNotesAlt = "gapNotes"
        case blockerNotes = "blocker_notes"
        case blockerNotesAlt = "blockerNotes"
        case redactionSummary = "redaction_summary"
        case redactionSummaryAlt = "redactionSummary"
        case safetyFlags = "safety_flags"
        case safety
        case fallbackReason = "fallback_reason"
        case reason
    }

    init(
        generatedBy: String = "local-v2.87",
        authorized: Bool = false,
        authorizationRequired: Bool = true,
        evidenceAvailable: Bool = false,
        evidenceInsufficient: Bool = true,
        authorizedPaths: [McpServerPreviewPath] = [],
        count: Int? = nil,
        serverRows: [McpServerPreviewRow] = [],
        gapNotes: [String] = [],
        blockerNotes: [String] = [],
        redactionSummary: LocalSessionPreviewRedactionSummary = LocalSessionPreviewRedactionSummary(),
        safetyFlags: CrossAgentReadinessSafety = CrossAgentReadinessSafety(),
        fallbackReason: String? = nil
    ) {
        self.generatedBy = generatedBy
        self.authorized = authorized
        self.authorizationRequired = authorizationRequired
        self.evidenceAvailable = evidenceAvailable
        self.evidenceInsufficient = evidenceInsufficient
        self.authorizedPaths = authorizedPaths
        self.count = count ?? serverRows.count
        self.serverRows = serverRows
        self.gapNotes = gapNotes
        self.blockerNotes = blockerNotes
        self.redactionSummary = redactionSummary
        self.safetyFlags = safetyFlags
        self.fallbackReason = fallbackReason
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rows = try container.decodeIfPresent([McpServerPreviewRow].self, forKey: .serverRows)
            ?? container.decodeIfPresent([McpServerPreviewRow].self, forKey: .serverRowsAlt)
            ?? container.decodeIfPresent([McpServerPreviewRow].self, forKey: .rows)
            ?? []
        self.init(
            generatedBy: try container.decodeIfPresent(String.self, forKey: .generatedBy)
                ?? container.decodeIfPresent(String.self, forKey: .generatedByAlt)
                ?? "local-v2.87",
            authorized: try container.decodeIfPresent(Bool.self, forKey: .authorized) ?? !rows.isEmpty,
            authorizationRequired: try container.decodeIfPresent(Bool.self, forKey: .authorizationRequired)
                ?? container.decodeIfPresent(Bool.self, forKey: .authorizationRequiredAlt)
                ?? false,
            evidenceAvailable: try container.decodeIfPresent(Bool.self, forKey: .evidenceAvailable)
                ?? container.decodeIfPresent(Bool.self, forKey: .evidenceAvailableAlt)
                ?? !rows.isEmpty,
            evidenceInsufficient: try container.decodeIfPresent(Bool.self, forKey: .evidenceInsufficient)
                ?? container.decodeIfPresent(Bool.self, forKey: .evidenceInsufficientAlt)
                ?? rows.isEmpty,
            authorizedPaths: try container.decodeIfPresent([McpServerPreviewPath].self, forKey: .authorizedPaths)
                ?? container.decodeIfPresent([McpServerPreviewPath].self, forKey: .authorizedPathsAlt)
                ?? [],
            count: try container.decodeIfPresent(Int.self, forKey: .count),
            serverRows: rows,
            gapNotes: try container.decodeFlexibleMcpStringArray(keys: [.gapNotes, .gapNotesAlt]),
            blockerNotes: try container.decodeFlexibleMcpStringArray(keys: [.blockerNotes, .blockerNotesAlt]),
            redactionSummary: try container.decodeIfPresent(LocalSessionPreviewRedactionSummary.self, forKey: .redactionSummary)
                ?? container.decodeIfPresent(LocalSessionPreviewRedactionSummary.self, forKey: .redactionSummaryAlt)
                ?? LocalSessionPreviewRedactionSummary(),
            safetyFlags: try container.decodeIfPresent(CrossAgentReadinessSafety.self, forKey: .safetyFlags)
                ?? container.decodeIfPresent(CrossAgentReadinessSafety.self, forKey: .safety)
                ?? CrossAgentReadinessSafety(),
            fallbackReason: try container.decodeIfPresent(String.self, forKey: .fallbackReason)
                ?? container.decodeIfPresent(String.self, forKey: .reason)
        )
    }

    static func unavailable(reason: String = UIStrings.text("mcpServerPreview.unavailable", "MCP server preview is unavailable.")) -> McpServerPreviewResult {
        McpServerPreviewResult(generatedBy: "unavailable", fallbackReason: reason)
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleMcpStringArray(keys: [Key]) throws -> [String] {
        for key in keys {
            if let values = try? decodeIfPresent([String].self, forKey: key) {
                return values
            }
            if let value = try? decodeIfPresent(String.self, forKey: key) {
                return value.isEmpty ? [] : [value]
            }
        }
        return []
    }
}
