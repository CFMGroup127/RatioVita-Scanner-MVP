import SwiftUI

struct DecimalOptionalField: View {
    let title: String
    @Binding var value: Decimal?

    @State private var text: String = ""

    var body: some View {
        TextField(title, text: $text)
        #if os(iOS)
            .keyboardType(.decimalPad)
        #endif
            .onAppear { syncFromValue() }
            .onChange(of: value) { _, _ in syncFromValue() }
            .onChange(of: text) { _, _ in commit() }
            .onSubmit { commit() }
    }

    private func syncFromValue() {
        if let v = value {
            text = "\(v)"
        } else {
            text = ""
        }
    }

    private func commit() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            value = nil
        } else {
            value = Decimal(string: trimmed.replacingOccurrences(of: ",", with: "."))
        }
    }
}
