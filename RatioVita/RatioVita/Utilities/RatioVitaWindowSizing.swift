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

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WindowSizingAnchorView {
        let view = WindowSizingAnchorView()
        view.configure(
            minimum: minimum,
            maximum: maximum,
            preferred: preferred,
            coordinator: context.coordinator
        )
        return view
    }

    func updateNSView(_ nsView: WindowSizingAnchorView, context: Context) {
        nsView.configure(
            minimum: minimum,
            maximum: maximum,
            preferred: preferred,
            coordinator: context.coordinator
        )
    }

    final class Coordinator {
        var configuredWindowID: ObjectIdentifier?
        var appliedMinimum: NSSize?
        var appliedMaximum: NSSize?
        var didScheduleInitialClamp = false
        var isApplyingFrame = false
    }
}

/// Applies window min/max and one-time frame clamping when attached — never during SwiftUI layout passes.
private final class WindowSizingAnchorView: NSView {
    private var minimum = NSSize(
        width: RatioVitaWindowSizing.minimumWidth,
        height: RatioVitaWindowSizing.minimumHeight
    )
    private var maximum = NSSize(
        width: RatioVitaWindowSizing.maximumWidth,
        height: RatioVitaWindowSizing.maximumHeight
    )
    private var preferred = NSSize(
        width: RatioVitaWindowSizing.defaultWidth,
        height: RatioVitaWindowSizing.defaultHeight
    )
    private weak var coordinator: RatioVitaWindowSizeConfigurator.Coordinator?

    func configure(
        minimum: NSSize,
        maximum: NSSize,
        preferred: NSSize,
        coordinator: RatioVitaWindowSizeConfigurator.Coordinator
    ) {
        self.minimum = minimum
        self.maximum = maximum
        self.preferred = preferred
        self.coordinator = coordinator
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        scheduleInitialClampIfNeeded()
    }

    private func scheduleInitialClampIfNeeded() {
        guard window != nil, let coordinator, !coordinator.didScheduleInitialClamp else { return }
        coordinator.didScheduleInitialClamp = true
        DispatchQueue.main.async { [weak self] in
            self?.applyWindowSizingIfNeeded()
        }
    }

    private func applyWindowSizingIfNeeded() {
        guard let window, let coordinator, !coordinator.isApplyingFrame else { return }

        let windowID = ObjectIdentifier(window)
        if coordinator.configuredWindowID != windowID {
            coordinator.configuredWindowID = windowID
            coordinator.appliedMinimum = nil
            coordinator.appliedMaximum = nil
        }

        if coordinator.appliedMinimum != minimum {
            window.minSize = minimum
            coordinator.appliedMinimum = minimum
        }
        if coordinator.appliedMaximum != maximum {
            window.maxSize = maximum
            coordinator.appliedMaximum = maximum
        }

        clampFrameIfNeeded(on: window, coordinator: coordinator)
    }

    private func clampFrameIfNeeded(
        on window: NSWindow,
        coordinator: RatioVitaWindowSizeConfigurator.Coordinator
    ) {
        let frame = window.frame
        guard frame.width.isFinite, frame.height.isFinite else {
            applyClampedFrame(
                to: window,
                width: preferred.width,
                height: preferred.height,
                from: frame,
                coordinator: coordinator
            )
            return
        }

        let tooSmall = frame.width < minimum.width || frame.height < minimum.height
        let tooLarge = frame.width > maximum.width || frame.height > maximum.height
        guard tooSmall || tooLarge else { return }

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
        let targetWidth = tooSmall ? max(width, preferred.width) : width
        let targetHeight = tooSmall ? max(height, preferred.height) : height

        guard abs(frame.width - targetWidth) > 1 || abs(frame.height - targetHeight) > 1 else { return }

        applyClampedFrame(
            to: window,
            width: targetWidth,
            height: targetHeight,
            from: frame,
            coordinator: coordinator
        )
    }

    private func applyClampedFrame(
        to window: NSWindow,
        width: CGFloat,
        height: CGFloat,
        from frame: NSRect,
        coordinator: RatioVitaWindowSizeConfigurator.Coordinator
    ) {
        coordinator.isApplyingFrame = true
        defer { coordinator.isApplyingFrame = false }

        let deltaHeight = height - frame.height
        window.setFrame(
            NSRect(
                x: frame.origin.x,
                y: frame.origin.y - deltaHeight,
                width: width,
                height: height
            ),
            display: true,
            animate: false
        )
    }
}
#endif
