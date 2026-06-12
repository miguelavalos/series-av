import SwiftUI

struct RootView: View {
    private enum ProfileMode: String, Identifiable {
        case settings
        case account

        var id: String { rawValue }
    }

    @State private var store = SeriesLibraryStore.persisted()
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
    @State private var isShowingLibrarySheet = false
    @State private var pendingUndo: PendingLibraryUndo?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                accountBar
                SeriesLibrarySummaryStrip(
                    watchingCount: countActiveEntries(with: .watching),
                    wantToWatchCount: countActiveEntries(with: .wantToWatch),
                    watchedCount: countActiveEntries(with: .watched)
                )

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
                        },
                        togglePinned: {
                            store.setPinned(currentEntry.isPinnedHomeSeries != true, for: currentEntry.id)
                        },
                        setStatus: { status in
                            store.setStatus(status, for: currentEntry.id)
                        },
                        archive: {
                            store.archive(currentEntry.id)
                            pendingUndo = PendingLibraryUndo(entryId: currentEntry.id, title: currentEntry.title, messageKey: "home.undo.archived")
                        },
                        delete: {
                            store.delete(currentEntry.id)
                            pendingUndo = PendingLibraryUndo(entryId: currentEntry.id, title: currentEntry.title, messageKey: "home.undo.deleted")
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
                        },
                        togglePinned: { entry in
                            store.setPinned(entry.isPinnedHomeSeries != true, for: entry.id)
                        },
                        setStatus: { entry, status in
                            store.setStatus(status, for: entry.id)
                        },
                        archive: { entry in
                            store.archive(entry.id)
                            pendingUndo = PendingLibraryUndo(entryId: entry.id, title: entry.title, messageKey: "home.undo.archived")
                        },
                        delete: { entry in
                            store.delete(entry.id)
                            pendingUndo = PendingLibraryUndo(entryId: entry.id, title: entry.title, messageKey: "home.undo.deleted")
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                if let pendingUndo {
                    SeriesUndoBar(
                        title: String(format: L10n.string(pendingUndo.messageKey), pendingUndo.title),
                        undo: {
                            store.restore(pendingUndo.entryId)
                            self.pendingUndo = nil
                        },
                        dismiss: {
                            self.pendingUndo = nil
                        }
                    )
                }

                Button {
                    isShowingAddSheet = true
                } label: {
                    Label(L10n.string("home.add"), systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!canAddSeries)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.regularMaterial)
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
        .sheet(isPresented: $isShowingLibrarySheet) {
            SeriesLibrarySheet(
                store: store,
                archive: { entry in
                    store.archive(entry.id)
                    pendingUndo = PendingLibraryUndo(entryId: entry.id, title: entry.title, messageKey: "home.undo.archived")
                },
                setStatus: { entry, status in
                    store.setStatus(status, for: entry.id)
                },
                restore: { entry in
                    store.restore(entry.id)
                },
                delete: { entry in
                    store.delete(entry.id)
                    pendingUndo = PendingLibraryUndo(entryId: entry.id, title: entry.title, messageKey: "home.undo.deleted")
                }
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

    private func countActiveEntries(with status: SeriesLibraryEntryStatus) -> Int {
        store.activeEntries.filter { $0.status == status }.count
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

            Button {
                isShowingLibrarySheet = true
            } label: {
                Image(systemName: "books.vertical")
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(L10n.string("library.title"))

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

private struct SeriesLibrarySummaryStrip: View {
    let watchingCount: Int
    let wantToWatchCount: Int
    let watchedCount: Int

    var body: some View {
        HStack(spacing: 8) {
            SeriesLibrarySummaryItem(
                title: L10n.string("library.filter.watching"),
                count: watchingCount,
                systemImage: "play.circle.fill"
            )
            SeriesLibrarySummaryItem(
                title: L10n.string("library.filter.wantToWatch"),
                count: wantToWatchCount,
                systemImage: "bookmark.fill"
            )
            SeriesLibrarySummaryItem(
                title: L10n.string("library.filter.watched"),
                count: watchedCount,
                systemImage: "checkmark.circle.fill"
            )
        }
    }
}

private struct SeriesLibrarySummaryItem: View {
    let title: String
    let count: Int
    let systemImage: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 1) {
                Text("\(count)")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 50)
        .padding(.horizontal, 10)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }
}

private struct PendingLibraryUndo: Identifiable, Equatable {
    var entryId: String
    var title: String
    var messageKey: String

    var id: String { "\(entryId)-\(messageKey)" }
}

private struct SeriesUndoBar: View {
    let title: String
    let undo: () -> Void
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(2)

            Spacer()

            Button(L10n.string("home.undo"), action: undo)
                .font(.system(size: 13, weight: .bold))

            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .frame(width: 28, height: 28)
            }
            .accessibilityLabel(L10n.string("common.close"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct SeriesLibrarySheet: View {
    private enum LibraryFilter: String, CaseIterable {
        case all
        case watching
        case wantToWatch
        case watched
        case archived
    }

    @Environment(\.dismiss) private var dismiss
    @Bindable var store: SeriesLibraryStore
    let archive: (SeriesLibraryEntry) -> Void
    let setStatus: (SeriesLibraryEntry, SeriesLibraryEntryStatus) -> Void
    let restore: (SeriesLibraryEntry) -> Void
    let delete: (SeriesLibraryEntry) -> Void

    @State private var query = ""
    @State private var selectedFilter: LibraryFilter = .all

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField(L10n.string("library.search.placeholder"), text: $query)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.search)

                    Picker(L10n.string("library.filter.title"), selection: $selectedFilter) {
                        ForEach(LibraryFilter.allCases, id: \.self) { filter in
                            Text(filterTitle(filter))
                                .tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if filteredActiveEntries.isEmpty == false {
                    Section(L10n.string("library.active.title")) {
                        ForEach(filteredActiveEntries) { entry in
                            SeriesLibraryRow(entry: entry, detail: libraryDetail(for: entry)) {
                                SeriesStatusButtons(entry: entry) { status in
                                    setStatus(entry, status)
                                }

                                Button {
                                    archive(entry)
                                } label: {
                                    Label(L10n.string("home.archive"), systemImage: "archivebox")
                                }

                                Button(role: .destructive) {
                                    delete(entry)
                                } label: {
                                    Label(L10n.string("home.delete"), systemImage: "trash")
                                }
                            }
                        }
                    }
                }

                if filteredArchivedEntries.isEmpty == false {
                    Section(L10n.string("library.archived.title")) {
                        ForEach(filteredArchivedEntries) { entry in
                            SeriesLibraryRow(entry: entry, detail: L10n.string("library.archived.detail")) {
                                Button {
                                    restore(entry)
                                } label: {
                                    Label(L10n.string("library.restore"), systemImage: "arrow.uturn.backward")
                                }

                                Button(role: .destructive) {
                                    delete(entry)
                                } label: {
                                    Label(L10n.string("home.delete"), systemImage: "trash")
                                }
                            }
                        }
                    }
                }

                if isShowingEmptyState {
                    ContentUnavailableView(
                        emptyTitle,
                        systemImage: "books.vertical",
                        description: Text(emptySubtitle)
                    )
                }
            }
            .navigationTitle(L10n.string("library.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("common.close")) {
                        dismiss()
                    }
                }
            }
        }
    }

    private var filteredActiveEntries: [SeriesLibraryEntry] {
        guard selectedFilter != .archived else {
            return []
        }

        return filter(store.activeEntries).filter { entry in
            switch selectedFilter {
            case .all:
                return true
            case .watching:
                return entry.status == .watching
            case .wantToWatch:
                return entry.status == .wantToWatch
            case .watched:
                return entry.status == .watched
            case .archived:
                return false
            }
        }
    }

    private var filteredArchivedEntries: [SeriesLibraryEntry] {
        guard selectedFilter == .all || selectedFilter == .archived else {
            return []
        }

        return filter(store.archivedEntries)
    }

    private var normalizedQuery: String {
        SeriesLibraryIdentity.normalizedSearchText(query)
    }

    private var isShowingEmptyState: Bool {
        filteredActiveEntries.isEmpty && filteredArchivedEntries.isEmpty
    }

    private var emptyTitle: String {
        if store.activeEntries.isEmpty && store.archivedEntries.isEmpty {
            return L10n.string("library.empty.title")
        }
        return L10n.string("library.search.empty.title")
    }

    private var emptySubtitle: String {
        if store.activeEntries.isEmpty && store.archivedEntries.isEmpty {
            return L10n.string("library.empty.subtitle")
        }
        return L10n.string("library.search.empty.subtitle")
    }

    private func filter(_ entries: [SeriesLibraryEntry]) -> [SeriesLibraryEntry] {
        guard normalizedQuery.isEmpty == false else {
            return entries
        }

        return entries.filter {
            SeriesLibraryIdentity.normalizedSearchText($0.title).contains(normalizedQuery)
        }
    }

    private func libraryDetail(for entry: SeriesLibraryEntry) -> String {
        "\(statusTitle(entry.status)) · \(entry.progressLabel)"
    }

    private func filterTitle(_ filter: LibraryFilter) -> String {
        switch filter {
        case .all:
            L10n.string("library.filter.all")
        case .watching:
            L10n.string("library.filter.watching")
        case .wantToWatch:
            L10n.string("library.filter.wantToWatch")
        case .watched:
            L10n.string("library.filter.watched")
        case .archived:
            L10n.string("library.filter.archived")
        }
    }
}

private struct SeriesLibraryRow<MenuContent: View>: View {
    let entry: SeriesLibraryEntry
    let detail: String
    @ViewBuilder let menuContent: () -> MenuContent

    var body: some View {
        HStack(spacing: 12) {
            SeriesPosterMark(seed: entry.fallbackVisualSeed ?? entry.title, size: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.title)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                Text(detail)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Menu {
                menuContent()
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(L10n.string("home.actions"))
        }
        .padding(.vertical, 4)
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
    let togglePinned: () -> Void
    let setStatus: (SeriesLibraryEntryStatus) -> Void
    let archive: () -> Void
    let delete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                SeriesPosterMark(seed: entry.fallbackVisualSeed ?? entry.title, size: 94)

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
                .padding(.top, 3)

                Spacer(minLength: 0)

                SeriesEntryActionsMenu(
                    entry: entry,
                    togglePinned: togglePinned,
                    setStatus: setStatus,
                    archive: archive,
                    delete: delete
                )
            }

            SeriesPrimaryContinueButton(
                title: L10n.string("home.next"),
                episodeLabel: cursorLabel(entry.nextEpisodeCursor),
                action: markNext
            )

            HStack(spacing: 12) {
                SeriesEpisodeChip(
                    title: L10n.string("home.previous"),
                    value: previousLabel,
                    systemImage: "arrow.counterclockwise",
                    action: markPrevious
                )
                .disabled(entry.lastWatchedEpisodeCursor == nil)

                Button(action: editProgress) {
                    Label(L10n.string("home.adjust"), systemImage: "slider.horizontal.3")
                        .frame(maxWidth: .infinity, minHeight: 96)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
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

private struct SeriesPrimaryContinueButton: View {
    let title: String
    let episodeLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 26, weight: .bold))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 13, weight: .bold))
                    Text(episodeLabel)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, minHeight: 86)
            .padding(.horizontal, 18)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }
}

