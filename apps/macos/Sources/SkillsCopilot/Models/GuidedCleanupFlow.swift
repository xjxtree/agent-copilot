import Foundation

typealias GuidedCleanupFlowEvidenceReference = ProviderObservabilityEvidenceReference
typealias GuidedCleanupFlowPromptRequest = ProviderObservabilityPromptRequest
typealias GuidedCleanupFlowSafety = ProviderObservabilitySafety

struct GuidedCleanupFlowFilters: Decodable, Hashable {
    let taskText: String?
    let agent: String?
    let agents: [String]
    let selectedSkillID: String?
    let selectedSkillName: String?
    let selectedSkillAgent: String?
    let projectRoot: String?
    let currentCWD: String?
    let workspace: String?
    let limit: Int?
    let includeIssueGroups: Bool
    let includeSafeNextActions: Bool
    let includeRecordedSteps: Bool
    let includeEvidence: Bool
    let includeSafetyFlags: Bool

    enum CodingKeys: String, CodingKey {
        case taskText = "task_text"
        case task
        case userIntent = "user_intent"
        case agent
        case agents
        case selectedSkillID = "selected_skill_id"
        case selectedSkillIDAlt = "selectedSkillID"
        case selectedSkillName = "selected_skill_name"
        case selectedSkillNameAlt = "selectedSkillName"
        case selectedSkillAgent = "selected_skill_agent"
        case selectedSkillAgentAlt = "selectedSkillAgent"
        case projectRoot = "project_root"
        case projectRootAlt = "projectRoot"
        case currentCWD = "current_cwd"
        case currentCWDAlt = "currentCWD"
        case workspace
        case workspaceID = "workspace_id"
        case limit
        case includeIssueGroups = "include_issue_groups"
        case includeIssueGroupsAlt = "includeIssueGroups"
        case includeSafeNextActions = "include_safe_next_actions"
        case includeSafeNextActionsAlt = "includeSafeNextActions"
        case includeRecordedSteps = "include_recorded_steps"
        case includeRecordedStepsAlt = "includeRecordedSteps"
        case includeEvidence = "include_evidence"
        case includeEvidenceAlt = "includeEvidence"
        case includeSafetyFlags = "include_safety_flags"
        case includeSafetyFlagsAlt = "includeSafetyFlags"
    }

    init(
        taskText: String? = nil,
        agent: String? = nil,
        agents: [String] = [],
        selectedSkillID: String? = nil,
        selectedSkillName: String? = nil,
        selectedSkillAgent: String? = nil,
        projectRoot: String? = nil,
        currentCWD: String? = nil,
        workspace: String? = nil,
        limit: Int? = nil,
        includeIssueGroups: Bool = true,
        includeSafeNextActions: Bool = true,
        includeRecordedSteps: Bool = true,
        includeEvidence: Bool = true,
        includeSafetyFlags: Bool = true
    ) {
        self.taskText = taskText
        self.agent = agent
        self.agents = agents
        self.selectedSkillID = selectedSkillID
        self.selectedSkillName = selectedSkillName
        self.selectedSkillAgent = selectedSkillAgent
        self.projectRoot = projectRoot
        self.currentCWD = currentCWD
        self.workspace = workspace
        self.limit = limit
        self.includeIssueGroups = includeIssueGroups
        self.includeSafeNextActions = includeSafeNextActions
        self.includeRecordedSteps = includeRecordedSteps
        self.includeEvidence = includeEvidence
        self.includeSafetyFlags = includeSafetyFlags
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        taskText = try container.decodeGuidedCleanupString(keys: [.taskText, .task, .userIntent])
        agent = try container.decodeGuidedCleanupString(keys: [.agent])
        agents = try container.decodeGuidedCleanupStringArray(keys: [.agents, .agent])
        selectedSkillID = try container.decodeGuidedCleanupString(keys: [.selectedSkillID, .selectedSkillIDAlt])
        selectedSkillName = try container.decodeGuidedCleanupString(keys: [.selectedSkillName, .selectedSkillNameAlt])
        selectedSkillAgent = try container.decodeGuidedCleanupString(keys: [.selectedSkillAgent, .selectedSkillAgentAlt])
        projectRoot = try container.decodeGuidedCleanupString(keys: [.projectRoot, .projectRootAlt])
        currentCWD = try container.decodeGuidedCleanupString(keys: [.currentCWD, .currentCWDAlt])
        workspace = try container.decodeGuidedCleanupString(keys: [.workspace, .workspaceID])
        limit = try container.decodeGuidedCleanupInt(keys: [.limit])
        includeIssueGroups = try container.decodeGuidedCleanupBool(keys: [.includeIssueGroups, .includeIssueGroupsAlt]) ?? true
        includeSafeNextActions = try container.decodeGuidedCleanupBool(keys: [.includeSafeNextActions, .includeSafeNextActionsAlt]) ?? true
        includeRecordedSteps = try container.decodeGuidedCleanupBool(keys: [.includeRecordedSteps, .includeRecordedStepsAlt]) ?? true
        includeEvidence = try container.decodeGuidedCleanupBool(keys: [.includeEvidence, .includeEvidenceAlt]) ?? true
        includeSafetyFlags = try container.decodeGuidedCleanupBool(keys: [.includeSafetyFlags, .includeSafetyFlagsAlt]) ?? true
    }
}

struct GuidedCleanupFlowSummary: Decodable, Hashable {
    let stepCount: Int
    let issueGroupCount: Int
    let safeActionCount: Int
    let recordedStepCount: Int
    let recommendedStepCount: Int
    let gapCount: Int
    let blockerCount: Int
    let summaryText: String

    enum CodingKeys: String, CodingKey {
        case stepCount = "step_count"
        case stepCountAlt = "stepCount"
        case steps
        case flowSteps = "flow_steps"
        case issueGroupCount = "issue_group_count"
        case issueGroupCountAlt = "issueGroupCount"
        case issueGroups = "issue_groups"
        case safeActionCount = "safe_action_count"
        case safeActionCountAlt = "safeActionCount"
        case safeNextActions = "safe_next_actions"
        case recordedStepCount = "recorded_step_count"
        case recordedStepCountAlt = "recordedStepCount"
        case recordedSteps = "recorded_steps"
        case recommendedStepCount = "recommended_step_count"
        case recommendedStepCountAlt = "recommendedStepCount"
        case recommendedSteps = "recommended_steps"
        case gapCount = "gap_count"
        case gaps
        case blockerCount = "blocker_count"
        case blockers
        case summary
        case message
        case text
    }

