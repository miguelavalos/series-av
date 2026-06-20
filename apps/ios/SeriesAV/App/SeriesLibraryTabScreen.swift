import AVAppShellFoundation
import AVBrandFoundation
import SwiftUI

struct SeriesLibraryTabScreen: View {
    @Bindable var store: SeriesLibraryStore
    let accessController: SeriesAccessController?

    @State private var query = ""
    @State private var selectedFilter: SeriesLibraryFilter = .all
    @State private var editorEntry: SeriesLibraryEntry?
    @State private var detailEntry: SeriesLibraryEntry?
    @State private var pendingLibraryUndo: PendingLibraryMutationUndo?
    @State private var pendingProgressUndo: PendingProgressUndo?

    init(store: SeriesLibraryStore, accessController: SeriesAccessController? = nil) {
        self.store = store
        self.accessController = accessController
    }

    var body: some View {
        AVAppShellScrollableScreenScaffold(
            alignment: .leading,
            spacing: 22
        ) {
            AVBrandSurface.shellBackground
        } content: {
            screenTitle(
                title: L10n.string("library.title"),
                subtitle: librarySubtitle
            )

            libraryControls

            if isShowingEmptyState {
                AVAppShellCard {
                    ContentUnavailableView(
                        emptyTitle,
                        systemImage: "books.vertical",
                        description: Text(emptySubtitle)
                    )
                }
            } else {
                if selectedFilter == .all && normalizedQuery.isEmpty {
                    SeriesUpcomingEpisodesSection(
                        entries: store.activeEntries,
                        editProgress: { entry in
                            editorEntry = entry
                        }
                    )
                }

                if filteredActiveEntries.isEmpty == false {
                    librarySection(title: L10n.string("library.active.title"), entries: filteredActiveEntries, isArchived: false)
                }

                if filteredArchivedEntries.isEmpty == false {
                    librarySection(title: L10n.string("library.archived.title"), entries: filteredArchivedEntries, isArchived: true)
                }
            }
        }
        .sheet(item: $editorEntry) { entry in
            SeriesProgressEditorSheet(
                entry: entry,
                markWatchedThrough: { cursor in
                    pendingProgressUndo = progressUndo(for: entry)
                    pendingLibraryUndo = nil
                    store.markWatchedThrough(cursor, for: entry.id)
                },
                clearProgress: {
                    pendingProgressUndo = progressUndo(for: entry)
                    pendingLibraryUndo = nil
                    store.clearProgress(for: entry.id)
                }
            )
            .presentationDetents([.large])
        }
        .sheet(item: $detailEntry) { entry in
            SeriesDetailScreen(
                entry: entry,
                markNext: { entry in
                    pendingProgressUndo = progressUndo(for: entry)
                    pendingLibraryUndo = nil
                    store.markNextEpisodeWatched(for: entry.id)
                },
                markWatchedThrough: { entry, cursor in
                    pendingProgressUndo = progressUndo(for: entry)
                    pendingLibraryUndo = nil
                    store.markWatchedThrough(cursor, for: entry.id)
                },
                clearProgress: { entry in
                    pendingProgressUndo = progressUndo(for: entry)
                    pendingLibraryUndo = nil
                    store.clearProgress(for: entry.id)
                },
                shareInviteClient: accessController.map { SeriesShareInviteClient(apiClient: $0.authenticatedAPIClient()) }
            )
            .presentationDetents([.large])
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

    private var libraryControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AVBrandColor.accent)

                TextField(L10n.string("library.search.placeholder"), text: $query)
                    .font(.system(size: 17, weight: .semibold))
                    .textInputAutocapitalization(.words)
                    .submitLabel(.search)

                if normalizedQuery.isEmpty == false {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.string("common.clear"))
                }
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SeriesLibraryFilter.allCases, id: \.self) { filter in
                        Button {
                            selectedFilter = filter
                        } label: {
                            Text(filterShortTitle(filter))
                                .font(.system(size: 13, weight: .bold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(selectedFilter == filter ? Color.white : Color.primary)
                        .background(selectedFilter == filter ? AVBrandColor.accent : Color(.secondarySystemGroupedBackground), in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(selectedFilter == filter ? AVBrandColor.accent.opacity(0.8) : Color.primary.opacity(0.08), lineWidth: 1)
                        }
                    }
                }
            }
        }
    }

    private func screenTitle(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 34, weight: .black))
                .foregroundStyle(AVBrandColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(subtitle)
                .font(AVBrandTypography.body)
                .foregroundStyle(AVBrandColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func librarySection(title: String, entries: [SeriesLibraryEntry], isArchived: Bool) -> some View {
        AVAppShellCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AVBrandColor.textSecondary)

                ForEach(entries) { entry in
                    SeriesLibraryRow(
                        entry: entry,
                        detail: isArchived ? L10n.string("library.archived.detail") : libraryDetail(for: entry),
                        editProgress: isArchived ? nil : { editorEntry = entry }
                    ) {
                        if isArchived {
                            archivedMenu(for: entry)
                        } else {
                            activeMenu(for: entry)
                        }
                    }

                    if entry.id != entries.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func activeMenu(for entry: SeriesLibraryEntry) -> some View {
        Button {
            detailEntry = entry
        } label: {
            Label(L10n.string("detail.open"), systemImage: "info.circle")
        }

        Divider()

        Button {
            pendingProgressUndo = progressUndo(for: entry)
            pendingLibraryUndo = nil
            store.markNextEpisodeWatched(for: entry.id)
        } label: {
            Label(quickProgressTitle(for: entry), systemImage: "checkmark.circle")
        }

        if entry.lastWatchedEpisodeCursor?.canStepBackQuickly == true {
            Button {
                pendingProgressUndo = progressUndo(for: entry)
                pendingLibraryUndo = nil
                store.markPreviousEpisodeWatched(for: entry.id)
            } label: {
                Label(previousProgressTitle(for: entry), systemImage: "arrow.uturn.backward.circle")
            }
        }

        SeriesStatusButtons(entry: entry) { status in
            pendingProgressUndo = progressUndo(for: entry, messageKey: "home.undo.status")
            pendingLibraryUndo = nil
            store.setStatus(status, for: entry.id)
        }

        Divider()

        Button {
            pendingLibraryUndo = PendingLibraryMutationUndo(
                entryId: entry.id,
                title: entry.title,
                messageKey: "home.undo.archived",
                action: .restoreActive
            )
            pendingProgressUndo = nil
            store.archive(entry.id)
        } label: {
            Label(L10n.string("home.archive"), systemImage: "archivebox")
        }

        Divider()

        Button(role: .destructive) {
            pendingLibraryUndo = PendingLibraryMutationUndo(
                entryId: entry.id,
                title: entry.title,
                messageKey: "home.undo.deleted",
                action: .restoreActive
            )
            pendingProgressUndo = nil
            store.delete(entry.id)
        } label: {
            Label(L10n.string("home.delete"), systemImage: "trash")
        }
    }

    @ViewBuilder
    private func archivedMenu(for entry: SeriesLibraryEntry) -> some View {
        Button {
            detailEntry = entry
        } label: {
            Label(L10n.string("detail.open"), systemImage: "info.circle")
        }

        Divider()

        Button {
            pendingLibraryUndo = PendingLibraryMutationUndo(
                entryId: entry.id,
                title: entry.title,
                messageKey: "home.undo.restored",
                action: .archive
            )
            pendingProgressUndo = nil
            store.restore(entry.id)
        } label: {
            Label(L10n.string("library.restore"), systemImage: "arrow.uturn.backward")
        }

        Divider()

        Button(role: .destructive) {
            pendingLibraryUndo = PendingLibraryMutationUndo(
                entryId: entry.id,
                title: entry.title,
                messageKey: "home.undo.deleted",
                action: .restoreArchived
            )
            pendingProgressUndo = nil
            store.delete(entry.id)
        } label: {
            Label(L10n.string("home.delete"), systemImage: "trash")
        }
    }

    private func applyLibraryUndo(_ undo: PendingLibraryMutationUndo) {
        switch undo.action {
        case .restoreActive:
            store.restore(undo.entryId)
        case .restoreArchived:
            store.restore(undo.entryId)
            store.archive(undo.entryId)
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

    private var librarySubtitle: String {
        let activeCount = store.activeEntries.count
        let archivedCount = store.archivedEntries.count
        if activeCount == 0 && archivedCount == 0 {
            return L10n.string("library.empty.subtitle")
        }
        return "\(filterTitle(selectedFilter)) · \(activeCount + archivedCount)"
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

    private func filterShortTitle(_ filter: SeriesLibraryFilter) -> String {
        switch filter {
        case .archived:
            return L10n.string("library.filter.archived.short")
        default:
            return filterTitle(filter)
        }
    }
}
