enum SidebarSelection: Hashable {
    case work(DetailSection)
    case session(String)
    case skill(String)
    case configOverview
    case configSnapshot(String)

    var isSkill: Bool {
        if case .skill = self {
            return true
        }
        return false
    }

    var isSession: Bool {
        if case .session = self {
            return true
        }
        return false
    }

    var isConfig: Bool {
        switch self {
        case .configOverview, .configSnapshot:
            return true
        default:
            return false
        }
    }

}
