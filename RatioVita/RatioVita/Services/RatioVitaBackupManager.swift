//
//  RatioVitaBackupManager.swift
//  RatioVita
//
//  Local `.rvvault` snapshots (cleartext ZIP) for Files-app safety and cross-device transport.
//

import Foundation
import SwiftData

#if canImport(UIKit)
import UIKit
#endif

enum RatioVitaBackupManager {
    static let vaultAppFolderName = "RatioVita"
    static let localBackupsFolderName = "Backups"
    static let packageExtension = "rvvault"

    private static let lastAutoArchiveKey = "com.ratiovita.backup.lastAutoArchive"
    private static let lastLocalArchivePathKey = "com.ratiovita.backup.lastLocalArchivePath"
    private static let autoArchiveInterval: TimeInterval = 24 * 60 * 60

    enum BackupError: Error, LocalizedError {
        case missingStoreURL
        case copyFailed(String)
        case couldNotCreateDirectory

        var errorDescription: String? {
            switch self {
                case .missingStoreURL: "Could not locate the SwiftData store URL."
                case let .copyFailed(msg): msg
                case .couldNotCreateDirectory: "Could not create the backup folder."
            }
        }
    }

    @MainActor
    static func deviceIdentifier() -> String {
        #if canImport(UIKit)
        UIDevice.current.identifierForVendor?.uuidString ?? "ios-unknown"
        #elseif os(macOS)
        Host.current().localizedName ?? "mac-unknown"
        #else
        "unknown-device"
        #endif
    }

    @MainActor
    static func deviceDisplayName() -> String {
        #if canImport(UIKit)
        UIDevice.current.name
        #elseif os(macOS)
        Host.current().localizedName ?? "Mac"
        #else
        "Device"
        #endif
    }

    /// Application Documents → `RatioVita/Backups/` (visible in Files when sharing is enabled).
    static func localBackupsDirectory() throws -> URL {
        try ensureDirectory(
            appDocumentsDirectory()
                .appendingPathComponent(vaultAppFolderName, isDirectory: true)
                .appendingPathComponent(localBackupsFolderName, isDirectory: true)
        )
    }

    static func appDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Builds a timestamped `.rvvault` in a temp file (caller moves or shares).
    @MainActor
    static func makeVaultPackage(modelContext: ModelContext) throws -> (url: URL, header: RatioVitaArchivePackage) {
        try ModelContextMainActorSave.saveThrows(modelContext)

        guard let storeURL = modelContext.container.configurations.first?.url else {
            throw BackupError.missingStoreURL
        }

        let fm = FileManager.default
        let workRoot = fm.temporaryDirectory.appendingPathComponent(
            "RatioVitaVault-\(UUID().uuidString)",
            isDirectory: true
        )
        try fm.createDirectory(at: workRoot, withIntermediateDirectories: true)

        let bundleRoot = workRoot.appendingPathComponent("bundle", isDirectory: true)
        let storeDir = bundleRoot.appendingPathComponent("swiftdata_store", isDirectory: true)
        let imagesDir = bundleRoot.appendingPathComponent("receipt_images", isDirectory: true)
        try fm.createDirectory(at: storeDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: imagesDir, withIntermediateDirectories: true)

        let copiedNames = try copySwiftDataStoreBundle(from: storeURL, toDirectory: storeDir)

        let images = try modelContext.fetch(FetchDescriptor<ReceiptImage>())
        for img in images {
            let name = "\(img.id.uuidString.lowercased()).jpg"
            try img.imageData.write(to: imagesDir.appendingPathComponent(name), options: .atomic)
        }

        let receipts = try modelContext.fetch(FetchDescriptor<Receipt>())
        let header = RatioVitaArchivePackage(
            timestamp: Date(),
            deviceIdentifier: deviceIdentifier(),
            deviceName: deviceDisplayName(),
            schemaVersion: LibrarySwiftDataSchema.schemaFingerprint,
            receiptCount: receipts.count,
            receiptImageCount: images.count,
            appMarketingVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        )
        let headerData = try JSONEncoder().encode(header)
        try headerData.write(
            to: bundleRoot.appendingPathComponent(RatioVitaArchivePackage.headerFileName),
            options: .atomic
        )

        let legacyManifest = SovereignMasterBackupService.Manifest(
            createdAt: header.timestamp,
            appMarketingVersion: header.appMarketingVersion,
            receiptCount: header.receiptCount,
            receiptImageCount: header.receiptImageCount,
            storeFileNames: copiedNames
        )
        try JSONEncoder().encode(legacyManifest).write(
            to: bundleRoot.appendingPathComponent("manifest.json"),
            options: .atomic
        )

        let clearZip = workRoot.appendingPathComponent("cleartext.zip")
        try ZipStoreWriter.zipDirectoryContents(rootDirectory: bundleRoot, destinationURL: clearZip)
        let zipData = try Data(contentsOf: clearZip)

        let stamp = ISO8601DateFormatter().string(from: header.timestamp).replacingOccurrences(of: ":", with: "-")
        let outName = "RatioVita_\(stamp).\(packageExtension)"
        let outURL = fm.temporaryDirectory.appendingPathComponent(outName)
        if fm.fileExists(atPath: outURL.path) {
            try fm.removeItem(at: outURL)
        }
        try zipData.write(to: outURL, options: .atomic)
        try? fm.removeItem(at: workRoot)

        return (outURL, header)
    }

