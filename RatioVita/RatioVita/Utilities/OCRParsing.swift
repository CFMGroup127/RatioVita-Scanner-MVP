import Foundation

struct OCRParsing {
    static func extractData(from text: String) -> ExtractedData {
        // Very naive placeholder parser
        let lines = text.components(separatedBy: .newlines)
        
        var merchant: String?
        var total: Decimal?
        let currency = "USD"
        var date: Date?
        
        // Look for merchant (first non-empty line)
        merchant = lines.first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        
        // Look for total (line containing currency symbols or numbers)
        for line in lines {
            if line.contains("$") || line.contains("Total") {
                let numbers = line.components(separatedBy: CharacterSet.decimalDigits.inverted)
                    .compactMap { Double($0) }
                if let lastNumber = numbers.last {
                    total = Decimal(lastNumber)
                }
            }
        }
        
        // Look for date
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        for line in lines {
            if let parsedDate = dateFormatter.date(from: line) {
                date = parsedDate
                break
            }
        }
        
        return ExtractedData(
            merchant: merchant,
            total: total,
            currency: currency,
            date: date,
            merchantConfidence: merchant != nil ? 0.8 : nil,
            totalConfidence: total != nil ? 0.9 : nil,
            dateConfidence: date != nil ? 0.7 : nil
        )
    }
}
