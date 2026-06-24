import Foundation
import SwiftData

/// Deterministic expense metadata extraction from receipt rows and OCR corpus.
enum OperationalBookkeeperParser {
    struct ParsedExpense: Sendable {
        let vendorName: String
        let netAmount: Decimal?
        let taxAmount: Decimal?
        let grossAmount: Decimal
        let currencyCode: String
        let transactionTimestamp: Date?
        let lineItemDescriptions: [String]
        let taxCategory: String?
        let glCode: String?
        let productionPUID: String?
        let ventureEntityID: UUID?
        let anomalyFlags: [String]
        let logisticsDocumentKind: String?
        let departmentalCostCodes: [String]
        let crewNameTokens: [String]
        let detectedVendorSignature: String?
        let canadianTaxRegistration: String?
    }

    // MARK: - Public entry

    static func parse(receipt: Receipt, scope: BookkeepingScope) -> ParsedExpense {
        let filenameHint = documentFilenameHint(receipt)
        let corpus = receiptTextCorpus(receipt)
        let isLogisticsDoc = LogisticsDocumentInterceptor.matchesLogisticsFilename(filenameHint)
            || LogisticsDocumentInterceptor.matchesLogisticsFilename(corpus)

        var vendor = normalizedVendor(receipt.merchant)
        let currency = receipt.currencyCode.isEmpty ? "CAD" : receipt.currencyCode

        let monetary = MonetaryExtractionRules.extract(from: corpus, currencyCode: currency)
        if let signature = VendorSignatureCatalog.match(in: corpus) ?? VendorSignatureCatalog.match(in: filenameHint) {
            vendor = signature
        } else if vendor == "Unknown vendor", let hint = monetary.inferredVendor {
            vendor = hint
        }

        let net = receipt.subtotalAmount ?? monetary.net ?? inferredNet(receipt: receipt)
        let tax = receipt.taxAmount ?? monetary.tax
        var gross = monetary.gross ?? receipt.total
        if gross == .zero, let extractedGross = monetary.gross {
            gross = extractedGross
        }

        var lineDescriptions = receipt.lineItems
            .sorted { $0.sortIndex < $1.sortIndex }
            .map(\.lineDescription)
            .filter { !$0.isEmpty }

        var taxCategory = receipt.taxCategory
        var glCode: String?
        for line in receipt.lineItems where line.glCode != nil {
            glCode = line.glCode
            break
        }

        var logisticsKind: String?
        var costCodes: [String] = []
        var crewTokens: [String] = []

        if isLogisticsDoc {
            let logistics = LogisticsDocumentInterceptor.parse(corpus: corpus, filenameHint: filenameHint)
            logisticsKind = logistics.documentKind
            if lineDescriptions.isEmpty {
                lineDescriptions = logistics.lineItemDescriptions
            } else {
                lineDescriptions.append(contentsOf: logistics.lineItemDescriptions)
            }
            costCodes = logistics.departmentalCostCodes
            crewTokens = logistics.crewNameTokens
            if taxCategory == nil {
                taxCategory = logistics.suggestedTaxCategory
            }
            if glCode == nil {
                glCode = logistics.suggestedGLCode
            }
        }

        if taxCategory == nil {
            taxCategory = ReceiptFinanceAgentsHeuristics.suggestTaxCategory(fromCorpus: corpus)
        }
        if glCode == nil {
            glCode = ReceiptFinanceAgentsHeuristics.suggestGLCode(fromCorpus: corpus)
            if glCode == nil, let firstCode = costCodes.first {
                glCode = firstCode
            }
        }

        var flags = detectAnomalies(
            receipt: receipt,
            scope: scope,
            net: net,
            tax: tax,
            gross: gross,
            currency: currency
        )
        if monetary.usedRegexFallback {
            flags.append("regex_amount_extraction")
        }
        if isLogisticsDoc {
            flags.append("logistics_document_stripped")
        }

        let puid = scope.productionPUID ?? receipt.productionProject?.sovereignPUID
        let ventureID = scope.ventureEntityID ?? receipt.productionProject?.businessEntity?.id

        if scope.requiresPUID, puid == nil {
            flags.append("unassigned_puid")
        }
        if scope.requiresVentureEntity, ventureID == nil {
            flags.append("unassigned_venture_entity")
        }

        return ParsedExpense(
            vendorName: vendor,
            netAmount: net,
            taxAmount: tax,
            grossAmount: gross,
            currencyCode: currency,
            transactionTimestamp: receipt.transactionDate ?? receipt.createdAt,
            lineItemDescriptions: Array(Set(lineDescriptions)).sorted(),
            taxCategory: taxCategory,
            glCode: glCode,
            productionPUID: puid,
            ventureEntityID: ventureID,
            anomalyFlags: flags,
            logisticsDocumentKind: logisticsKind,
            departmentalCostCodes: costCodes,
            crewNameTokens: crewTokens,
            detectedVendorSignature: VendorSignatureCatalog.match(in: corpus),
            canadianTaxRegistration: monetary.canadianTaxRegistration
        )
    }

