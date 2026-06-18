enum SidebarSelection: Hashable {
    case agentWorkspace
    case work(DetailSection)
    case skill(String)

    var isSkill: Bool {
        if case .skill = self {
            return true
        }
        return false
    }
}
