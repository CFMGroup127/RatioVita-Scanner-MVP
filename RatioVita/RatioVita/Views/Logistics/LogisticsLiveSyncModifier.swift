import SwiftUI

/// Keeps Firestore logistical guardian listeners bound to the active production workspace.
struct LogisticsLiveSyncModifier: ViewModifier {
    @AppStorage("forensicActiveProductionID") private var forensicActiveProductionID = ""
    @AppStorage("forensicActiveCallSheetFirestoreID") private var forensicActiveCallSheetFirestoreID = ""

    func body(content: Content) -> some View {
        content
            .onAppear(perform: refreshLiveSync)
            .onChange(of: forensicActiveProductionID) { _, _ in refreshLiveSync() }
            .onChange(of: forensicActiveCallSheetFirestoreID) { _, _ in refreshLiveSync() }
    }

    private func refreshLiveSync() {
        ProductionLogisticsLiveCoordinator.shared.syncActiveProduction(
            productionId: forensicActiveProductionID,
            callSheetId: forensicActiveCallSheetFirestoreID
        )
    }
}

extension View {
    func logisticsLiveSync() -> some View {
        modifier(LogisticsLiveSyncModifier())
    }
}
