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
                accessController: accessController,
                openAccount: { profileMode = .account },
                startSignInFlow: startSignInFlow
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

private enum SeriesLibraryFilter: String, CaseIterable {
    case all
    case watching
    case wantToWatch
    case watched
    case archived
}

private struct SeriesWatchingHomeScreen: View {
    @Bindable var store: SeriesLibraryStore
    let accessTitle: String
    let accessSubtitle: String
    let activeSeriesLimit: Int?
    let accessController: SeriesAccessController
    let openAccount: () -> Void
    let startSignInFlow: () -> Void

    @State private var editorEntry: SeriesLibraryEntry?
    @State private var isShowingAddSheet = false
    @State private var isShowingLibrarySheet = false
    @State private var isShowingProPaywall = false
    @State private var pendingProPaywallAfterAddDismiss = false
    @State private var pendingProgressEditorAfterAddEntryId: String?
    @State private var initialLibraryFilter: SeriesLibraryFilter = .all
    @State private var pendingUndo: PendingLibraryUndo?
    @State private var pendingProgressUndo: PendingProgressUndo?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                accountBar

                if let currentEntry {
                    SeriesCurrentWatchingCard(
                        entry: currentEntry,
                        markPrevious: {
                            pendingProgressUndo = progressUndo(for: currentEntry)
                            pendingUndo = nil
                            store.markPreviousEpisodeWatched(for: currentEntry.id)
                        },
                        markNext: {
                            pendingProgressUndo = progressUndo(for: currentEntry)
                            pendingUndo = nil
                            store.markNextEpisodeWatched(for: currentEntry.id)
                        },
                        editProgress: {
                            editorEntry = currentEntry
                        },
                        togglePinned: {
                            store.setPinned(currentEntry.isPinnedHomeSeries != true, for: currentEntry.id)
                        },
                        setStatus: { status in
                            pendingProgressUndo = progressUndo(for: currentEntry, messageKey: "home.undo.status")
                            pendingUndo = nil
                            store.setStatus(status, for: currentEntry.id)
                        },
                        archive: {
                            store.archive(currentEntry.id)
                            pendingProgressUndo = nil
                            pendingUndo = PendingLibraryUndo(entryId: currentEntry.id, title: currentEntry.title, messageKey: "home.undo.archived")
                        },
                        delete: {
                            store.delete(currentEntry.id)
                            pendingProgressUndo = nil
                            pendingUndo = PendingLibraryUndo(entryId: currentEntry.id, title: currentEntry.title, messageKey: "home.undo.deleted")
                        }
                    )
                } else {
                    SeriesEmptyWatchingView {
                        isShowingAddSheet = true
                    }
                }

                SeriesLibrarySummaryStrip(
                    watchingCount: countActiveEntries(with: .watching),
                    wantToWatchCount: countActiveEntries(with: .wantToWatch),
                    watchedCount: countActiveEntries(with: .watched),
                    archivedCount: store.archivedEntries.count,
                    openWatching: {
                        openLibrary(filter: .watching)
                    },
                    openWantToWatch: {
                        openLibrary(filter: .wantToWatch)
                    },
                    openWatched: {
                        openLibrary(filter: .watched)
                    },
                    openArchived: {
                        openLibrary(filter: .archived)
                    }
                )

