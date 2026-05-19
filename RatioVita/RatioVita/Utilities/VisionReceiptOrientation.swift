//
//  VisionReceiptOrientation.swift
//  RatioVita
//
//  When EXIF is missing or wrong, scores fast Vision OCR across rotations and horizontal mirror
//  on a downscaled probe, then applies the best transform before enhancement + full OCR.
//

import CoreGraphics
import CoreImage
import Foundation
import Vision

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum VisionReceiptOrientation {
    private static let probeMaxSide: CGFloat = 720
    private static let ciContext = CIContext(options: nil)

    /// Runs only when OCR is enabled. Inexpensive `.fast` text probe; applies mirror/rotation only if score clearly
    /// beats baseline.
    static func autoCorrectReceiptOrientation(image: RVImage, ocrEnabled: Bool) -> RVImage {
        guard ocrEnabled else { return image }
        return autoCorrectSync(image: image)
    }

    private static func autoCorrectSync(image: RVImage) -> RVImage {
        guard let fullCG = image.rv_cgImageForVisionAnalysis ?? image.rvCGImage,
              let probe = downscaleCGImage(fullCG, maxSide: probeMaxSide) else
        {
            return image
        }

        guard let baselineCG = renderProbeTransform(probe, quarterTurnsClockwise: 0, mirrorHorizontal: false) else {
            return image
        }
        let baselineScore = textOrientationScore(cgImage: baselineCG)

        var bestNoMirrorQ = 0
        var bestNoMirrorScore: Float = baselineScore
        for q in 0..<4 {
            guard let cg = renderProbeTransform(probe, quarterTurnsClockwise: q, mirrorHorizontal: false) else { continue }
            let s = textOrientationScore(cgImage: cg)
            if s > bestNoMirrorScore {
                bestNoMirrorScore = s
                bestNoMirrorQ = q
            }
        }

        var bestMirrorQ = 0
        var bestMirrorScore: Float = -1
        for q in 0..<4 {
            guard let cg = renderProbeTransform(probe, quarterTurnsClockwise: q, mirrorHorizontal: true) else { continue }
            let s = textOrientationScore(cgImage: cg)
            if s > bestMirrorScore {
                bestMirrorScore = s
                bestMirrorQ = q
            }
        }

        // Horizontal mirror is a common false positive on sparse / back-of-receipt pages; require strong evidence.
        let mirrorWins = bestMirrorScore > max(bestNoMirrorScore * 1.38, bestNoMirrorScore + 24)
        let bestScore = mirrorWins ? bestMirrorScore : bestNoMirrorScore
        let bestQ = mirrorWins ? bestMirrorQ : bestNoMirrorQ

        guard bestScore >= 18, bestScore > baselineScore * 1.12 + 2 else { return image }
        guard bestQ != 0 || mirrorWins else { return image }

        var out = image
        if mirrorWins, let f = out.rv_flippedHorizontally() { out = f }
        if bestQ != 0, let r = out.rv_rotatedQuarterTurnsClockwise(bestQ) { out = r }
        return out
    }

    private static func downscaleCGImage(_ cg: CGImage, maxSide: CGFloat) -> CGImage? {
        let w = CGFloat(cg.width)
        let h = CGFloat(cg.height)
        let longest = max(w, h)
        guard longest > 1 else { return nil }
        if longest <= maxSide { return cg }

        let scale = maxSide / longest
        var ci = CIImage(cgImage: cg)
        ci = ci.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let extent = ci.extent.integral
        guard extent.width > 1, extent.height > 1 else { return nil }
        return ciContext.createCGImage(ci, from: extent)
    }

    private static func renderProbeTransform(
        _ cg: CGImage,
        quarterTurnsClockwise q: Int,
        mirrorHorizontal: Bool
    ) -> CGImage? {
        var ci = CIImage(cgImage: cg)
        if mirrorHorizontal {
            let e = ci.extent
            ci = ci.transformed(by: CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: e.minX + e.maxX, ty: 0))
        }
        var turns = ((q % 4) + 4) % 4
        while turns > 0 {
            let e = ci.extent
            let t = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: e.height, ty: 0)
            ci = ci.transformed(by: t)
            turns -= 1
        }
        let extent = ci.extent.integral
        guard extent.width > 1, extent.height > 1 else { return nil }
        return ciContext.createCGImage(ci, from: extent)
    }

    private static func textOrientationScore(cgImage: CGImage) -> Float {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US"]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return 0
        }
        guard let results = request.results else { return 0 }

        var score: Float = 0
        for obs in results.prefix(100) {
            guard let cand = obs.topCandidates(1).first else { continue }
            let str = cand.string
            guard str.count >= 2 else { continue }
            if str.range(of: #"[A-Za-z0-9]"#, options: .regularExpression) != nil {
                score += Float(str.count) * max(0.05, cand.confidence)
            }
        }
        return score
    }
}
