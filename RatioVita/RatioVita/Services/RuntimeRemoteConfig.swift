import Foundation

/// Over-the-air manifest (`ratiovita_runtime_flags.json`) — hot-swapped on foreground.
struct RuntimeRemoteConfig: Codable, Sendable, Equatable {
    var schemaVersion: Int
    var deployedAt: String?
    var changelog: String?
    var featureFlags: [String: Bool]?
    var pettyCashAutoApproveCAD: Double?
    var experimentalViewFlags: [String: Bool]?

    static let defaults = RuntimeRemoteConfig(
        schemaVersion: 1,
        deployedAt: nil,
        changelog: nil,
        featureFlags: nil,
        pettyCashAutoApproveCAD: nil,
        experimentalViewFlags: nil
    )

    static let fileName = "ratiovita_runtime_flags.json"
}
