import Foundation
import SwiftData
import SwiftUI

enum ReceiptPageDecouplerError: LocalizedError {
    case needsAtLeastTwoPages
    case pickAtLeastOnePage
    case mustLeaveAtLeastOnePageOnOriginal

    var errorDescription: String? {
        switch self {
            case .needsAtLeastTwoPages: "Split needs at least two scanned pages."
            case .pickAtLeastOnePage: "Select at least one page to move."
            case .mustLeaveAtLeastOnePageOnOriginal: "Leave at least one page on the original record."
        }
    }
}

/// **Document decoupler**: moves selected `ReceiptImage` pages onto a new `Receipt` with a fresh UUID.
@MainActor
enum ReceiptPageDecouplerService {
    /// Creates a new receipt containing the selected pages (by `pageIndex`), re-numbers both sides, and appends
    /// a Sovereign audit row. Returns the new receipt.
    @discardableResult
    static func splitSelectedPages(
        from source: Receipt,
        selectedPageIndices: Set<Int>,
        modelContext: ModelContext,
        skipForensicRefresh: Bool = false
    ) throws -> Receipt {
        let sorted = source.images.sorted { $0.pageIndex < $1.pageIndex }
        guard sorted.count >= 2 else { throw ReceiptPageDecouplerError.needsAtLeastTwoPages }
        guard !selectedPageIndices.isEmpty else { throw ReceiptPageDecouplerError.pickAtLeastOnePage }
        let moving = sorted.filter { selectedPageIndices.contains($0.pageIndex) }
        let staying = sorted.filter { !selectedPageIndices.contains($0.pageIndex) }
        guard !moving.isEmpty,
              !staying.isEmpty else { throw ReceiptPageDecouplerError.mustLeaveAtLeastOnePageOnOriginal }

        let newReceipt = Receipt(
            merchant: splitMerchantLabel(from: source),
            total: 0,
            currencyCode: source.currencyCode,
            notes: "Split from \(source.merchant) (\(String(source.id.uuidString.prefix(8))))",
            transactionDate: source.transactionDate,
            extractionSource: source.extractionSource,
            documentType: source.documentType,
            pendingHumanReview: source.pendingHumanReview,
            scannedViaCamera: source.scannedViaCamera,
            reviewChecklistDone: false
        )
        modelContext.insert(newReceipt)
        newReceipt.productionProject = source.productionProject
        newReceipt.vaultPathPrefix = source.vaultPathPrefix
        newReceipt.department = source.department

        for (i, img) in moving.enumerated() {
            img.receipt = newReceipt
            img.pageIndex = i
        }
        for (i, img) in staying.enumerated() {
            img.receipt = source
            img.pageIndex = i
        }

        FilingCoordinator.appendAudit(
            context: modelContext,
            kindRaw: FilingCoordinator.auditKindReceiptPagesSplit,
            title: "Document decoupler: pages split",
            detail: "parentRid:\(source.id.uuidString);newRid:\(newReceipt.id.uuidString);movedPages:\(moving.map(\.pageIndex).sorted())"
        )
        try modelContext.save()
        ReceiptWorkspaceBatchGuard.retainAfterDecouple(
            parent: source,
            spawned: newReceipt,
            context: modelContext
        )
        LibraryPersistenceMonitor.recordSnapshot(context: modelContext, reason: "decouple-split")
        if !skipForensicRefresh {
            refreshForensicAfterDecouple(receipts: [source, newReceipt], context: modelContext)
        }
        return newReceipt
    }

    /// Each selected page becomes its own single-page receipt; unselected pages remain on `source`.
    @discardableResult
    static func explodeSelectedPages(
        from source: Receipt,
        selectedPageIndices: Set<Int>,
        modelContext: ModelContext
    ) throws -> [Receipt] {
        let sorted = source.images.sorted { $0.pageIndex < $1.pageIndex }
        guard sorted.count >= 2 else { throw ReceiptPageDecouplerError.needsAtLeastTwoPages }
        guard !selectedPageIndices.isEmpty else { throw ReceiptPageDecouplerError.pickAtLeastOnePage }

        let allIndices = Set(sorted.map(\.pageIndex))
        let toExplode = selectedPageIndices.intersection(allIndices)
        guard !toExplode.isEmpty else { throw ReceiptPageDecouplerError.pickAtLeastOnePage }
        guard toExplode.count < allIndices.count else {
            throw ReceiptPageDecouplerError.mustLeaveAtLeastOnePageOnOriginal
        }

        var spawned: [Receipt] = []
        for idx in toExplode.sorted().reversed() {
            let newR = try splitSelectedPages(
                from: source,
                selectedPageIndices: [idx],
                modelContext: modelContext,
                skipForensicRefresh: true
            )
            spawned.append(newR)
        }

        let batchID = source.id.uuidString
        for child in spawned {
            let link = ReceiptReferenceLink(
                fromReceipt: child,
                toReceipt: source,
                relationshipLabel: "Shadow: exploded page from batch \(batchID)"
            )
            modelContext.insert(link)
        }

        FilingCoordinator.appendAudit(
            context: modelContext,
            kindRaw: FilingCoordinator.auditKindReceiptExplodeSelectedPages,
            title: "Document decoupler: exploded selected pages",
            detail: "batchRid:\(batchID);pages:\(toExplode.sorted());spawned:\(spawned.map(\.id.uuidString).joined(separator: ","))"
        )
        try modelContext.save()
        ReceiptWorkspaceBatchGuard.retainAfterDecouple(
            parent: source,
            spawned: spawned,
            context: modelContext
        )

        var toRefresh: [Receipt] = [source]
        toRefresh.append(contentsOf: spawned)
        refreshForensicAfterDecouple(receipts: toRefresh, context: modelContext)
        return spawned
    }

