//
//  PhoneMoreHubView.swift
//  RatioVita
//
//  Compact iPhone tab: Settings and secondary library tools.
//

import SwiftData
import SwiftUI

struct PhoneMoreHubView: View {
    @Query(
        filter: #Predicate<BankTransaction> {
            $0.matchedReceipt == nil && $0.manuallyClearedForReconciliation == false
        }
    )
    private var unmatchedBankTransactions: [BankTransaction]

    @Query(
        filter: #Predicate<Receipt> { $0.trashedAt != nil },
        sort: \Receipt.createdAt,
        order: .reverse
    )
    private var trashedReceipts: [Receipt]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                } header: {
                    Text("App")
                } footer: {
                    Text("Configure Gemini API key, OCR, and module toggles.")
                        .font(DesignSystem.Typography.caption2)
                }

                Section("Library tools") {
                    NavigationLink {
                        ReconciliationReviewView()
                    } label: {
                        Label("Reconcile", systemImage: "arrow.triangle.merge")
                    }
                    .badge(unmatchedBankTransactions.count)

                    NavigationLink {
                        BankImportView()
                    } label: {
                        Label("Bank import", systemImage: "building.columns.fill")
                    }

                    NavigationLink {
                        ReceiptTrashView()
                    } label: {
                        Label("Trash", systemImage: "trash")
                    }
                    .badge(trashedReceipts.count)
                }

                Section("Production") {
                    NavigationLink {
                        LaborSentinelHubView()
                    } label: {
                        Label("Labor", systemImage: "shield.lefthalf.filled")
                    }

                    NavigationLink {
                        TimeSheetsHubView()
                    } label: {
                        Label("Time Sheets", systemImage: "calendar.day.timeline.left")
                    }

                    NavigationLink {
                        MediaCoreHubView()
                    } label: {
                        Label("Media Core", systemImage: "waveform.circle")
                    }
                }
            }
            .navigationTitle("More")
        }
    }
}
