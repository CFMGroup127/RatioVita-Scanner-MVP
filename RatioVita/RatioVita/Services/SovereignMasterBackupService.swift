import Foundation
import SwiftData

/// Builds an off-device **Sovereign Master Backup**: SwiftData store bundle + receipt JPEG blobs + manifest,
/// zipped (STORE), then sealed with `SovereignBackupEncryption` (password required).
///
/// Output uses the `.rvsovereign` extension (encrypted envelope around a ZIP). **Restore** is implemented by
/// `SovereignMasterRestoreService.mergeArchive` (merge-by-receipt UUID).
enum SovereignMasterBackupService {
    struct Manifest: Codable {
        var formatVersion: Int = 1
        var createdAt: Date
        var appMarketingVersion: String
        var receiptCount: Int
        var receiptImageCount: Int
        var storeFileNames: [String]
    }

    /// Writes an encrypted backup file into a **new temporary file** (caller shares it, then may delete).
    @MainActor
    static func makeEncryptedBackupFile(modelContext: ModelContext, password: String) throws -> URL {
        guard !password.isEmpty else {
            throw BackupError.emptyPassword
        }
        try modelContext.save()

        guard let storeURL = modelContext.container.configurations.first?.url else {
            throw BackupError.missingStoreURL
        }

        let fm = FileManager.default
        let workRoot = fm.temporaryDirectory.appendingPathComponent(
            "RatioVitaBackup-\(UUID().uuidString)",
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
        let manifest = Manifest(
            createdAt: Date(),
            appMarketingVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            receiptCount: receipts.count,
            receiptImageCount: images.count,
            storeFileNames: copiedNames
        )
        let encManifest = try JSONEncoder().encode(manifest)
        try encManifest.write(to: bundleRoot.appendingPathComponent("manifest.json"), options: .atomic)

        let clearZip = workRoot.appendingPathComponent("cleartext.zip")
        try ZipStoreWriter.zipDirectoryContents(rootDirectory: bundleRoot, destinationURL: clearZip)
        let zipData = try Data(contentsOf: clearZip)
        let sealed = try SovereignBackupEncryption.seal(plaintext: zipData, password: password)

        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let outName = "RatioVitaMaster_\(stamp).rvsovereign"
        let outURL = fm.temporaryDirectory.appendingPathComponent(outName)
        if fm.fileExists(atPath: outURL.path) {
            try fm.removeItem(at: outURL)
        }
        try sealed.write(to: outURL, options: .atomic)

        try? fm.removeItem(at: workRoot)
        return outURL
    }

    enum BackupError: Error, LocalizedError {
        case emptyPassword
        case missingStoreURL
        case copyFailed(String)

        var errorDescription: String? {
            switch self {
                case .emptyPassword: "Choose a non-empty passphrase."
                case .missingStoreURL: "Could not locate the SwiftData store URL."
                case let .copyFailed(msg): msg
            }
        }
    }

    /// Copies the SQLite store and common sidecar files (`-wal`, `-shm`, …) that share the same basename prefix.
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