    private static func refreshForensicAfterDecouple(receipts: [Receipt], context: ModelContext) {
        for r in receipts {
            try? ReceiptForensicRefresh.reapplyHeuristicPolarityAndShadow(receipt: r, context: context)
        }
    }

    /// Splits **every** page after the first onto its own `Receipt`, each **shadow-linked** back to the original batch.
    /// Page order is preserved; the original keeps page 0.
    @discardableResult
    static func explodeAllPages(
        from source: Receipt,
        modelContext: ModelContext
    ) throws -> [Receipt] {
        let sorted = source.images.sorted { $0.pageIndex < $1.pageIndex }
        guard sorted.count >= 2 else { throw ReceiptPageDecouplerError.needsAtLeastTwoPages }

        var spawned: [Receipt] = []
        while source.images.sorted(by: { $0.pageIndex < $1.pageIndex }).count > 1 {
            let last = source.images.sorted { $0.pageIndex < $1.pageIndex }.last!.pageIndex
            let newR = try splitSelectedPages(
                from: source,
                selectedPageIndices: [last],
                modelContext: modelContext,
                skipForensicRefresh: true
            )
            spawned.append(newR)
        }

        let batchID = source.id.uuidString
        for child in spawned {
            let link = ReceiptReferenceLink(
                fromReceipt: child,
                toReceipt: source,
                relationshipLabel: "Shadow: exploded page from batch \(batchID)"
            )
            modelContext.insert(link)
        }

        FilingCoordinator.appendAudit(
            context: modelContext,
            kindRaw: FilingCoordinator.auditKindReceiptExplodeAllPages,
            title: "Document decoupler: exploded all pages",
            detail: "batchRid:\(batchID);spawned:\(spawned.map(\.id.uuidString).joined(separator: ","))"
        )
        try modelContext.save()
        ReceiptWorkspaceBatchGuard.retainAfterDecouple(
            parent: source,
            spawned: spawned,
            context: modelContext
        )
        refreshForensicAfterDecouple(receipts: [source] + spawned, context: modelContext)
        return spawned
    }

    private static func splitMerchantLabel(from source: Receipt) -> String {
        let m = source.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        if m.isEmpty { return "Split record" }
        return "\(m) (split)"
    }
}

// MARK: - UI

/// Pick pages to move into a **new** sovereign receipt record.
struct ReceiptPageSplitSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let source: Receipt

    @State private var selected: Set<Int> = []
    @State private var errorMessage: String?

    private var sortedImages: [ReceiptImage] {
        source.images.sorted { $0.pageIndex < $1.pageIndex }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(
                        "Creates a new receipt with its own id. Selected pages move off this record; the rest stay "
                            + "here. Totals are not auto-split—edit each record."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

                Section("Pages on this record") {
                    ForEach(sortedImages, id: \.id) { img in
                        Toggle(
                            "Page \(img.pageIndex + 1) — move to new record",
                            isOn: Binding(
                                get: { selected.contains(img.pageIndex) },
                                set: { on in
                                    if on {
                                        selected.insert(img.pageIndex)
                                    } else {
                                        selected.remove(img.pageIndex)
                                    }
                                }
                            )
                        )
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(Color.ratioVitaError)
                    }
                }
            }
            .navigationTitle("Split pages")
            #if os(iOS) || os(visionOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Split") { splitTapped() }
                            .fontWeight(.semibold)
                            .disabled(sortedImages.count < 2)
                    }
                }
        }
    }

    private func splitTapped() {
        errorMessage = nil
        do {
            _ = try ReceiptPageDecouplerService.splitSelectedPages(
                from: source,
                selectedPageIndices: selected,
                modelContext: modelContext
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
