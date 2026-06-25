//
//  RatioVitaWindowSizing.swift
//  RatioVita
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

enum RatioVitaWindowSizing {
    static let defaultWidth: CGFloat = 1180
    static let defaultHeight: CGFloat = 760
    static let minimumWidth: CGFloat = 900
    static let minimumHeight: CGFloat = 600
    static let maximumWidth: CGFloat = SafeLayoutBounds.maxWindowWidth
    static let maximumHeight: CGFloat = SafeLayoutBounds.maxWindowHeight

    static func clampedDimension(_ value: CGFloat, min: CGFloat, max: CGFloat, fallback: CGFloat) -> CGFloat {
        guard value.isFinite, value > 0 else { return fallback }
        return Swift.min(max, Swift.max(min, value))
    }
}

#if os(macOS)
extension View {
    /// Clamps restored or animated NSWindow frames so AppKit never receives overflow proposals.
    func ratioVitaWindowSizing() -> some View {
        background(
            RatioVitaWindowSizeConfigurator(
                minimum: NSSize(
                    width: RatioVitaWindowSizing.minimumWidth,
                    height: RatioVitaWindowSizing.minimumHeight
                ),
                maximum: NSSize(
                    width: RatioVitaWindowSizing.maximumWidth,
                    height: RatioVitaWindowSizing.maximumHeight
                ),
                preferred: NSSize(
                    width: RatioVitaWindowSizing.defaultWidth,
                    height: RatioVitaWindowSizing.defaultHeight
                )
            )
        )
    }
}

@MainActor
private struct RatioVitaWindowSizeConfigurator: NSViewRepresentable {
    let minimum: NSSize
    let maximum: NSSize
    let preferred: NSSize

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async { apply(to: view) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { apply(to: nsView) }
    }

    private func apply(to view: NSView) {
        guard let window = view.window else { return }

        window.minSize = minimum
        window.maxSize = maximum

        let frame = window.frame
        let width = RatioVitaWindowSizing.clampedDimension(
            frame.width,
            min: minimum.width,
            max: maximum.width,
            fallback: preferred.width
        )
        let height = RatioVitaWindowSizing.clampedDimension(
            frame.height,
            min: minimum.height,
            max: maximum.height,
            fallback: preferred.height
        )

        let tooSmall = frame.width < minimum.width || frame.height < minimum.height
        let tooLarge = frame.width > maximum.width || frame.height > maximum.height
        let nonFinite = !frame.width.isFinite || !frame.height.isFinite
        guard tooSmall || tooLarge || nonFinite else { return }

        let targetWidth = tooSmall ? max(width, preferred.width) : width
        let targetHeight = tooSmall ? max(height, preferred.height) : height
        let deltaHeight = targetHeight - frame.height

        window.setFrame(
            NSRect(
                x: frame.origin.x,
                y: frame.origin.y - deltaHeight,
                width: targetWidth,
                height: targetHeight
            ),
            display: true,
            animate: false
        )
    }
}
#endif