    /// Copies a vault package into local `Backups/` and prunes old copies.
    @MainActor
    @discardableResult
    static func installToLocalBackups(packageURL: URL) throws -> URL {
        let destDir = try localBackupsDirectory()
        let dest = destDir.appendingPathComponent(packageURL.lastPathComponent)
        let fm = FileManager.default
        if fm.fileExists(atPath: dest.path) {
            try fm.removeItem(at: dest)
        }
        try fm.copyItem(at: packageURL, to: dest)
        UserDefaults.standard.set(dest.path, forKey: lastLocalArchivePathKey)
        pruneLocalBackups(keepingNewest: 12, in: destDir)
        return dest
    }

    /// Runs at most once per 24 hours on launch.
    @MainActor
    static func runScheduledAutoArchiveIfNeeded(modelContext: ModelContext) {
        let last = UserDefaults.standard.object(forKey: lastAutoArchiveKey) as? Date ?? .distantPast
        guard Date().timeIntervalSince(last) >= autoArchiveInterval else { return }
        do {
            let built = try makeVaultPackage(modelContext: modelContext)
            _ = try installToLocalBackups(packageURL: built.url)
            UserDefaults.standard.set(Date(), forKey: lastAutoArchiveKey)
            try? FileManager.default.removeItem(at: built.url)
        } catch {
            #if DEBUG
            print("RatioVita: scheduled auto-archive failed: \(error.localizedDescription)")
            #endif
        }
    }

    /// After bulk import / significant writes — throttled to once per hour.
    @MainActor
    static func archiveAfterSignificantWrite(modelContext: ModelContext) {
        let key = "com.ratiovita.backup.lastSignificantWriteArchive"
        let last = UserDefaults.standard.object(forKey: key) as? Date ?? .distantPast
        guard Date().timeIntervalSince(last) >= 3600 else { return }
        do {
            let built = try makeVaultPackage(modelContext: modelContext)
            _ = try installToLocalBackups(packageURL: built.url)
            UserDefaults.standard.set(Date(), forKey: key)
            try? FileManager.default.removeItem(at: built.url)
        } catch {
            #if DEBUG
            print("RatioVita: post-write archive failed: \(error.localizedDescription)")
            #endif
        }
    }

    @MainActor
    static func lastLocalBackupURL() -> URL? {
        guard let path = UserDefaults.standard.string(forKey: lastLocalArchivePathKey) else { return nil }
        let url = URL(fileURLWithPath: path)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    // MARK: - Private

    private static func ensureDirectory(_ url: URL) throws -> URL {
        let fm = FileManager.default
        if !fm.fileExists(atPath: url.path) {
            do {
                try fm.createDirectory(at: url, withIntermediateDirectories: true)
            } catch {
                throw BackupError.couldNotCreateDirectory
            }
        }
        return url
    }

    private static func pruneLocalBackups(keepingNewest maxCount: Int, in directory: URL) {
        let fm = FileManager.default
        guard let urls = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey]) else {
            return
        }
        let vaults = urls.filter { $0.pathExtension.lowercased() == packageExtension }
        guard vaults.count > maxCount else { return }
        let sorted = vaults.sorted { lhs, rhs in
            let l = (try? lhs.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            let r = (try? rhs.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            return l > r
        }
        for old in sorted.dropFirst(maxCount) {
            try? fm.removeItem(at: old)
        }
    }

    private static func copySwiftDataStoreBundle(from storeURL: URL, toDirectory destDir: URL) throws -> [String] {
        let fm = FileManager.default
        let parent = storeURL.deletingLastPathComponent()
        let base = storeURL.lastPathComponent
        let siblings = (try? fm.contentsOfDirectory(at: parent, includingPropertiesForKeys: nil)) ?? []
        var copied: [String] = []
        for url in siblings {
            let name = url.lastPathComponent
            guard name == base || name.hasPrefix(base + "-") || name.hasPrefix(base + ".") else { continue }
            let dest = destDir.appendingPathComponent(name)
            if fm.fileExists(atPath: dest.path) {
                try fm.removeItem(at: dest)
            }
            do {
                try fm.copyItem(at: url, to: dest)
                copied.append(name)
            } catch {
                throw BackupError.copyFailed("Could not copy \(name): \(error.localizedDescription)")
            }
        }
        guard !copied.isEmpty else {
            throw BackupError.copyFailed("No store files found next to \(storeURL.path).")
        }
        return copied.sorted()
    }
}
