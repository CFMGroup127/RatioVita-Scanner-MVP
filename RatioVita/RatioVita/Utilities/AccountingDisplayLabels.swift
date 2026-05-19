import Foundation

/// User-facing finance labels (AR / AP) for Review and detail forms.
enum AccountingDisplayLabels {
    static func totalFieldTitle(documentType: DocumentTypeOption) -> String {
        switch AccountingAmountPolarity.signExpectation(for: documentType) {
            case .mustBePositive:
                "Accounts Receivable"
            case .mustBeNegative:
                "Accounts Payable"
            case .unspecified:
                "Total"
        }
    }

    static func totalFieldHint(documentType: DocumentTypeOption) -> String {
        switch AccountingAmountPolarity.signExpectation(for: documentType) {
            case .mustBePositive:
                "Money in — deposits and cheques payable to your entity."
            case .mustBeNegative:
                "Money out — vendor receipts and expenses."
            case .unspecified:
                "Document total."
        }
    }

    static func glossaryTerm(for documentType: DocumentTypeOption) -> RatioVitaGlossary.Term? {
        switch AccountingAmountPolarity.signExpectation(for: documentType) {
            case .mustBePositive:
                .accountsReceivable
            case .mustBeNegative:
                .accountsPayable
            case .unspecified:
                nil
        }
    }
}
