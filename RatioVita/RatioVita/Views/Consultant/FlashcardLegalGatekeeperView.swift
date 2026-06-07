#if os(macOS)
import AppKit
#endif
import SwiftData
import SwiftUI

struct FlashcardLegalGatekeeperView: View {
    @Environment(\.modelContext) private var modelContext
    let profile: ExpertConsultantProfile
    var onComplete: () -> Void

    @State private var termIndex = 0
    @State private var scrolledToBottom = false
    @State private var initials = ""
    @State private var collectedInitials: [Int: String] = [:]
    @State private var exportPath: String?

    private var currentTerm: LegalTermCard {
        LegalShieldGatekeeper.standardTerms[termIndex]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Security gatekeeper")
                .font(.title2.bold())
            Text("Term \(termIndex + 1) of \(LegalShieldGatekeeper.standardTerms.count): \(currentTerm.title)")
                .font(.headline)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(currentTerm.body)
                        .font(.body)
                }
                .padding()
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: ScrollBottomPreferenceKey.self,
                            value: geo.frame(in: .named("legalScroll")).maxY
                        )
                    }
                )
            }
            .coordinateSpace(name: "legalScroll")
            .frame(height: 220)
            .background(Color.ratioVitaAdaptiveSurface.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .onPreferenceChange(ScrollBottomPreferenceKey.self) { maxY in
                if maxY < 280 { scrolledToBottom = true }
            }

            TextField("Initial here", text: $initials)
                .textFieldStyle(.roundedBorder)
                .disabled(!scrolledToBottom)

            Button(advanceTitle) {
                advanceTerm()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!scrolledToBottom || initials.trimmingCharacters(in: .whitespaces).count < 2)
            if let exportPath {
                Text("PDF saved: \(exportPath)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: SafeLayoutBounds.maxWorkspaceContentWidth)
        .onAppear {
            UserFrictionAnalytics.trackViewOpened("FlashcardLegalGatekeeper")
        }
        .onDisappear {
            _ = try? UserFrictionAnalytics.trackViewClosed(
                context: modelContext,
                identifier: "FlashcardLegalGatekeeper",
                unexpectedlyClosed: false,
                anonymousToken: profile.anonymousToken
            )
        }
    }

    private var advanceTitle: String {
        termIndex < LegalShieldGatekeeper.standardTerms.count - 1 ? "Agree & advance" : "Complete legal shield"
    }

    private func advanceTerm() {
        collectedInitials[currentTerm.id] = initials
        initials = ""
        scrolledToBottom = false
        if termIndex < LegalShieldGatekeeper.standardTerms.count - 1 {
            termIndex += 1
        } else {
            try? LegalShieldGatekeeper.completeLegalShield(
                context: modelContext,
                profile: profile,
                initialsPerTerm: collectedInitials
            )
            exportPackageIfPossible()
            onComplete()
        }
    }

    private func exportPackageIfPossible() {
        let locked = ImmutableProfileLock.read(profile: profile)
        do {
            let url = try OnboardingPDFExportEngine.exportConsultantPackage(
                profile: profile,
                lockedFields: locked,
                legalTokenHash: profile.legalTokenHash
            )
            exportPath = url.lastPathComponent
            #if os(macOS)
            NSWorkspace.shared.activateFileViewerSelecting([url])
            #endif
        } catch {
            exportPath = error.localizedDescription
        }
    }
}

private struct ScrollBottomPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
