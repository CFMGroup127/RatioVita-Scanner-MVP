import Foundation
import SwiftUI

/// Fresh split-view column sizing each app launch (macOS otherwise restores last drag-resized widths).
enum NavigationSplitViewSession {
    static let launchInstanceID = UUID()
}

extension View {
    func resetsNavigationSplitColumnsOnLaunch() -> some View {
        id(NavigationSplitViewSession.launchInstanceID)
    }
}
