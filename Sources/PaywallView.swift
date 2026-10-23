import SwiftUI
import StoreKit

/// Why the paywall is being shown. Drives the subtitle so the user sees the
/// value of Pro in the context of what they just tried to do.
enum PaywallContext: Identifiable {
    case general
    case highlightLimit
    case highlights
    case export
    case exportAll
    case statistics

    var id: Self { self }

    var subtitle: String {
        switch self {
        case .general:
            return "Your highlights are yours."
        case .highlightLimit:
            return "You've used all \(StoreManager.freeHighlightLimit) free highlights in this book."
        case .highlights:
            return "Keep every passage that matters, without a highlight limit."
        case .export:
            return "You've used your free export. Unlock unlimited Markdown export."
        case .exportAll:
            return "Export the highlights of every book at once, one Markdown file per book."
        case .statistics:
            return "Explore your weekly and all-time reading, streaks, and time per book."
        }
    }
}

/// The advance notice of the Leafmark Pro price change (ADR-0008).
///
/// The date lives only here. The notice names no amount because the price
/// differs by storefront currency, and it disappears on the change date in
/// the device's local time zone.
enum PriceChangeNotice {
    /// A Gregorian date. `changeDate(in:)` resolves it, so devices set to the
    /// Japanese or Buddhist calendar still get 2026-11-16.
    static let effectiveDate = DateComponents(year: 2026, month: 11, day: 16)

    /// True strictly before local midnight at the start of `effectiveDate`.
    static func isVisible(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let start = changeDate(in: calendar) else { return false }
        return now < start
    }

    /// Formats the date in the given calendar and locale, so a Japanese
    /// calendar device reads it in its own era.
    static func message(calendar: Calendar = .current, locale: Locale = .current) -> String {
        guard let date = changeDate(in: calendar) else { return "" }
        var style = Date.FormatStyle(date: .long, time: .omitted, locale: locale, calendar: calendar)
        style.timeZone = calendar.timeZone
        return "Price changes on \(date.formatted(style)). If you've already purchased, there's nothing more to pay."
    }

    /// Local midnight at the start of `effectiveDate`: Gregorian fields, read
    /// in the time zone of `calendar`.
    private static func changeDate(in calendar: Calendar) -> Date? {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        return gregorian.date(from: effectiveDate)
    }
}

/// Upgrade screen for the one-time "Leafmark Pro" purchase (ADR-0005).
/// Sells ownership, not a subscription: "Your highlights are yours."
struct PaywallView: View {
    @ObservedObject var store: StoreManager
    var context: PaywallContext = .general
    /// Overrides `context.funnelSource` when one context has several entries.
    var source: PaywallSource?
    /// Injected by tests; the app uses `FunnelAnalytics.shared`.
    var analytics: FunnelAnalytics?

    private var funnelSource: PaywallSource { source ?? context.funnelSource }
    private var funnel: FunnelAnalytics { analytics ?? .shared }

    /// Once per presentation: the paywall pushes no screens of its own.
    func recordShown() {
        funnel.record(.paywallShown(funnelSource))
    }

    /// Records the tap, then buys. Returns true when Pro was unlocked.
    func purchaseTapped() async -> Bool {
        funnel.record(.purchaseTapped(funnelSource))
        return await store.purchase(source: funnelSource)
    }
    @Environment(\.dismiss) private var dismiss

    private let perks: [(icon: String, title: String, detail: String)] = [
        ("highlighter", "Unlimited highlights", "Mark up every page, in any of four colors."),
        ("square.and.arrow.up", "Export to Markdown", "Markdown files with front matter for Obsidian. Export one book, or every book at once."),
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
                        Text(context.subtitle)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
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

                    ReadingNoteExample()

                    VStack(spacing: 12) {
                        if store.productLoadFailed && store.product == nil {
                            Button {
                                Task { await store.load() }
                            } label: {
                                Label("Could not load price. Tap to retry.", systemImage: "arrow.clockwise")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                        } else {
                            Button {
                                Task {
                                    if await purchaseTapped() { dismiss() }
                                }
                            } label: {
                                Group {
                                    if store.purchaseInFlight {
                                        ProgressView()
                                    } else if let product = store.product {
                                        Text("Unlock for \(product.displayPrice)")
                                    } else {
                                        ProgressView()
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .disabled(store.product == nil || store.purchaseInFlight)
                        }

                        Text("One-time purchase. No subscription.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        if PriceChangeNotice.isVisible() {
                            Label(PriceChangeNotice.message(), systemImage: "calendar")
                                .font(.footnote)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                        }

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
        .onAppear(perform: recordShown)
    }
}

/// A labeled example, never presented as the reader's own data.
struct ReadingNoteExample: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your reading notes, ready to keep")
                .font(.headline)
            Text("Example Markdown export")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("---\ntitle: \"A Book I Read\"\nsource: Leafmark\n---\n\n# A Book I Read\n\n> A passage worth remembering.\n\nMy note: Try this idea tomorrow.")
                .font(.body.monospaced())
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Keep quotes and your own notes together in a Markdown file.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .contain)
    }
}
