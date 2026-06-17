import Foundation

struct LocalSessionPreviewRoot: Decodable, Hashable, Identifiable {
    let root: String
    let status: String
    let candidateCount: Int
    let blocker: String?

    var id: String { root }

    enum CodingKeys: String, CodingKey {
        case root
        case status
        case candidateCount = "candidate_count"
        case candidateCountAlt = "candidateCount"
        case blocker
    }

    init(root: String, status: String, candidateCount: Int, blocker: String? = nil) {
        self.root = root
        self.status = status
        self.candidateCount = candidateCount
        self.blocker = blocker
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        root = try container.decodeIfPresent(String.self, forKey: .root) ?? ""
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? UIStrings.unknown
        candidateCount = try container.decodeIfPresent(Int.self, forKey: .candidateCount)
            ?? container.decodeIfPresent(Int.self, forKey: .candidateCountAlt)
            ?? 0
        blocker = try container.decodeIfPresent(String.self, forKey: .blocker)
    }
}

struct LocalSessionPreviewRow: Decodable, Hashable, Identifiable {
    let id: String
    let title: String
    let sourceKind: String
    let agent: String?
    let redactedPath: String
    let modifiedAt: String?
    let excerpt: String
    let excerptCharCount: Int
    let contentHash: String
    let evidenceRefs: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case sourceKind = "source_kind"
        case sourceKindAlt = "sourceKind"
        case agent
        case redactedPath = "redacted_path"
        case redactedPathAlt = "redactedPath"
        case path
        case modifiedAt = "modified_at"
        case modifiedAtAlt = "modifiedAt"
        case excerpt
        case redactedExcerpt = "redacted_excerpt"
        case excerptCharCount = "excerpt_char_count"
        case excerptCharCountAlt = "excerptCharCount"
        case contentHash = "content_hash"
        case contentHashAlt = "contentHash"
        case evidenceRefs = "evidence_refs"
        case evidenceRefsAlt = "evidenceRefs"
        case evidence
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? container.decodeIfPresent(String.self, forKey: .contentHash)
            ?? container.decodeIfPresent(String.self, forKey: .contentHashAlt)
            ?? UUID().uuidString
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? id
        sourceKind = try container.decodeIfPresent(String.self, forKey: .sourceKind)
            ?? container.decodeIfPresent(String.self, forKey: .sourceKindAlt)
            ?? "authorized-local-session"
        agent = try container.decodeIfPresent(String.self, forKey: .agent)
        redactedPath = try container.decodeIfPresent(String.self, forKey: .redactedPath)
            ?? container.decodeIfPresent(String.self, forKey: .redactedPathAlt)
            ?? container.decodeIfPresent(String.self, forKey: .path)
            ?? ""
        modifiedAt = try container.decodeFlexibleLocalSessionString(keys: [.modifiedAt, .modifiedAtAlt])
        excerpt = try container.decodeIfPresent(String.self, forKey: .excerpt)
            ?? container.decodeIfPresent(String.self, forKey: .redactedExcerpt)
            ?? ""
        excerptCharCount = try container.decodeIfPresent(Int.self, forKey: .excerptCharCount)
            ?? container.decodeIfPresent(Int.self, forKey: .excerptCharCountAlt)
            ?? excerpt.count
        contentHash = try container.decodeIfPresent(String.self, forKey: .contentHash)
            ?? container.decodeIfPresent(String.self, forKey: .contentHashAlt)
            ?? ""
        evidenceRefs = try container.decodeFlexibleLocalSessionStringArray(keys: [
            .evidenceRefs,
            .evidenceRefsAlt,
            .evidence
        ])
    }
}

struct LocalSessionPreviewRedactionSummary: Decodable, Hashable {
    let status: String
    let redactedValueCount: Int
    let redactedFields: [String]
    let rawTracePersisted: Bool
    let rawPromptPersisted: Bool
    let rawResponsePersisted: Bool
    let rawSecretReturned: Bool

    enum CodingKeys: String, CodingKey {
        case status
        case redactedValueCount = "redacted_value_count"
        case redactedValueCountAlt = "redactedValueCount"
        case redactedFields = "redacted_fields"
        case redactedFieldsAlt = "redactedFields"
        case rawTracePersisted = "raw_trace_persisted"
        case rawTracePersistedAlt = "rawTracePersisted"
        case rawPromptPersisted = "raw_prompt_persisted"
        case rawPromptPersistedAlt = "rawPromptPersisted"
        case rawResponsePersisted = "raw_response_persisted"
        case rawResponsePersistedAlt = "rawResponsePersisted"
        case rawSecretReturned = "raw_secret_returned"
        case rawSecretReturnedAlt = "rawSecretReturned"
    }