    // MARK: - Corpus assembly

    private static func documentFilenameHint(_ receipt: Receipt) -> String {
        var parts = [
            receipt.merchant,
            receipt.notes ?? "",
            receipt.documentKind ?? "",
            receipt.documentType,
            receipt.productionType ?? "",
            receipt.vaultPathPrefix ?? "",
            receipt.invoiceClientProjectTitle ?? "",
        ]
        for image in receipt.images.sorted(by: { $0.pageIndex < $1.pageIndex }) {
            if let ocr = image.ocrText, !ocr.isEmpty {
                parts.append(ocr)
            }
        }
        return parts.joined(separator: " ")
    }

    private static func normalizedVendor(_ merchant: String) -> String {
        let trimmed = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Unknown vendor" : trimmed
    }

    private static func inferredNet(receipt: Receipt) -> Decimal? {
        guard let tax = receipt.taxAmount, receipt.total > tax else { return nil }
        return receipt.total - tax
    }

    private static func receiptTextCorpus(_ receipt: Receipt) -> String {
        var parts = documentFilenameHint(receipt).split(separator: " ").map(String.init)
        parts.append(receipt.annotations ?? "")
        parts.append(receipt.department ?? "")
        for li in receipt.lineItems {
            parts.append(li.lineDescription)
        }
        return parts.joined(separator: " ")
    }

    private static func detectAnomalies(
        receipt: Receipt,
        scope: BookkeepingScope,
        net: Decimal?,
        tax: Decimal?,
        gross: Decimal,
        currency: String
    ) -> [String] {
        var flags: [String] = []

        if let net, let tax, net + tax != gross {
            flags.append("total_mismatch")
        }

        if let net, let tax, net > .zero {
            let impliedRate = (tax as NSDecimalNumber).doubleValue / (net as NSDecimalNumber).doubleValue
            let isCanadian = currency.uppercased() == "CAD"
            let expectedBand = isCanadian ? 0.05 ... 0.15 : 0.0 ... 0.12
            if !expectedBand.contains(impliedRate) {
                flags.append("tax_rate_mismatch")
            }
        }

        if receipt.productionProject == nil, scope.requiresPUID {
            flags.append("unassigned_project_code")
        }

        return flags
    }
}

// MARK: - Regex monetary extraction

private enum MonetaryExtractionRules {
    struct Result: Sendable {
        var gross: Decimal?
        var net: Decimal?
        var tax: Decimal?
        var canadianTaxRegistration: String?
        var inferredVendor: String?
        var usedRegexFallback: Bool = false
    }

    private static let amountCapture = #"([\d]{1,3}(?:,\d{3})*(?:\.\d{2})?|\d+\.\d{2})"#

    private static let grossPatterns = [
        #"(?i)\bgross(?:\s+(?:pay|amount|total))?\s*[:\-]?\s*\$?\s*"# + amountCapture,
        #"(?i)\btotal\s+due\s*[:\-]?\s*\$?\s*"# + amountCapture,
        #"(?i)\bamount\s+due\s*[:\-]?\s*\$?\s*"# + amountCapture,
        #"(?i)\bbalance\s+due\s*[:\-]?\s*\$?\s*"# + amountCapture,
        #"(?i)\btotal\s*[:\-]?\s*\$?\s*"# + amountCapture,
    ]

