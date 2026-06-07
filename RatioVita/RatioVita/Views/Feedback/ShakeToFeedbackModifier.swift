import SwiftUI

#if canImport(UIKit)
import UIKit

extension Notification.Name {
    static let ratioVitaDeviceDidShake = Notification.Name("com.ratiovita.deviceDidShake")
}

/// Installs shake detection via a zero-size host view controller.
struct ShakeToFeedbackHost: UIViewControllerRepresentable {
    func makeUIViewController(context _: Context) -> ShakeDetectingViewController {
        ShakeDetectingViewController()
    }

    func updateUIViewController(_: ShakeDetectingViewController, context _: Context) {}
}

final class ShakeDetectingViewController: UIViewController {
    override var canBecomeFirstResponder: Bool { true }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
    }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with _: UIEvent?) {
        guard motion == .motionShake else { return }
        NotificationCenter.default.post(name: .ratioVitaDeviceDidShake, object: nil)
    }
}
#endif

struct ShakeToFeedbackModifier: ViewModifier {
    let contextLabel: String

    func body(content: Content) -> some View {
        content
        #if os(iOS)
        .background(ShakeToFeedbackHost().frame(width: 0, height: 0))
        .onReceive(NotificationCenter.default.publisher(for: .ratioVitaDeviceDidShake)) { _ in
            LiveFeedbackManager.shared.presentFeedback(context: contextLabel)
        }
        #endif
    }
}

extension View {
    func shakeToFeedback(context: String = "RatioVita") -> some View {
        modifier(ShakeToFeedbackModifier(contextLabel: context))
    }
}
