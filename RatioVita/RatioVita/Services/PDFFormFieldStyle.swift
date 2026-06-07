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
    static let gridFontSize: CGFloat = 7.5
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

    /// Writes 7pt monospaced text into the AcroForm widget (editable in Preview; import reads widget + overlay).
    static func setGridOverlayValue(_ value: String, on page: PDFPage, named fieldName: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        for ann in page.annotations where ann.fieldName == fieldName {
            applyGridStyle(to: ann)
            ann.widgetStringValue = trimmed
            ann.isReadOnly = false
        }
    }

    /// Cast & Crew talent rows use `FIELD.0` … `FIELD.8` widget names.
    static func setIndexedGridValue(
        _ value: String,
        on page: PDFPage,
        baseName: String,
        index: Int
    ) {
        setGridOverlayValue(value, on: page, named: "\(baseName).\(index)")
    }

    /// Applies 7.5pt monospaced typography to grid widgets in the in-app preview (keeps cells editable).
    static func reinforceGridWidgetTypography(document: PDFDocument) {
        guard let page = document.page(at: 0) else { return }
        reinforceGridWidgetTypography(on: page)
    }

    static func reinforceGridWidgetTypography(on page: PDFPage) {
        for ann in page.annotations {
            guard let name = ann.fieldName, gridFieldNames.contains(name) else { continue }
            applyGridStyle(to: ann)
            ann.isReadOnly = false
        }
    }

    /// Prevents PDFKit from re-opening grid cells with EP’s oversized default font when previewing exports.
    /// Reads AcroForm widget text, then freeText overlays stamped by export (widgets are often cleared).
    static func readGridFieldValue(on page: PDFPage, named fieldName: String) -> String? {
        let widgets = page.annotations.filter { $0.fieldName == fieldName }
        for widget in widgets {
            if let value = normalizedFieldText(widget.widgetStringValue) {
                return value
            }
            if let overlay = overlayText(on: page, intersecting: widget.bounds) {
                return overlay
            }
        }
        return nil
    }

    private static func normalizedFieldText(_ raw: String?) -> String? {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty, trimmed.lowercased() != "off" else { return nil }
        return trimmed
    }

    private static func overlayText(on page: PDFPage, intersecting bounds: CGRect) -> String? {
        let expanded = bounds.insetBy(dx: -2, dy: -2)
        let hits = page.annotations.compactMap { ann -> String? in
            guard ann.fieldName == nil || ann.fieldName?.isEmpty == true else { return nil }
            let isFreeText = ann.type == "FreeText"
            guard isFreeText else { return nil }
            guard ann.bounds.intersects(expanded) else { return nil }
            return normalizedFieldText(ann.contents)
        }
        return hits.first
    }

    static func lockGridWidgetsForDisplay(on page: PDFPage) {
        for ann in page.annotations {
            guard let name = ann.fieldName, gridFieldNames.contains(name) else { continue }
            ann.isReadOnly = true
        }
    }

    private static let gridFieldNames: Set<String> = [
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
            ? NSFont.monospacedSystemFont(ofSize: fontSize, weight: fontSize >= 10 ? .bold : .regular)
            : NSFont.systemFont(ofSize: fontSize, weight: fontSize >= 10 ? .bold : .regular)
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