                if secondaryEntries.isEmpty == false {
                    SeriesWatchingQueueSection(
                        entries: secondaryEntries,
                        markNext: { entry in
                            pendingProgressUndo = progressUndo(for: entry)
                            pendingUndo = nil
                            store.markNextEpisodeWatched(for: entry.id)
                        },
                        editProgress: { entry in
                            editorEntry = entry
                        },
                        togglePinned: { entry in
                            store.setPinned(entry.isPinnedHomeSeries != true, for: entry.id)
                        },
                        setStatus: { entry, status in
                            pendingProgressUndo = progressUndo(for: entry, messageKey: "home.undo.status")
                            pendingUndo = nil
                            store.setStatus(status, for: entry.id)
                        },
                        archive: { entry in
                            store.archive(entry.id)
                            pendingProgressUndo = nil
                            pendingUndo = PendingLibraryUndo(entryId: entry.id, title: entry.title, messageKey: "home.undo.archived")
                        },
                        delete: { entry in
                            store.delete(entry.id)
                            pendingProgressUndo = nil
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
                if let pendingProgressUndo {
                    SeriesUndoBar(
                        title: String(format: L10n.string(pendingProgressUndo.messageKey), pendingProgressUndo.title),
                        undo: {
                            store.restoreProgress(
                                status: pendingProgressUndo.status,
                                lastWatchedEpisodeCursor: pendingProgressUndo.lastWatchedEpisodeCursor,
                                for: pendingProgressUndo.entryId
                            )
                            self.pendingProgressUndo = nil
                        },
                        dismiss: {
                            self.pendingProgressUndo = nil
                        }
                    )
                } else if let pendingUndo {
                    SeriesUndoBar(
                        title: String(format: L10n.string(pendingUndo.messageKey), pendingUndo.title),
                        undo: {
                            if pendingUndo.messageKey == "home.undo.added" {
                                store.delete(pendingUndo.entryId)
                            } else {
                                store.restore(pendingUndo.entryId)
                            }
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
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.regularMaterial)
        }
        .sheet(item: $editorEntry) { entry in
            SeriesProgressEditorSheet(
                entry: entry,
                markWatchedThrough: { cursor in
                    pendingProgressUndo = progressUndo(for: entry)
                    pendingUndo = nil
                    store.markWatchedThrough(cursor, for: entry.id)
                },
                clearProgress: {
                    pendingProgressUndo = progressUndo(for: entry)
                    pendingUndo = nil
                    store.clearProgress(for: entry.id)
                }
            )
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $isShowingAddSheet) {
            SeriesAddSheet(
                store: store,
                canAddSeries: canAddSeries,
                remainingSeriesCount: remainingSeriesCount,
                openProPaywall: {
                    pendingProPaywallAfterAddDismiss = true
                    isShowingAddSheet = false
                },
                didAddSeries: { entry in
                    pendingProgressUndo = nil
                    pendingProgressEditorAfterAddEntryId = entry.id
                    pendingUndo = PendingLibraryUndo(entryId: entry.id, title: entry.title, messageKey: "home.undo.added")
                }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $isShowingLibrarySheet) {
            SeriesLibrarySheet(
                store: store,
                initialFilter: initialLibraryFilter,
                archive: { entry in
                    store.archive(entry.id)
                },
                setStatus: { entry, status in
                    store.setStatus(status, for: entry.id)
                },
                markPrevious: { entry in
                    store.markPreviousEpisodeWatched(for: entry.id)
                },
                markNext: { entry in
                    store.markNextEpisodeWatched(for: entry.id)
                },
                markWatchedThrough: { entry, cursor in
                    store.markWatchedThrough(cursor, for: entry.id)
                },
                clearProgress: { entry in
                    store.clearProgress(for: entry.id)
                },
                restore: { entry in
                    store.restore(entry.id)
                },
                delete: { entry in
                    store.delete(entry.id)
                }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $isShowingProPaywall) {
            SeriesProPaywallView(
                accessController: accessController,
                startSignInFlow: startSignInFlow
            )
        }
        .onChange(of: isShowingAddSheet) { _, isShowing in
            guard !isShowing else { return }

            if pendingProPaywallAfterAddDismiss {
                pendingProPaywallAfterAddDismiss = false
                isShowingProPaywall = true
                return
            }

            if let entryId = pendingProgressEditorAfterAddEntryId {
                pendingProgressEditorAfterAddEntryId = nil
                guard let entry = store.entries.first(where: { $0.id == entryId }) else { return }
                editorEntry = entry
            }
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

    private func progressUndo(
        for entry: SeriesLibraryEntry,
        messageKey: String = "home.undo.progress"
    ) -> PendingProgressUndo {
        PendingProgressUndo(
            entryId: entry.id,
            title: entry.title,
            messageKey: messageKey,
            status: entry.status,
            lastWatchedEpisodeCursor: entry.lastWatchedEpisodeCursor
        )
    }

    private func openLibrary(filter: SeriesLibraryFilter = .all) {
        initialLibraryFilter = filter
        isShowingLibrarySheet = true
    }

    private var accountBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: accountStatusImage)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)

                Text(accessTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            .frame(minHeight: 30)
            .padding(.horizontal, 10)
            .background(Color(.secondarySystemGroupedBackground).opacity(0.72), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accountAccessibilityLabel)

            Spacer()

            Button {
                openLibrary()
            } label: {
                Image(systemName: "books.vertical")
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(L10n.string("library.title"))

            Button(action: openAccount) {
                Image(systemName: "person.crop.circle")
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel(L10n.string("shell.account"))
        }
        .padding(.horizontal, 2)
    }

    private var accountStatusImage: String {
        accessController.accessMode == .signedInPro ? "sparkles" : "person.crop.circle"
    }

    private var accountAccessibilityLabel: String {
        if accessSubtitle.isEmpty {
            return accessTitle
        }
        return "\(accessTitle), \(accessSubtitle)"
    }
}

private struct SeriesLibrarySummaryStrip: View {
    let watchingCount: Int
    let wantToWatchCount: Int
    let watchedCount: Int
    let archivedCount: Int
    let openWatching: () -> Void
    let openWantToWatch: () -> Void
    let openWatched: () -> Void
    let openArchived: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                SeriesLibrarySummaryItem(
                    title: L10n.string("library.filter.watching"),
                    count: watchingCount,
                    systemImage: "play.circle.fill",
                    action: openWatching
                )
                SeriesLibrarySummaryItem(
                    title: L10n.string("library.filter.wantToWatch"),
                    count: wantToWatchCount,
                    systemImage: "bookmark.fill",
                    action: openWantToWatch
                )
                SeriesLibrarySummaryItem(
                    title: L10n.string("library.filter.watched"),
                    count: watchedCount,
                    systemImage: "checkmark.circle.fill",
                    action: openWatched
                )

                if archivedCount > 0 {
                    SeriesLibrarySummaryItem(
                        title: L10n.string("library.filter.archived"),
                        count: archivedCount,
                        systemImage: "archivebox",
                        action: openArchived
                    )
                }
            }
        }
    }
}

private struct SeriesLibrarySummaryItem: View {
    let title: String
    let count: Int
    let systemImage: String
    let action: () -> Void

    private var isEnabled: Bool {
        count > 0
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)

                Text("\(count)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .monospacedDigit()

                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

            }
            .frame(minHeight: 30)
            .padding(.horizontal, 9)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.46)
        .background(Color(.secondarySystemGroupedBackground).opacity(0.72), in: Capsule())
        .overlay {
            Capsule()
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        }
        .accessibilityLabel("\(title): \(count)")
    }
}

private struct PendingLibraryUndo: Identifiable, Equatable {
    var entryId: String
    var title: String
    var messageKey: String

