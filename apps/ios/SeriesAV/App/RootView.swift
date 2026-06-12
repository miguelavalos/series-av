import SwiftUI

struct RootView: View {
    @State private var store = SeriesLibraryStore.sample()

    var body: some View {
        NavigationStack {
            List {
                Section("Watching") {
                    ForEach(store.activeEntries) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(entry.title)
                                .font(.headline)
                            Text(entry.progressLabel)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button("Next") {
                                store.markNextEpisodeWatched(for: entry.id)
                            }
                            .tint(.green)
                        }
                    }
                }
            }
            .navigationTitle("Series AV")
        }
    }
}

#Preview {
    RootView()
}