private struct SeriesWatchingQueueSection: View {
    let entries: [SeriesLibraryEntry]
    let markNext: (SeriesLibraryEntry) -> Void
    let editProgress: (SeriesLibraryEntry) -> Void
    let togglePinned: (SeriesLibraryEntry) -> Void
    let setStatus: (SeriesLibraryEntry, SeriesLibraryEntryStatus) -> Void
    let archive: (SeriesLibraryEntry) -> Void
    let delete: (SeriesLibraryEntry) -> Void

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
                            togglePinned(entry)
                        } label: {
                            Image(systemName: "pin")
                                .frame(width: 34, height: 34)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel(L10n.string("home.pin"))

                        Button {
                            markNext(entry)
                        } label: {
                            Image(systemName: "checkmark")
                                .frame(width: 34, height: 34)
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityLabel(L10n.string("shell.watch.next"))

                        SeriesEntryActionsMenu(
                            entry: entry,
                            togglePinned: { togglePinned(entry) },
                            editProgress: { editProgress(entry) },
                            setStatus: { setStatus(entry, $0) },
                            archive: { archive(entry) },
                            delete: { delete(entry) }
                        )
                    }
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
    }
}

private struct SeriesEntryActionsMenu: View {
    let entry: SeriesLibraryEntry
    let togglePinned: () -> Void
    var editProgress: (() -> Void)? = nil
    let setStatus: (SeriesLibraryEntryStatus) -> Void
    let archive: () -> Void
    let delete: () -> Void

