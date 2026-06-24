import Foundation

#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// Firebase bootstrap — synchronous configure at process launch before any Firestore access.
enum RatioVitaFirebaseBootstrap {
    static private(set) var isConfigured = false

    /// Evaluated the first time this type is referenced — before `@main` App property initializers.
    static let moduleBootstrap: Void = {
        configureIfNeededInternal()
    }()

    /// Idempotent configure — safe from App init, coordinators, and stream services.
    static func ensureConfigured() {
        _ = moduleBootstrap
        configureIfNeededInternal()
    }

    #if canImport(FirebaseFirestore)
    /// Returns Firestore only after `FirebaseApp.configure()` has completed.
    static func firestore() -> Firestore? {
        ensureConfigured()
        guard isConfigured, FirebaseApp.app() != nil else { return nil }
        return Firestore.firestore()
    }
    #endif

    static func configureIfNeeded() {
        ensureConfigured()
    }

    static func configureIfNeededAsync() async {
        ensureConfigured()
        await ensureAuthenticatedSession()
    }

    private static func configureIfNeededInternal() {
        #if canImport(FirebaseCore)
        guard !isConfigured else { return }
        if FirebaseApp.app() != nil {
            isConfigured = true
            return
        }

        if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           let options = FirebaseOptions(contentsOfFile: path)
        {
            FirebaseApp.configure(options: options)
            isConfigured = true
            #if DEBUG
            print("RatioVita Firebase: configured from GoogleService-Info.plist")
            #endif
            Task { await ensureAuthenticatedSession() }
            return
        }

        guard let rawFirebaseConfig = runtimeFirebaseConfigJSON(),
              let configData = rawFirebaseConfig.data(using: .utf8),
              let configDict = try? JSONSerialization.jsonObject(with: configData) as? [String: Any],
              let options = firebaseOptions(from: configDict)
        else {
            #if DEBUG
            print("RatioVita Firebase: GoogleService-Info.plist missing from app bundle.")
            #endif
            return
        }

        FirebaseApp.configure(options: options)
        isConfigured = true
        Task { await ensureAuthenticatedSession() }
        #endif
    }

    private static func runtimeFirebaseConfigJSON() -> String? {
        if let plistValue = Bundle.main.object(forInfoDictionaryKey: "__firebase_config") as? String,
           !plistValue.isEmpty,
           plistValue != "{}"
        {
            return plistValue
        }
        if let envValue = ProcessInfo.processInfo.environment["__firebase_config"],
           !envValue.isEmpty,
           envValue != "{}"
        {
            return envValue
        }
        return nil
    }

    #if canImport(FirebaseAuth)
    private static func ensureAuthenticatedSession() async {
        ensureConfigured()
        guard FirebaseApp.app() != nil else { return }
        guard Auth.auth().currentUser == nil else { return }
        do {
            _ = try await Auth.auth().signInAnonymously()
            #if DEBUG
            print("RatioVita Firebase: anonymous session established for Firestore listeners.")
            #endif
        } catch {
            #if DEBUG
            print("RatioVita Firebase: anonymous sign-in failed — \(error.localizedDescription)")
            #endif
        }
    }
    #else
    private static func ensureAuthenticatedSession() async {}
    #endif

    #if canImport(FirebaseCore)
    private static func firebaseOptions(from dict: [String: Any]) -> FirebaseOptions? {
        guard
            let googleAppID = dict["googleAppID"] as? String,
            let gcmSenderID = dict["gcmSenderID"] as? String
        else {
            return nil
        }
        let options = FirebaseOptions(googleAppID: googleAppID, gcmSenderID: gcmSenderID)
        if let apiKey = dict["apiKey"] as? String { options.apiKey = apiKey }
        if let projectID = dict["projectID"] as? String { options.projectID = projectID }
        if let databaseURL = dict["databaseURL"] as? String { options.databaseURL = databaseURL }
        return options
    }
    #endif
}
