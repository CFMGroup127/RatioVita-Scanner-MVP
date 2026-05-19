import SwiftData
import SwiftUI

/// Photos-style **year → month → day** drill-down over the filed receipt library (Arctic / Fort Knox).
/// Lives inside the main library `NavigationStack`: uses a custom back affordance while zoomed in so the system
/// back button still exits the archive from the **years** level.
struct ReceiptsArcticZoomView: View {
    @Environment(\.brandAccent) private var brandAccent

    @Query(
        filter: #Predicate<Receipt> { !$0.pendingHumanReview && $0.trashedAt == nil },
        sort: \Receipt.createdAt,
        order: .reverse
    )
    private var receipts: [Receipt]

    private let calendar = Calendar.current

    @State private var level: Level = .years
    @State private var focusedYear = Calendar.current.component(.year, from: Date())
    @State private var focusedMonth = Calendar.current.component(.month, from: Date())
    @State private var pinchVisualScale: CGFloat = 1

    private enum Level {
        case years
        case months
        case days
    }

    var body: some View {
        ZStack {
            Color.ratioVitaAdaptiveBackground.ignoresSafeArea()
            content
                .scaleEffect(pinchVisualScale)
                .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.82), value: pinchVisualScale)
                .animation(.snappy(duration: 0.32), value: level)
        }
        .navigationTitle(navTitle)
        #if os(iOS) || os(visionOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .navigationBarBackButtonHidden(level != .years)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    if level != .years {
                        Button {
                            popLevel()
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                        .accessibilityLabel("Zoom out one level")
                    }
                }
            }
            .onAppear {
                syncFocusFromLibrary()
            }
        #if os(iOS) || os(visionOS)
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { value in
                        pinchVisualScale = min(max(value.magnification, 0.92), 1.22)
                    }
                    .onEnded { value in
                        let m = value.magnification
                        if m > 1.18 {
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                                pinchVisualScale = 1
                                pinchZoomIn()
                            }
                        } else if m < 0.82 {
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                                pinchVisualScale = 1
                                pinchZoomOut()
                            }
                        } else {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                                pinchVisualScale = 1
                            }
                        }
                    }
            )
        #endif
    }

    private var navTitle: String {
        switch level {
            case .years:
                "Arctic archive"
            case .months:
                "\(focusedYear)"
            case .days:
                monthChrome
        }
    }

    private var monthChrome: String {
        let c = DateComponents(year: focusedYear, month: focusedMonth, day: 1)
        guard let d = calendar.date(from: c) else { return "\(focusedYear)" }
        return d.formatted(.dateTime.month(.wide).year())
    }

    @ViewBuilder
    private var content: some View {
        if receipts.isEmpty {
            ContentUnavailableView(
                "No receipts",
                systemImage: "doc.text",
                description: Text("File receipts in the library to browse them by year here.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            switch level {
                case .years:
                    yearsCanvas
                case .months:
                    monthsCanvas
                case .days:
                    daysCanvas
            }
        }
    }

    private struct YearSummary: Identifiable {
        var id: Int { year }
        let year: Int
        let count: Int
    }

    private var yearSummaries: [YearSummary] {
        let grouped = Dictionary(grouping: receipts) { calendar.component(
            .year,
            from: $0.transactionDate ?? $0.createdAt
        ) }
        return grouped.keys.sorted(by: >).map { y in
            YearSummary(year: y, count: grouped[y]?.count ?? 0)
        }
    }

    private var yearsCanvas: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), spacing: 12)], spacing: 12) {
                ForEach(yearSummaries) { item in
                    Button {
                        focusedYear = item.year
                        focusedMonth = defaultMonth(for: item.year)
                        withAnimation(.snappy(duration: 0.32)) {
                            level = .months
                        }
                    } label: {
                        yearTile(item)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }

    private func yearTile(_ item: YearSummary) -> some View {
        VStack(spacing: 8) {
            Text(String(item.year))
                .font(.title.weight(.bold))
                .foregroundStyle(Color.ratioVitaAdaptiveText)
            Text("\(item.count) receipt\(item.count == 1 ? "" : "s")")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(Color.ratioVitaTextSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.ratioVitaAdaptiveSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.ratioVitaAdaptiveBorder.opacity(0.4), lineWidth: 1)
        )
    }

    private var monthsCanvas: some View {
        let months = monthsWithData(for: focusedYear)
        return Group {
            if months.isEmpty {
                ContentUnavailableView(
                    "No activity",
                    systemImage: "calendar",
                    description: Text("No receipts dated in \(focusedYear). Zoom out or pick another year.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 10) {
                        ForEach(months, id: \.self) { m in
                            Button {
                                focusedMonth = m
                                withAnimation(.snappy(duration: 0.28)) {
                                    level = .days
                                }
                            } label: {
                                monthTile(m)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
        }
    }

    private func monthsWithData(for year: Int) -> [Int] {
        let ms = Set(receipts.compactMap { r -> Int? in
            let d = r.transactionDate ?? r.createdAt
            guard calendar.component(.year, from: d) == year else { return nil }
            return calendar.component(.month, from: d)
        })
        return ms.sorted()
    }

    private func monthTile(_ month: Int) -> some View {
        let comps = DateComponents(year: focusedYear, month: month, day: 1)
        let title: String = {
            guard let d = calendar.date(from: comps) else { return "\(month)" }
            return d.formatted(.dateTime.month(.abbreviated))
        }()
        let count = receipts.filter { r in
            let d = r.transactionDate ?? r.createdAt
            return calendar.component(.year, from: d) == focusedYear && calendar.component(.month, from: d) == month
        }.count
        return VStack(spacing: 6) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.ratioVitaAdaptiveText)
            Text("\(count)")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(Color.ratioVitaTextSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.ratioVitaAdaptiveSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.ratioVitaAdaptiveBorder.opacity(0.35), lineWidth: 1)
        )
    }

    private var daysCanvas: some View {
        let items = receipts.filter { r in
            let d = r.transactionDate ?? r.createdAt
            return calendar.component(.year, from: d) == focusedYear && calendar
                .component(.month, from: d) == focusedMonth
        }
        .sorted {
            ($0.transactionDate ?? $0.createdAt) > ($1.transactionDate ?? $1.createdAt)
        }

        return Group {
            if items.isEmpty {
                ContentUnavailableView(
                    "No receipts",
                    systemImage: "calendar.day.timeline.left",
                    description: Text("Nothing dated in \(monthChrome).")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 8)], spacing: 10) {
                        ForEach(items) { receipt in
                            NavigationLink {
                                ReceiptDetailPlatformView(receipt: receipt)
                            } label: {
                                ArcticReceiptThumbCell(receipt: receipt, accent: brandAccent)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
        }
    }

    private func pinchZoomIn() {
        switch level {
            case .years:
                syncFocusFromLibrary()
                focusedMonth = defaultMonth(for: focusedYear)
                withAnimation(.snappy(duration: 0.32)) {
                    level = .months
                }
            case .months:
                let months = monthsWithData(for: focusedYear)
                if !months.contains(focusedMonth) {
                    focusedMonth = months.first ?? 1
                }
                withAnimation(.snappy(duration: 0.32)) {
                    level = .days
                }
            case .days:
                break
        }
    }

    private func pinchZoomOut() {
        switch level {
            case .years:
                break
            case .months:
                withAnimation(.snappy(duration: 0.3)) {
                    level = .years
                }
            case .days:
                withAnimation(.snappy(duration: 0.3)) {
                    level = .months
                }
        }
    }

    private func popLevel() {
        pinchZoomOut()
    }

    private func syncFocusFromLibrary() {
        guard let top = yearSummaries.first?.year else { return }
        if !yearSummaries.contains(where: { $0.year == focusedYear }) {
            focusedYear = top
        }
    }

    private func defaultMonth(for year: Int) -> Int {
        monthsWithData(for: year).first ?? 1
    }
}

// MARK: - 64×64-style cell (Photos density)

private struct ArcticReceiptThumbCell: View {
    let receipt: Receipt
    let accent: Color
    private let side: CGFloat = 64

    var body: some View {
        VStack(spacing: 4) {
            Group {
                if let img = receipt.firstImage {
                    Image(rvImage: img)
                        .resizable()
                        .aspectRatio(1, contentMode: .fill)
                } else {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.ratioVitaAdaptiveBorder.opacity(0.35))
                        .overlay(
                            Image(systemName: "doc.text.image")
                                .font(.caption)
                                .foregroundStyle(Color.ratioVitaTextSecondary)
                        )
                }
            }
            .frame(width: side, height: side)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.ratioVitaAdaptiveBorder.opacity(0.45), lineWidth: 1)
            )

            Text(receipt.merchant)
                .font(.caption2.weight(.medium))
                .foregroundStyle(Color.ratioVitaAdaptiveText)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: side + 10)

            Text(
                CurrencyFormatter.shared.format(receipt.total, currencyCode: receipt.currencyCode)
            )
            .font(.caption2.weight(.semibold))
            .foregroundStyle(accent)
            .monospacedDigit()
            .lineLimit(1)
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        ReceiptsArcticZoomView()
    }
    .modelContainer(SampleData.previewContainer)
}
#endif
