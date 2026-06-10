import Foundation

enum LocalReportFormat: String, CaseIterable, Codable, Identifiable, Hashable {
    case markdown
    case json

    var id: String { rawValue }

    var title: String {
        switch self {
        case .markdown:
            return UIStrings.localReportFormatMarkdown
        case .json:
            return UIStrings.localReportFormatJSON
        }
    }

    var systemImage: String {
        switch self {
        case .markdown:
            return "doc.richtext"
        case .json:
            return "curlybraces"
        }
    }
}

struct LocalReportExportSection: Decodable, Identifiable, Hashable {
    let name: String
    let count: Int?

    var id: String { name }

    init(name: String, count: Int? = nil) {
        self.name = name
        self.count = count
    }

    init(from decoder: Decoder) throws {
        if let text = try? decoder.singleValueContainer().decode(String.self) {
            name = text
            count = nil
            return
        }
        let container = try decoder.container(keyedBy: FlexibleCodingKey.self)
        name = container.decodeString(for: ["name", "section", "title", "id"]) ?? UIStrings.unknown
        count = container.decodeInt(for: ["count", "item_count", "itemCount", "total"])
    }
}

struct LocalReportExportFile: Decodable, Hashable {
    let format: LocalReportFormat
    let path: String

    var filename: String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    init(format: LocalReportFormat, path: String) {
        self.format = format
        self.path = path
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: FlexibleCodingKey.self)
        let rawFormat = container.decodeString(for: ["format", "kind", "file_format"])
            .flatMap { LocalReportFormat(rawValue: $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) }
        format = rawFormat ?? .markdown
        path = container.decodeString(for: ["path", "file_path", "filePath", "local_path", "localPath"]) ?? ""
    }
}

struct LocalReportRedactionPayload: Decodable, Hashable {
    let enabled: Bool

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: FlexibleCodingKey.self)
        enabled = container.decodeBool(for: ["enabled", "redacted", "is_redacted", "isRedacted"]) ?? true
    }
}

struct LocalReportExportResult: Decodable, Hashable {
    let path: String?
    let filename: String?
    let format: LocalReportFormat
    let createdAt: String?
    let redacted: Bool
    let sections: [LocalReportExportSection]
    let summary: String
    let unavailableReason: String?

    var isUnavailable: Bool {
        unavailableReason != nil
    }

    var displayName: String {
        if let filename, !filename.isEmpty {
            return filename
        }
        guard let path, !path.isEmpty else {
            return UIStrings.localReportNoFile
        }
        return URL(fileURLWithPath: path).lastPathComponent
    }

    var displayPath: String {
        path?.isEmpty == false ? path! : UIStrings.localReportNoFile
    }

    var sectionSummary: String {
        guard !sections.isEmpty else {
            return UIStrings.localReportNoSections
        }
        return sections.map { section in
            if let count = section.count {
                return "\(section.name) (\(count))"
            }
            return section.name
        }.joined(separator: ", ")
    }

    static func unavailable(reason: String = UIStrings.localReportUnavailableFallback, format: LocalReportFormat = .markdown) -> LocalReportExportResult {
        LocalReportExportResult(
            path: nil,
            filename: nil,
            format: format,
            createdAt: nil,
            redacted: true,
            sections: [],
            summary: reason,
            unavailableReason: reason
        )
    }

    init(
        path: String?,
        filename: String?,
        format: LocalReportFormat,
        createdAt: String?,
        redacted: Bool,
        sections: [LocalReportExportSection],
        summary: String,
        unavailableReason: String? = nil
    ) {
        self.path = path
        self.filename = filename
        self.format = format
        self.createdAt = createdAt
        self.redacted = redacted
        self.sections = sections
        self.summary = summary
        self.unavailableReason = unavailableReason
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: FlexibleCodingKey.self)
        let files = container.decodeReportFiles(for: ["files", "exported_files", "exportedFiles"])
        let selectedFile = files.first
        path = container.decodeString(for: ["path", "file_path", "filePath", "local_path", "localPath"])
            ?? selectedFile?.path
        filename = container.decodeString(for: ["filename", "file_name", "fileName", "name"])
            ?? selectedFile?.filename
        let rawFormat = container.decodeString(for: ["format", "kind", "file_format"])
            .flatMap { LocalReportFormat(rawValue: $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) }
        format = rawFormat ?? selectedFile?.format ?? .markdown
        createdAt = container.decodeString(for: ["created_at", "createdAt", "created_time", "createdTime"])
        redacted = container.decodeBool(for: ["redacted", "is_redacted", "isRedacted", "redaction_enabled", "redactionEnabled"])
            ?? container.decodeReportRedaction(for: ["redaction"])?.enabled
            ?? true
        let decodedSections = container.decodeReportSections(for: ["sections", "section_counts", "sectionCounts"])
        let summarySections = container.decodeReportSections(for: ["summary"])
        summary = container.decodeString(for: ["summary", "message", "user_summary", "userSummary"])
            ?? UIStrings.localReportExportedSummary
        sections = decodedSections.isEmpty ? summarySections : decodedSections
        unavailableReason = container.decodeString(for: ["unavailable_reason", "unavailableReason", "fallback_reason", "fallbackReason"])
    }
}

extension KeyedDecodingContainer where K == FlexibleCodingKey {
    func decodeReportFiles(for keys: [String]) -> [LocalReportExportFile] {
        for key in keys {
            guard let codingKey = FlexibleCodingKey(stringValue: key) else { continue }
            if let files = try? decode([LocalReportExportFile].self, forKey: codingKey) {
                return files.filter { !$0.path.isEmpty }
            }
        }
        return []
    }

    func decodeReportRedaction(for keys: [String]) -> LocalReportRedactionPayload? {
        for key in keys {
            guard let codingKey = FlexibleCodingKey(stringValue: key) else { continue }
            if let value = try? decode(LocalReportRedactionPayload.self, forKey: codingKey) {
                return value
            }
        }
        return nil
    }

    func decodeReportSections(for keys: [String]) -> [LocalReportExportSection] {
        for key in keys {
            guard let codingKey = FlexibleCodingKey(stringValue: key) else { continue }
            if let sections = try? decode([LocalReportExportSection].self, forKey: codingKey) {
                return sections
            }
            if let dictionary = try? decode([String: Int].self, forKey: codingKey) {
                return dictionary
                    .map { LocalReportExportSection(name: $0.key, count: $0.value) }
                    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            }
            if let names = try? decode([String].self, forKey: codingKey) {
                return names.map { LocalReportExportSection(name: $0) }
            }
        }
        return []
    }
}
