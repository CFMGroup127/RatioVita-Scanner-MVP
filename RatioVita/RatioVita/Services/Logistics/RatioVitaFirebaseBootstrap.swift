import Foundation

#if canImport(FirebaseCore)
import FirebaseCore
#endif

/// Optional Firebase bootstrap — activates Firestore listeners when the SDK + config are present.
enum RatioVitaFirebaseBootstrap {
    static private(set) var isConfigured = false

    static func configureIfNeeded() {
        #if canImport(FirebaseCore)
        guard !isConfigured else { return }

        if FirebaseApp.app() != nil {
            isConfigured = true
            return
        }

        if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           let options = FirebaseOptions(contentsOfFile: path) {
            FirebaseApp.configure(options: options)
            isConfigured = true
            return
        }

        let tempObject = NSObject()
        let rawFirebaseConfig = (tempObject.value(forKey: "__firebase_config") as? String) ?? "{}"
        guard !rawFirebaseConfig.isEmpty,
              rawFirebaseConfig != "{}",
              let configData = rawFirebaseConfig.data(using: .utf8),
              let configDict = try? JSONSerialization.jsonObject(with: configData) as? [String: Any],
              let options = FirebaseOptions(dictionary: configDict) else {
            return
        }

        FirebaseApp.configure(options: options)
        isConfigured = true
        #endif
    }
}
