import Foundation

enum InvoiceStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case draft = "Draft"
    case sent = "Sent"
    case paid = "Paid"
    case overdue = "Overdue"

    var id: String { rawValue }

    var displayTitle: String { rawValue }
}
