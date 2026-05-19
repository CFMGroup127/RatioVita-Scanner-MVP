import SwiftUI

/// 873 position menu with **Other** → free-text custom title.
struct IATSE873OccupationPicker: View {
    @Binding var occupationTitle: String?

    @State private var pickerChoice: String = IATSE873PositionCatalog.standardTitles.first ?? ""
    @State private var customTitle: String = ""

    var body: some View {
        Picker("Occupation (873)", selection: $pickerChoice) {
            ForEach(IATSE873PositionCatalog.pickerOptions, id: \.self) { title in
                Text(title).tag(title)
            }
        }
        .onAppear { syncFromBinding() }
        .onChange(of: pickerChoice) { _, _ in commit() }
        if pickerChoice == IATSE873PositionCatalog.otherTitle {
            TextField("Custom classification", text: $customTitle)
                .onSubmit { commit() }
                .onChange(of: customTitle) { _, _ in commit() }
        }
    }

    private func syncFromBinding() {
        let raw = occupationTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if raw.isEmpty {
            pickerChoice = IATSE873PositionCatalog.standardTitles.first ?? IATSE873PositionCatalog.otherTitle
            customTitle = ""
            return
        }
        if IATSE873PositionCatalog.standardTitles.contains(raw) {
            pickerChoice = raw
            customTitle = ""
        } else {
            pickerChoice = IATSE873PositionCatalog.otherTitle
            customTitle = raw
        }
    }

    private func commit() {
        if pickerChoice == IATSE873PositionCatalog.otherTitle {
            let t = customTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            occupationTitle = t.isEmpty ? nil : t
        } else {
            occupationTitle = pickerChoice
        }
    }
}
