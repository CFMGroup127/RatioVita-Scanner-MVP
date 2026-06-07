import SwiftData
import SwiftUI

/// Aubry / Tess / Wayne hawk-eye feed (Sprint SSS).
struct CreativeMonitorFeedView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        sort: \CreativeFirstLookSnapshot.capturedAt,
        order: .reverse
    ) private var snapshots: [CreativeFirstLookSnapshot]

    var body: some View {
        List {
            if snapshots.isEmpty {
                Text("No first-look frames yet. Capture from RV · First Looks.")
                    .foregroundStyle(.secondary)
            }
            ForEach(snapshots) { shot in
                VStack(alignment: .leading, spacing: 6) {
                    Text("Cast \(shot.castDisplayID)")
                        .font(.headline)
                    Text(shot.sessionTag)
                        .font(.caption.weight(.semibold))
                    Text("Continuity anchor: \(shot.continuityCodeUntouched) (unchanged)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(shot.notes)
                        .font(.caption)
                    Text(shot.capturedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Creative monitor")
    }
}
