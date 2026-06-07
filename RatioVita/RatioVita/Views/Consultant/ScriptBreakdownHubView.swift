import SwiftData
import SwiftUI

struct ScriptBreakdownHubView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ScriptSceneBreakdown.sceneNumber) private var scenes: [ScriptSceneBreakdown]

    var body: some View {
        List {
            if scenes.isEmpty {
                ContentUnavailableView(
                    "No scenes",
                    systemImage: "film",
                    description: Text("Ingest a master scene to propagate department overlays.")
                )
            }
            ForEach(scenes) { scene in
                VStack(alignment: .leading, spacing: 6) {
                    Text("Scene \(scene.sceneNumber)")
                        .font(.headline)
                    Text(scene.locationSetting)
                        .font(.caption)
                    Text(scene.sceneDescription)
                        .font(.subheadline)
                    ForEach(IndustryDepartmentScope.allCases.prefix(4)) { dept in
                        let note = scene.note(for: dept)
                        if !note.isEmpty {
                            Text("\(dept.displayName): \(note)")
                                .font(.caption2)
                        }
                    }
                }
            }
        }
        .navigationTitle("Script breakdown")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Seed Hearn scene") { seed() }
            }
        }
    }

    private func seed() {
        _ = try? MasterScriptBreakdownEngine.ingestScene(
            context: modelContext,
            sceneNumber: 12,
            location: "INT. HEARN GENERATING PLANT",
            description: "Roughneck miner enters control room in damaged 1980s cargo van.",
            characters: ["JADEN-01", "MALCOLM-02"],
            productionTitle: "Sanctuary"
        )
    }
}
