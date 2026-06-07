import Foundation

#if canImport(LocalAuthentication)
import LocalAuthentication
#endif

/// Lightweight biometric confirmation before locking a signature box.
@MainActor
enum BiometricApprovalGate {
    static func confirm(reason: String) async -> Bool {
        #if canImport(LocalAuthentication)
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return true
        }
        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
        } catch {
            return false
        }
        #else
        return true
        #endif
    }
}
