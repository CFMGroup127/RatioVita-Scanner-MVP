import Foundation

/// Shared retry policy for Gemini `generateContent` calls (overload / rate limits).
enum GeminiAPITransientRetry {
    static let maxGenerateContentAttempts = 3

    static func isRetriableGenerateContentHTTPStatus(_ code: Int) -> Bool {
        code == 503 || code == 429 || code == 500
    }

    /// Seconds to wait after attempt index `attempt` fails (0 → 1s before 2nd try, 1 → 2s, 2 → 4s).
    static func backoffSecondsAfterFailedAttempt(_ attempt: Int) -> Int {
        1 << min(max(0, attempt), 5)
    }
}
