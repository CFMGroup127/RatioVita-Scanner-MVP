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

    #if canImport(FirebaseFirestore)
    private var callSheetListener: ListenerRegistration?
    private var transitListener: ListenerRegistration?
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
        RatioVitaFirebaseBootstrap.configureIfNeeded()

        #if canImport(FirebaseFirestore)
        guard RatioVitaFirebaseBootstrap.isConfigured else { return }

        if let callSheetId, !callSheetId.isEmpty {
            attachTransitListener(productionId: trimmedProduction, callSheetId: callSheetId)
        } else {
            attachLatestCallSheetListener(productionId: trimmedProduction)
        }
        isListening = true
        #endif
    }

    func stopListening() {
        #if canImport(FirebaseFirestore)
        transitListener?.remove()
        transitListener = nil
        callSheetListener?.remove()
        callSheetListener = nil
        #endif
        activeProductionId = nil
        activeCallSheetId = nil
        isListening = false
        activeBannerMessage = nil
        activeException = nil
    }

    #if canImport(FirebaseFirestore)
    private func attachLatestCallSheetListener(productionId: String) {
        let db = Firestore.firestore()
        callSheetListener = db
            .collection(ProductionFirestorePathHelpers.callSheetsCollection(productionId: productionId))
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
                    Task { @MainActor in
                        self.clearAlerts()
                    }
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

        let db = Firestore.firestore()
        let path = ProductionFirestorePathHelpers.transitExceptionsCollection(
            productionId: productionId,
            callSheetId: callSheetId
        )
        transitListener = db.collection(path).addSnapshotListener { [weak self] snapshot, error in
            guard let self else { return }
            if let error {
                #if DEBUG
                print("TransitGuardian: transit listener error — \(error.localizedDescription)")
                #endif
                return
            }
            let records = snapshot?.documents.compactMap(Self.parseTransitException) ?? []
            let critical = records.filter(\.isHighwayCritical)
            Task { @MainActor in
                if let first = critical.first {
                    self.activeException = first
                    self.activeBannerMessage = first.crewBannerText
                } else {
                    self.clearAlerts()
                }
            }
        }
    }

    private func clearAlerts() {
        activeException = nil
        activeBannerMessage = nil
    }

    private static func parseTransitException(from document: QueryDocumentSnapshot) -> TransitExceptionRecord? {
        let data = document.data()
        let notes = data["descriptionNotes"] as? String ?? ""
        let arterial = data["affectedArterial"] as? String ?? ""
        guard !notes.isEmpty || !arterial.isEmpty else { return nil }

        let callSheetId = data["callSheetId"] as? String ?? ""
        let severity = data["severity"] as? String ?? "Critical_Closure"
        let loggedAt: Date
        if let timestamp = data["loggedAt"] as? Timestamp {
            loggedAt = timestamp.dateValue()
        } else {
            loggedAt = Date()
        }

        return TransitExceptionRecord(
            id: document.documentID,
            callSheetId: callSheetId,
            descriptionNotes: notes,
            affectedArterial: arterial,
            severity: severity,
            loggedAt: loggedAt
        )
    }
    #endif
}
