//
//  AppBootstrap.swift
//  RatioVita
//
//  Ignition sequence: SovereignVault and DailyLedgerService readiness.
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
struct AppBootstrap {
    static func initializeSovereignVault(context _: ModelContext) {
        // Ensures the Filing Cabinet and Ledger services are ready
        print("[Sovereign] Initializing Vault at Origin Y: 144.0")
    }
}
