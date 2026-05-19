import Foundation

// MARK: - Request / response DTOs (Gemini REST)

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

/// JSON shape returned by Gemini when `responseMimeType` is `application/json`.
struct GeminiReceiptPayload: Codable, Equatable, Sendable {
    struct Line: Codable, Equatable, Sendable {
        var description: String
        var quantity: Int?
        var unitPrice: Double?
        var totalPrice: Double?
        var serialNumber: String?
    }

    struct WorkDay: Codable, Equatable, Sendable {
        var date: String?
        var hours: Double?
        var showTitle: String?
    }

    var merchant: String?
    /// “Pay to the order of …” (your business when receiving a check).
    var payee: String?
    /// Check drawer / payer.
    var payor: String?
    var vendorAddress: String?
    var payorAddress: String?
    var documentNumber: String?
    /// ISO date `YYYY-MM-DD` when known.
    var transactionDate: String?
    var subtotal: Double?
    var taxAmount: Double?
    var total: Double?
    /// ISO 4217 such as CAD, USD.
    var currency: String?
    var paymentMethod: String?
    var documentKind: String?
    var lineItems: [Line]?
    /// Time sheet / pay stub rows (`work_days` in JSON).
    var workDays: [WorkDay]?
    /// Client PO # on invoices (e.g. "PO 12345").
    var purchaseOrderNumber: String?
    /// Production manager or billing contact when labeled.
    var productionManagerName: String?
    /// Project / episode title on invoice (not the letterhead merchant).
    var clientProjectTitle: String?
    /// Production company or network ("Production Co:", "Bill to").
    var clientProductionCompany: String?
    /// Physical cheque / MICR clearing number (not vendor invoice #).
    var chequeNumber: String?
    /// Your issued invoice # on remittance stub (FACTURE / INVOICE column).
    var internalInvoiceNumber: String?
    /// Client SAP / ref. document token on payout stub.
    var clientAccountingToken: String?

    enum CodingKeys: String, CodingKey {
        case merchant
        case payee
        case payor
        case vendorAddress
        case payorAddress
        case documentNumber
        case transactionDate
        case subtotal
        case taxAmount
        case total
        case currency
        case paymentMethod
        case documentKind
        case lineItems
        case workDays = "work_days"
        case purchaseOrderNumber = "purchase_order_number"
        case productionManagerName = "production_manager_name"
        case clientProjectTitle = "client_project_title"
        case clientProductionCompany = "client_production_company"
    }
}

enum GeminiReceiptExtractionError: Error, LocalizedError {
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

extension GeminiReceiptExtractionError {
    fileprivate static func compactErrorBody(_ body: String) -> String {
        let t = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.count <= 220 { return t.isEmpty ? "(no detail)" : t }
        return String(t.prefix(220)) + "…"
    }
}

private struct GeminiListModelsResponse: Decodable {
    let models: [GeminiListedModel]?
}

private struct GeminiListedModel: Decodable {
    let name: String?
}

enum GeminiReceiptExtractionService {
    private static let endpointHost = "generativelanguage.googleapis.com"

    /// Lightweight `models.list` call to confirm the API key is accepted (used at launch and from Settings).
    static func verifyAPIKeyConnectivity(apiKey: String) async throws {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { throw GeminiReceiptExtractionError.missingAPIKey }

        var components = URLComponents()
        components.scheme = "https"
        components.host = endpointHost
        components.path = "/v1beta/models"
        components.queryItems = [
            URLQueryItem(name: "key", value: trimmedKey),
            URLQueryItem(name: "pageSize", value: "1"),
        ]
        guard let url = components.url else {
            throw GeminiReceiptExtractionError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GeminiReceiptExtractionError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let snippet = String(data: data, encoding: .utf8) ?? ""
            throw GeminiReceiptExtractionError.httpStatus(http.statusCode, snippet)
        }
        _ = try? JSONDecoder().decode(GeminiListModelsResponse.self, from: data)
    }

