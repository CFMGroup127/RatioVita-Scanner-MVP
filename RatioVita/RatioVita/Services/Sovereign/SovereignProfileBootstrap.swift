import CryptoKit
import Foundation
import SwiftData

@MainActor
enum SovereignProfileBootstrap {
    /// Ensures a sovereign profile exists for the master identity — idempotent across devices.
    static func ensureProfile(
        for master: MasterUserIdentity,
        modelContext: ModelContext
    ) throws -> SovereignProfile {
        let masterID = master.id
        let descriptor = FetchDescriptor<SovereignProfile>(
            predicate: #Predicate { $0.masterIdentityID == masterID }
        )
        if let existing = try modelContext.fetch(descriptor).first {
            return existing
        }

        let signingKey = try SovereignProfileSeedStore.loadOrCreateSigningKey()
        let spid = SovereignIdentifierService.userSPID(from: signingKey.publicKey)
        let routingToken = PrivacyShieldEngine.newRoutingProxyToken()

        let profile = SovereignProfile(
            userSPID: spid,
            masterIdentityID: master.id,
            legalName: master.primaryLegalName,
            routingProxyToken: routingToken,
            signingPublicKeyBase64: signingKey.publicKey.rawRepresentation.base64EncodedString()
        )
        modelContext.insert(profile)
        try modelContext.save()
        return profile
    }

    static func fetchPrimaryProfile(modelContext: ModelContext) throws -> SovereignProfile? {
        var descriptor = FetchDescriptor<SovereignProfile>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}
