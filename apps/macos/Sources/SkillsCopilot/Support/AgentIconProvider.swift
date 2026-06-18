import AppKit

enum AgentIconProvider {
    static func image(for filter: SkillAgentFilter) -> NSImage? {
        for candidate in candidates(for: filter) {
            if let image = load(candidate: candidate) {
                image.size = NSSize(width: 32, height: 32)
                return image
            }
        }
        return nil
    }

    private static func candidates(for filter: SkillAgentFilter) -> [AgentIconCandidate] {
        switch filter {
        case .claudeCode:
            return [
                .appBundle("/Applications/Claude.app"),
                .resource("/Applications/Claude.app/Contents/Resources/electron.icns"),
                .fileIcon("/opt/homebrew/bin/claude")
            ]
        case .codex:
            return [
                .appBundle("/Applications/Codex.app"),
                .resource("/Applications/Codex.app/Contents/Resources/icon.icns"),
                .resource("/Applications/Codex.app/Contents/Resources/app.icns"),
                .resource("/Applications/Codex.app/Contents/Resources/default_app/icon.png"),
                .fileIcon("/opt/homebrew/bin/codex")
            ]
        case .opencode:
            return [
                .appBundle("/Applications/OpenCode.app"),
                .appBundle("/Applications/opencode.app"),
                .resource("/Applications/OpenCode.app/Contents/Resources/icon.icns"),
                .fileIcon("/opt/homebrew/bin/opencode")
            ]
        case .pi:
            return [
                .bundledResource("PiBadge.svg"),
                .appBundle("/Applications/Pi.app"),
                .appBundle("/Applications/Pi Coding Agent.app"),
                .resource("/opt/homebrew/lib/node_modules/@earendil-works/pi-coding-agent/assets/icon.png"),
                .resource("/opt/homebrew/lib/node_modules/@earendil-works/pi-coding-agent/resources/icon.png"),
                .resource("/opt/homebrew/lib/node_modules/@earendil-works/pi-coding-agent/dist/icon.png"),
                .fileIcon("/opt/homebrew/bin/pi")
            ]
        case .hermes:
            return [
                .bundledResource("HermesIcon.png")
            ]
        case .openclaw:
            return [
                .bundledResource("OpenClawIcon.svg")
            ]
        case .all:
            return []
        }
    }

    private static func load(candidate: AgentIconCandidate) -> NSImage? {
        switch candidate.kind {
        case .bundledResource:
            guard let url = Bundle.module.url(forResource: candidate.path, withExtension: nil) else {
                return nil
            }
            return NSImage(contentsOf: url)
        case .appBundle, .fileIcon:
            guard FileManager.default.fileExists(atPath: candidate.path) else {
                return nil
            }
            return NSWorkspace.shared.icon(forFile: candidate.path)
        case .resource:
            guard FileManager.default.fileExists(atPath: candidate.path) else {
                return nil
            }
            return NSImage(contentsOfFile: candidate.path)
        }
    }
}

private struct AgentIconCandidate {
    enum Kind {
        case appBundle
        case fileIcon
        case bundledResource
        case resource
    }

    let kind: Kind
    let path: String

    static func appBundle(_ path: String) -> AgentIconCandidate {
        AgentIconCandidate(kind: .appBundle, path: path)
    }

    static func fileIcon(_ path: String) -> AgentIconCandidate {
        AgentIconCandidate(kind: .fileIcon, path: path)
    }

    static func bundledResource(_ path: String) -> AgentIconCandidate {
        AgentIconCandidate(kind: .bundledResource, path: path)
    }

    static func resource(_ path: String) -> AgentIconCandidate {
        AgentIconCandidate(kind: .resource, path: path)
    }
}