    /// Calls Gemini with raw OCR text and returns a decoded payload, or throws on transport/API errors.
    /// Retries transient **503 / 429 / 500** on `generateContent`.
    static func extractReceiptPayload(
        combinedOCRText: String,
        apiKey: String,
        modelId: String,
        onRetryScheduled: (@Sendable (Int) -> Void)? = nil
    ) async throws -> GeminiReceiptPayload {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        #if DEBUG
        if trimmedKey.isEmpty {
            await MainActor.run {
                GeminiAPIKeyResolver
                    .logGeminiKeyDiagnostics(
                        context: "GeminiReceiptExtractionService.extractReceiptPayload (caller passed empty key)"
                    )
            }
        }
        #endif
        guard !trimmedKey.isEmpty else { throw GeminiReceiptExtractionError.missingAPIKey }

        let model = modelId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? GeminiAPIKeyResolver.defaultGeminiModelId
            : modelId.trimmingCharacters(in: .whitespacesAndNewlines)

        var lastError: Error?
        for attempt in 0..<GeminiAPITransientRetry.maxGenerateContentAttempts {
            do {
                return try await extractReceiptPayloadSingleRequest(
                    combinedOCRText: combinedOCRText,
                    trimmedKey: trimmedKey,
                    model: model
                )
            } catch let err as GeminiReceiptExtractionError {
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
        throw lastError ?? GeminiReceiptExtractionError.invalidResponse
    }

    private static func extractReceiptPayloadSingleRequest(
        combinedOCRText: String,
        trimmedKey: String,
        model: String
    ) async throws -> GeminiReceiptPayload {
        var components = URLComponents()
        components.scheme = "https"
        components.host = endpointHost
        components.path = "/v1beta/models/\(model):generateContent"
        components.queryItems = [URLQueryItem(name: "key", value: trimmedKey)]

        guard let url = components.url else {
            throw GeminiReceiptExtractionError.invalidResponse
        }

        let prompt = Self.buildPrompt(ocr: combinedOCRText)
        let body = GeminiGenerateContentRequest(
            contents: [
                .init(role: "user", parts: [.init(text: prompt)]),
            ],
            generationConfig: .init(responseMimeType: "application/json", temperature: 0.1)
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GeminiReceiptExtractionError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let snippet = String(data: data, encoding: .utf8) ?? ""
            throw GeminiReceiptExtractionError.httpStatus(http.statusCode, snippet)
        }

        let decoded = try JSONDecoder().decode(GeminiGenerateContentResponse.self, from: data)
        guard let text = decoded.candidates?.first?.content?.parts?.first?.text,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else
        {
            throw GeminiReceiptExtractionError.emptyCandidates
        }

        let payloadData = Data(text.utf8)
        return try JSONDecoder().decode(GeminiReceiptPayload.self, from: payloadData)
    }

    private static func buildPrompt(ocr: String) -> String {
        """
        You parse retail receipts, invoices, payment slips, lottery tickets, **fuel / gas station receipts**, **time sheets**, and **pay stubs** from noisy OCR.

        Return ONLY valid JSON (no markdown) with exactly this shape and key names:
        {
          "merchant": string or null,
          "payee": string or null,
          "payor": string or null,
          "vendorAddress": string or null,
          "payorAddress": string or null,
          "documentNumber": string or null,
          "cheque_number": string or null,
          "internal_invoice_number": string or null,
          "client_accounting_token": string or null,
          "purchase_order_number": string or null,
          "production_manager_name": string or null,
          "client_project_title": string or null,
          "client_production_company": string or null,
          "transactionDate": "YYYY-MM-DD" or null,
          "subtotal": number or null,
          "taxAmount": number or null,
          "total": number or null,
          "currency": "CAD" | "USD" | "GBP" | "EUR" or null,
          "paymentMethod": string or null,
          "documentKind": "receipt" | "invoice" | "payment_slip" | "lottery" | "fuel" | "time_sheet" | "pay_stub" | "deal_memo" | "canadian_t4" | "canadian_t4a" | "canadian_roe" | "bank_statement" | "other" or null,
          "lineItems": [
            {
              "description": string,
              "quantity": number or null,
              "unitPrice": number or null,
              "totalPrice": number or null,
              "serialNumber": string or null
            }
          ] or null,
          "work_days": [
            { "date": "YYYY-MM-DD", "hours": number or null, "showTitle": string or null }
          ] or null
        }

        Rules:
        - Prefer amounts on lines labeled TOTAL, AMOUNT DUE, TOTAL CHARGES, or the card slip total over tax-only lines (e.g. HST), subtotals, or BALANCE / change due.
        - If both a merchandise receipt and a card/payment slip appear, prefer the purchase total that matches the main receipt when obvious; otherwise prefer the explicit TOTAL on the primary receipt page.
        - BALANCE 0.00 is not the purchase total when "Total Charges" or similar exists.
        - Do not treat store numbers (e.g. #2038) or terminal IDs as years or prices.
        - "CUSTOMER RECEIPT" / "RECEIPT" is a document title, not the merchant name; use the actual business name from the logo area or letterhead.
        - Long numeric strings (barcodes, ticket IDs, phone numbers, bank routing, SIN/ID blocks) are not currency amounts.
        - For **deal memos** / **production personnel services agreements** (EP, Cast & Crew, rate sheets): set documentKind **"deal_memo"**; populate **client_project_title**, **client_production_company**, **production_manager_name**, **position**, and **start date** when on page 1; set **subtotal**, **taxAmount**, and **total** to **null** (contracts are not purchase receipts).
        - **GST/HST registration numbers** (9-digit Business Number + RT suffix, e.g. `76001212 RT0001`) are **identity anchors**, not purchase tax — never put them in **taxAmount** or **total**.
        - For **Canadian CRA slips**: if you see a **T4 Statement of Remuneration**, set documentKind to **"canadian_t4"** and merchant to the payer (employer) when visible; total may be Box 14 employment income when clearly labeled, otherwise null.
        - For **T4A** (pension, self-employed commissions, patronage allocations, etc.), set documentKind to **"canadian_t4a"**.
        - For a **Record of Employment (ROE)**, set documentKind to **"canadian_roe"**.
        - For **bank / card statements** (running balance, grid of debits/credits), set documentKind to **"bank_statement"** (not a retail receipt).
        - For **time sheets** and **pay stubs**, set documentKind to "time_sheet" or "pay_stub" and populate **work_days** with every distinct date worked (one object per day when possible); hours and showTitle when visible.
        - For **fuel / gas** (pump totals, litres/gallons, station chain), set documentKind to "fuel"; total is the amount charged for fuel or the pump transaction total.
        - For lottery tickets, set documentKind to "lottery" and merchant to the operator (e.g. OLG) when visible; total is the ticket price / stake if shown.
        - currency must be a 3-letter ISO code only when explicit in the text ($, CAD, USD, £, etc.); if unclear use null.
        - If transactionDate is ambiguous, use null rather than guessing a future year.
        - For **RatioVita**, **VitaLogic**, **Cursor**, dev tools, or SaaS before incorporation, set documentKind **"other"** and mention pre-start R&D in merchant when visible.
        - For **checks** and **corporate payout stubs** (remittance table + cheque): set documentKind **"income"** when the payee is the recipient business.
        - Set **payee** to “Pay to the order of …” (who receives funds) and **payor** to the drawer / network (e.g. Bell Media Inc.).
        - **cheque_number**: the physical bank clearing number (often 10–14 digits, labeled “Cheque No”, “No du chèque”, or MICR) — never the vendor’s internal invoice #.
        - **internal_invoice_number**: your invoice # from a FACTURE / INVOICE column on the stub (e.g. 8011) — not the cheque number.
        - **client_accounting_token**: network SAP / ref. document # (e.g. 8001216205) when labeled SAP, Ref. Document, or similar.
        - Put **internal_invoice_number** in **documentNumber** only when no separate cheque_number is returned; never put the cheque number in **documentNumber**.
        - **payorAddress** is the payer’s street line when visible; **vendorAddress** is the payor’s address on income checks — not the payee’s address printed at the bottom of the cheque.
        - When **payee** matches the user's own business on a check, set documentKind **"income"** (money in) and keep **total** positive; default **currency** to **CAD** for Canadian banks (BMO, etc.) when $ or CAD is implied.
        - Do not use the payee as **merchant** on incoming checks — use **payor** as merchant when the payee is the user's entity.
        - For **film / TV / catering invoices** (especially when letterhead is the vendor’s own company): populate **client_production_company** from “Production Co:”, “Bill To”, or network name; **client_project_title** from “Project Title”, “Show”, or episode code; **production_manager_name** from “PM:”, “Production Manager”, or “Attention:”; **purchase_order_number** from “PO”, “P.O.”, or “Purchase Order”. Put the actual **invoice number** in **documentNumber** (never the phone number).

        OCR (one or more pages, separated by blank lines):
        \(ocr)
        """
    }
}

extension GeminiReceiptExtractionService {
    /// Normalizes a monetary `total` from JSON using `DocumentTypeOption` rules (income / AR = +, retail / AP = −).
    static func validateSign(documentType: DocumentTypeOption, amount: Decimal) -> Decimal {
        AccountingAmountPolarity.validateSign(documentType: documentType, amount: amount)
    }
}
