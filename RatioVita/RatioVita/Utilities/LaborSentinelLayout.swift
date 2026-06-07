import CoreGraphics

/// Fixed column widths for Labor Sentinel — prevents AppKit runaway frame calculations.
enum LaborSentinelLayout {
    static let sidebarMinWidth: CGFloat = 260
    static let sidebarIdealWidth: CGFloat = 380
    static let sidebarMaxWidth: CGFloat = 480

    static let detailMinWidth: CGFloat = 400
    static let detailIdealWidth: CGFloat = 650
    static let detailMaxWidth: CGFloat = 1200

    /// Hard cap for any hosted window / sheet (guards against INT_MAX-width crashes).
    static let maxSafeWindowWidth: CGFloat = 2400
}
