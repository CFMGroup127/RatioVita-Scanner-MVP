import Combine
import Contacts
import MapKit
import SwiftUI

/// Multi-suite aware address entry: geolocator fills street/city/province/postal,
/// while the Suite/Unit field stays manual and is never overwritten (Sprint KKKK).
struct StandardizedAddressField: View {
    @Binding var address: StandardizedAddress
    var streetPlaceholder: String = "Street address"

    @StateObject private var completer = StructuredAddressCompleterModel()
    @State private var showSuggestions = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Street address")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                TextField(streetPlaceholder, text: $address.streetAddress)
                    .textFieldStyle(.roundedBorder)
                #if os(iOS)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                #endif
                    .onChange(of: address.streetAddress) { _, new in
                        completer.queryFragment = new
                        showSuggestions = !new.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    }

                if showSuggestions, !completer.results.isEmpty {
                    suggestionList
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Suite / Unit / Office (manual)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                TextField("Suite 248", text: $address.unitSuiteNumber)
                    .textFieldStyle(.roundedBorder)
            }

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("City")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    TextField("Toronto", text: $address.city)
                        .textFieldStyle(.roundedBorder)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Prov.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    TextField("ON", text: $address.province)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 70)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Postal code")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                TextField("M8V 1J3", text: $address.postalCode)
                    .textFieldStyle(.roundedBorder)
                #if os(iOS)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                #endif
            }
        }
    }

    private var suggestionList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(completer.results.prefix(6), id: \.self) { completion in
                Button {
                    applySuggestion(completion)
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

    private func applySuggestion(_ completion: MKLocalSearchCompletion) {
        Task {
            if let resolved = await completer.resolveComponents(completion) {
                // Geolocator owns the structural lines; the manual suite is preserved.
                address.streetAddress = resolved.streetAddress
                address.city = resolved.city
                address.province = resolved.province
                address.postalCode = resolved.postalCode
            }
            showSuggestions = false
        }
    }
}

/// Drop-in wrapper for screens that still persist a single mailing string.
/// Parses on appear (isolating any Suite token) and writes the standardized multi-line string back.
struct StandardizedAddressStringEditor: View {
    @Binding var rawAddress: String
    var streetPlaceholder: String = "Street address"

    @State private var address = StandardizedAddress()
    @State private var didLoad = false

    var body: some View {
        StandardizedAddressField(address: $address, streetPlaceholder: streetPlaceholder)
            .onAppear {
                guard !didLoad else { return }
                address = AddressComponentParser.parse(rawAddress)
                didLoad = true
            }
            .onChange(of: address) { _, new in
                rawAddress = new.multiLineFormatted
            }
    }
}

@MainActor
private final class StructuredAddressCompleterModel: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var results: [MKLocalSearchCompletion] = []
    private let completer = MKLocalSearchCompleter()

    var queryFragment: String = "" {
        didSet { completer.queryFragment = queryFragment }
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

    func resolveComponents(_ completion: MKLocalSearchCompletion) async -> StandardizedAddress? {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        guard let response = try? await search.start(),
              let placemark = response.mapItems.first?.placemark else
        {
            return nil
        }
        let streetParts = [placemark.subThoroughfare, placemark.thoroughfare].compactMap { $0 }
        var resolved = StandardizedAddress()
        resolved.streetAddress = AddressComponentParser.normalizeStreet(streetParts.joined(separator: " "))
        resolved.city = placemark.locality ?? ""
        resolved.province = placemark.administrativeArea ?? ""
        resolved.postalCode = placemark.postalCode ?? ""
        return resolved
    }
}
