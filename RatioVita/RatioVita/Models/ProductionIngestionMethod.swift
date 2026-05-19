import Foundation

/// How a new production workspace is bootstrapped.
enum ProductionIngestionMethod: String, CaseIterable, Identifiable {
    case pdfImport = "Import Portal PDF (EP / Cast & Crew Hub)"
    case cameraOCR = "Scan Handwritten Paperwork Photo"
    case manualEntry = "Manual Entry / Standalone Timesheet"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
            case .pdfImport: "doc.fill"
            case .cameraOCR: "camera.fill"
            case .manualEntry: "square.and.pencil"
        }
    }

    var detail: String {
        switch self {
            case .pdfImport:
                "Parse a digital timesheet downloaded from Entertainment Partners or Cast & Crew."
            case .cameraOCR:
                "Photograph handwritten continuity or paper timecards for OCR-assisted entry."
            case .manualEntry:
                "Create a blank show or start a detached weekly time sheet stream."
        }
    }
}
