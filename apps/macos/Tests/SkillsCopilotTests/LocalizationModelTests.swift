import Foundation
@testable import SkillsCopilot

struct LocalizationModelTests {
    func run() throws {
        defer {
            UIStrings.use(.english)
        }

        try expectEqual(AppLanguage.fromStorage(nil), .english, "Missing language storage should default to English")
        try expectEqual(AppLanguage.fromStorage("en"), .english, "English language storage should parse")
        try expectEqual(AppLanguage.fromStorage("zh-Hans"), .simplifiedChinese, "Simplified Chinese language storage should parse")
        try expectEqual(AppLanguage.fromStorage("fr"), .english, "Unsupported language storage should default to English")

        UIStrings.use(.english)
        try expectEqual(UIStrings.scan, "Scan", "English scan label should load from en resources")
        try expectEqual(UIStrings.languageSettings, "Language", "English language settings label should load")
        try expectEqual(UIStrings.scannedSkills(2), "Scanned 2 skills across supported adapters.", "English formatted scan summary should preserve arguments")

        UIStrings.use(.simplifiedChinese)
        let diagnostics = UIStrings.localizationResourceDiagnostics(for: .simplifiedChinese)
        if diagnostics.count == 0 {
            throw NativeModelTestFailure(description: "Chinese localization resources should be visible at runtime: paths=\(diagnostics.paths)")
        }
        try expectEqual(UIStrings.scan, "扫描", "Chinese scan label should load from zh-Hans resources")
        try expectEqual(UIStrings.languageSettings, "语言", "Chinese language settings label should load")
        try expectEqual(UIStrings.aiProviderSettings, "AI 提供方", "Chinese provider settings label should load")
        try expectEqual(UIStrings.service, "服务", "Chinese service label should load")
        try expectEqual(UIStrings.scannedSkills(2), "已扫描受支持 adapter 中的 2 个技能。", "Chinese formatted scan summary should preserve arguments")

        UIStrings.use(.english)
        try expectEqual(UIStrings.scan, "Scan", "Switching back to English should not reuse cached Chinese values")
    }
}
