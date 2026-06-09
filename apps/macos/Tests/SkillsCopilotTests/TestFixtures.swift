import Foundation
@testable import SkillsCopilot

func skill(
    id: String,
    agent: String = "claude-code",
    scope: String,
    path: String,
    definitionId: String,
    name: String,
    state: String = "loaded",
    enabled: Bool = true
) -> SkillRecord {
    SkillRecord(
        id: id,
        agent: agent,
        scope: scope,
        path: path,
        displayPath: path,
        definitionId: definitionId,
        name: name,
        state: state,
        enabled: enabled
    )
}
