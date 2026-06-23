import Combine
import Foundation

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class LookBoardVaultStreamService: ObservableObject {
    static let shared = LookBoardVaultStreamService()

    @Published private(set) var assets: [LookBoardAsset] = LookBoardAsset.previewSamples()
    @Published private(set) var isListening = false
    @Published private(set) var isFirebaseLinked = false
    @Published private(set) var lastSyncSummary: String?

    #if canImport(FirebaseFirestore)
    private var listener: ListenerRegistration?
    #endif

    private var activeProductionId: String?

    private init() {}

    func startListening(productionId: String) {
        let trimmed = productionId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            stopListening()
            assets = LookBoardAsset.previewSamples()
            return
        }

        if trimmed == activeProductionId, isListening { return }

        stopListening()
        activeProductionId = trimmed

        Task { [weak self] in
            guard let self else { return }
            await RatioVitaFirebaseBootstrap.configureIfNeeded()
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.isFirebaseLinked = RatioVitaFirebaseBootstrap.isConfigured
                #if canImport(FirebaseFirestore)
                guard RatioVitaFirebaseBootstrap.isConfigured else {
                    self.assets = LookBoardAsset.previewSamples()
                    self.lastSyncSummary = "Offline preview — connect Firebase to stream live look boards."
                    return
                }

                listener = FirestoreCollectionRefs
                    .lookBoardAssets(productionId: trimmed)
                    .order(by: "title")
                    .addSnapshotListener { [weak self] snapshot, error in
                        Task { @MainActor [weak self] in
                            guard let self else { return }
                            if let error {
                                self.lastSyncSummary = "Look board sync error: \(error.localizedDescription)"
                                return
                            }
                            guard let docs = snapshot?.documents, !docs.isEmpty else {
                                self.assets = LookBoardAsset.previewSamples()
                                self.lastSyncSummary = "No cloud look boards yet — showing VitaLogic samples."
                                self.isListening = true
                                return
                            }

                            let parsed = docs.compactMap { LookBoardAsset(documentId: $0.documentID, data: $0.data()) }
                            self.assets = parsed.isEmpty ? LookBoardAsset.previewSamples() : parsed
                            self.lastSyncSummary = "\(self.assets.count) look board\(self.assets.count == 1 ? "" : "s") synced."
                            self.isListening = true
                        }
                    }
                #else
                self.assets = LookBoardAsset.previewSamples()
                self.lastSyncSummary = "Firestore SDK unavailable — showing local samples."
                #endif
            }
        }
    }

    func stopListening() {
        #if canImport(FirebaseFirestore)
        listener?.remove()
        listener = nil
        #endif
        activeProductionId = nil
        isListening = false
    }

    func groupedAssets(filterTag: String?) -> [(tag: String, items: [LookBoardAsset])] {
        let pool: [LookBoardAsset]
        if let filterTag, !filterTag.isEmpty {
            pool = assets.filter { asset in
                asset.tags.contains { $0.caseInsensitiveCompare(filterTag) == .orderedSame }
            }
        } else {
            pool = assets
        }

        let grouped = Dictionary(grouping: pool) { $0.primaryGroupTag }
        return grouped.keys.sorted().map { key in
            (tag: key, items: grouped[key]?.sorted(by: { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }) ?? [])
        }
    }

    var allTags: [String] {
        Array(Set(assets.flatMap(\.tags))).sorted()
    }
}
