import SwiftUI

/// Reading statistics: today / this week / all time, streak and per-book time.
struct StatsView: View {
    @ObservedObject var stats: StatsStore
    @ObservedObject var library: LibraryStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if stats.sessions.isEmpty {
                    ContentUnavailableView(
                        "No Reading Yet",
                        systemImage: "chart.bar",
                        description: Text("Statistics appear once you start reading.")
                    )
                } else {
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
            }
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
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
