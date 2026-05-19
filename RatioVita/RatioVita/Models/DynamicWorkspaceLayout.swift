import Foundation

/// Right-hand Review panel mode — retail AP/AR vs contract vs labor tracking.
enum DynamicWorkspaceLayout: Equatable, Sendable {
    case retailTransaction
    case contractBlueprint
    case laborTimeline
    case chequePayout

    static func forDocumentType(_ option: DocumentTypeOption) -> DynamicWorkspaceLayout {
        switch option {
            case .dealMemo:
                .contractBlueprint
            case .incomeOrCheck:
                .chequePayout
            case .timeSheet, .paycheck:
                .laborTimeline
            default:
                .retailTransaction
        }
    }
}