    init(
        stepCount: Int = 0,
        issueGroupCount: Int = 0,
        safeActionCount: Int = 0,
        recordedStepCount: Int = 0,
        recommendedStepCount: Int = 0,
        gapCount: Int = 0,
        blockerCount: Int = 0,
        summaryText: String = ""
    ) {
        self.stepCount = stepCount
        self.issueGroupCount = issueGroupCount
        self.safeActionCount = safeActionCount
        self.recordedStepCount = recordedStepCount
        self.recommendedStepCount = recommendedStepCount
        self.gapCount = gapCount
        self.blockerCount = blockerCount
        self.summaryText = summaryText
    }

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            self.init(summaryText: value)
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            stepCount: try container.decodeGuidedCleanupInt(keys: [.stepCount, .stepCountAlt, .steps, .flowSteps]) ?? 0,
            issueGroupCount: try container.decodeGuidedCleanupInt(keys: [.issueGroupCount, .issueGroupCountAlt, .issueGroups]) ?? 0,
            safeActionCount: try container.decodeGuidedCleanupInt(keys: [.safeActionCount, .safeActionCountAlt, .safeNextActions]) ?? 0,
            recordedStepCount: try container.decodeGuidedCleanupInt(keys: [.recordedStepCount, .recordedStepCountAlt, .recordedSteps]) ?? 0,
            recommendedStepCount: try container.decodeGuidedCleanupInt(keys: [.recommendedStepCount, .recommendedStepCountAlt, .recommendedSteps]) ?? 0,
            gapCount: try container.decodeGuidedCleanupInt(keys: [.gapCount, .gaps]) ?? 0,
            blockerCount: try container.decodeGuidedCleanupInt(keys: [.blockerCount, .blockers]) ?? 0,
            summaryText: try container.decodeGuidedCleanupString(keys: [.summary, .message, .text]) ?? ""
        )
    }
}

struct GuidedCleanupFlowStep: Decodable, Identifiable, Hashable {
    let id: String
    let title: String
    let kind: String
    let status: String
    let priority: String
    let order: Int?
    let actionLabel: String
    let safeEntryMethod: String?
    let existingSafeMethod: String?
    let safeActionDeepLink: GuidedCleanupSafeActionDeepLink
    let reviewArea: String?
    let agent: String?
    let skill: CapabilityTaxonomySkill?
    let rationale: String
    let detail: String
    let recommended: Bool
    let appLocalRecordOnly: Bool
    let evidenceRefs: [String]
    let gapNotes: [String]
    let blockerNotes: [String]
    let safetyFlags: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case stepID = "step_id"
        case stepIDAlt = "stepID"
        case itemID = "item_id"
        case title
        case name
        case label
        case kind
        case category
        case type
        case status
        case state
        case priority
        case severity
        case order
        case rank
        case actionLabel = "action_label"
        case actionLabelAlt = "actionLabel"
        case safeActionLabel = "safe_action_label"
        case suggestedAction = "suggested_action"
        case recommendedActionLabel = "recommended_action_label"
        case recommendedActionLabelAlt = "recommendedActionLabel"
        case action
        case safeEntryMethod = "safe_entry_method"
        case safeEntryMethodAlt = "safeEntryMethod"
        case existingSafeMethod = "existing_safe_method"
        case existingSafeMethodAlt = "existingSafeMethod"
        case safeActionDeepLink = "safe_action_deep_link"
        case safeActionDeepLinkAlt = "safeActionDeepLink"
        case deepLink = "deep_link"
        case reviewArea = "review_area"
        case reviewAreaAlt = "reviewArea"
        case nextArea = "next_area"
        case agent
        case skill
        case affectedSkill = "affected_skill"
        case affectedSkillAlt = "affectedSkill"
        case rationale
        case reason
        case summary
        case detail
        case message
        case recommended
        case isRecommended = "is_recommended"
        case isRecommendedAlt = "isRecommended"
        case selected
        case appLocalRecordOnly = "app_local_record_only"
        case appLocalRecordOnlyAlt = "appLocalRecordOnly"
        case metadataOnly = "metadata_only"
        case evidenceRefs = "evidence_refs"
        case evidenceRefsAlt = "evidenceRefs"
        case evidence
        case gapNotes = "gap_notes"
        case gapNotesAlt = "gapNotes"
        case gaps
        case blockerNotes = "blocker_notes"
        case blockerNotesAlt = "blockerNotes"
        case blockers
        case safetyFlags = "safety_flags"
        case safetyFlagsAlt = "safetyFlags"
        case safety
        case flags
    }

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self),
           let text = value.guidedCleanupNonEmpty {
            id = text
            title = text
            kind = UIStrings.guidedCleanupFlowStep
            status = UIStrings.guidedCleanupFlowPreviewOnly
            priority = UIStrings.unknown
            order = nil
            actionLabel = UIStrings.guidedCleanupFlowRecordGuidance
            safeEntryMethod = nil
            existingSafeMethod = nil
            safeActionDeepLink = GuidedCleanupSafeActionDeepLink.fallback(label: UIStrings.guidedCleanupFlowRecordGuidance)
            reviewArea = nil
            agent = nil
            skill = nil
            rationale = text
            detail = ""
            recommended = false
            appLocalRecordOnly = true
            evidenceRefs = []
            gapNotes = []
            blockerNotes = []
            safetyFlags = []
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeGuidedCleanupString(keys: [.title, .name, .label]) ?? UIStrings.guidedCleanupFlowStep
        kind = try container.decodeGuidedCleanupString(keys: [.kind, .category, .type]) ?? UIStrings.unknown
        status = try container.decodeGuidedCleanupString(keys: [.status, .state]) ?? UIStrings.guidedCleanupFlowPreviewOnly
        priority = try container.decodeGuidedCleanupString(keys: [.priority, .severity]) ?? UIStrings.unknown
        order = try container.decodeGuidedCleanupInt(keys: [.order, .rank])
        actionLabel = try container.decodeGuidedCleanupString(keys: [.actionLabel, .actionLabelAlt, .safeActionLabel, .suggestedAction, .recommendedActionLabel, .recommendedActionLabelAlt, .action]) ?? UIStrings.guidedCleanupFlowRecordGuidance
        safeEntryMethod = try container.decodeGuidedCleanupString(keys: [.safeEntryMethod, .safeEntryMethodAlt])
        existingSafeMethod = try container.decodeGuidedCleanupString(keys: [.existingSafeMethod, .existingSafeMethodAlt])
        reviewArea = try container.decodeGuidedCleanupString(keys: [.reviewArea, .reviewAreaAlt, .nextArea])
        agent = try container.decodeGuidedCleanupString(keys: [.agent])
        skill = try container.decodeIfPresent(CapabilityTaxonomySkill.self, forKey: .skill)
            ?? container.decodeIfPresent(CapabilityTaxonomySkill.self, forKey: .affectedSkill)
            ?? container.decodeIfPresent(CapabilityTaxonomySkill.self, forKey: .affectedSkillAlt)
        rationale = try container.decodeGuidedCleanupString(keys: [.rationale, .reason, .summary]) ?? ""
        detail = try container.decodeGuidedCleanupString(keys: [.detail, .message]) ?? ""
        recommended = try container.decodeGuidedCleanupBool(keys: [.recommended, .isRecommended, .isRecommendedAlt, .selected]) ?? false
        appLocalRecordOnly = try container.decodeGuidedCleanupBool(keys: [.appLocalRecordOnly, .appLocalRecordOnlyAlt, .metadataOnly]) ?? true
        evidenceRefs = try container.decodeGuidedCleanupStringArray(keys: [.evidenceRefs, .evidenceRefsAlt, .evidence])
        gapNotes = try container.decodeGuidedCleanupStringArray(keys: [.gapNotes, .gapNotesAlt, .gaps])
        blockerNotes = try container.decodeGuidedCleanupStringArray(keys: [.blockerNotes, .blockerNotesAlt, .blockers])
        safetyFlags = try container.decodeGuidedCleanupStringArray(keys: [.safetyFlags, .safetyFlagsAlt, .safety, .flags])
        id = try container.decodeGuidedCleanupString(keys: [.id, .stepID, .stepIDAlt, .itemID]) ?? "\(kind):\(title)"
        let explicitDeepLink = try container.decodeIfPresent(GuidedCleanupSafeActionDeepLink.self, forKey: .safeActionDeepLink)
        let explicitDeepLinkAlt = try container.decodeIfPresent(GuidedCleanupSafeActionDeepLink.self, forKey: .safeActionDeepLinkAlt)
        let genericDeepLink = try container.decodeIfPresent(GuidedCleanupSafeActionDeepLink.self, forKey: .deepLink)
        safeActionDeepLink = explicitDeepLink
            ?? explicitDeepLinkAlt
            ?? genericDeepLink
            ?? GuidedCleanupSafeActionDeepLink.fallback(
                label: actionLabel,
                method: safeEntryMethod ?? existingSafeMethod,
                detailSection: reviewArea,
                instanceIDs: [skill?.instanceID].compactMap { $0 },
                relatedStepIDs: [id],
                evidenceRefs: evidenceRefs
            )
    }
}

