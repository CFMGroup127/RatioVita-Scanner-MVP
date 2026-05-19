import SwiftData
import SwiftUI

/// Modal wrapper around `TimecardWorkspaceView` (iOS full-screen / macOS sheet).
struct WorkDateDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var day: CrewTimecardDay
    var siblingProjectDays: [CrewTimecardDay]

    var body: some View {
        TimecardWorkspaceView(
            day: day,
            siblingProjectDays: siblingProjectDays,
            showsToolbarDone: true,
            onToolbarDone: { dismiss() }
        )
        .navigationTitle("Work day")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
