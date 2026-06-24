#if DEBUG
import SwiftData
import SwiftUI

/// Debug / QA surface for bundled sample data (also reachable from the sidebar **Samples** item).
struct SamplesLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.brandAccent) private var brandAccent
    @StateObject private var viewModel: ReceiptsViewModel

    #if os(macOS)
    @State private var finderViewMode: ReceiptLibraryViewMode = .list
    @State private var finderSort: ReceiptLibrarySort = .dateAddedNewest
    #endif

    init() {
        _viewModel = StateObject(wrappedValue: ReceiptsViewModel())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                SectionHeader(
                    title: "Samples",
                    subtitle: "Seed demo receipts or import the bundled 2020 archive through the same pipeline as file import."
                )

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Button {
                        SampleSeed.insertSamples(into: modelContext)
                    } label: {
                        Label("Seed random samples", systemImage: "leaf")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(brandAccent)

                    Button {
                        do {
                            _ = try MultiHatPayWeekSeedService.seed(
                                modelContext: modelContext,
                                forceReload: true
                            )
                        } catch {
                            #if DEBUG
                            print("MultiHatPayWeekSeedService: \(error)")
                            #endif
                        }
                    } label: {
                        Label(MultiHatPayWeekSeedService.productionTitle, systemImage: "calendar.badge.plus")
                    }
                    .buttonStyle(.bordered)

                    Menu {
                        Button("Smoke (10 files)") {
                            Task { await viewModel.importBundledHistoricalArchive(limit: 10) }
                        }
                        Button("All (every synced file)") {
                            Task { await viewModel.importBundledHistoricalArchive(limit: nil) }
                        }
                    } label: {
                        Label("Import 2020 bundle", systemImage: "square.stack.3d.down.right")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(DesignSystem.Spacing.lg)
            .frame(maxWidth: 560, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.ratioVitaAdaptiveBackground)
        .navigationTitle("Samples")
        #if os(macOS)
            .toolbar {
                ToolbarItemGroup(placement: .navigation) {
                    Button {} label: { Image(systemName: "chevron.backward") }
                        .disabled(true)
                    Button {} label: { Image(systemName: "chevron.forward") }
                        .disabled(true)
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    Picker("View", selection: $finderViewMode) {
                        ForEach(ReceiptLibraryViewMode.allCases) { mode in
                            Image(systemName: mode.systemImage)
                                .accessibilityLabel(mode.title)
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                    .fixedSize(horizontal: true, vertical: false)

                    Menu {
                        Picker("Sort", selection: $finderSort) {
                            ForEach(ReceiptLibrarySort.allCases) { option in
                                Text(option.menuTitle).tag(option)
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                    .menuIndicator(.hidden)

                    Menu {
                        Button("Share…") {}
                            .disabled(true)
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .menuIndicator(.hidden)

                    Menu {
                        Button("Assign Tags…") {}
                            .disabled(true)
                    } label: {
                        Image(systemName: "tag")
                    }
                    .menuIndicator(.hidden)

                    Menu {
                        Button("Seed random samples") {
                            SampleSeed.insertSamples(into: modelContext)
                        }
                        Menu("Import 2020 bundle") {
                            Button("Smoke (10 files)") {
                                Task { await viewModel.importBundledHistoricalArchive(limit: 10) }
                            }
                            Button("All (every synced file)") {
                                Task { await viewModel.importBundledHistoricalArchive(limit: nil) }
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .menuIndicator(.hidden)
                }
            }
        #endif
            .onAppear {
                viewModel.bootstrapScannerIfNeeded()
                viewModel.updateDependencies(context: modelContext)
            }
    }
}

#Preview {
    NavigationStack {
        SamplesLibraryView()
    }
    .modelContainer(SampleData.previewContainer)
}
#endif