struct GuidedCleanupIssueGroup: Decodable, Identifiable, Hashable {
    let id: String
    let title: String
    let category: String
    let severity: String
    let status: String
    let count: Int
    let summary: String
    let issueRefs: [String]
    let safeNextActionIDs: [String]
    let evidenceRefs: [String]
    let gapNotes: [String]
    let blockerNotes: [String]
    let safetyFlags: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case groupID = "group_id"
        case title
        case name
        case label
        case category
        case kind
        case type
        case severity
        case priority
        case status
        case state
        case count
        case itemCount = "item_count"
        case issues
        case summary
        case rationale
        case detail
        case issueRefs = "issue_refs"
        case refs
        case safeNextActionIDs = "safe_next_action_ids"
        case safeNextActions = "safe_next_actions"
        case evidenceRefs = "evidence_refs"
        case evidence
        case gapNotes = "gap_notes"
        case gaps
        case blockerNotes = "blocker_notes"
        case blockers
        case safetyFlags = "safety_flags"
        case safety
    }

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self),
           let text = value.guidedCleanupNonEmpty {
            id = text
            title = text
            category = UIStrings.unknown
            severity = UIStrings.unknown
            status = UIStrings.guidedCleanupFlowPreviewOnly
            count = 0
            summary = text
            issueRefs = []
            safeNextActionIDs = []
            evidenceRefs = []
            gapNotes = []
            blockerNotes = []
            safetyFlags = []
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeGuidedCleanupString(keys: [.title, .name, .label]) ?? UIStrings.guidedCleanupFlowIssueGroup
        category = try container.decodeGuidedCleanupString(keys: [.category, .kind, .type]) ?? UIStrings.unknown
        severity = try container.decodeGuidedCleanupString(keys: [.severity, .priority]) ?? UIStrings.unknown
        status = try container.decodeGuidedCleanupString(keys: [.status, .state]) ?? UIStrings.guidedCleanupFlowPreviewOnly
        count = try container.decodeGuidedCleanupInt(keys: [.count, .itemCount, .issues]) ?? 0
        summary = try container.decodeGuidedCleanupString(keys: [.summary, .rationale, .detail]) ?? ""
        issueRefs = try container.decodeGuidedCleanupStringArray(keys: [.issueRefs, .refs, .issues])
        safeNextActionIDs = try container.decodeGuidedCleanupStringArray(keys: [.safeNextActionIDs, .safeNextActions])
        evidenceRefs = try container.decodeGuidedCleanupStringArray(keys: [.evidenceRefs, .evidence])
        gapNotes = try container.decodeGuidedCleanupStringArray(keys: [.gapNotes, .gaps])
        blockerNotes = try container.decodeGuidedCleanupStringArray(keys: [.blockerNotes, .blockers])
        safetyFlags = try container.decodeGuidedCleanupStringArray(keys: [.safetyFlags, .safety])
        id = try container.decodeGuidedCleanupString(keys: [.id, .groupID]) ?? "\(category):\(title)"
    }
}

