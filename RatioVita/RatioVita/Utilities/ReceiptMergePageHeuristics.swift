//
//  ReceiptMergePageHeuristics.swift
//  RatioVita
//
//  Lightweight OCR cues for “back of receipt” boilerplate (terms, merchant copy, etc.) before merge → Review.
//

import Foundation

enum ReceiptMergePageHeuristics {
    /// Short UI label when OCR suggests boilerplate / non-receipt legalese.
    static func boilerplateTag(for page: ScannedPage) -> String? {
        guard let ocr = page.ocrText?.trimmingCharacters(in: .whitespacesAndNewlines), ocr.count >= 60 else {
            return nil
        }
        let lower = ocr.lowercased()
        let needles = [
            "terms and conditions",
            "terms & conditions",
            "please retain this",
            "for your records",
            "customer copy",
            "merchant copy",
            "store copy",
            "void where prohibited",
            "no signature required",
            "authorized signature",
            "see reverse",
            "on the back",
            "privacy policy",
            "return policy",
            "non-negotiable",
            "not a deposit",
        ]
        for n in needles where lower.contains(n) {
            return "Boilerplate / conditions"
        }
        return nil
    }

    /// Stronger signal for bulk “remove flagged pages” (long OCR + multiple legal-ish hits).
    static func isLikelyBoilerplatePage(for page: ScannedPage) -> Bool {
        guard let ocr = page.ocrText?.lowercased(), ocr.count >= 400 else { return false }
        let needles = [
            "terms and conditions",
            "privacy policy",
            "return policy",
            "customer copy",
            "merchant copy",
        ]
        var hits = 0
        for n in needles where ocr.contains(n) {
            hits += 1
        }
        return hits >= 2
    }

    /// Page IDs to pre-select in merge review (conditions / boilerplate candidates).
    static func likelyBoilerplatePageIDs(in pages: [ScannedPage]) -> Set<UUID> {
        Set(pages.filter { isLikelyBoilerplatePage(for: $0) }.map(\.id))
    }
}
