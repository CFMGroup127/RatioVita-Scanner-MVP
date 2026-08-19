import CoreGraphics
import Foundation

/// Tracks consecutive stable document-rectangle frames for hands-free auto-capture.
struct DocumentFrameStabilityTracker: Sendable {
    static let requiredStableFrames = 8
    /// Normalized Vision coordinate tolerance (~5 pt on a typical preview).
    static let cornerTolerance: CGFloat = 0.015
    static let minimumConfidence: Float = 0.85

    private var previousBounds: DocumentRectangleBounds?
    private(set) var stableFrameCounter = 0

    mutating func reset() {
        previousBounds = nil
        stableFrameCounter = 0
    }

    /// Returns `true` when stability threshold is met and auto-capture should fire.
    mutating func register(_ bounds: DocumentRectangleBounds?) -> Bool {
        guard let bounds, bounds.confidence >= Self.minimumConfidence else {
            reset()
            return false
        }

        guard let previousBounds else {
            self.previousBounds = bounds
            stableFrameCounter = 1
            return false
        }

        if bounds.isStable(relativeTo: previousBounds, tolerance: Self.cornerTolerance) {
            stableFrameCounter += 1
            self.previousBounds = bounds
            return stableFrameCounter >= Self.requiredStableFrames
        }

        self.previousBounds = bounds
        stableFrameCounter = 1
        return false
    }

    var isApproachingStable: Bool {
        stableFrameCounter >= Self.requiredStableFrames / 2
    }
}

extension DocumentRectangleBounds {
    func maxCornerDelta(from other: DocumentRectangleBounds) -> CGFloat {
        let lhs = [topLeft, topRight, bottomRight, bottomLeft]
        let rhs = [other.topLeft, other.topRight, other.bottomRight, other.bottomLeft]
        return zip(lhs, rhs)
            .map { hypot($0.x - $1.x, $0.y - $1.y) }
            .max() ?? .greatestFiniteMagnitude
    }

    func isStable(relativeTo other: DocumentRectangleBounds, tolerance: CGFloat) -> Bool {
        maxCornerDelta(from: other) <= tolerance
    }
}