    private static let netPatterns = [
        #"(?i)\bnet(?:\s+(?:pay|amount|total))?\s*[:\-]?\s*\$?\s*"# + amountCapture,
        #"(?i)\bsub\s*total\s*[:\-]?\s*\$?\s*"# + amountCapture,
        #"(?i)\bsubtotal\s*[:\-]?\s*\$?\s*"# + amountCapture,
    ]

    private static let taxLinePatterns = [
        #"(?i)\bhst\s*(?:\(?\s*13\s*%\)?|\@?\s*13\s*%)?\s*[:\-]?\s*\$?\s*"# + amountCapture,
        #"(?i)\bgst\s*(?:\(?\s*5\s*%\)?|\@?\s*5\s*%)?\s*[:\-]?\s*\$?\s*"# + amountCapture,
        #"(?i)\bpst\s*(?:\(?\s*(?:7|8|10)\s*%\)?)?\s*[:\-]?\s*\$?\s*"# + amountCapture,
        #"(?i)\bqst\s*[:\-]?\s*\$?\s*"# + amountCapture,
        #"(?i)\b(?:hst|gst|pst|qst|g/hst|sales\s+tax)\s*[:\-]?\s*\$?\s*"# + amountCapture,
        #"(?i)\b(?:13|5|15)\s*%\s*(?:hst|gst|tax)\s*[:\-]?\s*\$?\s*"# + amountCapture,
    ]

    private static let taxRegistrationPattern =
        #"(?i)(?:g/?hst|gst|hst|pst|qst)\s*(?:#|no\.?|reg(?:istration)?\.?\s*no\.?)?\s*:?\s*(\d{9}(?:\s*rt\s*\d{4})?|\d{9}rt\d{4})"#

    static func extract(from corpus: String, currencyCode: String) -> Result {
        var result = Result()
        result.gross = firstAmount(matchingAny: grossPatterns, in: corpus)
        result.net = firstAmount(matchingAny: netPatterns, in: corpus)
        result.tax = firstAmount(matchingAny: taxLinePatterns, in: corpus)
        result.canadianTaxRegistration = firstCapture(pattern: taxRegistrationPattern, in: corpus)?
            .uppercased()
            .replacingOccurrences(of: "  ", with: " ")

        if result.gross != nil || result.net != nil || result.tax != nil {
            result.usedRegexFallback = true
        }

        if result.gross == nil, let net = result.net, let tax = result.tax {
            result.gross = net + tax
        }
        if result.net == nil, let gross = result.gross, let tax = result.tax, gross > tax {
            result.net = gross - tax
        }

        if currencyCode.uppercased() == "CAD", result.tax == nil {
            result.tax = inferCanadianTaxFromRateLines(corpus: corpus, net: result.net)
        }

        return result
    }

    private static func inferCanadianTaxFromRateLines(corpus: String, net: Decimal?) -> Decimal? {
        guard let net, net > .zero else { return nil }
        let lower = corpus.lowercased()
        let rate: Decimal?
        if lower.contains("hst 13") || lower.contains("13% hst") || lower.contains("hst @ 13") {
            rate = Decimal(string: "0.13")
        } else if lower.contains("gst 5") || lower.contains("5% gst") || lower.contains("gst @ 5") {
            rate = Decimal(string: "0.05")
        } else if lower.contains("pst 7") || lower.contains("7% pst") {
            rate = Decimal(string: "0.07")
        } else {
            rate = nil
        }
        guard let rate else { return nil }
        return net * rate
    }

    private static func firstAmount(matchingAny patterns: [String], in text: String) -> Decimal? {
        for pattern in patterns {
            if let capture = firstCapture(pattern: pattern, in: text),
               let value = parseDecimal(capture)
            {
                return value
            }
        }
        return nil
    }

    private static func parseDecimal(_ raw: String) -> Decimal? {
        let cleaned = raw
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Decimal(string: cleaned)
    }

