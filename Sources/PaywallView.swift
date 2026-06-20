import SwiftUI
import StoreKit

/// Upgrade screen for the one-time "Leafmark Pro" purchase (ADR-0005).
/// Sells ownership, not a subscription: "Your highlights are yours."
struct PaywallView: View {
    @ObservedObject var store: StoreManager
    @Environment(\.dismiss) private var dismiss

    private let perks: [(icon: String, title: String, detail: String)] = [
        ("highlighter", "Unlimited highlights", "Mark up every page, in any of four colors."),
        ("square.and.arrow.up", "Export to Markdown", "Send your highlights and notes to Obsidian or Notion."),
        ("chart.bar", "Reading statistics", "Track your time, streak and progress per book."),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.tint)
                        Text("Leafmark Pro")
                            .font(.largeTitle.bold())
                        Text("Your highlights are yours.")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 24)

                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(perks, id: \.title) { perk in
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: perk.icon)
                                    .font(.title3)
                                    .foregroundStyle(.tint)
                                    .frame(width: 30)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(perk.title).font(.body.weight(.semibold))
                                    Text(perk.detail)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 4)

                    VStack(spacing: 12) {
                        Button {
                            Task {
                                if await store.purchase() { dismiss() }
                            }
                        } label: {
                            Group {
                                if store.purchaseInFlight {
                                    ProgressView()
                                } else if let product = store.product {
                                    Text("Unlock for \(product.displayPrice)")
                                } else {
                                    Text("Unlock")
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(store.product == nil || store.purchaseInFlight)

                        Text("One-time purchase. No subscription.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Button("Restore Purchase") {
                            Task {
                                await store.restore()
                                if store.isPro { dismiss() }
                            }
                        }
                        .font(.footnote)
                    }
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onChange(of: store.isPro) { _, isPro in
                if isPro { dismiss() }
            }
        }
    }
}
