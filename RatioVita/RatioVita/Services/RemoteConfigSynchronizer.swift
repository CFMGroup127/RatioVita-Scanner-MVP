import Combine
import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

/// Silent background sync of runtime flags from cloud vault or optional HTTPS URL.
@MainActor
final class RemoteConfigSynchronizer: ObservableObject {
    static let shared = RemoteConfigSynchronizer()

    @Published private(set) var activeConfig: RuntimeRemoteConfig = .defaults
    @Published private(set) var lastSyncedAt: Date?
    @Published private(set) var lastSyncMessage: String?

    func noteSyncMessage(_ message: String) {
        lastSyncMessage = message
    }

    private var foregroundObserver: NSObjectProtocol?

    private init() {
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.syncIfNeeded(trigger: "foreground")
            }
        }
    }

    deinit {
        if let foregroundObserver {
            NotificationCenter.default.removeObserver(foregroundObserver)
        }
    }

    private var willEnterForegroundNotification: Notification.Name {
        #if canImport(UIKit)
        UIApplication.willEnterForegroundNotification
        #else
        NSApplication.willBecomeActiveNotification
        #endif
    }

    func syncIfNeeded(trigger: String) async {
        do {
            let fetched = try Self.loadConfigFromDisk()
            if fetched != activeConfig {
                apply(config: fetched)
                lastSyncMessage = "Runtime updated (\(trigger))."
            } else {
                lastSyncMessage = "Runtime already current."
            }
            lastSyncedAt = .now
        } catch {
            lastSyncMessage = "Sync skipped: \(error.localizedDescription)"
        }
    }

    func apply(config: RuntimeRemoteConfig) {
        activeConfig = config
        if let flags = config.featureFlags {
            for (key, value) in flags {
                UserDefaults.standard.set(value, forKey: key)
            }
        }
        if let petty = config.pettyCashAutoApproveCAD {
            UserDefaults.standard.set(petty, forKey: RuntimeConfigKeys.pettyCashOverrideKey)
        }
    }

    /// In-house publish: writes manifest beside cloud vault for crew devices to pull.
    func publishToCloudVault(_ config: RuntimeRemoteConfig) throws -> URL {
        let data = try JSONEncoder.pretty.encode(config)
        let dir = try VaultImportExportService.ensureCloudVaultDirectory()
        let url = dir.appendingPathComponent(RuntimeRemoteConfig.fileName)
        try data.write(to: url, options: .atomic)
        activeConfig = config
        lastSyncedAt = .now
        lastSyncMessage = "Published to \(VaultImportExportService.cloudVaultDisplayPath())."
        return url
    }

    private static func loadConfigFromDisk() throws -> RuntimeRemoteConfig {
        if let custom = customConfigURL(),
           FileManager.default.fileExists(atPath: custom.path)
        {
            return try decodeFile(at: custom)
        }
        let cloudURL = VaultImportExportService.cloudVaultRootURL()
            .appendingPathComponent(RuntimeRemoteConfig.fileName)
        if FileManager.default.fileExists(atPath: cloudURL.path) {
            return try decodeFile(at: cloudURL)
        }
        if let bundled = Bundle.main.url(forResource: "ratiovita_runtime_flags", withExtension: "json") {
            return try decodeFile(at: bundled)
        }
        return .defaults
    }

    private static func customConfigURL() -> URL? {
        guard let raw = UserDefaults.standard.string(forKey: RuntimeConfigKeys.remoteConfigURLKey),
              let url = URL(string: raw) else { return nil }
        return url
    }

    private static func decodeFile(at url: URL) throws -> RuntimeRemoteConfig {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(RuntimeRemoteConfig.self, from: data)
    }
}

enum RuntimeConfigKeys {
    static let remoteConfigURLKey = "com.ratiovita.remoteConfigURL"
    static let pettyCashOverrideKey = "com.ratiovita.runtime.pettyCashAutoApproveCAD"
}

extension JSONEncoder {
    fileprivate static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
