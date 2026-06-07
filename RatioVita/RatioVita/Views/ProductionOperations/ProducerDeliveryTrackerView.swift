import SwiftData
import SwiftUI

/// Door-to-chair play-by-play for producers / cross-venture orders.
struct ProducerDeliveryTrackerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CrossVentureOrderTicket.updatedAt, order: .reverse) private var tickets: [CrossVentureOrderTicket]

    var body: some View {
        List {
            if tickets.isEmpty {
                ContentUnavailableView(
                    "No active deliveries",
                    systemImage: "shippingbox.fill",
                    description: Text("Create a cross-venture order from Operations hub.")
                )
            }
            ForEach(tickets) { ticket in
                VStack(alignment: .leading, spacing: 10) {
                    Text(ticket.itemDescription)
                        .font(.headline)
                    Text("For: \(ticket.recipientName.isEmpty ? "Producer" : ticket.recipientName)")
                        .font(.caption)
                    Text("Holder: \(ticket.currentHolderLabel)")
                        .font(.subheadline)
                    HStack(spacing: 6) {
                        ForEach(
                            Array(CrossVentureLogisticsEngine.statusSteps(for: ticket).enumerated()),
                            id: \.offset
                        ) { idx, step in
                            Text(step.0)
                                .font(.system(size: 9, weight: .semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(step.1 ? Color.green.opacity(0.2) : Color.secondary.opacity(0.12))
                                .clipShape(Capsule())
                            if idx < CrossVentureLogisticsEngine.statusSteps(for: ticket).count - 1 {
                                Image(systemName: "arrow.right")
                                    .font(.caption2)
                            }
                        }
                    }
                    if ticket.status != .deliveredToChair {
                        Button("Advance custody (sim)") {
                            advance(ticket)
                        }
                        .font(.caption)
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .navigationTitle("Delivery tracker")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Demo Texas ribs order") { seedDemoOrder() }
            }
        }
    }

    private func advance(_ ticket: CrossVentureOrderTicket) {
        let next = AssetChainOfCustodyState(rawValue: min(4, ticket.status.rawValue + 1)) ?? .deliveredToChair
        let holders = ["Kitchen", "Driver Jafar", "2nd Meal truck", "Set PA Sally", "Producer chair"]
        let label = holders[min(holders.count - 1, next.rawValue)]
        try? CrossVentureLogisticsEngine.advance(
            context: modelContext,
            ticket: ticket,
            to: next,
            holderLabel: label
        )
    }

    private func seedDemoOrder() {
        let ticket = CrossVentureOrderTicket(
            itemDescription: "Texas ribs — Guest Texas crew wrap gift",
            sourceEntityID: "176_YONGE",
            currentHolderLabel: "Kitchen expeditor",
            status: .preparedAtKitchen,
            recipientName: "Mario (Producer)"
        )
        modelContext.insert(ticket)
        try? modelContext.save()
    }
}