struct GuidedCleanupSafeAction: Decodable, Identifiable, Hashable {
    let id: String
    let title: String
    let kind: String
    let entryMethod: String?
    let reviewArea: String?
    let description: String
    let requiresPreview: Bool
    let requiresConfirmation: Bool
    let copyOnly: Bool
    let requiresExistingSafeEntry: Bool
    let appLocalOnly: Bool
    let canApplyFix: Bool
    let relatedStepIDs: [String]
    let deepLink: GuidedCleanupSafeActionDeepLink
    let evidenceRefs: [String]
    let safetyFlags: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case actionID = "action_id"
        case title
        case name
        case label
        case kind
        case category
        case type
        case entryMethod = "entry_method"
        case entryMethodAlt = "entryMethod"
        case reviewArea = "review_area"
        case reviewAreaAlt = "reviewArea"
        case nextArea = "next_area"
        case description
        case detail
        case summary
        case requiresPreview = "requires_preview"
        case requiresPreviewAlt = "requiresPreview"
        case requiresConfirmation = "requires_confirmation"
        case requiresConfirmationAlt = "requiresConfirmation"
        case copyOnly = "copy_only"
        case copyOnlyAlt = "copyOnly"
        case requiresExistingSafeEntry = "requires_existing_safe_entry"
        case existingSafeEntry = "existing_safe_entry"
        case appLocalOnly = "app_local_only"
        case metadataOnly = "metadata_only"
        case canApplyFix = "can_apply_fix"
        case applyAllowed = "apply_allowed"
        case relatedStepIDs = "related_step_ids"
        case relatedStepIDsAlt = "relatedStepIDs"
        case deepLink = "deep_link"
        case deepLinkAlt = "deepLink"
        case evidenceRefs = "evidence_refs"
        case evidence
        case safetyFlags = "safety_flags"
        case safety
    }

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self),
           let text = value.guidedCleanupNonEmpty {
            id = text
            title = text
            kind = UIStrings.guidedCleanupFlowSafeAction
            entryMethod = nil
            reviewArea = nil
            description = text
            requiresPreview = true
            requiresConfirmation = false
            copyOnly = false
            requiresExistingSafeEntry = true
            appLocalOnly = true
            canApplyFix = false
            relatedStepIDs = []
            deepLink = GuidedCleanupSafeActionDeepLink.fallback(label: text)
            evidenceRefs = []
            safetyFlags = []
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeGuidedCleanupString(keys: [.title, .name, .label]) ?? UIStrings.guidedCleanupFlowSafeAction
        kind = try container.decodeGuidedCleanupString(keys: [.kind, .category, .type]) ?? UIStrings.unknown
        entryMethod = try container.decodeGuidedCleanupString(keys: [.entryMethod, .entryMethodAlt])
        reviewArea = try container.decodeGuidedCleanupString(keys: [.reviewArea, .reviewAreaAlt, .nextArea])
        description = try container.decodeGuidedCleanupString(keys: [.description, .detail, .summary]) ?? ""
        requiresPreview = try container.decodeGuidedCleanupBool(keys: [.requiresPreview, .requiresPreviewAlt]) ?? true
        requiresConfirmation = try container.decodeGuidedCleanupBool(keys: [.requiresConfirmation, .requiresConfirmationAlt]) ?? false
        copyOnly = try container.decodeGuidedCleanupBool(keys: [.copyOnly, .copyOnlyAlt]) ?? false
        requiresExistingSafeEntry = try container.decodeGuidedCleanupBool(keys: [.requiresExistingSafeEntry, .existingSafeEntry]) ?? true
        appLocalOnly = try container.decodeGuidedCleanupBool(keys: [.appLocalOnly, .metadataOnly]) ?? true
        canApplyFix = try container.decodeGuidedCleanupBool(keys: [.canApplyFix, .applyAllowed]) ?? false
        relatedStepIDs = try container.decodeGuidedCleanupStringArray(keys: [.relatedStepIDs, .relatedStepIDsAlt])
        evidenceRefs = try container.decodeGuidedCleanupStringArray(keys: [.evidenceRefs, .evidence])
        safetyFlags = try container.decodeGuidedCleanupStringArray(keys: [.safetyFlags, .safety])
        id = try container.decodeGuidedCleanupString(keys: [.id, .actionID]) ?? "\(kind):\(title)"
        let explicitDeepLink = try container.decodeIfPresent(GuidedCleanupSafeActionDeepLink.self, forKey: .deepLink)
        let explicitDeepLinkAlt = try container.decodeIfPresent(GuidedCleanupSafeActionDeepLink.self, forKey: .deepLinkAlt)
        deepLink = explicitDeepLink
            ?? explicitDeepLinkAlt
            ?? GuidedCleanupSafeActionDeepLink.fallback(
                label: title,
                method: entryMethod,
                detailSection: reviewArea,
                relatedStepIDs: relatedStepIDs,
                evidenceRefs: evidenceRefs,
                requiresPreview: requiresPreview,
                requiresConfirmation: requiresConfirmation,
                copyOnly: copyOnly,
                canApply: canApplyFix
            )
    }
}

struct GuidedCleanupSafeActionDeepLink: Decodable, Hashable {
    let label: String
    let target: String
    let detailSection: String?
    let method: String?
    let trigger: String
    let previewOnly: Bool
    let requiresConfirmation: Bool
    let copyOnly: Bool
    let canApply: Bool
    let instanceIDs: [String]
    let relatedStepIDs: [String]
    let evidenceRefs: [String]
    let safetyFlags: [String]

    enum CodingKeys: String, CodingKey {
        case label
        case title
        case target
        case detailSection = "detail_section"
        case detailSectionAlt = "detailSection"
        case section
        case method
        case entryMethod = "entry_method"
        case entryMethodAlt = "entryMethod"
        case trigger
        case action
        case previewOnly = "preview_only"
        case previewOnlyAlt = "previewOnly"
        case requiresConfirmation = "requires_confirmation"
        case requiresConfirmationAlt = "requiresConfirmation"
        case copyOnly = "copy_only"
        case copyOnlyAlt = "copyOnly"
        case canApply = "can_apply"
        case canApplyAlt = "canApply"
        case applyAllowed = "apply_allowed"
        case instanceIDs = "instance_ids"
        case instanceIDsAlt = "instanceIDs"
        case relatedStepIDs = "related_step_ids"
        case relatedStepIDsAlt = "relatedStepIDs"
        case evidenceRefs = "evidence_refs"
        case evidenceRefsAlt = "evidenceRefs"
        case evidence
        case safetyFlags = "safety_flags"
        case safetyFlagsAlt = "safetyFlags"
        case safety
    }

