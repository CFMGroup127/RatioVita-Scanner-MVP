//
//  RatioVitaAppDelegate.swift
//  RatioVita
//

import Foundation
#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

#if os(macOS)
final class RatioVitaAppDelegate: NSObject, NSApplicationDelegate {
    private static let firebaseOrdering: Void = {
        SystemIndexingDonationGuard.applyDevelopmentBypassIfNeeded()
        RatioVitaFirebaseBootstrap.ensureConfigured()
    }()

    override init() {
        super.init()
        _ = Self.firebaseOrdering
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        RatioVitaFirebaseBootstrap.ensureConfigured()
    }
}
#elseif canImport(UIKit)
final class RatioVitaAppDelegate: NSObject, UIApplicationDelegate {
    private static let firebaseOrdering: Void = {
        SystemIndexingDonationGuard.applyDevelopmentBypassIfNeeded()
        RatioVitaFirebaseBootstrap.ensureConfigured()
    }()

    override init() {
        super.init()
        _ = Self.firebaseOrdering
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        RatioVitaFirebaseBootstrap.ensureConfigured()
        return true
    }
}
#endif