    var id: String { "\(entryId)-\(messageKey)" }
}

private enum PendingLibraryMutationUndoAction: Equatable {
    case restore
    case archive
}

private struct PendingLibraryMutationUndo: Identifiable, Equatable {
    var entryId: String
    var title: String
    var messageKey: String
    var action: PendingLibraryMutationUndoAction

    var id: String { "\(entryId)-\(messageKey)" }
}

private struct PendingProgressUndo: Identifiable, Equatable {
    var entryId: String
    var title: String
    var messageKey: String
    var status: SeriesLibraryEntryStatus
    var lastWatchedEpisodeCursor: SeriesEpisodeCursor?

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
    @Environment(\.dismiss) private var dismiss
    @Bindable var store: SeriesLibraryStore
    let initialFilter: SeriesLibraryFilter
    let archive: (SeriesLibraryEntry) -> Void
    let setStatus: (SeriesLibraryEntry, SeriesLibraryEntryStatus) -> Void
    let markPrevious: (SeriesLibraryEntry) -> Void
    let markNext: (SeriesLibraryEntry) -> Void
    let markWatchedThrough: (SeriesLibraryEntry, SeriesEpisodeCursor) -> Void
    let clearProgress: (SeriesLibraryEntry) -> Void
    let restore: (SeriesLibraryEntry) -> Void
    let delete: (SeriesLibraryEntry) -> Void

