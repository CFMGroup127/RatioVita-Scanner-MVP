import Foundation

/// JSON shape returned by Gemini when parsing bank statement text.
struct GeminiBankStatementPayload: Codable, Equatable, Sendable {
    struct Row: Codable, Equatable, Sendable {
        /// ISO `YYYY-MM-DD` when known.
        var postedDate: String?
        var description: String?
        /// Signed posting amount as on the statement.
        var amount: Double?
        /// ISO 4217 when known; may be null if only one currency on the statement.
        var currency: String?
    }

    var rows: [Row]?
    /// Default currency for rows that omit `currency` (e.g. CAD).
    var defaultCurrency: String?
}

enum GeminiBankStatementExtractionError: Error, LocalizedError {
    case missingAPIKey
    case invalidResponse
    case httpStatus(Int, String)
    case emptyCandidates

    var errorDescription: String? {
        switch self {
            case .missingAPIKey:
                "Gemini API key is not configured."
            case .invalidResponse:
                "Could not read the model response."
            case let .httpStatus(code, body):
                switch code {
                    case 503:
                        "Gemini is temporarily unavailable. Please try again in a few minutes."
                    case 429:
                        "Gemini rate limit reached. Wait a few minutes or try again."
                    case 500:
                        "Gemini returned a temporary server error. Please try again."
                    default:
                        "Gemini request failed (\(code)): \(Self.compactErrorBody(body))"
                }
            case .emptyCandidates:
                "The model returned no usable content."
        }
    }
}

extension GeminiBankStatementExtractionError {
    fileprivate static func compactErrorBody(_ body: String) -> String {
        let t = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.count <= 220 { return t.isEmpty ? "(no detail)" : t }
        return String(t.prefix(220)) + "…"
    }
}

enum GeminiBankStatementExtractionService {
    private static let endpointHost = "generativelanguage.googleapis.com"

    /// Parses noisy bank PDF / export text into structured posting rows. Retries **503 / 429 / 500** with exponential
    /// backoff.
    static func extractStatementRows(
        statementText: String,
        apiKey: String,
        modelId: String,
        onRetryScheduled: (@Sendable (Int) -> Void)? = nil
    ) async throws -> GeminiBankStatementPayload {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        #if DEBUG
        if trimmedKey.isEmpty {
            await MainActor.run {
                GeminiAPIKeyResolver
                    .logGeminiKeyDiagnostics(
                        context: "GeminiBankStatementExtractionService.extractStatementRows (caller passed empty key)"
                    )
            }
        }
        #endif
        guard !trimmedKey.isEmpty else { throw GeminiBankStatementExtractionError.missingAPIKey }

        let model = modelId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? GeminiAPIKeyResolver.defaultGeminiModelId
            : modelId.trimmingCharacters(in: .whitespacesAndNewlines)

        var lastError: Error?
        for attempt in 0..<GeminiAPITransientRetry.maxGenerateContentAttempts {
            do {
                return try await extractStatementRowsSingleRequest(
                    statementText: statementText,
                    trimmedKey: trimmedKey,
                    model: model
                )
            } catch let err as GeminiBankStatementExtractionError {
                lastError = err
                guard attempt < GeminiAPITransientRetry.maxGenerateContentAttempts - 1 else { break }
                if case let .httpStatus(code, _) = err,
                   GeminiAPITransientRetry.isRetriableGenerateContentHTTPStatus(code)
                {
                    let waitSec = GeminiAPITransientRetry.backoffSecondsAfterFailedAttempt(attempt)
                    onRetryScheduled?(waitSec)
                    try await Task.sleep(nanoseconds: UInt64(waitSec) * 1_000_000_000)
                    continue
                }
                throw err
            } catch {
                throw error
            }
        }
        throw lastError ?? GeminiBankStatementExtractionError.invalidResponse
    }

    private static func extractStatementRowsSingleRequest(
        statementText: String,
        trimmedKey: String,
        model: String
    ) async throws -> GeminiBankStatementPayload {
        var components = URLComponents()
        components.scheme = "https"
        components.host = endpointHost
        components.path = "/v1beta/models/\(model):generateContent"
        components.queryItems = [URLQueryItem(name: "key", value: trimmedKey)]

        guard let url = components.url else {
            throw GeminiBankStatementExtractionError.invalidResponse
        }

        let prompt = Self.buildPrompt(statementText: statementText)
        let body = GeminiGenerateContentRequest(
            contents: [
                .init(role: "user", parts: [.init(text: prompt)]),
            ],
            generationConfig: .init(responseMimeType: "application/json", temperature: 0.05)
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GeminiBankStatementExtractionError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let snippet = String(data: data, encoding: .utf8) ?? ""
            throw GeminiBankStatementExtractionError.httpStatus(http.statusCode, snippet)
        }

        let decoded = try JSONDecoder().decode(GeminiGenerateContentResponse.self, from: data)
        guard let text = decoded.candidates?.first?.content?.parts?.first?.text,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else
        {
            throw GeminiBankStatementExtractionError.emptyCandidates
        }

        let payloadData = Data(text.utf8)
        return try JSONDecoder().decode(GeminiBankStatementPayload.self, from: payloadData)
    }

    private static func buildPrompt(statementText: String) -> String {
        """
        You extract individual bank or credit card posting rows from statement text (PDF text dump, CSV-like lines, or OCR).

        Return ONLY valid JSON (no markdown) with exactly this shape:
        {
          "defaultCurrency": "CAD" | "USD" | "GBP" | "EUR" or null,
          "rows": [
            {
              "postedDate": "YYYY-MM-DD" or null,
              "description": string or null,
              "amount": number or null,
              "currency": "CAD" | "USD" or null
            }
          ] or null
        }

        Rules:
        - Each row is one line item that would appear on a bank statement. Use **signed `amount` in personal-checking convention**: money **leaving** the account (purchases, card charges, fees, withdrawals, bill payments) is **negative**; money **entering** (deposits, refunds, salary, transfers in) is **positive**. If the source text uses separate Debit and Credit columns, map debits to negative and credits to positive.
        - Skip headers, footers, page numbers, running balances, interest summaries unless they are clearly a single posting row.
        - Ignore column labels repeated every page.
        - If the statement shows recurring similar merchants (subscriptions), still emit one row per posting date.
        - Prefer posted / transaction date over value date when both exist.
        - If a row has no parseable date, omit it from `rows` rather than guessing.
        - `defaultCurrency` should be the dominant ISO currency on the statement when obvious; otherwise null.
        - If `amount` cannot be parsed, omit that row.

        Statement text:
        \(statementText)
        """
    }
}

// Reuse Gemini REST DTOs from receipt service (same file module visibility — duplicate minimal structs if needed).
// These mirror `GeminiReceiptExtractionService` private types; kept file-private here to avoid widening API.

private struct GeminiGenerateContentRequest: Encodable {
    struct Content: Encodable {
        let role: String?
        let parts: [Part]
    }

    struct Part: Encodable {
        let text: String
    }

    let contents: [Content]
    let generationConfig: GenerationConfig

    struct GenerationConfig: Encodable {
        let responseMimeType: String
        let temperature: Double
    }
}

private struct GeminiGenerateContentResponse: Decodable {
    struct Candidate: Decodable {
        let content: Content?
    }

    struct Content: Decodable {
        let parts: [Part]?
    }

    struct Part: Decodable {
        let text: String?
    }

    let candidates: [Candidate]?
}
