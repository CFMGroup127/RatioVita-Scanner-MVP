import Foundation
import Network

/// Lightweight check before calling remote APIs (e.g. Gemini). Does not replace App Sandbox **Outgoing Connections**
/// (`com.apple.security.network.client`); without that entitlement, requests can fail with errors like **-1003**.
enum NetworkConnectivityGate {
    /// Whether the system currently reports a satisfied path (Wi‑Fi, Ethernet, cellular, etc.).
    static func pathSatisfiesInternet() async -> Bool {
        await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            let queue = DispatchQueue(label: "com.ratiovita.NetworkConnectivityGate")
            monitor.start(queue: queue)
            queue.asyncAfter(deadline: .now() + 0.05) {
                let ok = monitor.currentPath.status == .satisfied
                monitor.cancel()
                continuation.resume(returning: ok)
            }
        }
    }
}