    @State private var query = ""
    @State private var selectedFilter: SeriesLibraryFilter
    @State private var editorEntry: SeriesLibraryEntry?
    @State private var pendingLibraryUndo: PendingLibraryMutationUndo?
    @State private var pendingProgressUndo: PendingProgressUndo?

    init(
        store: SeriesLibraryStore,
        initialFilter: SeriesLibraryFilter,
        archive: @escaping (SeriesLibraryEntry) -> Void,
        setStatus: @escaping (SeriesLibraryEntry, SeriesLibraryEntryStatus) -> Void,
        markPrevious: @escaping (SeriesLibraryEntry) -> Void,
        markNext: @escaping (SeriesLibraryEntry) -> Void,
        markWatchedThrough: @escaping (SeriesLibraryEntry, SeriesEpisodeCursor) -> Void,
        clearProgress: @escaping (SeriesLibraryEntry) -> Void,
        restore: @escaping (SeriesLibraryEntry) -> Void,
        delete: @escaping (SeriesLibraryEntry) -> Void
    ) {
        self.store = store
        self.initialFilter = initialFilter
        self.archive = archive
        self.setStatus = setStatus
        self.markPrevious = markPrevious
        self.markNext = markNext
        self.markWatchedThrough = markWatchedThrough
        self.clearProgress = clearProgress
        self.restore = restore
        self.delete = delete
        _selectedFilter = State(initialValue: initialFilter)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField(L10n.string("library.search.placeholder"), text: $query)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.search)

