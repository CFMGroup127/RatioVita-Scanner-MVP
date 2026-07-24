//
//  ExportMenuSheet.swift
//  RatioVita
//
//  User-facing export actions wired to AppleiWorkService and batch PDF/CSV helpers.
//

import SwiftData
import SwiftUI

/// Runs export jobs on the main actor (Receipt is a SwiftData @Model).
@MainActor
enum ReceiptExportRunner {
    private static let iwork = AppleiWorkService()

    static func exportSovereignPDF(receipt: Receipt) async throws -> URL {
        try await iwork.exportReceiptToPDF(receipt)
    }

    #if os(macOS)
    static func exportToPages(receipt: Receipt) async throws -> URL {
        try await iwork.exportReceiptToPages(receipt)
    }

    static func exportToKeynote(receipt: Receipt) async throws -> URL {
        try await iwork.exportReceiptToKeynote(receipt)
    }
    #endif
}

/// Toolbar / menu block: sovereign iWork export + optional batch paths.
struct ReceiptExportMenuContent: View {
    let receipts: [Receipt]
    var onExportedURL: (URL) -> Void

    var body: some View {
        if receipts.count == 1, let receipt = receipts.first {
            Button("Export Sovereign PDF…") {
                runExport { try await ReceiptExportRunner.exportSovereignPDF(receipt: receipt) }
            }
            #if os(macOS)
            Button("Export to Pages…") {
                runExport { try await ReceiptExportRunner.exportToPages(receipt: receipt) }
            }
            Button("Export to Keynote…") {
                runExport { try await ReceiptExportRunner.exportToKeynote(receipt: receipt) }
            }
            #endif
            Divider()
        }

        Button("Export combined PDF…") {
            runExport { try ReceiptBatchExport.makeCombinedPDF(receipts: receipts) }
        }
        .disabled(receipts.isEmpty)

        Button("Export CSV…") {
            runExport { try ReceiptBatchExport.makeCSV(receipts: receipts) }
        }
        .disabled(receipts.isEmpty)

        if !receipts.isEmpty {
            Divider()
            Button("Email selection…") {
                ReceiptSelectionMailer.presentEmailComposer(for: receipts)
            }
        }
    }

    private func runExport(_ work: @escaping () async throws -> URL) {
        Task {
            do {
                let url = try await work()
                await MainActor.run {
                    onExportedURL(url)
                }
            } catch {
                await MainActor.run {
                    UserMessageCenter.shared.present(
                        title: "Export failed",
                        message: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    )
                }
            }
        }
    }

    private func runExport(_ work: @escaping () throws -> URL) {
        Task {
            do {
                let url = try work()
                await MainActor.run {
                    onExportedURL(url)
                }
            } catch {
                await MainActor.run {
                    UserMessageCenter.shared.present(
                        title: "Export failed",
                        message: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    )
                }
            }
        }
    }
}

/// Sheet wrapper when presenting export share from a single receipt detail flow.
struct ExportMenuSheet: View {
    let receipt: Receipt
    @Environment(\.dismiss) private var dismiss
    @State private var sharePayload: ExportSharePayload?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                Text(receipt.merchant)
                    .font(DesignSystem.Typography.title3)
                Text("Choose an export format. PDF includes the Sovereign audit stamp.")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)

                ReceiptExportMenuContent(receipts: [receipt]) { url in
                    sharePayload = ExportSharePayload(url: url)
                }
            }
            .padding(DesignSystem.Spacing.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .navigationTitle("Export receipt")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                }
                .sheet(item: $sharePayload) { payload in
                    ShareExportSheet(url: payload.url)
                }
        }
    }
}

struct ExportSharePayload: Identifiable {
    let id = UUID()
    let url: URL
}
