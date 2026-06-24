import Foundation

enum ConfigContentRedactor {
    static let redactedValue = "[REDACTED]"

    static func redactedForDisplay(_ content: String) -> String {
        guard !content.isEmpty else { return content }
        if let json = redactedJSON(content) {
            return json
        }
        return content
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { redactSimpleSecretLine(String($0)) }
            .joined(separator: "\n")
    }

    static func containsSensitiveKey(_ key: String) -> Bool {
        let normalized = key
            .unicodeScalars
            .filter { scalar in
                scalar.isASCII
                    && CharacterSet.alphanumerics.contains(scalar)
            }
            .map { Character($0).lowercased() }
            .joined()
        return [
            "apikey",
            "token",
            "accesstoken",
            "refreshtoken",
            "secret",
            "clientsecret",
            "password",
            "passwd"
        ].contains(normalized)
            || normalized.hasSuffix("apikey")
            || normalized.hasSuffix("token")
            || normalized.hasSuffix("secret")
            || normalized.hasSuffix("password")
    }

    private static func redactedJSON(_ content: String) -> String? {
        guard let data = content.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }
        let (redacted, changed) = redactJSONValue(json)
        guard changed,
              JSONSerialization.isValidJSONObject(redacted),
              let renderedData = try? JSONSerialization.data(
                withJSONObject: redacted,
                options: [.prettyPrinted, .sortedKeys]
              ),
              let rendered = String(data: renderedData, encoding: .utf8) else {
            return changed ? content : nil
        }
        return rendered + (content.hasSuffix("\n") ? "\n" : "")
    }

    private static func redactJSONValue(_ value: Any) -> (Any, Bool) {
        if let dictionary = value as? [String: Any] {
            var changed = false
            var redacted: [String: Any] = [:]
            for (key, child) in dictionary {
                if containsSensitiveKey(key) {
                    redacted[key] = redactedValue
                    if (child as? String) != redactedValue {
                        changed = true
                    }
                } else {
                    let (redactedChild, childChanged) = redactJSONValue(child)
                    redacted[key] = redactedChild
                    changed = changed || childChanged
                }
            }
            return (redacted, changed)
        }
        if let array = value as? [Any] {
            var changed = false
            let redacted = array.map { child in
                let (redactedChild, childChanged) = redactJSONValue(child)
                changed = changed || childChanged
                return redactedChild
            }
            return (redacted, changed)
        }
        return (value, false)
    }

    private static func redactSimpleSecretLine(_ line: String) -> String {
        guard let separatorIndex = line.firstIndex(where: { $0 == "=" || $0 == ":" }) else {
            return line
        }
        let keyPart = String(line[..<separatorIndex])
        let separator = String(line[separatorIndex])
        let valuePart = String(line[line.index(after: separatorIndex)...])
        let key = keyPart.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        guard containsSensitiveKey(key) else { return line }

        let trimmedValue = valuePart.trimmingCharacters(in: .whitespaces)
        let suffix = trimmedValue.hasSuffix(",") ? "," : ""
        return "\(keyPart)\(separator) \"\(redactedValue)\"\(suffix)"
    }
}
