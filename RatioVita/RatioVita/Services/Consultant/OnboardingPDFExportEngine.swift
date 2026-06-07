import CoreGraphics
import Foundation

/// Consultant onboarding receipt PDF after NDA + immutable profile lock (Sprint RRR).
@MainActor
enum OnboardingPDFExportEngine {
    enum ExportError: Error, LocalizedError {
        case couldNotWrite

        var errorDescription: String? {
            "Could not write the onboarding PDF package."
        }
    }

    static func exportConsultantPackage(
        profile: ExpertConsultantProfile,
        lockedFields: LockedConsultantFields?,
        legalTokenHash: String
    ) throws -> URL {
        let lines = buildLines(profile: profile, lockedFields: lockedFields, legalTokenHash: legalTokenHash)
        let url = defaultOutputURL(anonymousToken: profile.anonymousToken)
        try writePDF(lines: lines, to: url)
        return url
    }

    private static func buildLines(
        profile: ExpertConsultantProfile,
        lockedFields: LockedConsultantFields?,
        legalTokenHash: String
    ) -> [String] {
        var lines: [String] = [
            "RatioVita — Consultant Onboarding Package",
            "Generated: \(Date().formatted())",
            "Sandbox token: \(profile.anonymousToken)",
            "Department: \(profile.department.displayName)",
            "Production (locked): \(profile.activeProductionTitle)",
            "Union local: \(profile.unionLocalCode)",
            "Legal verification: \(legalTokenHash.isEmpty ? "Pending" : "Complete")",
            "",
            "— Operational agreement summary —",
        ]
        if let locked = lockedFields {
            lines += [
                "Legal name (your copy): \(locked.legalName)",
                "Address: \(locked.addressLine)",
                "Corporate entity: \(locked.corporateEntityName.isEmpty ? "Individual" : locked.corporateEntityName)",
                "Union tier: \(locked.unionTier)",
                "Hourly rate (Page 1 harvest): \(locked.hourlyRate) CAD",
                "Kit / box allowance: \(locked.kitAllowance) CAD",
                "",
                AnonymizedPayrollEngine.estimatedGrossDisclaimer,
            ]
        } else {
            lines.append("Profile not yet locked — complete Page 1 harvest in Expert program.")
        }
        lines += [
            "",
            "— Non-disclosure acknowledgement —",
            "You completed the RatioVita flashcard NDA / NCA sequence.",
            "Do not disclose interface layouts, transport matrices, or accounting protocols.",
            "",
            "This document is for your personal records. Sandbox testing uses token \(profile.anonymousToken) in shared ledgers.",
        ]
        return lines
    }

    private static func defaultOutputURL(anonymousToken: String) -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let safe = anonymousToken.replacingOccurrences(of: "/", with: "-")
        return dir.appendingPathComponent("RatioVita_Onboarding_\(safe).pdf")
    }

    private static func writePDF(lines: [String], to url: URL) throws {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData) else {
            throw ExportError.couldNotWrite
        }
        var mediaBox = pageRect
        guard let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw ExportError.couldNotWrite
        }

        let titleAttr = TimecardPDFDrawUtils.makeAttrs(size: 14, bold: true)
        let bodyAttr = TimecardPDFDrawUtils.makeAttrs(size: 10, bold: false)

        ctx.beginPDFPage(nil)
        ctx.saveGState()
        ctx.setFillColor(CGColor(gray: 1, alpha: 1))
        ctx.fill(pageRect)

        var y: CGFloat = 740
        let left: CGFloat = 54
        TimecardPDFDrawUtils.draw("RatioVita", at: CGPoint(x: left, y: y), attributes: titleAttr, in: ctx)
        y -= 28

        for line in lines {
            if y < 56 {
                ctx.endPDFPage()
                ctx.beginPDFPage(nil)
                ctx.saveGState()
                ctx.setFillColor(CGColor(gray: 1, alpha: 1))
                ctx.fill(pageRect)
                y = 740
            }
            TimecardPDFDrawUtils.draw(line, at: CGPoint(x: left, y: y), attributes: bodyAttr, in: ctx)
            y -= 13
        }

        ctx.restoreGState()
        ctx.endPDFPage()
        ctx.closePDF()
        try (data as Data).write(to: url, options: .atomic)
    }
}
