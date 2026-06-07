//
//  VaultImportExportService.swift
//  RatioVita
//
//  Cross-device `.rvvault` transport via iCloud Drive (when available) or local Documents vault.
//

import Foundation
import SwiftData

enum VaultImportExportService {
    static let cloudVaultFolderName = "RatioVita_Vault"
    private static let lastPulledArchiveKey = "com.ratiovita.vault.lastPulledArchiveTimestamp"

    enum VaultError: Error, LocalizedError {
        case iCloudUnavailable
        case noCloudSnapshot
        case invalidPackage
        case unpackFailed(String)

        var errorDescription: String? {
            switch self {
                case .iCloudUnavailable:
                    "iCloud Drive container is not available. Use a paid Apple Developer iCloud Documents capability, or copy `.rvvault` files manually via Files."
                case .noCloudSnapshot: "No `.rvvault` snapshot found in the cloud vault folder."
                case .invalidPackage: "The vault package is missing a valid header."
                case let .unpackFailed(msg): msg
            }
        }
    }

    enum PullResolution {
        case mergeMissingRecords
        case replaceLocalLibrary
    }

    struct CloudSnapshotInfo: Sendable {
        var url: URL
        var header: RatioVitaArchivePackage
        var isFromOtherDevice: Bool
        var isNewerThanLastPull: Bool
    }

    /// `iCloud Drive/…/Documents/RatioVita_Vault` when ubiquity is enabled; otherwise local Documents mirror.
    static func cloudVaultRootURL() -> URL {
        if let ubiquity = FileManager.default.url(forUbiquityContainerIdentifier: nil) {
            return ubiquity
                .appendingPathComponent("Documents", isDirectory: true)
                .appendingPathComponent(cloudVaultFolderName, isDirectory: true)
        }
        return RatioVitaBackupManager.appDocumentsDirectory()
            .appendingPathComponent(cloudVaultFolderName, isDirectory: true)
    }

    static func isICloudDriveContainerAvailable() -> Bool {
        FileManager.default.url(forUbiquityContainerIdentifier: nil) != nil
    }

    static func cloudVaultDisplayPath() -> String {
        if isICloudDriveContainerAvailable() {
            return "iCloud Drive/\(cloudVaultFolderName)"
        }
        return "On My Device/RatioVita/\(cloudVaultFolderName)"
    }

    @MainActor
    static func ensureCloudVaultDirectory() throws -> URL {
        let url = cloudVaultRootURL()
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Writes the newest snapshot into the cloud vault folder (filename includes timestamp).
    @MainActor
    static func pushSnapshotToCloudVault(modelContext: ModelContext) throws -> URL {
        let vaultDir = try ensureCloudVaultDirectory()
        let built = try RatioVitaBackupManager.makeVaultPackage(modelContext: modelContext)
        defer { try? FileManager.default.removeItem(at: built.url) }

        let dest = vaultDir.appendingPathComponent(built.url.lastPathComponent)
        let fm = FileManager.default
        if fm.fileExists(atPath: dest.path) {
            try fm.removeItem(at: dest)
        }
        try fm.copyItem(at: built.url, to: dest)
        _ = try? RatioVitaBackupManager.installToLocalBackups(packageURL: dest)
        return dest
    }

    @MainActor
    static func newestCloudSnapshot(localDeviceID: String) -> CloudSnapshotInfo? {
        guard let url = try? ensureCloudVaultDirectory() else { return nil }
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) else { return nil }
        let packages = files.filter { $0.pathExtension.lowercased() == RatioVitaBackupManager.packageExtension }
        guard !packages.isEmpty else { return nil }

        var best: (url: URL, header: RatioVitaArchivePackage)?
        for file in packages {
            guard let header = try? readHeader(fromVaultPackage: file) else { continue }
            if let current = best {
                if header.timestamp > current.header.timestamp {
                    best = (file, header)
                }
            } else {
                best = (file, header)
            }
        }
        guard let best else { return nil }

        let lastPull = UserDefaults.standard.object(forKey: lastPulledArchiveKey) as? Date ?? .distantPast
        return CloudSnapshotInfo(
            url: best.url,
            header: best.header,
            isFromOtherDevice: best.header.deviceIdentifier != localDeviceID,
            isNewerThanLastPull: best.header.timestamp > lastPull
        )
    }

    @MainActor
    static func pullSnapshotFromCloudVault(
        modelContext: ModelContext,
        snapshot: CloudSnapshotInfo,
        resolution: PullResolution
    ) throws -> SovereignMasterRestoreService.Summary {
        switch resolution {
            case .mergeMissingRecords:
                let summary = try RatioVitaVaultMergeService.mergeVaultPackage(
                    fileURL: snapshot.url,
                    into: modelContext
                )
                UserDefaults.standard.set(snapshot.header.timestamp, forKey: lastPulledArchiveKey)
                return summary
            case .replaceLocalLibrary:
                let safety = try RatioVitaBackupManager.makeVaultPackage(modelContext: modelContext)
                _ = try RatioVitaBackupManager.installToLocalBackups(packageURL: safety.url)
                try? FileManager.default.removeItem(at: safety.url)

                try LibraryDeveloperReset.purgeEntirePersistentLibrary(modelContext: modelContext)
                let summary = try RatioVitaVaultMergeService.mergeVaultPackage(
                    fileURL: snapshot.url,
                    into: modelContext
                )
                UserDefaults.standard.set(snapshot.header.timestamp, forKey: lastPulledArchiveKey)
                return summary
        }
    }

    static func readHeader(fromVaultPackage packageURL: URL) throws -> RatioVitaArchivePackage {
        let data = try Data(contentsOf: packageURL)
        let work = FileManager.default.temporaryDirectory.appendingPathComponent(
            "RatioVitaHeader-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: work) }
        try ZipStoreReader.unzip(data: data, to: work)
        let headerURL = work.appendingPathComponent(RatioVitaArchivePackage.headerFileName)
        guard FileManager.default.fileExists(atPath: headerURL.path) else {
            throw VaultError.invalidPackage
        }
        return try JSONDecoder().decode(RatioVitaArchivePackage.self, from: Data(contentsOf: headerURL))
    }
}
