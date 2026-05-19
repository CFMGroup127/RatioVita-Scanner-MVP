import Foundation

/// Layman-friendly forensic glossary for the **?** hint layer.
enum RatioVitaGlossary {
    enum Term: String, CaseIterable, Identifiable {
        case accountsReceivable
        case accountsPayable
        case accrual
        case polarity
        case amortization
        case gstHst
        case mealPenalty
        case crewCall
        case preIncorporationRD
        case shadowRegistry
        case depreciation
        case fixedAssets

        var id: String { rawValue }

        var title: String {
            switch self {
                case .accountsReceivable: "Accounts Receivable"
                case .accountsPayable: "Accounts Payable"
                case .accrual: "Accrual"
                case .polarity: "Polarity"
                case .amortization: "Amortization"
                case .gstHst: "GST / HST"
                case .mealPenalty: "Meal Penalty"
                case .crewCall: "General Crew Call"
                case .preIncorporationRD: "Pre-Incorporation R&D"
                case .shadowRegistry: "Shadow Registry"
                case .depreciation: "Depreciation"
                case .fixedAssets: "Fixed Assets"
            }
        }

        var simpleTip: String {
            switch self {
                case .accountsReceivable:
                    "Money coming **in** to you — deposits, client cheques, and invoices you issued that someone still owes."
                case .accountsPayable:
                    "Money going **out** — receipts and bills you paid (or still owe) to vendors."
                case .accrual:
                    "You record income or costs when the work happens, not only when cash moves — like logging a shoot day before the cheque lands."
                case .polarity:
                    "Whether a dollar is treated as **in** (green, positive) or **out** (red, negative) based on document type."
                case .amortization:
                    "Spreading the cost of gear or software over several years instead of one big hit the day you bought it."
                case .gstHst:
                    "Canada’s sales tax on goods and services — your business number lets you claim Input Tax Credits (ITCs) on eligible spend."
                case .mealPenalty:
                    "Union rule: if you work long enough without a proper meal break, you may earn extra half-hour pay units."
                case .crewCall:
                    "The department-wide call time on the callsheet — meal rules can reference this even if you started earlier."
                case .preIncorporationRD:
                    "Start-up costs before incorporation (subscriptions, dev tools, your time) that CRA may let you track for future ITCs or losses."
                case .shadowRegistry:
                    "A provisional company folder RatioVita builds from payee names on checks before you upload Articles of Incorporation."
                case .depreciation:
                    "The portion of a durable asset’s cost you expense each year as it wears out — different from a one-day kit rental on a timecard."
                case .fixedAssets:
                    "Long-lived gear and vehicles you capitalize on the books (trucks, cameras) rather than expensing entirely when purchased."
            }
        }

        var learnMoreNote: String? {
            switch self {
                case .preIncorporationRD:
                    "Keep receipts for RatioVita / VitaLogic seats, Cursor, and cloud tools — tag them here so registration day is painless."
                case .shadowRegistry:
                    "When you register the official entity, tap **Merge shadow profile** in Corporate Registry."
                default:
                    nil
            }
        }
    }
}
