//
//  UserMessageCenter.swift
//  RatioVita
//
//  Phase 1: centralized user-visible alerts (save/scan failures, daily ledger errors).
//

import Combine
import Foundation
import SwiftUI

extension Error {
    /// Human-readable text for alerts (prefers `LocalizedError` description + recovery).
    var ratioVitaUserDescription: String {
        if let le = self as? LocalizedError {
            let parts = [le.errorDescription, le.recoverySuggestion].compactMap { $0 }.filter { !$0.isEmpty }
            if !parts.isEmpty {
                return parts.joined(separator: "\n\n")
            }
        }
        return localizedDescription
    }
}

/// Centralized alerts; `@Published` updates are always delivered on the main queue so Combine never warns when code
/// paths touch persistence completion handlers off the actor.
final class UserMessageCenter: ObservableObject {
    static let shared = UserMessageCenter()

    @Published var isPresented = false
    @Published private(set) var title = ""
    @Published private(set) var message = ""

    private init() {}

    func present(title: String, message: String) {
        let apply = {
            self.title = title
            self.message = message
            self.isPresented = true
        }
        if Thread.isMainThread {
            apply()
        } else {
            DispatchQueue.main.async(execute: apply)
        }
    }

    func dismiss() {
        let apply = { self.isPresented = false }
        if Thread.isMainThread {
            apply()
        } else {
            DispatchQueue.main.async(execute: apply)
        }
    }
}