    var body: some View {
        Menu {
            SeriesStatusButtons(entry: entry, setStatus: setStatus)

            if let editProgress {
                Button(action: editProgress) {
                    Label(L10n.string("home.adjust"), systemImage: "slider.horizontal.3")
                }
            }

            Button(action: togglePinned) {
                Label(pinTitle, systemImage: entry.isPinnedHomeSeries == true ? "pin.slash" : "pin")
            }

            Button(action: archive) {
                Label(L10n.string("home.archive"), systemImage: "archivebox")
            }

            Button(role: .destructive, action: delete) {
                Label(L10n.string("home.delete"), systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(L10n.string("home.actions"))
    }

    private var pinTitle: String {
        entry.isPinnedHomeSeries == true ? L10n.string("home.unpin") : L10n.string("home.pin")
    }
}

private struct SeriesStatusButtons: View {
    let entry: SeriesLibraryEntry
    let setStatus: (SeriesLibraryEntryStatus) -> Void

    var body: some View {
        ForEach(SeriesLibraryEntryStatus.allCases, id: \.self) { status in
            Button {
                setStatus(status)
            } label: {
                Label(statusTitle(status), systemImage: statusIcon(status, isSelected: entry.status == status))
            }
            .disabled(entry.status == status)
        }
    }
}

private func statusTitle(_ status: SeriesLibraryEntryStatus) -> String {
    switch status {
    case .wantToWatch:
        L10n.string("library.status.wantToWatch")
    case .watching:
        L10n.string("library.status.watching")
    case .watched:
        L10n.string("library.status.watched")
    }
}

private func statusIcon(_ status: SeriesLibraryEntryStatus, isSelected: Bool) -> String {
    if isSelected {
        return "checkmark.circle.fill"
    }

    switch status {
    case .wantToWatch:
        return "bookmark"
    case .watching:
        return "play.circle"
    case .watched:
        return "checkmark.circle"
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