                    Picker(L10n.string("library.filter.title"), selection: $selectedFilter) {
                        ForEach(SeriesLibraryFilter.allCases, id: \.self) { filter in
                            Text(filterTitle(filter))
                                .tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if filteredActiveEntries.isEmpty == false {
                    Section(L10n.string("library.active.title")) {
                        ForEach(filteredActiveEntries) { entry in
                            SeriesLibraryRow(
                                entry: entry,
                                detail: libraryDetail(for: entry),
                                editProgress: {
                                    editorEntry = entry
                                }
                            ) {
                                Button {
                                    pendingProgressUndo = progressUndo(for: entry)
                                    pendingLibraryUndo = nil
                                    markNext(entry)
                                } label: {
                                    Label(
                                        quickProgressTitle(for: entry),
                                        systemImage: "checkmark.circle"
                                    )
                                }

                                if entry.lastWatchedEpisodeCursor != nil {
                                    Button {
                                        pendingProgressUndo = progressUndo(for: entry)
                                        pendingLibraryUndo = nil
                                        markPrevious(entry)
                                    } label: {
                                        Label(previousProgressTitle(for: entry), systemImage: "arrow.uturn.backward.circle")
                                    }
                                }

                                SeriesStatusButtons(entry: entry) { status in
                                    pendingProgressUndo = progressUndo(for: entry, messageKey: "home.undo.status")
                                    pendingLibraryUndo = nil
                                    setStatus(entry, status)
                                }

                                Button {
                                    pendingLibraryUndo = PendingLibraryMutationUndo(
                                        entryId: entry.id,
                                        title: entry.title,
                                        messageKey: "home.undo.archived",
                                        action: .restore
                                    )
                                    pendingProgressUndo = nil
                                    archive(entry)
                                } label: {
                                    Label(L10n.string("home.archive"), systemImage: "archivebox")
                                }

                                Button(role: .destructive) {
                                    pendingLibraryUndo = PendingLibraryMutationUndo(
                                        entryId: entry.id,
                                        title: entry.title,
                                        messageKey: "home.undo.deleted",
                                        action: .restore
                                    )
                                    pendingProgressUndo = nil
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
                            SeriesLibraryRow(
                                entry: entry,
                                detail: L10n.string("library.archived.detail"),
                                editProgress: nil
                            ) {
                                Button {
                                    pendingLibraryUndo = PendingLibraryMutationUndo(
                                        entryId: entry.id,
                                        title: entry.title,
                                        messageKey: "home.undo.restored",
                                        action: .archive
                                    )
                                    pendingProgressUndo = nil
                                    restore(entry)
                                } label: {
                                    Label(L10n.string("library.restore"), systemImage: "arrow.uturn.backward")
                                }

                                Button(role: .destructive) {
                                    pendingLibraryUndo = PendingLibraryMutationUndo(
                                        entryId: entry.id,
                                        title: entry.title,
                                        messageKey: "home.undo.deleted",
                                        action: .restore
                                    )
                                    pendingProgressUndo = nil
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
            .sheet(item: $editorEntry) { entry in
                SeriesProgressEditorSheet(
                    entry: entry,
                    markWatchedThrough: { cursor in
                        pendingProgressUndo = progressUndo(for: entry)
                        pendingLibraryUndo = nil
                        markWatchedThrough(entry, cursor)
                    },
                    clearProgress: {
                        pendingProgressUndo = progressUndo(for: entry)
                        pendingLibraryUndo = nil
                        clearProgress(entry)
                    }
                )
                .presentationDetents([.medium])
            }
            .safeAreaInset(edge: .bottom) {
                if let pendingLibraryUndo {
                    SeriesUndoBar(
                        title: String(format: L10n.string(pendingLibraryUndo.messageKey), pendingLibraryUndo.title),
                        undo: {
                            applyLibraryUndo(pendingLibraryUndo)
                            self.pendingLibraryUndo = nil
                        },
                        dismiss: {
                            self.pendingLibraryUndo = nil
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.regularMaterial)
                } else if let pendingProgressUndo {
                    SeriesUndoBar(
                        title: String(format: L10n.string(pendingProgressUndo.messageKey), pendingProgressUndo.title),
                        undo: {
                            store.restoreProgress(
                                status: pendingProgressUndo.status,
                                lastWatchedEpisodeCursor: pendingProgressUndo.lastWatchedEpisodeCursor,
                                for: pendingProgressUndo.entryId
                            )
                            self.pendingProgressUndo = nil
                        },
                        dismiss: {
                            self.pendingProgressUndo = nil
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.regularMaterial)
                }
            }
        }
    }

    private func applyLibraryUndo(_ undo: PendingLibraryMutationUndo) {
        switch undo.action {
        case .restore:
            store.restore(undo.entryId)
        case .archive:
            store.archive(undo.entryId)
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
        if entry.status == .wantToWatch {
            return "\(statusTitle(entry.status)) · \(String(format: L10n.string("home.queue.wantToWatch.progress"), cursorLabel(entry.nextEpisodeCursor)))"
        }
        return "\(statusTitle(entry.status)) · \(entry.progressLabel)"
    }

    private func quickProgressTitle(for entry: SeriesLibraryEntry) -> String {
        let actionTitle = entry.status == .wantToWatch ? L10n.string("home.start") : L10n.string("home.next")
        return "\(actionTitle) \(cursorLabel(entry.nextEpisodeCursor))"
    }

    private func previousProgressTitle(for entry: SeriesLibraryEntry) -> String {
        entry.lastWatchedEpisodeCursor?.previousEpisode == nil
            ? L10n.string("home.notStarted")
            : L10n.string("home.previous")
    }

    private func progressUndo(
        for entry: SeriesLibraryEntry,
        messageKey: String = "home.undo.progress"
    ) -> PendingProgressUndo {
        PendingProgressUndo(
            entryId: entry.id,
            title: entry.title,
            messageKey: messageKey,
            status: entry.status,
            lastWatchedEpisodeCursor: entry.lastWatchedEpisodeCursor
        )
    }

    private func filterTitle(_ filter: SeriesLibraryFilter) -> String {
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
    let editProgress: (() -> Void)?
    @ViewBuilder let menuContent: () -> MenuContent

    var body: some View {
        HStack(spacing: 12) {
            if let editProgress {
                Button(action: editProgress) {
                    rowContent
                }
                .buttonStyle(.plain)
                .accessibilityHint(L10n.string("home.adjust"))
            } else {
                rowContent
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

    private var rowContent: some View {
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
        }
    }
}

private struct SeriesAddSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var store: SeriesLibraryStore
    let canAddSeries: Bool
    let remainingSeriesCount: Int?
    let openProPaywall: () -> Void
    let didAddSeries: (SeriesLibraryEntry) -> Void

    @State private var query = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        TextField(L10n.string("add.search.placeholder"), text: $query)
                            .font(.system(size: 24, weight: .bold))
                            .textFieldStyle(.plain)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.done)
                            .onSubmit {
                                addSeries()
                            }

                        Rectangle()
                            .fill(Color.primary.opacity(0.12))
                            .frame(height: 1)
                    }
                    .padding(18)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    }

                    Button {
                        addSeries()
                    } label: {
                        Label(L10n.string("add.action"), systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!canSubmit)

                    VStack(alignment: .leading, spacing: 10) {
                        Text(limitText)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        if shouldShowUpgradeAction {
                            Button {
                                openProPaywall()
                            } label: {
                                Label(L10n.string("add.footer.upgrade"), systemImage: "sparkles")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }

                    if matchingEntries.isEmpty == false {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(L10n.string("add.matches.title"))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.secondary)

                            VStack(spacing: 0) {
                                ForEach(matchingEntries) { entry in
                                    HStack(spacing: 12) {
                                        SeriesPosterMark(seed: entry.fallbackVisualSeed ?? entry.title, size: 34)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(entry.title)
                                                .font(.system(size: 15, weight: .semibold))
                                            Text(matchDetail(for: entry))
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer(minLength: 0)
                                    }
                                    .padding(.vertical, 8)

                                    if entry.id != matchingEntries.last?.id {
                                        Divider()
                                    }
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
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

    private var shouldShowUpgradeAction: Bool {
        remainingSeriesCount != nil && !canAddSeries
    }

    private var canSubmit: Bool {
        canAddSeries && query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private var limitText: String {
        guard let remainingSeriesCount else {
            return "\(L10n.string("add.footer.pro"))\n\(L10n.string("add.footer.hint"))"
        }
        if canAddSeries {
            return "\(String(format: L10n.string("add.footer.remaining"), remainingSeriesCount))\n\(L10n.string("add.footer.hint"))"
        }
        return L10n.string("add.footer.limitReached")
    }

    private func matchDetail(for entry: SeriesLibraryEntry) -> String {
        if entry.status == .wantToWatch {
            return "\(statusTitle(entry.status)) · \(String(format: L10n.string("home.queue.wantToWatch.progress"), cursorLabel(entry.nextEpisodeCursor)))"
        }
        return "\(statusTitle(entry.status)) · \(entry.progressLabel)"
    }

    private func addSeries() {
        guard let entry = store.addLocalSeries(title: query) else {
            return
        }
        didAddSeries(entry)
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
        VStack(alignment: .leading, spacing: 22) {
            ViewThatFits(in: .horizontal) {
                horizontalHeader
                verticalHeader
            }

            SeriesPrimaryContinueButton(
                title: primaryActionTitle,
                episodeLabel: cursorLabel(entry.nextEpisodeCursor),
                action: markNext
            )

            HStack(spacing: 12) {
                if entry.lastWatchedEpisodeCursor != nil {
                    SeriesEpisodeChip(
                        title: L10n.string("home.previous"),
                        value: previousLabel,
                        systemImage: "arrow.counterclockwise",
                        action: markPrevious
                    )
                }

                Button(action: editProgress) {
                    Label(progressEditTitle, systemImage: "slider.horizontal.3")
                        .frame(maxWidth: .infinity, minHeight: 96)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .padding(22)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private var horizontalHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            SeriesPosterMark(seed: entry.fallbackVisualSeed ?? entry.title, size: 118)
            titleBlock
                .padding(.top, 3)
            Spacer(minLength: 0)
            actionsMenu
        }
    }

    private var verticalHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                SeriesPosterMark(seed: entry.fallbackVisualSeed ?? entry.title, size: 96)
                Spacer(minLength: 0)
                actionsMenu
            }

            titleBlock
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(currentTitle)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text(entry.title)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(3)
                .minimumScaleFactor(0.78)
                .fixedSize(horizontal: false, vertical: true)

            Text(currentProgress)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }

    private var actionsMenu: some View {
        SeriesEntryActionsMenu(
            entry: entry,
            togglePinned: togglePinned,
            setStatus: setStatus,
            archive: archive,
            delete: delete
        )
    }

    private var currentTitle: String {
        entry.status == .wantToWatch
            ? L10n.string("home.current.wantToWatch.title")
            : L10n.string("home.current.title")
    }

    private var currentProgress: String {
        guard entry.status != .wantToWatch else {
            return String(format: L10n.string("home.queue.wantToWatch.progress"), cursorLabel(entry.nextEpisodeCursor))
        }
        return String(format: L10n.string("home.current.progress"), entry.progressLabel)
    }

    private var primaryActionTitle: String {
        entry.status == .wantToWatch ? L10n.string("home.start") : L10n.string("home.next")
    }

    private var progressEditTitle: String {
        entry.lastWatchedEpisodeCursor == nil ? L10n.string("home.chooseEpisode") : L10n.string("home.adjust")
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
            .frame(maxWidth: .infinity, minHeight: 104)
            .padding(.horizontal, 20)
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
        VStack(alignment: .leading, spacing: 8) {
            Text(queueTitle)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                ForEach(entries) { entry in
                    HStack(spacing: 12) {
                        SeriesPosterMark(seed: entry.fallbackVisualSeed ?? entry.title, size: 40)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(entry.title)
                                .font(.system(size: 15, weight: .semibold))
                                .lineLimit(1)
                            Text(queueProgress(for: entry))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Button {
                            markNext(entry)
                        } label: {
                            Image(systemName: "checkmark")
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel(primaryActionTitle(for: entry))

                        SeriesEntryActionsMenu(
                            entry: entry,
                            togglePinned: { togglePinned(entry) },
                            editProgress: { editProgress(entry) },
                            setStatus: { setStatus(entry, $0) },
                            archive: { archive(entry) },
                            delete: { delete(entry) }
                        )
                    }
                    .padding(10)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .opacity(0.92)
                }
            }
        }
    }

    private var queueTitle: String {
        entries.allSatisfy { $0.status == .wantToWatch }
            ? L10n.string("home.queue.wantToWatch.title")
            : L10n.string("home.queue.title")
    }

    private func queueProgress(for entry: SeriesLibraryEntry) -> String {
        guard entry.status != .wantToWatch else {
            return String(format: L10n.string("home.queue.wantToWatch.progress"), cursorLabel(entry.nextEpisodeCursor))
        }
        return String(format: L10n.string("home.queue.progress"), entry.progressLabel, cursorLabel(entry.nextEpisodeCursor))
    }

    private func primaryActionTitle(for entry: SeriesLibraryEntry) -> String {
        entry.status == .wantToWatch ? L10n.string("home.start") : L10n.string("shell.watch.next")
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
            if status != entry.status {
                Button {
                    setStatus(status)
                } label: {
                    Label(statusTitle(status), systemImage: statusIcon(status, isSelected: false))
                }
            }
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
    let clearProgress: () -> Void

    @State private var seasonNumber: Int
    @State private var episodeNumber: Int

    init(
        entry: SeriesLibraryEntry,
        markWatchedThrough: @escaping (SeriesEpisodeCursor) -> Void,
        clearProgress: @escaping () -> Void
    ) {
        self.entry = entry
        self.markWatchedThrough = markWatchedThrough
        self.clearProgress = clearProgress
        let cursor = entry.lastWatchedEpisodeCursor ?? SeriesEpisodeCursor(seasonNumber: 1, episodeNumber: 1)
        _seasonNumber = State(initialValue: cursor.seasonNumber)
        _episodeNumber = State(initialValue: cursor.episodeNumber)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .lastTextBaseline) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.lastWatchedEpisodeCursor == nil ? L10n.string("home.editor.startPrompt") : L10n.string("home.adjust"))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                Text(selectedCursorLabel)
                                    .font(.system(size: 40, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                            }

                            Spacer()

                            Image(systemName: "play.rectangle.on.rectangle")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }

                        SeriesProgressNumberControl(
                            title: L10n.string("home.editor.season.short"),
                            value: seasonNumber,
                            decrement: { seasonNumber = max(1, seasonNumber - 1) },
                            increment: { seasonNumber = min(99, seasonNumber + 1) },
                            canDecrement: seasonNumber > 1,
                            canIncrement: seasonNumber < 99
                        )

                        SeriesProgressNumberControl(
                            title: L10n.string("home.editor.episode.short"),
                            value: episodeNumber,
                            decrement: { episodeNumber = max(1, episodeNumber - 1) },
                            increment: { episodeNumber = min(999, episodeNumber + 1) },
                            canDecrement: episodeNumber > 1,
                            canIncrement: episodeNumber < 999
                        )
                    }
                } footer: {
                    Text(L10n.string("home.editor.footer"))
                }

                Section {
                    Button {
                        markWatchedThrough(SeriesEpisodeCursor(seasonNumber: seasonNumber, episodeNumber: episodeNumber))
                        dismiss()
                    } label: {
                        Text(confirmTitle)
                            .frame(maxWidth: .infinity)
                    }

                    if entry.lastWatchedEpisodeCursor != nil {
                        Button(role: .destructive) {
                            clearProgress()
                            dismiss()
                        } label: {
                            Text(L10n.string("home.notStarted"))
                                .frame(maxWidth: .infinity)
                        }
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

    private var confirmTitle: String {
        entry.lastWatchedEpisodeCursor == nil ? L10n.string("home.editor.confirmFirstPoint") : L10n.string("home.editor.confirm")
    }

    private var selectedCursorLabel: String {
        cursorLabel(SeriesEpisodeCursor(seasonNumber: seasonNumber, episodeNumber: episodeNumber))
    }
}

private struct SeriesProgressNumberControl: View {
    let title: String
    let value: Int
    let decrement: () -> Void
    let increment: () -> Void
    let canDecrement: Bool
    let canIncrement: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.headline)
                .monospacedDigit()

            Spacer()

            Button(action: decrement) {
                Image(systemName: "minus")
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.bordered)
            .disabled(!canDecrement)
            .accessibilityLabel("\(title) -1")

            Text("\(value)")
                .font(.headline)
                .monospacedDigit()
                .frame(minWidth: 34)

            Button(action: increment) {
                Image(systemName: "plus")
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canIncrement)
            .accessibilityLabel("\(title) +1")
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
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
    let addSeries: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                SeriesPosterMark(seed: "Series AV", size: 74)

                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(.ultraThinMaterial, in: Circle())
            }

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.string("home.empty.title"))
                        .font(.system(size: 22, weight: .bold))
                    Text(L10n.string("home.empty.subtitle"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button(action: addSeries) {
                    Label(L10n.string("home.add"), systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private func cursorLabel(_ cursor: SeriesEpisodeCursor) -> String {
    "S\(cursor.seasonNumber) E\(cursor.episodeNumber)"
}
