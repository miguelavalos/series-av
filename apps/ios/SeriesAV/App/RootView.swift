import SwiftUI

struct RootView: View {
    private enum ProfileMode: String, Identifiable {
        case settings
        case account

        var id: String { rawValue }
    }

    @State private var store = SeriesLibraryStore.sample()
    @State private var profileMode: ProfileMode?
    let accessController: SeriesAccessController
    let startSignInFlow: () -> Void

    var body: some View {
        NavigationStack {
            SeriesWatchingHomeScreen(
                store: store,
                accessTitle: accessTitle,
                accessSubtitle: accessSubtitle,
                activeSeriesLimit: accessController.limits.activeLibrarySeries,
                openSettings: { profileMode = .settings },
                openAccount: { profileMode = .account }
            )
            .navigationTitle("Series AV")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(item: $profileMode) { mode in
            SeriesProfileScreen(
                mode: mode == .settings ? .settings : .account,
                accessController: accessController,
                startSignInFlow: startSignInFlow
            )
        }
    }

    private var accessTitle: String {
        switch accessController.accessMode {
        case .guest:
            L10n.string("shell.mode.guest")
        case .signedInFree:
            L10n.string("shell.mode.free")
        case .signedInPro:
            L10n.string("shell.mode.pro")
        }
    }

    private var accessSubtitle: String {
        accessController.accountUser?.emailAddress ?? accessController.accountUser?.displayName ?? ""
    }
}

#Preview {
    RootView(accessController: SeriesAccessController(), startSignInFlow: {})
}

private struct SeriesWatchingHomeScreen: View {
    @Bindable var store: SeriesLibraryStore
    let accessTitle: String
    let accessSubtitle: String
    let activeSeriesLimit: Int?
    let openSettings: () -> Void
    let openAccount: () -> Void

    @State private var editorEntry: SeriesLibraryEntry?
    @State private var isShowingAddSheet = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                accountBar

                if let currentEntry {
                    SeriesCurrentWatchingCard(
                        entry: currentEntry,
                        markPrevious: {
                            store.markPreviousEpisodeWatched(for: currentEntry.id)
                        },
                        markNext: {
                            store.markNextEpisodeWatched(for: currentEntry.id)
                        },
                        editProgress: {
                            editorEntry = currentEntry
                        }
                    )
                } else {
                    SeriesEmptyWatchingView()
                }