    init(
        label: String,
        target: String = "detail_section",
        detailSection: String? = nil,
        method: String? = nil,
        trigger: String = "selectDetailSection",
        previewOnly: Bool = true,
        requiresConfirmation: Bool = false,
        copyOnly: Bool = false,
        canApply: Bool = false,
        instanceIDs: [String] = [],
        relatedStepIDs: [String] = [],
        evidenceRefs: [String] = [],
        safetyFlags: [String] = []
    ) {
        self.label = label
        self.target = target
        self.detailSection = detailSection
        self.method = method
        self.trigger = trigger
        self.previewOnly = previewOnly
        self.requiresConfirmation = requiresConfirmation
        self.copyOnly = copyOnly
        self.canApply = canApply
        self.instanceIDs = instanceIDs
        self.relatedStepIDs = relatedStepIDs
        self.evidenceRefs = evidenceRefs
        self.safetyFlags = safetyFlags
    }

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self),
           let text = value.guidedCleanupNonEmpty {
            self = .fallback(label: text)
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let method = try container.decodeGuidedCleanupString(keys: [.method, .entryMethod, .entryMethodAlt])
        let detailSection = try container.decodeGuidedCleanupString(keys: [.detailSection, .detailSectionAlt, .section])
        self.init(
            label: try container.decodeGuidedCleanupString(keys: [.label, .title]) ?? "Open safe entry",
            target: try container.decodeGuidedCleanupString(keys: [.target]) ?? GuidedCleanupSafeActionDeepLink.defaultTarget(method: method, detailSection: detailSection),
            detailSection: detailSection ?? GuidedCleanupSafeActionDeepLink.defaultDetailSection(for: method),
            method: method,
            trigger: try container.decodeGuidedCleanupString(keys: [.trigger, .action]) ?? GuidedCleanupSafeActionDeepLink.defaultTrigger(for: method),
            previewOnly: try container.decodeGuidedCleanupBool(keys: [.previewOnly, .previewOnlyAlt]) ?? true,
            requiresConfirmation: try container.decodeGuidedCleanupBool(keys: [.requiresConfirmation, .requiresConfirmationAlt]) ?? false,
            copyOnly: try container.decodeGuidedCleanupBool(keys: [.copyOnly, .copyOnlyAlt]) ?? false,
            canApply: try container.decodeGuidedCleanupBool(keys: [.canApply, .canApplyAlt, .applyAllowed]) ?? false,
            instanceIDs: try container.decodeGuidedCleanupStringArray(keys: [.instanceIDs, .instanceIDsAlt]),
            relatedStepIDs: try container.decodeGuidedCleanupStringArray(keys: [.relatedStepIDs, .relatedStepIDsAlt]),
            evidenceRefs: try container.decodeGuidedCleanupStringArray(keys: [.evidenceRefs, .evidenceRefsAlt, .evidence]),
            safetyFlags: try container.decodeGuidedCleanupStringArray(keys: [.safetyFlags, .safetyFlagsAlt, .safety])
        )
    }

    static func fallback(
        label: String,
        method: String? = nil,
        detailSection: String? = nil,
        instanceIDs: [String] = [],
        relatedStepIDs: [String] = [],
        evidenceRefs: [String] = [],
        requiresPreview: Bool = true,
        requiresConfirmation: Bool = false,
        copyOnly: Bool = false,
        canApply: Bool = false
    ) -> GuidedCleanupSafeActionDeepLink {
        GuidedCleanupSafeActionDeepLink(
            label: label,
            target: defaultTarget(method: method, detailSection: detailSection),
            detailSection: detailSection ?? defaultDetailSection(for: method),
            method: method,
            trigger: defaultTrigger(for: method),
            previewOnly: requiresPreview,
            requiresConfirmation: requiresConfirmation,
            copyOnly: copyOnly,
            canApply: canApply,
            instanceIDs: instanceIDs,
            relatedStepIDs: relatedStepIDs,
            evidenceRefs: evidenceRefs,
            safetyFlags: []
        )
    }

    private static func defaultTarget(method: String?, detailSection: String?) -> String {
        if method == "batch.previewSkillToggles" {
            return "sidebar_preview"
        }
        if method == "cleanup.recordGuidedStep" {
            return "guided_metadata"
        }
        if detailSection != nil || method == nil || method == "cleanup.listQueue" || method == "skill.lifecycleTimeline" || method == "task.buildCockpit" {
            return "detail_section"
        }
        return "analysis_action"
    }

    private static func defaultDetailSection(for method: String?) -> String? {
        switch method {
        case "cleanup.listQueue", "batch.previewSkillToggles":
            return "cleanup"
        case "skill.lifecycleTimeline":
            return "analysis"
        case "task.buildCockpit":
            return "taskCockpit"
        case "cleanup.recordGuidedStep":
            return "guidedCleanup"
        case "remediation.plan", "remediation.previewDrafts", "remediation.previewImpact", "remediation.batchReview":
            return "analysis"
        default:
            return nil
        }
    }

    private static func defaultTrigger(for method: String?) -> String {
        switch method {
        case "remediation.plan":
            return "planRemediation"
        case "remediation.previewDrafts":
            return "previewRemediationDrafts"
        case "remediation.previewImpact":
            return "previewRemediationImpact"
        case "remediation.batchReview":
            return "reviewRemediationBatch"
        case "skill.lifecycleTimeline":
            return "loadSkillLifecycleTimeline"
        case "task.buildCockpit":
            return "buildTaskCockpit"
        case "batch.previewSkillToggles":
            return "openSafeBatchPreviewPanel"
        case "cleanup.recordGuidedStep":
            return "recordGuidedStep"
        default:
            return "selectDetailSection"
        }
    }
}

