import CoreGraphics

/// Hard upper bounds so AppKit never receives astronomical frame proposals.
enum SafeLayoutBounds {
    static let maxMacColumnWidth: CGFloat = 600
    static let maxDetailPaneWidth: CGFloat = 900
    static let maxTimecardPreviewWidth: CGFloat = 720
    static let maxWorkspaceContentWidth: CGFloat = 1200
    static let maxWindowWidth: CGFloat = 2400
    static let maxWindowHeight: CGFloat = 1600
    static let inboxListWidth: CGFloat = 280
    static let signaturePanelWidth: CGFloat = 300
    static let commandRailWidth: CGFloat = 220
    static let lockedGridCellWidth: CGFloat = 72

    /// Total width of the EP weekly matrix (all fixed columns).
    static var weeklyMatrixTotalWidth: CGFloat {
        let headers = [
            "Day", "Date", "Trav", "Call", "M1 out", "M1 in", "M2 out", "M2 in", "Wrap", "Trav end", "Work h",
        ]
        return headers.reduce(CGFloat(0)) { $0 + FixedColumnWidths.matrixColumnWidth(header: $1) }
            + CGFloat(headers.count - 1) * 6
    }
}
