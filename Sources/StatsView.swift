import SwiftUI

/// Reading statistics: today / this week / all time, streak and per-book time.
struct StatsView: View {
    @ObservedObject var stats: StatsStore
    @ObservedObject var library: LibraryStore
    @EnvironmentObject private var store: StoreManager
    @Environment(\.dismiss) private var dismiss
    @State private var showPaywall = false

    private var isPro: Bool { store.isPro }

    var body: some View {
        NavigationStack {
            ZStack {
                statsContent
                if !isPro {
                    lockedOverlay
                }
            }
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(store: store, context: .statistics)
            }
        }
    }

    private var statsContent: some View {
        Group {
            if stats.sessions.isEmpty && isPro {
                ContentUnavailableView(
                    "No Reading Yet",
                    systemImage: "chart.bar",
                    description: Text("Statistics appear once you start reading.")
                )
            } else if isPro {
                realStatsContent
            } else {
                sampleStatsContent
                    .blur(radius: 6)
                    .allowsHitTesting(false)
            }
        }
    }

    private var realStatsContent: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    StatCard(title: "Today", value: StatsStore.format(stats.todayTime))
                    StatCard(title: "This Week", value: StatsStore.format(stats.thisWeekTime))
                    StatCard(title: "All Time", value: StatsStore.format(stats.totalTime()))
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            Section {
                HStack {
                    Label("Reading Streak", systemImage: "flame.fill")
                        .foregroundStyle(.orange)
                    Spacer()
                    Text("\(stats.streakDays) day\(stats.streakDays == 1 ? "" : "s")")
                        .fontWeight(.semibold)
                }
            }
            Section("By Book") {
                ForEach(stats.timePerBook(), id: \.bookID) { entry in
                    HStack {
                        Text(bookTitle(entry.bookID))
                            .lineLimit(1)
                        Spacer()
                        Text(StatsStore.format(entry.time))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
        }
    }

    private var sampleStatsContent: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    StatCard(title: "Today", value: "12m")
                    StatCard(title: "This Week", value: "3h")
                    StatCard(title: "All Time", value: "48h")
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            Section {
                HStack {
                    Label("Reading Streak", systemImage: "flame.fill")
                        .foregroundStyle(.orange)
                    Spacer()
                    Text("7 days").fontWeight(.semibold)
                }
            }
            Section("By Book") {
                HStack {
                    Text("Peter and Wendy")
                    Spacer()
                    Text("2h 15m").foregroundStyle(.secondary).monospacedDigit()
                }
                HStack {
                    Text("Pride and Prejudice")
                    Spacer()
                    Text("5h 42m").foregroundStyle(.secondary).monospacedDigit()
                }
            }
        }
    }

    private var lockedOverlay: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Unlock Reading Statistics")
                .font(.title3.bold())
            Text("Track your time, streaks, and progress per book.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                showPaywall = true
            } label: {
                Text("Upgrade to Leafmark Pro")
                    .frame(maxWidth: 280)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }

    private func bookTitle(_ bookID: String) -> String {
        library.books.first { $0.id == bookID }?.title ?? "Deleted book"
    }
}

private struct StatCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.weight(.bold))
                .monospacedDigit()
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
