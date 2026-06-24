@testable import SkillsCopilot

struct ConfigContentRedactorTests {
    func run() throws {
        try redactsNestedJSONSecretKeys()
        try redactsSimpleAssignmentSecretKeys()
    }

    private func redactsNestedJSONSecretKeys() throws {
        let authTokenKey = ["ANTHROPIC", "_AUTH", "_TOKEN"].joined()
        let tokenValue = "fixture-token-value"
        let apiValue = "fixture-api-value"
        let content = """
        {
          "env": {
            "\(authTokenKey)": "\(tokenValue)",
            "ANTHROPIC_BASE_URL": "https://example.invalid/v1"
          },
          "apiKey": "\(apiValue)"
        }
        """

        let redacted = ConfigContentRedactor.redactedForDisplay(content)

        try expectFalse(redacted.contains(tokenValue), "JSON config preview must hide token values.")
        try expectFalse(redacted.contains(apiValue), "JSON config preview must hide apiKey values.")
        try expectContains(redacted, ConfigContentRedactor.redactedValue, "JSON config preview should show redaction placeholders.")
        try expectContains(redacted, "ANTHROPIC_BASE_URL", "Non-sensitive config keys should remain visible.")
    }

    private func redactsSimpleAssignmentSecretKeys() throws {
        let apiKey = ["OPENAI", "_API", "_KEY"].joined()
        let accessTokenKey = ["access", "_token"].joined()
        let apiValue = "fixture-key-value"
        let tokenValue = "fixture-token-value"
        let content = """
        \(apiKey)=\(apiValue)
        profile: local
        \(accessTokenKey): \(tokenValue),
        """

        let redacted = ConfigContentRedactor.redactedForDisplay(content)

        try expectFalse(redacted.contains(apiValue), "Assignment config preview must hide API key values.")
        try expectFalse(redacted.contains(tokenValue), "Assignment config preview must hide token values.")
        try expectContains(redacted, "profile: local", "Non-sensitive assignment lines should remain visible.")
    }
}
