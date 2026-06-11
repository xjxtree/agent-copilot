import Foundation

struct RemediationPreviewDraftSummary: Decodable, Hashable {
    let totalCount: Int
    let frontmatterCount: Int
    let descriptionCount: Int
    let permissionsCount: Int
    let dependencyCount: Int
    let policyCount: Int
    let blockerCount: Int
    let copyOnlyCount: Int
    let summaryText: String

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case draftCount = "draft_count"
        case itemCount = "item_count"
        case items
        case frontmatterCount = "frontmatter_count"
        case frontmatter
        case descriptionCount = "description_count"
        case descriptions
        case permissionsCount = "permissions_count"
        case permissions
        case dependencyCount = "dependency_count"
        case dependencies
        case policyCount = "policy_count"
        case policies
        case blockerCount = "blocker_count"
        case blockers
        case copyOnlyCount = "copy_only_count"
        case copyOnly = "copy_only"
        case summary
        case message
        case text
    }

    init(
        totalCount: Int = 0,
        frontmatterCount: Int = 0,
        descriptionCount: Int = 0,
        permissionsCount: Int = 0,
        dependencyCount: Int = 0,
        policyCount: Int = 0,
        blockerCount: Int = 0,
        copyOnlyCount: Int = 0,
        summaryText: String = ""
    ) {
        self.totalCount = totalCount
        self.frontmatterCount = frontmatterCount
        self.descriptionCount = descriptionCount
        self.permissionsCount = permissionsCount
        self.dependencyCount = dependencyCount
        self.policyCount = policyCount
        self.blockerCount = blockerCount
        self.copyOnlyCount = copyOnlyCount
        self.summaryText = summaryText
    }

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            self.init(summaryText: value)
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            totalCount: try container.decodeFlexibleDraftInt(keys: [.totalCount, .draftCount, .itemCount, .items]) ?? 0,
            frontmatterCount: try container.decodeFlexibleDraftInt(keys: [.frontmatterCount, .frontmatter]) ?? 0,
            descriptionCount: try container.decodeFlexibleDraftInt(keys: [.descriptionCount, .descriptions]) ?? 0,
            permissionsCount: try container.decodeFlexibleDraftInt(keys: [.permissionsCount, .permissions]) ?? 0,
            dependencyCount: try container.decodeFlexibleDraftInt(keys: [.dependencyCount, .dependencies]) ?? 0,
            policyCount: try container.decodeFlexibleDraftInt(keys: [.policyCount, .policies]) ?? 0,
            blockerCount: try container.decodeFlexibleDraftInt(keys: [.blockerCount, .blockers]) ?? 0,
            copyOnlyCount: try container.decodeFlexibleDraftInt(keys: [.copyOnlyCount, .copyOnly]) ?? 0,
            summaryText: try container.decodeIfPresent(String.self, forKey: .summary)
                ?? container.decodeIfPresent(String.self, forKey: .message)
                ?? container.decodeIfPresent(String.self, forKey: .text)
                ?? ""
        )
    }
}