struct GuidedCleanupRecordedStep: Decodable, Identifiable, Hashable {
    let id: String
    let stepID: String?
    let title: String
    let status: String
    let decision: String?
    let sourceMethod: String?
    let recordedAt: String?
    let note: String
    let redacted: Bool
    let appLocalOnly: Bool
    let evidenceRefs: [String]
    let safetyFlags: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case recordID = "record_id"
        case stepID = "step_id"
        case stepIDAlt = "stepID"
        case title
        case name
        case label
        case status
        case state
        case decision
        case sourceMethod = "source_method"
        case recordedAt = "recorded_at"
        case createdAt = "created_at"
        case note
        case summary
        case detail
        case redacted
        case metadataRedacted = "metadata_redacted"
        case appLocalOnly = "app_local_only"
        case localOnly = "local_only"
        case evidenceRefs = "evidence_refs"
        case evidence
        case safetyFlags = "safety_flags"
        case safety
    }

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self),
           let text = value.guidedCleanupNonEmpty {
            id = text
            stepID = nil
            title = text
            status = UIStrings.remediationHistoryStatusRecorded
            decision = nil
            sourceMethod = nil
            recordedAt = nil
            note = text
            redacted = true
            appLocalOnly = true
            evidenceRefs = []
            safetyFlags = []
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        stepID = try container.decodeGuidedCleanupString(keys: [.stepID, .stepIDAlt])
        title = try container.decodeGuidedCleanupString(keys: [.title, .name, .label]) ?? UIStrings.guidedCleanupFlowRecordedStep
        status = try container.decodeGuidedCleanupString(keys: [.status, .state]) ?? UIStrings.remediationHistoryStatusRecorded
        decision = try container.decodeGuidedCleanupString(keys: [.decision])
        sourceMethod = try container.decodeGuidedCleanupString(keys: [.sourceMethod])
        recordedAt = try container.decodeGuidedCleanupString(keys: [.recordedAt, .createdAt])
        note = try container.decodeGuidedCleanupString(keys: [.note, .summary, .detail]) ?? ""
        redacted = try container.decodeGuidedCleanupBool(keys: [.redacted, .metadataRedacted]) ?? true
        appLocalOnly = try container.decodeGuidedCleanupBool(keys: [.appLocalOnly, .localOnly]) ?? true
        evidenceRefs = try container.decodeGuidedCleanupStringArray(keys: [.evidenceRefs, .evidence])
        safetyFlags = try container.decodeGuidedCleanupStringArray(keys: [.safetyFlags, .safety])
        id = try container.decodeGuidedCleanupString(keys: [.id, .recordID]) ?? [stepID, title, recordedAt].compactMap { $0?.guidedCleanupNonEmpty }.joined(separator: ":")
    }
}

struct GuidedCleanupFlowResult: Decodable, Hashable {
    let generatedBy: String
    let catalogAvailable: Bool
    let filters: GuidedCleanupFlowFilters
    let summary: GuidedCleanupFlowSummary
    let flowSteps: [GuidedCleanupFlowStep]
    let issueGroups: [GuidedCleanupIssueGroup]
    let safeNextActions: [GuidedCleanupSafeAction]
    let recordedSteps: [GuidedCleanupRecordedStep]
    let gapNotes: [String]
    let blockerNotes: [String]
    let evidenceReferences: [GuidedCleanupFlowEvidenceReference]
    let promptRequest: GuidedCleanupFlowPromptRequest?
    let safetyFlags: GuidedCleanupFlowSafety
    let fallbackReason: String?

    var isUnavailable: Bool {
        generatedBy == "unavailable"
            || (!catalogAvailable && flowSteps.isEmpty && issueGroups.isEmpty && safeNextActions.isEmpty && fallbackReason != nil)
    }

    var recommendedStep: GuidedCleanupFlowStep? {
        flowSteps.first(where: \.recommended) ?? flowSteps.first
    }

    enum CodingKeys: String, CodingKey {
        case generatedBy = "generated_by"
        case generatedByAlt = "generatedBy"
        case catalogAvailable = "catalog_available"
        case catalogAvailableAlt = "catalogAvailable"
        case filters
        case summary
        case flowSteps = "flow_steps"
        case flowStepsAlt = "flowSteps"
        case steps
        case rows
        case issueGroups = "issue_groups"
        case issueGroupsAlt = "issueGroups"
        case groups
        case safeNextActions = "safe_next_actions"
        case safeNextActionsAlt = "safeNextActions"
        case safeActions = "safe_actions"
        case actions
        case recordedSteps = "recorded_steps"
        case recordedStepsAlt = "recordedSteps"
        case records
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
        case promptMetadata = "prompt_metadata"
        case promptMetadataAlt = "promptMetadata"
        case safetyFlags = "safety_flags"
        case safetyFlagsAlt = "safetyFlags"
        case safety
        case fallbackReason = "fallback_reason"
        case fallbackReasonAlt = "fallbackReason"
        case reason
    }

    init(
        generatedBy: String = "local-v2.67",
        catalogAvailable: Bool = true,
        filters: GuidedCleanupFlowFilters = GuidedCleanupFlowFilters(),
        summary: GuidedCleanupFlowSummary = GuidedCleanupFlowSummary(),
        flowSteps: [GuidedCleanupFlowStep] = [],
        issueGroups: [GuidedCleanupIssueGroup] = [],
        safeNextActions: [GuidedCleanupSafeAction] = [],
        recordedSteps: [GuidedCleanupRecordedStep] = [],
        gapNotes: [String] = [],
        blockerNotes: [String] = [],
        evidenceReferences: [GuidedCleanupFlowEvidenceReference] = [],
        promptRequest: GuidedCleanupFlowPromptRequest? = nil,
        safetyFlags: GuidedCleanupFlowSafety = GuidedCleanupFlowSafety(),
        fallbackReason: String? = nil
    ) {
        self.generatedBy = generatedBy
        self.catalogAvailable = catalogAvailable
        self.filters = filters
        self.summary = summary
        self.flowSteps = flowSteps
        self.issueGroups = issueGroups
        self.safeNextActions = safeNextActions
        self.recordedSteps = recordedSteps
        self.gapNotes = gapNotes
        self.blockerNotes = blockerNotes
        self.evidenceReferences = evidenceReferences
        self.promptRequest = promptRequest
        self.safetyFlags = safetyFlags
        self.fallbackReason = fallbackReason
    }