    private static func firstCapture(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(text.startIndex ..< text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges > 1,
              let capture = Range(match.range(at: 1), in: text)
        else { return nil }
        return String(text[capture])
    }
}

// MARK: - Vendor signatures (production logistics)

private enum VendorSignatureCatalog {
    private static let signatures: [(pattern: String, label: String)] = [
        (#"(?i)\bcostco\b(?:\s+wholesale)?"#, "Costco Wholesale"),
        (#"(?i)\bsysco\b"#, "Sysco Food Services"),
        (#"(?i)\bgfs\b|\bgordon\s+food"#, "GFS / Gordon Food Service"),
        (#"(?i)\bpetro[\-\s]?canada\b"#, "Petro-Canada"),
        (#"(?i)\besso\b|\bexxon\b"#, "Esso"),
        (#"(?i)\bshell\b(?:\s+(?:canada|gas))?"#, "Shell"),
        (#"(?i)\bcanadian\s+tire\b"#, "Canadian Tire"),
        (#"(?i)\bhome\s+depot\b"#, "Home Depot"),
        (#"(?i)\buber\b(?:\s+eats|\s+trip)?"#, "Uber"),
        (#"(?i)\blyft\b"#, "Lyft"),
        (#"(?i)\bbespoke\s+craft\b|\bbespoke\s+catering\b"#, "Bespoke Craft & Catering"),
        (#"(?i)\bcraft\s+services\b|\bcraft\s+svc\b"#, "Craft Services"),
        (#"(?i)\b(?:fuel|gas)\s+station\b|\btruck\s+stop\b"#, "Fuel Station"),
    ]

    static func match(in text: String) -> String? {
        for entry in signatures {
            if text.range(of: entry.pattern, options: .regularExpression) != nil {
                return entry.label
            }
        }
        return nil
    }
}

// MARK: - Logistics document interceptor

private enum LogisticsDocumentInterceptor {
    struct ParseResult: Sendable {
        let documentKind: String
        let lineItemDescriptions: [String]
        let departmentalCostCodes: [String]
        let crewNameTokens: [String]
        let suggestedTaxCategory: String
        let suggestedGLCode: String
    }

    private static let filenamePatterns = [
        #"(?i)\[\s*\d*\s*tm\s*-\s*payroll\s+info\s+sheet"#,
        #"(?i)payroll\s+info\s+sheet"#,
        #"(?i)sustainability\s+memo"#,
        #"(?i)production\s+logistics"#,
        #"(?i)crew\s+(?:call|list|schedule|sheet)"#,
        #"(?i)department(?:al)?\s+cost\s+(?:code|sheet)"#,
        #"(?i)logistics\s+(?:memo|pack|bundle)"#,
    ]

    private static let costCodePatterns = [
        #"(?i)(?:dept|department|cost\s*code|gl|account)\s*[:\-#]?\s*([A-Z0-9][A-Z0-9\-]{2,14})"#,
        #"(?i)\b(GL-\d{4}-[A-Z]+)\b"#,
        #"(?i)\b(DEPT-\d{2,5})\b"#,
        #"(?i)\b(CC-\d{3,6})\b"#,
    ]

    private static let crewNamePatterns = [
        #"(?i)(?:employee|crew|name|payee|member)\s*[:\-]\s*([A-Za-z][A-Za-z\-']+(?:\s+[A-Za-z][A-Za-z\-']+)*)"#,
        #"(?i)\b([A-Z][a-z]+(?:\s+[A-Z][a-z]+){1,2})\s+(?:hours|days|rate|position|role)\b"#,
    ]

    private static let lineItemPatterns = [
        #"(?i)^[\-\•\*]\s*(.{4,120}?)(?:\s+\$?\s*([\d,]+\.\d{2}))?\s*$"#,
        #"(?i)(.{6,80}?)\s+\$?\s*([\d,]+\.\d{2})\s*$"#,
    ]

    static func matchesLogisticsFilename(_ hint: String) -> Bool {
        filenamePatterns.contains { hint.range(of: $0, options: .regularExpression) != nil }
    }

    static func parse(corpus: String, filenameHint: String) -> ParseResult {
        let kind = classifyDocumentKind(corpus: corpus, filenameHint: filenameHint)
        let lineItems = extractLineItems(from: corpus)
        let costCodes = extractAll(patterns: costCodePatterns, in: corpus)
        let crewNames = extractAll(patterns: crewNamePatterns, in: corpus)

        let taxCategory: String
        let glCode: String
        switch kind {
        case "payroll_info_sheet":
            taxCategory = "Payroll_ProductionLogistics"
            glCode = costCodes.first ?? "GL-6100-PAYROLL"
        case "sustainability_memo":
            taxCategory = "Production_Sustainability"
            glCode = costCodes.first ?? "GL-5220-SUSTAIN"
        default:
            taxCategory = "Production_Logistics"
            glCode = costCodes.first ?? "GL-5200-LOGISTICS"
        }

        return ParseResult(
            documentKind: kind,
            lineItemDescriptions: lineItems,
            departmentalCostCodes: costCodes,
            crewNameTokens: crewNames,
            suggestedTaxCategory: taxCategory,
            suggestedGLCode: glCode
        )
    }

    private static func classifyDocumentKind(corpus: String, filenameHint: String) -> String {
        let combined = "\(filenameHint) \(corpus)"
        if combined.range(of: #"(?i)payroll\s+info\s+sheet|\d+\s*tm\s*-\s*payroll"#, options: .regularExpression) != nil {
            return "payroll_info_sheet"
        }
        if combined.range(of: #"(?i)sustainability\s+memo"#, options: .regularExpression) != nil {
            return "sustainability_memo"
        }
        return "production_logistics"
    }

    private static func extractLineItems(from corpus: String) -> [String] {
        var items: [String] = []
        let lines = corpus.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count >= 4 else { continue }
            for pattern in lineItemPatterns {
                if let capture = firstCapture(pattern: pattern, in: trimmed) {
                    let cleaned = capture.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !cleaned.isEmpty, !items.contains(cleaned) {
                        items.append(cleaned)
                    }
                }
            }
            if trimmed.hasPrefix("-") || trimmed.hasPrefix("•") || trimmed.hasPrefix("*") {
                let stripped = trimmed.drop(while: { $0 == "-" || $0 == "•" || $0 == "*" || $0 == " " })
                let text = String(stripped).trimmingCharacters(in: .whitespacesAndNewlines)
                if text.count >= 4, !items.contains(text) {
                    items.append(text)
                }
            }
        }
        return Array(items.prefix(24))
    }

    private static func extractAll(patterns: [String], in text: String) -> [String] {
        var found: [String] = []
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }
            let range = NSRange(text.startIndex ..< text.endIndex, in: text)
            regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
                guard let match, match.numberOfRanges > 1,
                      let capture = Range(match.range(at: 1), in: text)
                else { return }
                let token = String(text[capture]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !token.isEmpty, !found.contains(token) {
                    found.append(token)
                }
            }
        }
        return found
    }

    private static func firstCapture(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(text.startIndex ..< text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges > 1,
              let capture = Range(match.range(at: 1), in: text)
        else { return nil }
        return String(text[capture])
    }
}

struct BookkeepingScope: Sendable {
    let productionPUID: String?
    let ventureEntityID: UUID?
    let requiresPUID: Bool
    let requiresVentureEntity: Bool

    static func fromSovereignContext(_ context: SovereignContextManager, modelContext: ModelContext) -> BookkeepingScope {
        switch context.activeHub {
        case .production:
            let puid: String? = {
                guard let id = context.activeProductionID else { return nil }
                let projects = (try? modelContext.fetch(FetchDescriptor<ProductionProject>())) ?? []
                return projects.first(where: { $0.id == id })?.sovereignPUID
            }()
            return BookkeepingScope(
                productionPUID: puid,
                ventureEntityID: nil,
                requiresPUID: true,
                requiresVentureEntity: false
            )
        case .ventures:
            return BookkeepingScope(
                productionPUID: nil,
                ventureEntityID: context.activeVentureEntityID,
                requiresPUID: false,
                requiresVentureEntity: true
            )
        case .personal:
            return BookkeepingScope(
                productionPUID: nil,
                ventureEntityID: nil,
                requiresPUID: false,
                requiresVentureEntity: false
            )
        }
    }
}
