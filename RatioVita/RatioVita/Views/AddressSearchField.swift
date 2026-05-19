import Combine
import Contacts
import MapKit
import SwiftUI

/// MapKit-powered address suggestions; selecting a row fills the bound address string.
struct AddressSearchField: View {
    @Binding var address: String
    var placeholder: String = "Business address"

    @StateObject private var completer = AddressSearchCompleterModel()
    @State private var showSuggestions = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField(placeholder, text: $address, axis: .vertical)
                .lineLimit(2...5)
                .onChange(of: address) { _, new in
                    completer.queryFragment = new
                    showSuggestions = !new.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }
            if showSuggestions, !completer.results.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(completer.results.prefix(6), id: \.self) { completion in
                        Button {
                            Task {
                                if let resolved = await completer.resolve(completion) {
                                    address = resolved
                                } else {
                                    address = completion.title + ", " + completion.subtitle
                                }
                                showSuggestions = false
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(completion.title)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                if !completion.subtitle.isEmpty {
                                    Text(completion.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 10)
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.ratioVitaAdaptiveSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.ratioVitaAdaptiveBorder.opacity(0.4), lineWidth: 1)
                )
            }
        }
    }
}

@MainActor
private final class AddressSearchCompleterModel: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var results: [MKLocalSearchCompletion] = []
    private let completer = MKLocalSearchCompleter()

    var queryFragment: String = "" {
        didSet {
            completer.queryFragment = queryFragment
        }
    }

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in
            results = completer.results
        }
    }

    nonisolated func completer(_: MKLocalSearchCompleter, didFailWithError _: Error) {
        Task { @MainActor in
            results = []
        }
    }

    func resolve(_ completion: MKLocalSearchCompletion) async -> String? {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        let fallback = [completion.title, completion.subtitle]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        guard let response = try? await search.start(),
              let item = response.mapItems.first else
        {
            return fallback.isEmpty ? nil : fallback
        }
        let pm = item.placemark
        let postal = CNMutablePostalAddress()
        let streetParts = [pm.subThoroughfare, pm.thoroughfare].compactMap { $0 }
        if !streetParts.isEmpty {
            postal.street = streetParts.joined(separator: " ")
        }
        postal.city = pm.locality ?? ""
        postal.state = pm.administrativeArea ?? ""
        postal.postalCode = pm.postalCode ?? ""
        postal.country = pm.country ?? ""
        let formatted = CNPostalAddressFormatter.string(from: postal, style: .mailingAddress)
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        if !formatted.isEmpty { return formatted }
        let named = [item.name, pm.title].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
        return named.isEmpty ? fallback : named
    }
}

/// Saved addresses from registry entities for 1-tap fill.
struct LocationVaultAddressPicker: View {
    let savedAddresses: [String]
    @Binding var address: String

    var body: some View {
        if !savedAddresses.isEmpty {
            Section("Location vault") {
                ForEach(savedAddresses, id: \.self) { addr in
                    Button(addr) {
                        address = addr
                    }
                    .font(.caption)
                }
            }
        }
    }
}
