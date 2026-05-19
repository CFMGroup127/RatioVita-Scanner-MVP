import Foundation

#if canImport(PDFKit)
import PDFKit
#endif

#if canImport(AppKit)
import AppKit
#endif

/// Keeps AcroForm text inside narrow EP / Cast & Crew cells.
enum PDFFormFieldStyle {
    #if canImport(PDFKit)
    static let gridFontSize: CGFloat = 7
    static let headerFontSize: CGFloat = 8
    /// EP grid cells clip at ~7pt; vendor default is ~18pt when filled manually in Preview.
    static let gridOverlayVerticalLift: CGFloat = 2

    static func applyGridStyle(to annotation: PDFAnnotation) {
        #if canImport(AppKit)
        annotation.font = NSFont.monospacedSystemFont(ofSize: gridFontSize, weight: .regular)
        annotation.fontColor = .black
        #endif
    }

    static func applyHeaderStyle(to annotation: PDFAnnotation) {
        #if canImport(AppKit)
        annotation.font = NSFont.systemFont(ofSize: headerFontSize, weight: .regular)
        annotation.fontColor = .black
        #endif
    }

    static func setValue(
        _ value: String,
        on page: PDFPage,
        named fieldName: String,
        where matches: ((PDFAnnotation) -> Bool)? = nil,
        style: FieldStyle = .header
    ) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        for ann in page.annotations where ann.fieldName == fieldName {
            if let matches, !matches(ann) { continue }
            switch style {
                case .header: applyHeaderStyle(to: ann)
                case .grid: applyGridStyle(to: ann)
            }
            ann.widgetStringValue = trimmed
        }
    }

    /// Clears every widget for a field name (e.g. EP’s duplicate `PST` widgets).
    static func clearField(on page: PDFPage, named fieldName: String) {
        for ann in page.annotations where ann.fieldName == fieldName {
            ann.widgetStringValue = ""
        }
    }

    /// Draws 7pt monospaced text inside the widget box (avoids EP’s oversized default appearance).
    static func setGridOverlayValue(_ value: String, on page: PDFPage, named fieldName: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        for ann in page.annotations where ann.fieldName == fieldName {
            ann.widgetStringValue = ""
            ann.isReadOnly = true
            stampTextOverlay(trimmed, on: page, in: ann.bounds, fontSize: gridFontSize, monospaced: true)
        }
    }

    /// Prevents PDFKit from re-opening grid cells with EP’s oversized default font when previewing exports.
    static func lockGridWidgetsForDisplay(on page: PDFPage) {
        let gridNames: Set<String> = [
            "DATESUN", "DATEMON", "DATETUE", "DATEWED", "DATETHU", "DATEFRI", "DATESAT",
            "TRAVEL STARTSUN", "TRAVEL STARTMON", "TRAVEL STARTTUE", "TRAVEL STARTWED",
            "TRAVEL STARTTHU", "TRAVEL STARTFRI", "TRAVEL STARTSAT",
            "CALL TIMESUN", "CALL TIMEMON", "CALL TIMETUE", "CALL TIMEWED",
            "CALL TIMETHU", "CALL TIMEFRI", "CALL TIMESAT",
            "STARTSUN", "STARTMON", "STARTTUE", "STARTWED", "STARTTHU", "STARTFRI", "STARTSAT",
            "ENDSUN", "ENDMON", "ENDTUE", "ENDWED", "ENDTHU", "ENDFRI", "ENDSAT",
            "STARTSUN_2", "STARTMON_2", "STARTTUE_2", "STARTWED_2", "STARTTHU_2", "STARTFRI_2", "STARTSAT_2",
            "ENDSUN_2", "ENDMON_2", "ENDTUE_2", "ENDWED_2", "ENDTHU_2", "ENDFRI_2", "ENDSAT_2",
            "WRAP TIMESUN", "WRAP TIMEMON", "WRAP TIMETUE", "WRAP TIMEWED",
            "WRAP TIMETHU", "WRAP TIMEFRI", "WRAP TIMESAT",
            "TRAVEL ENDSUN", "TRAVEL ENDMON", "TRAVEL ENDTUE", "TRAVEL ENDWED",
            "TRAVEL ENDTHU", "TRAVEL ENDFRI", "TRAVEL ENDSAT",
        ]
        for ann in page.annotations {
            guard let name = ann.fieldName, gridNames.contains(name) else { continue }
            ann.isReadOnly = true
        }
    }

    static func stampTextOverlay(
        _ text: String,
        on page: PDFPage,
        in bounds: CGRect,
        fontSize: CGFloat,
        monospaced: Bool = false,
        lift: CGFloat = 0
    ) {
        #if canImport(AppKit)
        var box = bounds.insetBy(dx: 1.5, dy: 1)
        if lift > 0 {
            box.origin.y += lift
            box.size.height = max(4, box.size.height - lift)
        }
        let mark = PDFAnnotation(bounds: box, forType: .freeText, withProperties: nil)
        mark.contents = text
        mark.font = monospaced
            ? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
            : NSFont.systemFont(ofSize: fontSize, weight: .regular)
        mark.color = .clear
        mark.fontColor = .black
        page.addAnnotation(mark)
        #endif
    }

    enum FieldStyle {
        case header
        case grid
    }
    #endif
}
