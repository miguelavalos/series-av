import SwiftUI

struct LibraryScreen: View {
    @EnvironmentObject private var libraryStore: SeriesLibraryStore

    let bottomContentPadding: CGFloat

    @State private var activeStatus: ShowStatus = .watching
    @State private var query = ""
    @State private var selectedDetail: SelectedShowDetail?
    private let service = TVMazeService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ShellBrandHeader(statusTitle: libraryStore.shows.isEmpty ? L10n.string("library.status.empty") : L10n.string("library.status.saved", libraryStore.shows.count))
                SectionHeading(
                    eyebrow: L10n.string("library.eyebrow"),
                    title: L10n.string("library.title"),
                    subtitle: L10n.string("library.subtitle")
                )

                VStack(alignment: .leading, spacing: 14) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(ShowStatus.allCases) { status in
                                Button(status.title) {
                                    activeStatus = status
                                }
                                .font(.system(size: 13, weight: .bold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(activeStatus == status ? SeriesTheme.highlight : SeriesTheme.cardSurface, in: Capsule())
                                .foregroundStyle(activeStatus == status ? Color.white : SeriesTheme.textPrimary)
                                .overlay {
                                    Capsule()
                                        .stroke(activeStatus == status ? SeriesTheme.highlight : SeriesTheme.borderSubtle, lineWidth: 1)
                                }
                            }
                        }
                    }

                    SearchField(query: $query, prompt: L10n.string("library.search.prompt", activeStatus.title.lowercased()))
                }
                .padding(22)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(SeriesTheme.mutedSurface)
                        .overlay {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(SeriesTheme.borderSubtle, lineWidth: 1)
                        }
                )

                let filtered = libraryStore.filteredShows(status: activeStatus, query: query)
                if filtered.isEmpty {
                    EmptyStateCard(title: L10n.string("library.empty.title", activeStatus.title.lowercased()), detail: L10n.string("library.empty.detail"))
                } else {
                    ForEach(filtered) { show in
                        Button {
                            selectedDetail = .library(id: show.id)
                        } label: {
                            LibraryRowCard(show: show)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(24)
            .padding(.bottom, bottomContentPadding)
        }
        .scrollIndicators(.hidden)
        .background(SeriesTheme.shellBackground.ignoresSafeArea())
        .sheet(item: $selectedDetail) { detail in
            ShowDetailScreen(
                libraryShowID: detail.libraryShowID,
                summary: detail.summary,
                remoteSeriesID: detail.remoteSeriesID,
                service: service
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }
}
