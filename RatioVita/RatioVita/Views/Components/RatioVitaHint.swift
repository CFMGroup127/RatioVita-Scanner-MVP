import SwiftUI

/// Contextual **?** mentor — hover on macOS, tap on iPhone/iPad.
struct RatioVitaHint: View {
    let term: RatioVitaGlossary.Term

    @State private var showPopover = false

    var body: some View {
        Button {
            showPopover = true
        } label: {
            Image(systemName: "questionmark.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        #if os(macOS)
            .help(term.simpleTip)
        #endif
            .accessibilityLabel("Help: \(term.title)")
            .popover(isPresented: $showPopover, arrowEdge: .top) {
                hintPopoverContent
                    .padding(12)
                    .frame(maxWidth: 280)
            }
    }

    private var hintPopoverContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(term.title)
                .font(.headline)
            Text(term.simpleTip)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            if let more = term.learnMoreNote {
                Text(more)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Inline label + optional glossary hint.
struct RatioVitaLabeledHint: View {
    let title: String
    var term: RatioVitaGlossary.Term?

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
            if let term {
                RatioVitaHint(term: term)
            }
        }
    }
}
