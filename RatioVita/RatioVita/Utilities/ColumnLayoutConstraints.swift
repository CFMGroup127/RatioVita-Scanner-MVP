import CoreGraphics

/// Fixed structural widths — prevents SwiftUI from recalculating column sizes on each launch.
enum FixedColumnWidths {
    static let deptWidth: CGFloat = 120
    static let unitWidth: CGFloat = 88
    static let hoursWidth: CGFloat = 60
    static let dayDateWidth: CGFloat = 52
    static let timeCellWidth: CGFloat = 56
    static let workHoursWidth: CGFloat = 44
    static let approvalBoxWidth: CGFloat = 80
    static let approvalBoxHeight: CGFloat = 44
    static let matrixHeaderHeight: CGFloat = 22
    static let matrixRowHeight: CGFloat = 20

    static func matrixColumnWidth(header: String) -> CGFloat {
        switch header {
            case "Day", "Date": dayDateWidth
            case "Work h": workHoursWidth
            default: timeCellWidth
        }
    }
}