    init(
        status: String = "redacted-local-only",
        redactedValueCount: Int = 0,
        redactedFields: [String] = [],
        rawTracePersisted: Bool = false,
        rawPromptPersisted: Bool = false,
        rawResponsePersisted: Bool = false,
        rawSecretReturned: Bool = false
    ) {
        self.status = status
        self.redactedValueCount = redactedValueCount
        self.redactedFields = redactedFields
        self.rawTracePersisted = rawTracePersisted
        self.rawPromptPersisted = rawPromptPersisted
        self.rawResponsePersisted = rawResponsePersisted
        self.rawSecretReturned = rawSecretReturned
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "redacted-local-only"
        redactedValueCount = try container.decodeIfPresent(Int.self, forKey: .redactedValueCount)
            ?? container.decodeIfPresent(Int.self, forKey: .redactedValueCountAlt)
            ?? 0
        redactedFields = try container.decodeFlexibleLocalSessionStringArray(keys: [.redactedFields, .redactedFieldsAlt])
        rawTracePersisted = try container.decodeIfPresent(Bool.self, forKey: .rawTracePersisted)
            ?? container.decodeIfPresent(Bool.self, forKey: .rawTracePersistedAlt)
            ?? false
        rawPromptPersisted = try container.decodeIfPresent(Bool.self, forKey: .rawPromptPersisted)
            ?? container.decodeIfPresent(Bool.self, forKey: .rawPromptPersistedAlt)
            ?? false
        rawResponsePersisted = try container.decodeIfPresent(Bool.self, forKey: .rawResponsePersisted)
            ?? container.decodeIfPresent(Bool.self, forKey: .rawResponsePersistedAlt)
            ?? false
        rawSecretReturned = try container.decodeIfPresent(Bool.self, forKey: .rawSecretReturned)
            ?? container.decodeIfPresent(Bool.self, forKey: .rawSecretReturnedAlt)
            ?? false
    }
}

struct LocalSessionPreviewResult: Decodable, Hashable {
    let generatedBy: String
    let authorized: Bool
    let authorizationRequired: Bool
    let roots: [LocalSessionPreviewRoot]
    let sessionRows: [LocalSessionPreviewRow]
    let count: Int
    let totalCandidateCount: Int
    let gapNotes: [String]
    let blockerNotes: [String]
    let redactionSummary: LocalSessionPreviewRedactionSummary
    let safetyFlags: CrossAgentReadinessSafety
    let fallbackReason: String?

    var isUnavailable: Bool {
        fallbackReason != nil && sessionRows.isEmpty
    }

    enum CodingKeys: String, CodingKey {
        case generatedBy = "generated_by"
        case generatedByAlt = "generatedBy"
        case authorized
        case authorizationRequired = "authorization_required"
        case authorizationRequiredAlt = "authorizationRequired"
        case roots
        case sessionRows = "session_rows"
        case sessionRowsAlt = "sessionRows"
        case rows
        case count
        case totalCandidateCount = "total_candidate_count"
        case totalCandidateCountAlt = "totalCandidateCount"
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
        roots: [LocalSessionPreviewRoot] = [],
        sessionRows: [LocalSessionPreviewRow] = [],
        count: Int? = nil,
        totalCandidateCount: Int = 0,
        gapNotes: [String] = [],
        blockerNotes: [String] = [],
        redactionSummary: LocalSessionPreviewRedactionSummary = LocalSessionPreviewRedactionSummary(),
        safetyFlags: CrossAgentReadinessSafety = CrossAgentReadinessSafety(),
        fallbackReason: String? = nil
    ) {
        self.generatedBy = generatedBy
        self.authorized = authorized
        self.authorizationRequired = authorizationRequired
        self.roots = roots
        self.sessionRows = sessionRows
        self.count = count ?? sessionRows.count
        self.totalCandidateCount = totalCandidateCount
        self.gapNotes = gapNotes
        self.blockerNotes = blockerNotes
        self.redactionSummary = redactionSummary
        self.safetyFlags = safetyFlags
        self.fallbackReason = fallbackReason
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rows = try container.decodeIfPresent([LocalSessionPreviewRow].self, forKey: .sessionRows)
            ?? container.decodeIfPresent([LocalSessionPreviewRow].self, forKey: .sessionRowsAlt)
            ?? container.decodeIfPresent([LocalSessionPreviewRow].self, forKey: .rows)
            ?? []
        self.init(
            generatedBy: try container.decodeIfPresent(String.self, forKey: .generatedBy)
                ?? container.decodeIfPresent(String.self, forKey: .generatedByAlt)
                ?? "local-v2.87",
            authorized: try container.decodeIfPresent(Bool.self, forKey: .authorized) ?? !rows.isEmpty,
            authorizationRequired: try container.decodeIfPresent(Bool.self, forKey: .authorizationRequired)
                ?? container.decodeIfPresent(Bool.self, forKey: .authorizationRequiredAlt)
                ?? false,
            roots: try container.decodeIfPresent([LocalSessionPreviewRoot].self, forKey: .roots) ?? [],
            sessionRows: rows,
            count: try container.decodeIfPresent(Int.self, forKey: .count),
            totalCandidateCount: try container.decodeIfPresent(Int.self, forKey: .totalCandidateCount)
                ?? container.decodeIfPresent(Int.self, forKey: .totalCandidateCountAlt)
                ?? rows.count,
            gapNotes: try container.decodeFlexibleLocalSessionStringArray(keys: [.gapNotes, .gapNotesAlt]),
            blockerNotes: try container.decodeFlexibleLocalSessionStringArray(keys: [.blockerNotes, .blockerNotesAlt]),
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

    static func unavailable(reason: String = UIStrings.text("localSessionPreview.unavailable", "Local session preview is unavailable.")) -> LocalSessionPreviewResult {
        LocalSessionPreviewResult(generatedBy: "unavailable", fallbackReason: reason)
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleLocalSessionString(keys: [Key]) throws -> String? {
        for key in keys {
            if let value = try? decodeIfPresent(String.self, forKey: key) {
                return value
            }
            if let value = try? decodeIfPresent(Int.self, forKey: key) {
                return "\(value)"
            }
        }
        return nil
    }

    func decodeFlexibleLocalSessionStringArray(keys: [Key]) throws -> [String] {
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