struct RemediationPreviewDraftItem: Decodable, Hashable, Identifiable {
    let id: String
    let title: String
    let draftType: String
    let agent: String?
    let affectedSkill: CapabilityTaxonomySkill?
    let findingID: String?
    let ruleID: String?
    let currentText: String?
    let proposedText: String
    let rationale: String
    let confidenceScore: Int?
    let confidenceBand: String?
    let copyLabel: String
    let editGuidance: String
    let evidenceRefs: [String]
    let blockerNotes: [String]
    let safetyFlags: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case draftID = "draft_id"
        case draftId = "draftId"
        case itemID = "item_id"
        case title
        case name
        case draftType = "draft_type"
        case draftTypeAlt = "draftType"
        case type
        case kind
        case agent
        case affectedSkill = "affected_skill"
        case affectedSkillAlt = "affectedSkill"
        case skill
        case skillRef = "skill_ref"
        case findingID = "finding_id"
        case findingId = "findingId"
        case finding
        case ruleID = "rule_id"
        case ruleId = "ruleId"
        case rule
        case currentText = "current_text"
        case currentTextAlt = "currentText"
        case current
        case before
        case proposedText = "proposed_text"
        case proposedTextAlt = "proposedText"
        case proposed
        case after
        case proposedPatch = "proposed_patch"
        case patch
        case snippet
        case draft
        case rationale
        case reason
        case summary
        case confidence
        case confidenceScore = "confidence_score"
        case confidenceScoreAlt = "confidenceScore"
        case score
        case band
        case confidenceBand = "confidence_band"
        case confidenceBandAlt = "confidenceBand"
        case copyLabel = "copy_label"
        case copyLabelAlt = "copyLabel"
        case copyAction = "copy_action"
        case editGuidance = "edit_guidance"
        case editGuidanceAlt = "editGuidance"
        case guidance
        case instructions
        case evidenceRefs = "evidence_refs"
        case evidenceRefsAlt = "evidenceRefs"
        case evidence
        case blockerNotes = "blocker_notes"
        case blockerNotesAlt = "blockerNotes"
        case blockers
        case safetyFlags = "safety_flags"
        case safety
        case flags
    }

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            id = value
            title = value
            draftType = UIStrings.unknown
            agent = nil
            affectedSkill = nil
            findingID = nil
            ruleID = nil
            currentText = nil
            proposedText = value
            rationale = ""
            confidenceScore = nil
            confidenceBand = nil
            copyLabel = UIStrings.fixPreviewCopyDraft
            editGuidance = UIStrings.fixPreviewEditGuidanceFallback
            evidenceRefs = []
            blockerNotes = []
            safetyFlags = []
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title)
            ?? container.decodeIfPresent(String.self, forKey: .name)
            ?? UIStrings.fixPreviewDraft
        draftType = try container.decodeIfPresent(String.self, forKey: .draftType)
            ?? container.decodeIfPresent(String.self, forKey: .draftTypeAlt)
            ?? container.decodeIfPresent(String.self, forKey: .type)
            ?? container.decodeIfPresent(String.self, forKey: .kind)
            ?? UIStrings.unknown
        agent = try container.decodeIfPresent(String.self, forKey: .agent)
        affectedSkill = try container.decodeIfPresent(CapabilityTaxonomySkill.self, forKey: .affectedSkill)
            ?? container.decodeIfPresent(CapabilityTaxonomySkill.self, forKey: .affectedSkillAlt)
            ?? container.decodeIfPresent(CapabilityTaxonomySkill.self, forKey: .skill)
            ?? container.decodeIfPresent(CapabilityTaxonomySkill.self, forKey: .skillRef)
        findingID = try container.decodeIfPresent(String.self, forKey: .findingID)
            ?? container.decodeIfPresent(String.self, forKey: .findingId)
            ?? container.decodeIfPresent(String.self, forKey: .finding)
        ruleID = try container.decodeIfPresent(String.self, forKey: .ruleID)
            ?? container.decodeIfPresent(String.self, forKey: .ruleId)
            ?? container.decodeIfPresent(String.self, forKey: .rule)
        currentText = try container.decodeIfPresent(String.self, forKey: .currentText)
            ?? container.decodeIfPresent(String.self, forKey: .currentTextAlt)
            ?? container.decodeIfPresent(String.self, forKey: .current)
            ?? container.decodeIfPresent(String.self, forKey: .before)
        proposedText = try container.decodeIfPresent(String.self, forKey: .proposedText)
            ?? container.decodeIfPresent(String.self, forKey: .proposedTextAlt)
            ?? container.decodeIfPresent(String.self, forKey: .proposed)
            ?? container.decodeIfPresent(String.self, forKey: .after)
            ?? container.decodeIfPresent(String.self, forKey: .proposedPatch)
            ?? container.decodeIfPresent(String.self, forKey: .patch)
            ?? container.decodeIfPresent(String.self, forKey: .snippet)
            ?? container.decodeIfPresent(String.self, forKey: .draft)
            ?? ""
        rationale = try container.decodeIfPresent(String.self, forKey: .rationale)
            ?? container.decodeIfPresent(String.self, forKey: .reason)
            ?? container.decodeIfPresent(String.self, forKey: .summary)
            ?? ""
        confidenceScore = try container.decodeFlexibleDraftInt(keys: [.confidenceScore, .confidenceScoreAlt, .confidence, .score])
        confidenceBand = try container.decodeIfPresent(String.self, forKey: .confidenceBand)
            ?? container.decodeIfPresent(String.self, forKey: .confidenceBandAlt)
            ?? container.decodeIfPresent(String.self, forKey: .band)
        copyLabel = try container.decodeIfPresent(String.self, forKey: .copyLabel)
            ?? container.decodeIfPresent(String.self, forKey: .copyLabelAlt)
            ?? container.decodeIfPresent(String.self, forKey: .copyAction)
            ?? UIStrings.fixPreviewCopyDraft
        editGuidance = try container.decodeIfPresent(String.self, forKey: .editGuidance)
            ?? container.decodeIfPresent(String.self, forKey: .editGuidanceAlt)
            ?? container.decodeIfPresent(String.self, forKey: .guidance)
            ?? container.decodeIfPresent(String.self, forKey: .instructions)
            ?? UIStrings.fixPreviewEditGuidanceFallback
        evidenceRefs = try container.decodeFlexibleDraftStringArray(keys: [.evidenceRefs, .evidenceRefsAlt, .evidence])
        blockerNotes = try container.decodeFlexibleDraftStringArray(keys: [.blockerNotes, .blockerNotesAlt, .blockers])
        safetyFlags = try container.decodeFlexibleDraftStringArray(keys: [.safetyFlags, .safety, .flags])
        id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? container.decodeIfPresent(String.self, forKey: .draftID)
            ?? container.decodeIfPresent(String.self, forKey: .draftId)
            ?? container.decodeIfPresent(String.self, forKey: .itemID)
            ?? "\(draftType)-\(title)"
    }
}

