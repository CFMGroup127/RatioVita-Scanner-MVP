import SwiftData
import SwiftUI

/// Sidebar destination: browse `ProductionContact` rows and open CRM profiles.
enum ProductionContactsFilter {
    static func isExternalContact(_ person: ProductionContact, ownedCorporations: [BusinessEntity]) -> Bool {
        if person.entityClassification.isInternalIdentity { return false }
        let resolved = InternalIdentityRegistry.classify(contact: person, ownedCorporations: ownedCorporations)
        return !resolved.isInternalIdentity
    }
}

struct ProductionContactsLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ProductionContact.name) private var contacts: [ProductionContact]
    @Query(filter: #Predicate<BusinessEntity> { $0.isOwnedCorporation }, sort: \BusinessEntity.legalName)
    private var ownedCorporations: [BusinessEntity]

    private var externalContacts: [ProductionContact] {
        contacts.filter { ProductionContactsFilter.isExternalContact($0, ownedCorporations: ownedCorporations) }
    }

    var body: some View {
        Group {
            if externalContacts.isEmpty {
                ContentUnavailableView(
                    "No contacts yet",
                    systemImage: "person.2",
                    description: Text(
                        "Import Zoho Books contacts (CSV) or Zoho invoice PDFs from the vault inbox. Contacts also appear in Settings."
                    )
                )
            } else {
                List {
                    ForEach(externalContacts, id: \.id) { person in
                        NavigationLink {
                            ProductionContactDetailView(contact: person)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(person.name)
                                    .font(DesignSystem.Typography.bodyEmphasized)
                                if let company = person.companyName, !company.isEmpty {
                                    Text(company)
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundStyle(Color.ratioVitaTextSecondary)
                                }
                                Text("\(person.linkedReceipts.filter { $0.trashedAt == nil }.count) receipts")
                                    .font(DesignSystem.Typography.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Contacts")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .background(Color.ratioVitaAdaptiveBackground.ignoresSafeArea())
            .onAppear {
                InternalIdentityRegistry.syncOwnedEntities(context: modelContext)
            }
    }
}

#Preview {
    NavigationStack {
        ProductionContactsLibraryView()
    }
    .modelContainer(SampleData.previewContainer)
}
