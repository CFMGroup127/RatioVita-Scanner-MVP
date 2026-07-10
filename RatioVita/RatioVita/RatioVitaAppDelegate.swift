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

    func applicationWillFinishLaunching(_: Notification) {
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
        _: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        RatioVitaFirebaseBootstrap.ensureConfigured()
        return true
    }
}
#endif