    init(from decoder: Decoder) throws {
        if let rows = try? decoder.singleValueContainer().decode([GuidedCleanupFlowStep].self) {
            self.init(flowSteps: rows)
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let steps = try container.decodeGuidedCleanupRows(type: GuidedCleanupFlowStep.self, keys: [.flowSteps, .flowStepsAlt, .steps, .rows])
        let groups = try container.decodeGuidedCleanupRows(type: GuidedCleanupIssueGroup.self, keys: [.issueGroups, .issueGroupsAlt, .groups])
        let actions = try container.decodeGuidedCleanupRows(type: GuidedCleanupSafeAction.self, keys: [.safeNextActions, .safeNextActionsAlt, .safeActions, .actions])
        let records = try container.decodeGuidedCleanupRows(type: GuidedCleanupRecordedStep.self, keys: [.recordedSteps, .recordedStepsAlt, .records])
        self.init(
            generatedBy: try container.decodeGuidedCleanupString(keys: [.generatedBy, .generatedByAlt]) ?? "local-v2.67",
            catalogAvailable: try container.decodeGuidedCleanupBool(keys: [.catalogAvailable, .catalogAvailableAlt]) ?? true,
            filters: try container.decodeIfPresent(GuidedCleanupFlowFilters.self, forKey: .filters) ?? GuidedCleanupFlowFilters(),
            summary: try container.decodeIfPresent(GuidedCleanupFlowSummary.self, forKey: .summary)
                ?? GuidedCleanupFlowSummary(stepCount: steps.count, issueGroupCount: groups.count, safeActionCount: actions.count, recordedStepCount: records.count, recommendedStepCount: steps.filter(\.recommended).count),
            flowSteps: steps,
            issueGroups: groups,
            safeNextActions: actions,
            recordedSteps: records,
            gapNotes: try container.decodeGuidedCleanupStringArray(keys: [.gapNotes, .gapNotesAlt, .gaps]),
            blockerNotes: try container.decodeGuidedCleanupStringArray(keys: [.blockerNotes, .blockerNotesAlt, .blockers]),
            evidenceReferences: try container.decodeGuidedCleanupRows(type: GuidedCleanupFlowEvidenceReference.self, keys: [.evidenceReferences, .evidenceReferencesAlt, .evidence]),
            promptRequest: try container.decodeIfPresent(GuidedCleanupFlowPromptRequest.self, forKey: .promptRequest)
                ?? container.decodeIfPresent(GuidedCleanupFlowPromptRequest.self, forKey: .promptRequestAlt)
                ?? container.decodeIfPresent(GuidedCleanupFlowPromptRequest.self, forKey: .promptMetadata)
                ?? container.decodeIfPresent(GuidedCleanupFlowPromptRequest.self, forKey: .promptMetadataAlt),
            safetyFlags: try container.decodeIfPresent(GuidedCleanupFlowSafety.self, forKey: .safetyFlags)
                ?? container.decodeIfPresent(GuidedCleanupFlowSafety.self, forKey: .safetyFlagsAlt)
                ?? container.decodeIfPresent(GuidedCleanupFlowSafety.self, forKey: .safety)
                ?? GuidedCleanupFlowSafety(),
            fallbackReason: try container.decodeGuidedCleanupString(keys: [.fallbackReason, .fallbackReasonAlt, .reason])
        )
    }

    static func unavailable(reason: String = UIStrings.guidedCleanupFlowUnavailable) -> GuidedCleanupFlowResult {
        GuidedCleanupFlowResult(
            generatedBy: "unavailable",
            catalogAvailable: false,
            summary: GuidedCleanupFlowSummary(summaryText: reason),
            safetyFlags: GuidedCleanupFlowSafety(notes: [reason]),
            fallbackReason: reason
        )
    }
}

struct GuidedCleanupRecordStepResult: Decodable, Hashable {
    let recorded: Bool
    let generatedBy: String
    let appLocalOnly: Bool
    let metadataRedacted: Bool
    let record: GuidedCleanupRecordedStep?
    let records: [GuidedCleanupRecordedStep]
    let summary: GuidedCleanupFlowSummary
    let message: String
    let evidenceReferences: [GuidedCleanupFlowEvidenceReference]
    let promptRequest: GuidedCleanupFlowPromptRequest?
    let safetyFlags: GuidedCleanupFlowSafety
    let fallbackReason: String?

    var isUnavailable: Bool {
        generatedBy == "unavailable" || (!recorded && fallbackReason != nil)
    }

    enum CodingKeys: String, CodingKey {
        case recorded
        case ok
        case generatedBy = "generated_by"
        case generatedByAlt = "generatedBy"
        case appLocalOnly = "app_local_only"
        case appLocalOnlyAlt = "appLocalOnly"
        case metadataRedacted = "metadata_redacted"
        case metadataRedactedAlt = "metadataRedacted"
        case redacted
        case record
        case stepRecord = "step_record"
        case records
        case recordedSteps = "recorded_steps"
        case summary
        case message
        case detail
        case evidenceReferences = "evidence_references"
        case evidenceReferencesAlt = "evidenceReferences"
        case evidence
        case promptRequest = "prompt_request"
        case promptRequestAlt = "promptRequest"
        case promptMetadata = "prompt_metadata"
        case promptMetadataAlt = "promptMetadata"
        case safetyFlags = "safety_flags"
        case safetyFlagsAlt = "safetyFlags"
        case safety
        case fallbackReason = "fallback_reason"
        case fallbackReasonAlt = "fallbackReason"
        case reason
    }