                if secondaryEntries.isEmpty == false {
                    SeriesWatchingQueueSection(
                        entries: secondaryEntries,
                        markNext: { entry in
                            store.markNextEpisodeWatched(for: entry.id)
                        },
                        editProgress: { entry in
                            editorEntry = entry
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) {
            Button {
                isShowingAddSheet = true
            } label: {
                Label(L10n.string("home.add"), systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.regularMaterial)
            .disabled(!canAddSeries)
        }
        .sheet(item: $editorEntry) { entry in
            SeriesProgressEditorSheet(
                entry: entry,
                markWatchedThrough: { cursor in
                    store.markWatchedThrough(cursor, for: entry.id)
                }
            )
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $isShowingAddSheet) {
            SeriesAddSheet(
                store: store,
                canAddSeries: canAddSeries,
                remainingSeriesCount: remainingSeriesCount
            )
            .presentationDetents([.medium, .large])
        }
    }

    private var currentEntry: SeriesLibraryEntry? {
        store.homeEntries.first
    }

    private var secondaryEntries: [SeriesLibraryEntry] {
        Array(store.homeEntries.dropFirst())
    }

    private var canAddSeries: Bool {
        guard let activeSeriesLimit else {
            return true
        }
        return store.activeEntries.count < activeSeriesLimit
    }

    private var remainingSeriesCount: Int? {
        guard let activeSeriesLimit else {
            return nil
        }
        return max(0, activeSeriesLimit - store.activeEntries.count)
    }

    private var accountBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(accessTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                if accessSubtitle.isEmpty == false {
                    Text(accessSubtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button(action: openSettings) {
                Image(systemName: "gearshape")
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(L10n.string("shell.settings"))

            Button(action: openAccount) {
                Image(systemName: "person.crop.circle")
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel(L10n.string("shell.account"))
        }
        .padding(.horizontal, 2)
    }
}

private struct SeriesAddSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var store: SeriesLibraryStore
    let canAddSeries: Bool
    let remainingSeriesCount: Int?

    @State private var query = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField(L10n.string("add.search.placeholder"), text: $query)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)

                    Button {
                        addSeries()
                    } label: {
                        Label(L10n.string("add.action"), systemImage: "plus")
                    }
                    .disabled(!canSubmit)
                } footer: {
                    Text(limitText)
                }

                if matchingEntries.isEmpty == false {
                    Section(L10n.string("add.matches.title")) {
                        ForEach(matchingEntries) { entry in
                            HStack(spacing: 12) {
                                SeriesPosterMark(seed: entry.fallbackVisualSeed ?? entry.title, size: 34)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(entry.title)
                                        .font(.system(size: 15, weight: .semibold))
                                    Text(entry.progressLabel)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle(L10n.string("add.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("common.cancel")) {
                        dismiss()
                    }
                }
            }
        }
    }

    private var matchingEntries: [SeriesLibraryEntry] {
        store.searchEntries(matching: query)
    }

    private var canSubmit: Bool {
        canAddSeries && query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private var limitText: String {
        guard let remainingSeriesCount else {
            return L10n.string("add.footer.pro")
        }
        if canAddSeries {
            return String(format: L10n.string("add.footer.remaining"), remainingSeriesCount)
        }
        return L10n.string("add.footer.limitReached")
    }

    private func addSeries() {
        guard store.addLocalSeries(title: query) != nil else {
            return
        }
        dismiss()
    }
}

private struct SeriesCurrentWatchingCard: View {
    let entry: SeriesLibraryEntry
    let markPrevious: () -> Void
    let markNext: () -> Void
    let editProgress: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 14) {
                SeriesPosterMark(seed: entry.fallbackVisualSeed ?? entry.title, size: 82)

                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.string("home.current.title"))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Text(entry.title)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(String(format: L10n.string("home.current.progress"), entry.progressLabel))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 12) {
                SeriesEpisodeChip(
                    title: L10n.string("home.previous"),
                    value: previousLabel,
                    systemImage: "arrow.counterclockwise",
                    action: markPrevious
                )
                .disabled(entry.lastWatchedEpisodeCursor == nil)

                SeriesEpisodeChip(
                    title: L10n.string("home.next"),
                    value: cursorLabel(entry.nextEpisodeCursor),
                    systemImage: "checkmark",
                    action: markNext,
                    isProminent: true
                )
            }

            Button(action: editProgress) {
                Label(L10n.string("home.adjust"), systemImage: "slider.horizontal.3")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private var previousLabel: String {
        guard let cursor = entry.lastWatchedEpisodeCursor?.previousEpisode else {
            return L10n.string("home.notStarted")
        }
        return cursorLabel(cursor)
    }
}

private struct SeriesWatchingQueueSection: View {
    let entries: [SeriesLibraryEntry]
    let markNext: (SeriesLibraryEntry) -> Void
    let editProgress: (SeriesLibraryEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.string("home.queue.title"))
                .font(.system(size: 16, weight: .bold))

            VStack(spacing: 8) {
                ForEach(entries) { entry in
                    HStack(spacing: 12) {
                        SeriesPosterMark(seed: entry.fallbackVisualSeed ?? entry.title, size: 46)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(entry.title)
                                .font(.system(size: 15, weight: .semibold))
                                .lineLimit(1)
                            Text(String(format: L10n.string("home.queue.progress"), entry.progressLabel, cursorLabel(entry.nextEpisodeCursor)))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Button {
                            markNext(entry)
                        } label: {
                            Image(systemName: "checkmark")
                                .frame(width: 34, height: 34)
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityLabel(L10n.string("shell.watch.next"))

                        Button {
                            editProgress(entry)
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                                .frame(width: 34, height: 34)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel(L10n.string("home.adjust"))
                    }
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
    }
}

private struct SeriesProgressEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let entry: SeriesLibraryEntry
    let markWatchedThrough: (SeriesEpisodeCursor) -> Void

    @State private var seasonNumber: Int
    @State private var episodeNumber: Int

    init(entry: SeriesLibraryEntry, markWatchedThrough: @escaping (SeriesEpisodeCursor) -> Void) {
        self.entry = entry
        self.markWatchedThrough = markWatchedThrough
        let cursor = entry.lastWatchedEpisodeCursor ?? SeriesEpisodeCursor(seasonNumber: 1, episodeNumber: 1)
        _seasonNumber = State(initialValue: cursor.seasonNumber)
        _episodeNumber = State(initialValue: cursor.episodeNumber)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: $seasonNumber, in: 1...99) {
                        Text(String(format: L10n.string("home.editor.season"), seasonNumber))
                    }

                    Stepper(value: $episodeNumber, in: 1...999) {
                        Text(String(format: L10n.string("home.editor.episode"), episodeNumber))
                    }
                } footer: {
                    Text(L10n.string("home.editor.footer"))
                }

                Section {
                    Button {
                        markWatchedThrough(SeriesEpisodeCursor(seasonNumber: seasonNumber, episodeNumber: episodeNumber))
                        dismiss()
                    } label: {
                        Text(L10n.string("home.editor.confirm"))
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle(entry.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("common.cancel")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct SeriesEpisodeChip: View {
    let title: String
    let value: String
    let systemImage: String
    let action: () -> Void
    var isProminent = false

    @ViewBuilder
    var body: some View {
        if isProminent {
            button
                .buttonStyle(.borderedProminent)
        } else {
            button
                .buttonStyle(.bordered)
        }
    }

    private var button: some View {
        Button(action: action) {
            content
        }
    }

    private var content: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .bold))
            Text(title)
                .font(.system(size: 12, weight: .bold))
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, minHeight: 96)
    }
}

private struct SeriesPosterMark: View {
    let seed: String
    let size: CGFloat

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: palette,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Text(initials)
                .font(.system(size: size * 0.24, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .padding(size * 0.12)
        }
        .frame(width: size, height: size * 1.38)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.35), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.10), radius: 10, y: 5)
    }

    private var initials: String {
        seed
            .split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
    }

    private var palette: [Color] {
        let palettes: [[Color]] = [
            [Color(red: 0.18, green: 0.33, blue: 0.43), Color(red: 0.79, green: 0.32, blue: 0.26)],
            [Color(red: 0.18, green: 0.43, blue: 0.36), Color(red: 0.86, green: 0.67, blue: 0.30)],
            [Color(red: 0.42, green: 0.23, blue: 0.35), Color(red: 0.28, green: 0.50, blue: 0.66)]
        ]
        let index = abs(seed.hashValue) % palettes.count
        return palettes[index]
    }
}

private struct SeriesEmptyWatchingView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "play.rectangle")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(L10n.string("home.empty.title"))
                .font(.system(size: 22, weight: .bold))
            Text(L10n.string("home.empty.subtitle"))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private func cursorLabel(_ cursor: SeriesEpisodeCursor) -> String {
    "S\(cursor.seasonNumber) E\(cursor.episodeNumber)"
}
