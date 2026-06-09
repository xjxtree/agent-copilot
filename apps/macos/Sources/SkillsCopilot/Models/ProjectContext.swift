import Foundation

struct ProjectContextState: Codable, Hashable {
    let active: ProjectContext?
    let recent: [ProjectContext]
}

struct ProjectContext: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let rootPath: String
    let currentCWD: String?
    let lastUsedAt: String?
    let isActive: Bool
    let validationError: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case rootPath = "root_path"
        case currentCWD = "current_cwd"
        case lastUsedAt = "last_used_at"
        case isActive = "is_active"
        case validationError = "validation_error"
    }

    init(
        id: String,
        name: String,
        rootPath: String,
        currentCWD: String?,
        lastUsedAt: String?,
        isActive: Bool,
        validationError: String?
    ) {
        self.id = id
        self.name = name
        self.rootPath = rootPath
        self.currentCWD = currentCWD
        self.lastUsedAt = lastUsedAt
        self.isActive = isActive
        self.validationError = validationError
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        rootPath = try container.decode(String.self, forKey: .rootPath)
        currentCWD = try container.decodeIfPresent(String.self, forKey: .currentCWD)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        validationError = try container.decodeIfPresent(String.self, forKey: .validationError)

        if let value = try? container.decodeIfPresent(String.self, forKey: .lastUsedAt) {
            lastUsedAt = value
        } else if let value = try? container.decodeIfPresent(Int64.self, forKey: .lastUsedAt) {
            lastUsedAt = String(value)
        } else {
            lastUsedAt = nil
        }
    }
}