typealias RemediationPreviewDraftEvidenceReference = CrossAgentReadinessEvidenceReference
typealias RemediationPreviewDraftSafety = CrossAgentReadinessSafety

struct RemediationPreviewDraftsResult: Decodable, Hashable {
    let generatedBy: String
    let catalogAvailable: Bool
    let filters: RemediationPlanFilters
    let summary: RemediationPreviewDraftSummary
    let draftItems: [RemediationPreviewDraftItem]
    let gapNotes: [String]
    let blockerNotes: [String]
    let evidenceReferences: [RemediationPreviewDraftEvidenceReference]
    let promptRequest: RoutingAccuracyPromptRequest?
    let safetyFlags: RemediationPreviewDraftSafety
    let fallbackReason: String?

    var isUnavailable: Bool { fallbackReason != nil && !catalogAvailable }

    enum CodingKeys: String, CodingKey {
        case generatedBy = "generated_by"
        case generatedByAlt = "generatedBy"
        case catalogAvailable = "catalog_available"
        case catalogAvailableAlt = "catalogAvailable"
        case filters
        case summary
        case draftItems = "draft_items"
        case draftItemsAlt = "draftItems"
        case drafts
        case items
        case rows
        case recommendations
        case gapNotes = "gap_notes"
        case gapNotesAlt = "gapNotes"
        case gaps
        case blockerNotes = "blocker_notes"
        case blockerNotesAlt = "blockerNotes"
        case blockers
        case evidenceReferences = "evidence_references"
        case evidenceReferencesAlt = "evidenceReferences"
        case evidence
        case promptRequest = "prompt_request"
        case promptRequestAlt = "promptRequest"
        case safetyFlags = "safety_flags"
        case safety
        case fallbackReason = "fallback_reason"
        case reason
    }