    init(
        recorded: Bool = false,
        generatedBy: String = "local-v2.67",
        appLocalOnly: Bool = true,
        metadataRedacted: Bool = true,
        record: GuidedCleanupRecordedStep? = nil,
        records: [GuidedCleanupRecordedStep] = [],
        summary: GuidedCleanupFlowSummary = GuidedCleanupFlowSummary(),
        message: String = "",
        evidenceReferences: [GuidedCleanupFlowEvidenceReference] = [],
        promptRequest: GuidedCleanupFlowPromptRequest? = nil,
        safetyFlags: GuidedCleanupFlowSafety = GuidedCleanupFlowSafety(),
        fallbackReason: String? = nil
    ) {
        self.recorded = recorded
        self.generatedBy = generatedBy
        self.appLocalOnly = appLocalOnly
        self.metadataRedacted = metadataRedacted
        self.record = record
        self.records = records
        self.summary = summary
        self.message = message
        self.evidenceReferences = evidenceReferences
        self.promptRequest = promptRequest
        self.safetyFlags = safetyFlags
        self.fallbackReason = fallbackReason
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedRecord = try container.decodeIfPresent(GuidedCleanupRecordedStep.self, forKey: .record)
            ?? container.decodeIfPresent(GuidedCleanupRecordedStep.self, forKey: .stepRecord)
        let decodedRecords = try container.decodeGuidedCleanupRows(type: GuidedCleanupRecordedStep.self, keys: [.records, .recordedSteps])
        self.init(
            recorded: try container.decodeGuidedCleanupBool(keys: [.recorded, .ok]) ?? (decodedRecord != nil || !decodedRecords.isEmpty),
            generatedBy: try container.decodeGuidedCleanupString(keys: [.generatedBy, .generatedByAlt]) ?? "local-v2.67",
            appLocalOnly: try container.decodeGuidedCleanupBool(keys: [.appLocalOnly, .appLocalOnlyAlt]) ?? true,
            metadataRedacted: try container.decodeGuidedCleanupBool(keys: [.metadataRedacted, .metadataRedactedAlt, .redacted]) ?? true,
            record: decodedRecord,
            records: decodedRecords,
            summary: try container.decodeIfPresent(GuidedCleanupFlowSummary.self, forKey: .summary)
                ?? GuidedCleanupFlowSummary(recordedStepCount: decodedRecords.count + (decodedRecord == nil ? 0 : 1)),
            message: try container.decodeGuidedCleanupString(keys: [.message, .detail]) ?? "",
            evidenceReferences: try container.decodeGuidedCleanupRows(type: GuidedCleanupFlowEvidenceReference.self, keys: [.evidenceReferences, .evidenceReferencesAlt, .evidence]),
            promptRequest: try container.decodeIfPresent(GuidedCleanupFlowPromptRequest.self, forKey: .promptRequest)
                ?? container.decodeIfPresent(GuidedCleanupFlowPromptRequest.self, forKey: .promptRequestAlt)
                ?? container.decodeIfPresent(GuidedCleanupFlowPromptRequest.self, forKey: .promptMetadata)
                ?? container.decodeIfPresent(GuidedCleanupFlowPromptRequest.self, forKey: .promptMetadataAlt),
            safetyFlags: try container.decodeIfPresent(GuidedCleanupFlowSafety.self, forKey: .safetyFlags)
                ?? container.decodeIfPresent(GuidedCleanupFlowSafety.self, forKey: .safetyFlagsAlt)
                ?? container.decodeIfPresent(GuidedCleanupFlowSafety.self, forKey: .safety)
                ?? GuidedCleanupFlowSafety(),
            fallbackReason: try container.decodeGuidedCleanupString(keys: [.fallbackReason, .fallbackReasonAlt, .reason])
        )
    }

    static func unavailable(reason: String = UIStrings.guidedCleanupRecordUnavailable) -> GuidedCleanupRecordStepResult {
        GuidedCleanupRecordStepResult(
            recorded: false,
            generatedBy: "unavailable",
            appLocalOnly: true,
            metadataRedacted: true,
            message: reason,
            safetyFlags: GuidedCleanupFlowSafety(notes: [reason]),
            fallbackReason: reason
        )
    }
}

private extension KeyedDecodingContainer {
    func decodeGuidedCleanupString(keys: [Key]) throws -> String? {
        for key in keys {
            if let value = try? decodeIfPresent(String.self, forKey: key),
               let text = value.guidedCleanupNonEmpty {
                return text
            }
            if let value = try? decodeIfPresent(Int.self, forKey: key) {
                return String(value)
            }
            if let value = try? decodeIfPresent(Double.self, forKey: key) {
                return value.formatted()
            }
            if let value = try? decodeIfPresent(Bool.self, forKey: key) {
                return value ? UIStrings.stateEnabled : UIStrings.stateDisabled
            }
        }
        return nil
    }

    func decodeGuidedCleanupInt(keys: [Key]) throws -> Int? {
        for key in keys {
            if let value = try? decodeIfPresent(Int.self, forKey: key) {
                return value
            }
            if let value = try? decodeIfPresent(Double.self, forKey: key) {
                return Int(value.rounded())
            }
            if let value = try? decodeIfPresent(Bool.self, forKey: key) {
                return value ? 1 : 0
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
            if let values = try? decodeIfPresent([GuidedCleanupFlowStep].self, forKey: key) {
                return values.count
            }
            if let values = try? decodeIfPresent([GuidedCleanupIssueGroup].self, forKey: key) {
                return values.count
            }
            if let values = try? decodeIfPresent([GuidedCleanupSafeAction].self, forKey: key) {
                return values.count
            }
            if let values = try? decodeIfPresent([GuidedCleanupRecordedStep].self, forKey: key) {
                return values.count
            }
        }
        return nil
    }

    func decodeGuidedCleanupBool(keys: [Key]) throws -> Bool? {
        for key in keys {
            if let value = try? decodeIfPresent(Bool.self, forKey: key) {
                return value
            }
            if let value = try? decodeIfPresent(Int.self, forKey: key) {
                return value != 0
            }
            if let value = try? decodeIfPresent(String.self, forKey: key) {
                switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
                case "true", "yes", "1", "enabled", "available", "recommended", "selected", "recorded":
                    return true
                case "false", "no", "0", "disabled", "blocked", "unavailable", "none":
                    return false
                default:
                    break
                }
            }
        }
        return nil
    }

    func decodeGuidedCleanupStringArray(keys: [Key]) throws -> [String] {
        for key in keys {
            if let values = try? decodeIfPresent([String].self, forKey: key) {
                return values.compactMap(\.guidedCleanupNonEmpty)
            }
            if let value = try? decodeIfPresent(String.self, forKey: key),
               let text = value.guidedCleanupNonEmpty {
                return [text]
            }
            if let values = try? decodeIfPresent([GuidedCleanupFlowEvidenceReference].self, forKey: key) {
                return values.compactMap { $0.detail.guidedCleanupNonEmpty ?? $0.title.guidedCleanupNonEmpty }
            }
            if let value = try? decodeIfPresent(GuidedCleanupFlowEvidenceReference.self, forKey: key) {
                return [value.detail.guidedCleanupNonEmpty ?? value.title]
            }
            if let value = try? decodeIfPresent(Bool.self, forKey: key) {
                return [value ? UIStrings.stateEnabled : UIStrings.stateDisabled]
            }
        }
        return []
    }

    func decodeGuidedCleanupRows<T: Decodable>(type: T.Type, keys: [Key]) throws -> [T] {
        for key in keys {
            if let values = try? decodeIfPresent([T].self, forKey: key) {
                return values
            }
            if let value = try? decodeIfPresent(T.self, forKey: key) {
                return [value]
            }
        }
        return []
    }
}

private extension String {
    var guidedCleanupNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
