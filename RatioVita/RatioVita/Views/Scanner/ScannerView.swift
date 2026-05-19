import SwiftUI

struct ScannerView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)

                Text("Receipt Scanner")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Scanner functionality coming soon")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
            .padding(.top, DesignSystem.Layout.topMargin)
            .navigationTitle("Scanner")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    #if os(iOS)
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                    #else
                    ToolbarItem(placement: .primaryAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                    #endif
                }
        }
    }
}

#Preview {
    ScannerView()
}