    init(
        generatedBy: String = "local",
        catalogAvailable: Bool = false,
        filters: RemediationPlanFilters = RemediationPlanFilters(),
        summary: RemediationPreviewDraftSummary = RemediationPreviewDraftSummary(),
        draftItems: [RemediationPreviewDraftItem] = [],
        gapNotes: [String] = [],
        blockerNotes: [String] = [],
        evidenceReferences: [RemediationPreviewDraftEvidenceReference] = [],
        promptRequest: RoutingAccuracyPromptRequest? = nil,
        safetyFlags: RemediationPreviewDraftSafety = RemediationPreviewDraftSafety(),
        fallbackReason: String? = nil
    ) {
        self.generatedBy = generatedBy
        self.catalogAvailable = catalogAvailable
        self.filters = filters
        self.summary = summary
        self.draftItems = draftItems
        self.gapNotes = gapNotes
        self.blockerNotes = blockerNotes
        self.evidenceReferences = evidenceReferences
        self.promptRequest = promptRequest
        self.safetyFlags = safetyFlags
        self.fallbackReason = fallbackReason
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        generatedBy = try container.decodeIfPresent(String.self, forKey: .generatedBy)
            ?? container.decodeIfPresent(String.self, forKey: .generatedByAlt)
            ?? "local"
        catalogAvailable = try container.decodeIfPresent(Bool.self, forKey: .catalogAvailable)
            ?? container.decodeIfPresent(Bool.self, forKey: .catalogAvailableAlt)
            ?? true
        filters = try container.decodeIfPresent(RemediationPlanFilters.self, forKey: .filters) ?? RemediationPlanFilters()
        draftItems = try container.decodeIfPresent([RemediationPreviewDraftItem].self, forKey: .draftItems)
            ?? container.decodeIfPresent([RemediationPreviewDraftItem].self, forKey: .draftItemsAlt)
            ?? container.decodeIfPresent([RemediationPreviewDraftItem].self, forKey: .drafts)
            ?? container.decodeIfPresent([RemediationPreviewDraftItem].self, forKey: .items)
            ?? container.decodeIfPresent([RemediationPreviewDraftItem].self, forKey: .rows)
            ?? container.decodeIfPresent([RemediationPreviewDraftItem].self, forKey: .recommendations)
            ?? []
        summary = try container.decodeIfPresent(RemediationPreviewDraftSummary.self, forKey: .summary)
            ?? RemediationPreviewDraftSummary(totalCount: draftItems.count)
        gapNotes = try container.decodeFlexibleDraftStringArray(keys: [.gapNotes, .gapNotesAlt, .gaps])
        blockerNotes = try container.decodeFlexibleDraftStringArray(keys: [.blockerNotes, .blockerNotesAlt, .blockers])
        evidenceReferences = try container.decodeIfPresent([RemediationPreviewDraftEvidenceReference].self, forKey: .evidenceReferences)
            ?? container.decodeIfPresent([RemediationPreviewDraftEvidenceReference].self, forKey: .evidenceReferencesAlt)
            ?? container.decodeIfPresent([RemediationPreviewDraftEvidenceReference].self, forKey: .evidence)
            ?? []
        promptRequest = try container.decodeIfPresent(RoutingAccuracyPromptRequest.self, forKey: .promptRequest)
            ?? container.decodeIfPresent(RoutingAccuracyPromptRequest.self, forKey: .promptRequestAlt)
        safetyFlags = try container.decodeIfPresent(RemediationPreviewDraftSafety.self, forKey: .safetyFlags)
            ?? container.decodeIfPresent(RemediationPreviewDraftSafety.self, forKey: .safety)
            ?? RemediationPreviewDraftSafety()
        fallbackReason = try container.decodeIfPresent(String.self, forKey: .fallbackReason)
            ?? container.decodeIfPresent(String.self, forKey: .reason)
    }

    static func unavailable(reason: String = UIStrings.fixPreviewUnavailable) -> RemediationPreviewDraftsResult {
        RemediationPreviewDraftsResult(
            generatedBy: "unavailable",
            catalogAvailable: false,
            fallbackReason: reason
        )
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleDraftInt(keys: [Key]) throws -> Int? {
        for key in keys {
            if let value = try? decodeIfPresent(Int.self, forKey: key) {
                return value
            }
            if let value = try? decodeIfPresent(Double.self, forKey: key) {
                return Int(value.rounded())
            }
            if let value = try? decodeIfPresent(String.self, forKey: key) {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if let int = Int(trimmed) {
                    return int
                }
                if let double = Double(trimmed.replacingOccurrences(of: "%", with: "")) {
                    return Int(double.rounded())
                }
            }
            if let values = try? decodeIfPresent([String].self, forKey: key) {
                return values.count
            }
            if let values = try? decodeIfPresent([RemediationPreviewDraftItem].self, forKey: key) {
                return values.count
            }
        }
        return nil
    }

    func decodeFlexibleDraftStringArray(keys: [Key]) throws -> [String] {
        for key in keys {
            if let values = try? decodeIfPresent([String].self, forKey: key) {
                return values
            }
            if let value = try? decodeIfPresent(String.self, forKey: key) {
                return value.isEmpty ? [] : [value]
            }
            if let values = try? decodeIfPresent([RemediationPreviewDraftEvidenceReference].self, forKey: key) {
                return values.map(\.detail)
            }
            if let value = try? decodeIfPresent(RemediationPreviewDraftEvidenceReference.self, forKey: key) {
                return [value.detail]
            }
            if let value = try? decodeIfPresent(Bool.self, forKey: key) {
                return [value ? UIStrings.stateEnabled : UIStrings.stateDisabled]
            }
            if let value = try? decodeIfPresent(Int.self, forKey: key) {
                return ["\(value)"]
            }
        }
        return []
    }
}
