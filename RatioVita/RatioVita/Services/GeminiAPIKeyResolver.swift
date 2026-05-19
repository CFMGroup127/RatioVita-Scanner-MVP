import Dispatch
import Foundation

/// Single source of truth for Gemini API key + toggles (receipt extraction + bank PDF import).
enum GeminiAPIKeyResolver {
    private static let envKeyName = "GEMINI_API_KEY"
    private static let userDefaultsKey = "geminiAPIKey"
    private static let enabledKey = "geminiExtractionEnabled"
    private static let modelKey = "geminiModelId"

    /// Default model when Settings is blank, and replacement when a **retired** id is still stored.
    /// High-volume `generateContent` (receipts + bank PDFs); override in Settings if Google renames tiers.
    static let defaultGeminiModelId = "gemini-3.1-flash-lite"

    /// Model ids no longer valid for `v1beta` `generateContent` (404); migrated to `defaultGeminiModelId`.
    private static let retiredGeminiModelIds: Set<String> = [
        "gemini-2.0-flash",
        "gemini-1.5-flash",
    ]

    /// Xcode **Run** scheme environment variable `GEMINI_API_KEY` wins; then **Keychain** (iCloud Keychain when
    /// enabled); then **Settings** (`geminiAPIKey` in `UserDefaults`, same backing as `@AppStorage("geminiAPIKey")`).
    static func resolveAPIKeyTrimmed() -> String {
        let env = ProcessInfo.processInfo.environment[envKeyName]?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !env.isEmpty { return env }
        if let k = GeminiAPIKeyKeychain.readTrimmed(), !k.isEmpty { return k }
        return UserDefaults.standard.string(forKey: userDefaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    /// Mirrors `@AppStorage("geminiExtractionEnabled")` default of `true` when unset.
    static func isGeminiExtractionEnabled() -> Bool {
        (UserDefaults.standard.object(forKey: enabledKey) as? Bool) ?? true
    }

    static func resolveModelId() -> String {
        let stored = UserDefaults.standard.string(forKey: modelKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let raw = stored.isEmpty ? defaultGeminiModelId : stored
        let bare = raw.hasPrefix("models/") ? String(raw.dropFirst("models/".count)) : raw
        let migrated = retiredGeminiModelIds.contains(bare) ? defaultGeminiModelId : bare
        let final = migrated.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? defaultGeminiModelId
            : migrated
        if final != stored {
            // `UserDefaults` can trigger SwiftUI `@AppStorage` publishing — never write off the main thread.
            if Thread.isMainThread {
                UserDefaults.standard.set(final, forKey: modelKey)
            } else {
                DispatchQueue.main.async {
                    UserDefaults.standard.set(final, forKey: modelKey)
                }
            }
        }
        return final
    }

    #if DEBUG
    /// Explains why Gemini is unavailable (scheme name typo, empty SecureField, toggle off, etc.).
    @MainActor
    static func logGeminiKeyDiagnostics(context: String) {
        let envRaw = ProcessInfo.processInfo.environment[envKeyName] ?? ""
        let envTrim = envRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        let storedRaw = UserDefaults.standard.string(forKey: userDefaultsKey) ?? ""
        let storedTrim = storedRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        let keychainTrim = GeminiAPIKeyKeychain.readTrimmed() ?? ""
        let enabled = isGeminiExtractionEnabled()
        let effective = resolveAPIKeyTrimmed()
        let model = resolveModelId()
        print(
            """
            RatioVita DEBUG [Gemini] \(context)
              geminiExtractionEnabled → \(enabled) (UserDefaults key "\(enabledKey)")
              ProcessInfo "\(envKeyName)" → rawLen=\(envRaw.count) trimmedLen=\(envTrim.count) isEmpty=\(envTrim
                .isEmpty)
              Keychain (sync) → len=\(keychainTrim.count) isEmpty=\(keychainTrim.isEmpty)
              UserDefaults "\(userDefaultsKey)" → rawLen=\(storedRaw.count) trimmedLen=\(storedTrim
                .count) isEmpty=\(storedTrim.isEmpty)
              effectiveKeyAfterMerge → len=\(effective.count) isEmpty=\(effective.isEmpty)
              resolvedModelId → \(model)
            """
        )
    }
    #endif
}
