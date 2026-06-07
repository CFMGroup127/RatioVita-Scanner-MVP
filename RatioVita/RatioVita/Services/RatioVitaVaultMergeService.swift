//
//  RatioVitaVaultMergeService.swift
//  RatioVita
//
//  Cleartext `.rvvault` merge (cross-device transport packages).
//

import Foundation
import SwiftData

enum RatioVitaVaultMergeService {
    enum MergeError: Error, LocalizedError {
        case unpackFailed(String)

        var errorDescription: String? {
            switch self {
                case let .unpackFailed(msg): msg
            }
        }
    }

    @MainActor
    static func mergeVaultPackage(fileURL: URL, into modelContext: ModelContext) throws -> SovereignMasterRestoreService
        .Summary
    {
        let data = try Data(contentsOf: fileURL)
        let fm = FileManager.default
        let work = fm.temporaryDirectory.appendingPathComponent(
            "RatioVitaVaultMerge-\(UUID().uuidString)",
            isDirectory: true
        )
        try fm.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: work) }

        do {
            try ZipStoreReader.unzip(data: data, to: work)
        } catch {
            throw MergeError.unpackFailed(error.localizedDescription)
        }

        return try SovereignMasterRestoreService.mergeUnpackedBundle(at: work, into: modelContext)
    }
}
