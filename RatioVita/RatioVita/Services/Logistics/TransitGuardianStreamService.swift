import Combine
import Foundation

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class TransitGuardianStreamService: ObservableObject {
    static let shared = TransitGuardianStreamService()

    @Published private(set) var activeBannerMessage: String?
    @Published private(set) var activeException: TransitExceptionRecord?
    @Published private(set) var isListening = false
    @Published private(set) var isFirebaseLinked = false
    @Published private(set) var lastIngestionSummary: String?

    #if canImport(FirebaseFirestore)
    private var callSheetListener: ListenerRegistration?
    private var transitListener: ListenerRegistration?
    private var ingestionListener: ListenerRegistration?
    #endif

    private var activeProductionId: String?
    private var activeCallSheetId: String?

    private init() {}

    func startListening(productionId: String, callSheetId: String? = nil) {
        let trimmedProduction = productionId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedProduction.isEmpty else {
            stopListening()
            return
        }

        if trimmedProduction == activeProductionId,
           callSheetId == activeCallSheetId,
           isListening {
            return
        }

        stopListening()
        activeProductionId = trimmedProduction
        activeCallSheetId = callSheetId

        Task {
            await RatioVitaFirebaseBootstrap.configureIfNeededAsync()
            await MainActor.run {
                self.isFirebaseLinked = RatioVitaFirebaseBootstrap.isConfigured
                #if canImport(FirebaseFirestore)
                guard RatioVitaFirebaseBootstrap.isConfigured else { return }

                attachIngestionListener(productionId: trimmedProduction)

                if let callSheetId, !callSheetId.isEmpty {
                    attachTransitListener(productionId: trimmedProduction, callSheetId: callSheetId)
                } else {
                    attachLatestCallSheetListener(productionId: trimmedProduction)
                }
                isListening = true
                #endif
            }
        }
    }

    func stopListening() {
        #if canImport(FirebaseFirestore)
        transitListener?.remove()
        transitListener = nil
        callSheetListener?.remove()
        callSheetListener = nil
        ingestionListener?.remove()
        ingestionListener = nil
        #endif
        activeProductionId = nil
        activeCallSheetId = nil
        isListening = false
        activeBannerMessage = nil
        activeException = nil
        lastIngestionSummary = nil
    }

    #if canImport(FirebaseFirestore)
    private func attachLatestCallSheetListener(productionId: String) {
        guard let callSheets = FirestoreCollectionRefs.callSheets(productionId: productionId) else { return }
        callSheetListener = callSheets
            .order(by: "lastUpdated", descending: true)
            .limit(to: 1)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    #if DEBUG
                    print("TransitGuardian: call sheet listener error — \(error.localizedDescription)")
                    #endif
                    return
                }
                guard let doc = snapshot?.documents.first else {
                    Task { @MainActor in self.clearTransitAlerts() }
                    return
                }
                Task { @MainActor in
                    self.attachTransitListener(productionId: productionId, callSheetId: doc.documentID)
                }
            }
    }

    private func attachTransitListener(productionId: String, callSheetId: String) {
        transitListener?.remove()
        activeCallSheetId = callSheetId

        guard let collection = FirestoreCollectionRefs
            .transitExceptions(productionId: productionId, callSheetId: callSheetId)
        else { return }

        transitListener = collection
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    #if DEBUG
                    print("TransitGuardian: transit listener error — \(error.localizedDescription)")
                    #endif
                    return
                }
                let records = snapshot?.documents.compactMap(Self.parseTransitException) ?? []
                let critical = records
                    .filter(\.isHighwayCritical)
                    .sorted { $0.loggedAt > $1.loggedAt }
                Task { @MainActor in
                    if let first = critical.first {
                        self.activeException = first
                        self.activeBannerMessage = first.crewBannerText
                    } else {
                        self.clearTransitAlerts()
                    }
                }
            }
    }

    private func attachIngestionListener(productionId: String) {
        guard let collection = FirestoreCollectionRefs.ingestionLogs(productionId: productionId) else { return }
        ingestionListener = collection
            .order(by: "processedAt", descending: true)
            .limit(to: 1)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self, let doc = snapshot?.documents.first else { return }
                let data = doc.data()
                let fileName = data["sourceFileName"] as? String ?? "artifact batch"
                let records = data["recordsExtracted"] as? Int ?? 0
                let status = data["status"] as? String ?? "Success"
                Task { @MainActor in
                    self.lastIngestionSummary = "Latest ingestion: \(fileName) · \(records) records · \(status)"
                }
            }
    }

    private func clearTransitAlerts() {
        activeException = nil
        activeBannerMessage = nil
    }

    private static func parseTransitException(from document: QueryDocumentSnapshot) -> TransitExceptionRecord? {
        let data = document.data()
        let notes = data["descriptionNotes"] as? String ?? ""
        let arterial = data["affectedArterial"] as? String ?? ""
        let agentText = data["agentTriggeredWarningText"] as? String
        let combinedNotes = [notes, agentText ?? ""].joined(separator: " ").trimmingCharacters(in: .whitespaces)
        guard !combinedNotes.isEmpty || !arterial.isEmpty else { return nil }

        let callSheetId = data["callSheetId"] as? String ?? ""
        let severity = data["severity"] as? String ?? "Critical_Closure"
        let loggedAt = parseFirestoreDate(data["loggedAt"]) ?? Date()

        return TransitExceptionRecord(
            id: document.documentID,
            callSheetId: callSheetId,
            descriptionNotes: combinedNotes.isEmpty ? arterial : combinedNotes,
            affectedArterial: arterial,
            severity: severity,
            loggedAt: loggedAt
        )
    }

    private static func parseFirestoreDate(_ value: Any?) -> Date? {
        if let timestamp = value as? Timestamp {
            return timestamp.dateValue()
        }
        if let seconds = value as? TimeInterval {
            return Date(timeIntervalSinceReferenceDate: seconds)
        }
        if let seconds = value as? Double {
            return Date(timeIntervalSinceReferenceDate: seconds)
        }
        return nil
    }
    #endif
}
