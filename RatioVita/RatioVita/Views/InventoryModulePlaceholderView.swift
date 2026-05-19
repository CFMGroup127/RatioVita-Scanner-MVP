import SwiftUI

/// Placeholder for **Inventory** (device daily rentals → Labor Sentinel “Other rates”).
struct InventoryModulePlaceholderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.brandAccent) private var brandAccent

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Inventory", systemImage: "shippingbox.fill")
            } description: {
                Text(
                    "Track iPads, laptops, and trucks with daily rental rates. Linked gear will auto-fill "
                        + "Sentinel kit lines on crew days in a future update."
                )
            } actions: {
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .tint(brandAccent)
            }
            .navigationTitle("Inventory")
            #if os(iOS) || os(visionOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
}
