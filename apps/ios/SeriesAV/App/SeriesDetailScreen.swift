import AVAppShellFoundation
import AVBrandFoundation
import AVExternalLinkFoundation
import SwiftUI

struct SeriesDetailScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var externalLinkPreferences: AppExternalLinkPreferencesController

    let catalogItem: SeriesCatalogItem?
    let entry: SeriesLibraryEntry?
    let canFollow: Bool
    let follow: (() -> Void)?
    let markNext: ((SeriesLibraryEntry) -> Void)?
    let markWatchedThrough: ((SeriesLibraryEntry, SeriesEpisodeCursor) -> Void)?
    let clearProgress: ((SeriesLibraryEntry) -> Void)?
    let setPinned: ((SeriesLibraryEntry, Bool) -> Void)?
    let setPrivateNote: ((SeriesLibraryEntry, String?) -> Void)?
    let archive: ((SeriesLibraryEntry) -> Void)?
    let delete: ((SeriesLibraryEntry) -> Void)?

    private let episodeGuideClient: SeriesEpisodeGuideClient
    private let detailClient: SeriesDetailClient
    private let shareInviteClient: SeriesShareInviteClient?

    @State private var guideState: SeriesDetailGuideState = .loading
    @State private var resolvedCatalogItem: SeriesCatalogItem?
    @State private var isShowingProgressEditor = false
    @State private var isShowingPrivateNoteEditor = false
    @State private var displayedPinnedOverride: Bool?
    @State private var hasDisplayedPrivateNoteOverride = false
    @State private var displayedPrivateNote: String?
    @State private var displayedLastWatchedEpisodeCursor: SeriesEpisodeCursor?
    @State private var isShowingShareComposer = false
    @State private var inAppBrowserDestination: SeriesInAppBrowserDestination?
    @State private var shareSheetItem: SeriesShareSheetItem?

    init(
        catalogItem: SeriesCatalogItem? = nil,
        entry: SeriesLibraryEntry? = nil,
        canFollow: Bool = false,
        follow: (() -> Void)? = nil,
        markNext: ((SeriesLibraryEntry) -> Void)? = nil,
        markWatchedThrough: ((SeriesLibraryEntry, SeriesEpisodeCursor) -> Void)? = nil,
        clearProgress: ((SeriesLibraryEntry) -> Void)? = nil,
        setPinned: ((SeriesLibraryEntry, Bool) -> Void)? = nil,
        setPrivateNote: ((SeriesLibraryEntry, String?) -> Void)? = nil,
        archive: ((SeriesLibraryEntry) -> Void)? = nil,
        delete: ((SeriesLibraryEntry) -> Void)? = nil,
        episodeGuideClient: SeriesEpisodeGuideClient = SeriesEpisodeGuideClient(apiClient: SeriesAVAPIClient()),
        detailClient: SeriesDetailClient = SeriesDetailClient(),
        shareInviteClient: SeriesShareInviteClient? = nil
    ) {
        self.catalogItem = catalogItem
        self.entry = entry
        self.canFollow = canFollow
        self.follow = follow
        self.markNext = markNext
        self.markWatchedThrough = markWatchedThrough
        self.clearProgress = clearProgress
        self.setPinned = setPinned
        self.setPrivateNote = setPrivateNote
        self.archive = archive
        self.delete = delete
        self.episodeGuideClient = episodeGuideClient
        self.detailClient = detailClient
        self.shareInviteClient = shareInviteClient
        _displayedLastWatchedEpisodeCursor = State(initialValue: entry?.lastWatchedEpisodeCursor)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    sourcesSection
                    trackingSection
                    privateNoteSection
                    libraryManagementSection
                    guideSection
                }
                .padding(18)
            }
            .background(AVBrandSurface.shellBackground.ignoresSafeArea())
            .navigationTitle(L10n.string("detail.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("common.close")) {
                        dismiss()
                    }
                }
                if shareInviteClient != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            isShowingShareComposer = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .disabled(seriesId.isEmpty)
                        .accessibilityLabel(L10n.string("detail.share"))
                    }
                }
            }
            .task(id: seriesId) {
                async let detailTask: Void = loadCatalogDetailIfNeeded()
                async let guideTask: Void = loadEpisodeGuide()
                _ = await (detailTask, guideTask)
            }
            .sheet(isPresented: $isShowingProgressEditor) {
                if let entry,
                   let markWatchedThrough,
                   let clearProgress {
                    SeriesProgressEditorSheet(
                        entry: entry,
                        markWatchedThrough: { cursor in
                            displayedLastWatchedEpisodeCursor = cursor
                            markWatchedThrough(entry, cursor)
                        },
                        clearProgress: {
                            displayedLastWatchedEpisodeCursor = nil
                            clearProgress(entry)
                        }
                    )
                    .presentationDetents([.large])
                }
            }
            .sheet(item: $inAppBrowserDestination) { destination in
                SeriesInAppBrowserView(url: destination.url)
                    .ignoresSafeArea()
            }
            .sheet(isPresented: $isShowingPrivateNoteEditor) {
                if let entry, let setPrivateNote {
                    SeriesPrivateNoteEditorSheet(
                        entry: entry,
                        save: { note in
                            hasDisplayedPrivateNoteOverride = true
                            displayedPrivateNote = Self.normalizedPrivateNote(note)
                            setPrivateNote(entry, note)
                        }
                    )
                    .presentationDetents([.medium, .large])
                }
            }
            .sheet(isPresented: $isShowingShareComposer) {
                SeriesShareInviteComposerSheet(
                    seriesTitle: title,
                    createInvite: createShareInvite(message:),
                    onCreated: { item in
                        shareSheetItem = item
                    }
                )
                .presentationDetents([.medium])
            }
            .sheet(item: $shareSheetItem) { item in
                ShareLink(item: item.url, subject: Text(item.subject), message: Text(item.message)) {
                    Label(L10n.string("detail.share.open"), systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(24)
                .presentationDetents([.height(140)])
            }
        }
    }

    private var header: some View {
        AVAppShellCard {
            HStack(alignment: .top, spacing: 16) {
                artwork

                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(AVBrandColor.textPrimary)
                        .lineLimit(3)
                        .minimumScaleFactor(0.72)
                        .fixedSize(horizontal: false, vertical: true)

                    if metadataText.isEmpty == false {
                        Text(metadataText)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let summary = effectiveCatalogItem?.summary?.trimmingCharacters(in: .whitespacesAndNewlines),
                       summary.isEmpty == false {
                        Text(summary)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AVBrandColor.textSecondary)
                            .lineLimit(4)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(L10n.string("detail.summary.unavailable"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AVBrandColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .layoutPriority(1)
            }
        }
    }

    private var trackingSection: some View {
        AVAppShellCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle(L10n.string("detail.tracking.title"))

                if let entry {
                    HStack(alignment: .center, spacing: 12) {
                        Label(statusTitle(entry.status), systemImage: detailStatusIcon(entry.status))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AVBrandColor.accent)

                        Text(trackingDetail(for: entry))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(spacing: 10) {
                        Button {
                            markNext?(entry)
                        } label: {
                            Image(systemName: entry.status == .wantToWatch ? "play.fill" : "checkmark")
                                .font(.system(size: 18, weight: .black))
                                .frame(width: 50, height: 50)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.black.opacity(0.84))
                        .background(AVBrandColor.accent, in: Circle())
                        .accessibilityLabel(nextActionTitle(for: entry))

                        Button {
                            isShowingProgressEditor = true
                        } label: {
                            Image(systemName: "scope")
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .accessibilityLabel(L10n.string("home.adjust"))

                        if let setPinned {
                            Button {
                                let nextPinned = currentIsPinned == false
                                displayedPinnedOverride = nextPinned
                                setPinned(entry, nextPinned)
                            } label: {
                                Image(systemName: currentIsPinned ? "pin.slash" : "pin")
                                    .frame(width: 44, height: 44)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                            .accessibilityLabel(pinTitle)
                        }
                    }
                } else if let follow {
                    Text(L10n.string("detail.tracking.notFollowed"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        follow()
                    } label: {
                        Label(L10n.string("search.follow"), systemImage: canFollow ? "plus" : "sparkles")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
        }
    }

    private var sourcesSection: some View {
        AVAppShellCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle(L10n.string("detail.sources.title"))

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10)], spacing: 10) {
                    ForEach(sourceLinks) { source in
                        Button {
                            openSource(source.url)
                        } label: {
                            Label(source.title, systemImage: source.systemImage)
                                .font(.system(size: 13, weight: .bold))
                                .frame(maxWidth: .infinity, minHeight: 42)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var libraryManagementSection: some View {
        if let entry, archive != nil || delete != nil {
            AVAppShellCard {
                VStack(alignment: .leading, spacing: 12) {
                    sectionTitle(L10n.string("library.title"))

                    HStack(spacing: 10) {
                        if let archive {
                            Button {
                                archive(entry)
                                dismiss()
                            } label: {
                                Label(L10n.string("home.archive"), systemImage: "archivebox")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                        }

                        if let delete {
                            Button(role: .destructive) {
                                delete(entry)
                                dismiss()
                            } label: {
                                Label(L10n.string("home.delete"), systemImage: "trash")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var privateNoteSection: some View {
        if entry != nil, setPrivateNote != nil {
            AVAppShellCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        sectionTitle(L10n.string("detail.privateNote.title"))
                        Spacer()
                        Button {
                            isShowingPrivateNoteEditor = true
                        } label: {
                            Image(systemName: "square.and.pencil")
                                .frame(width: 36, height: 36)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel(L10n.string("detail.privateNote.edit"))
                    }

                    if let note = currentPrivateNote?.trimmingCharacters(in: .whitespacesAndNewlines),
                       note.isEmpty == false {
                        Text(note)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(AVBrandColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(L10n.string("detail.privateNote.empty"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var guideSection: some View {
        AVAppShellCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle(L10n.string("detail.episodes.title"))

                switch guideState {
                case .loading:
                    SeriesDetailGuideSkeleton()
                case .loaded(let episodes):
                    if episodes.isEmpty {
                        ContentUnavailableView(
                            L10n.string("detail.episodes.unavailable"),
                            systemImage: "list.bullet.rectangle",
                            description: Text(L10n.string("detail.episodes.unavailable.detail"))
                        )
                    } else {
                        VStack(spacing: 8) {
                            ForEach(episodes.prefix(8), id: \.cursor) { episode in
                                SeriesDetailEpisodeRow(
                                    episode: episode,
                                    displayedLastWatchedEpisodeCursor: displayedLastWatchedEpisodeCursor,
                                    markWatchedThrough: markEpisodeWatchedThroughAction(for: episode)
                                )
                            }
                        }

                        if episodes.count > 8 {
                            Text(String(format: L10n.string("detail.episodes.more"), episodes.count - 8))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                    }
                case .failed:
                    ContentUnavailableView(
                        L10n.string("detail.episodes.unavailable"),
                        systemImage: "wifi.exclamationmark",
                        description: Text(L10n.string("detail.episodes.retryLater"))
                    )
                }
            }
        }
    }

    private var presentation: SeriesDetailPresentation {
        SeriesDetailPresentationBuilder.build(
            catalogItem: catalogItem,
            resolvedCatalogItem: resolvedCatalogItem,
            entry: entry,
            searchEngine: externalLinkPreferences.searchEngine,
            fallbackTitle: L10n.string("detail.title")
        )
    }

    private var currentPrivateNote: String? {
        hasDisplayedPrivateNoteOverride ? displayedPrivateNote : entry?.privateNote
    }

    private var currentIsPinned: Bool {
        displayedPinnedOverride ?? (entry?.isPinnedHomeSeries == true)
    }

    private var pinTitle: String {
        currentIsPinned ? L10n.string("home.unpin") : L10n.string("home.pin")
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .black))
            .foregroundStyle(AVBrandColor.textSecondary)
            .textCase(.uppercase)
    }

    @MainActor
    private func createShareInvite(message: String?) async throws -> SeriesShareSheetItem {
        guard let shareInviteClient else {
            throw SeriesShareInviteComposerError.missingClient
        }

        let response = try await shareInviteClient.createRecommendation(seriesId: seriesId, message: message)
        let url = shareURL(for: response.token)
        return SeriesShareSheetItem(
            title: title,
            url: url,
            message: Self.shareMessage(for: title, url: url)
        )
    }

    private func shareURL(for token: String) -> URL {
        let encodedToken = token.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? token
        return AppConfig.seriesWebBaseURL
            .appending(path: "i")
            .appending(path: "r")
            .appending(path: encodedToken)
    }

    private static func shareMessage(for title: String, url: URL) -> String {
        String(format: L10n.string("detail.share.message"), title, url.absoluteString)
    }

    private static func normalizedPrivateNote(_ note: String?) -> String? {
        let normalizedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalizedNote?.isEmpty == false ? normalizedNote : nil
    }

    @ViewBuilder
    private var artwork: some View {
        if let detailEntry = presentation.detailEntry {
            SeriesEntryArtworkView(entry: detailEntry, size: 92)
        } else if let url = effectiveCatalogItem?.displayArtwork.url {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    SeriesPosterMark(seed: title, size: 92)
                }
            }
            .frame(width: 92, height: 128)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.24), lineWidth: 1)
            }
        } else {
            SeriesPosterMark(seed: title, size: 92)
                .frame(width: 92, height: 128)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var seriesId: String {
        entry?.seriesId ?? effectiveCatalogItem?.seriesId ?? ""
    }

    private var title: String {
        presentation.title
    }

    private var metadataText: String {
        presentation.metadataText
    }

    private var effectiveCatalogItem: SeriesCatalogItem? {
        catalogItem ?? resolvedCatalogItem
    }

    private var sourceLinks: [SeriesExternalSourceLink] {
        presentation.sourceLinks
    }

    private func trackingDetail(for entry: SeriesLibraryEntry) -> String {
        SeriesDetailPresentationBuilder.trackingDetail(for: entry)
    }

    private func nextActionTitle(for entry: SeriesLibraryEntry) -> String {
        SeriesDetailPresentationBuilder.nextActionTitle(for: entry)
    }

    private func detailStatusIcon(_ status: SeriesLibraryEntryStatus) -> String {
        SeriesDetailPresentationBuilder.detailStatusIcon(status)
    }

    private func markEpisodeWatchedThroughAction(for episode: SeriesEpisodeGuideItem) -> (() -> Void)? {
        guard let entry, let markWatchedThrough else {
            return nil
        }

        return {
            displayedLastWatchedEpisodeCursor = episode.cursor
            markWatchedThrough(entry, episode.cursor)
        }
    }

    private func openSource(_ url: URL) {
        switch externalLinkPreferences.webOpenMode {
        case .inApp:
            inAppBrowserDestination = SeriesInAppBrowserDestination(url: url)
        case .system:
            openURL(url)
        }
    }

    private func loadEpisodeGuide() async {
        guard seriesId.isEmpty == false else {
            guideState = .failed
            return
        }

        guideState = .loading
        do {
            let response = try await episodeGuideClient.episodes(
                for: seriesId,
                lastWatchedEpisodeCursor: entry?.lastWatchedEpisodeCursor
            )
            guideState = .loaded(response.items)
        } catch {
            guideState = .failed
        }
    }

    private func loadCatalogDetailIfNeeded() async {
        guard catalogItem == nil, seriesId.isEmpty == false else {
            return
        }

        do {
            let response = try await detailClient.series(seriesId, locale: Locale.current.identifier)
            resolvedCatalogItem = response.summary
        } catch {
            resolvedCatalogItem = nil
        }
    }
}

private struct SeriesShareSheetItem: Identifiable {
    let title: String
    let url: URL
    let message: String

    var id: URL { url }
    var subject: String { title }
}

private enum SeriesShareInviteComposerError: Error {
    case missingClient
}

private struct SeriesPrivateNoteEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let entry: SeriesLibraryEntry
    let save: (String?) -> Void

    @State private var note: String

    init(entry: SeriesLibraryEntry, save: @escaping (String?) -> Void) {
        self.entry = entry
        self.save = save
        _note = State(initialValue: entry.privateNote ?? "")
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text(entry.title)
                    .font(.headline)
                    .foregroundStyle(AVBrandColor.textPrimary)

                TextEditor(text: $note)
                    .font(.body)
                    .frame(minHeight: 180)
                    .padding(10)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    }
                    .onChange(of: note) { _, value in
                        if value.count > 2000 {
                            note = String(value.prefix(2000))
                        }
                    }

                Text(String(format: L10n.string("detail.privateNote.count"), note.count, 2000))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)
            }
            .padding(20)
            .background(AVBrandSurface.shellBackground.ignoresSafeArea())
            .navigationTitle(L10n.string("detail.privateNote.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("common.cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string("common.save")) {
                        save(note)
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct SeriesShareInviteComposerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let seriesTitle: String
    let createInvite: (String?) async throws -> SeriesShareSheetItem
    let onCreated: (SeriesShareSheetItem) -> Void

    @State private var message = ""
    @State private var isCreating = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(seriesTitle)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(AVBrandColor.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)

                    Text(L10n.string("detail.share.composer.detail"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                TextEditor(text: $message)
                    .font(.system(size: 16, weight: .medium))
                    .frame(minHeight: 108)
                    .padding(8)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(alignment: .topLeading) {
                        if message.isEmpty {
                            Text(L10n.string("detail.share.message.placeholder"))
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 13)
                                .padding(.vertical, 16)
                                .allowsHitTesting(false)
                        }
                    }
                    .onChange(of: message) { _, newValue in
                        if newValue.count > 280 {
                            message = String(newValue.prefix(280))
                        }
                    }

                HStack {
                    Spacer()
                    Text("\(message.count)/280")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    Task { await share() }
                } label: {
                    Label(isCreating ? L10n.string("detail.share.creating") : L10n.string("detail.share.create"), systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isCreating)

                Spacer(minLength: 0)
            }
            .padding(20)
            .background(AVBrandSurface.shellBackground.ignoresSafeArea())
            .navigationTitle(L10n.string("detail.share"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("common.cancel")) {
                        dismiss()
                    }
                    .disabled(isCreating)
                }
            }
        }
    }

    @MainActor
    private func share() async {
        isCreating = true
        errorMessage = nil
        defer { isCreating = false }

        do {
            let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
            let item = try await createInvite(trimmedMessage.isEmpty ? nil : trimmedMessage)
            dismiss()
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 250_000_000)
                onCreated(item)
            }
        } catch {
            errorMessage = L10n.string("detail.share.failed")
        }
    }
}

private enum SeriesDetailGuideState {
    case loading
    case loaded([SeriesEpisodeGuideItem])
    case failed
}

private struct SeriesDetailEpisodeRow: View {
    let episode: SeriesEpisodeGuideItem
    let displayedLastWatchedEpisodeCursor: SeriesEpisodeCursor?
    let markWatchedThrough: (() -> Void)?

    var body: some View {
        if let markWatchedThrough {
            Button(action: markWatchedThrough) {
                rowContent
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(format: L10n.string("home.editor.confirmThrough"), cursorLabel(episode.cursor)))
        } else {
            rowContent
        }
    }

    private var episodeTitle: String {
        guard let title = episode.title?.trimmingCharacters(in: .whitespacesAndNewlines),
              title.isEmpty == false else {
            return L10n.string("detail.episodes.untitled")
        }
        return title
    }

    private var rowContent: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(cursorLabel(episode.cursor))
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(cursorColor)
                .monospacedDigit()
                .frame(width: 54, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(episodeTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AVBrandColor.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if let airDate = episode.airDate, airDate.isEmpty == false {
                    Text(airDate)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Text(stateTitle)
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(stateTitleColor)
                    .textCase(.uppercase)
            }

            Spacer(minLength: 0)

            if markWatchedThrough != nil {
                stateIcon
            }
        }
        .padding(10)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(rowBorderColor, lineWidth: rowBorderWidth)
        )
    }

    private var stateIcon: some View {
        Image(systemName: stateIconName)
            .font(.system(size: stateIconSize, weight: .black))
            .foregroundStyle(stateIconColor)
            .frame(width: 34, height: 34)
            .background(stateIconBackground, in: Circle())
            .accessibilityHidden(true)
    }

    private var stateIconName: String {
        switch effectiveRelativeState {
        case .watched:
            "checkmark"
        case .current, .next, .pending:
            "checkmark.circle.fill"
        }
    }

    private var stateTitle: String {
        switch effectiveRelativeState {
        case .watched:
            L10n.string("detail.episodes.state.watched")
        case .current:
            L10n.string("detail.episodes.state.current")
        case .next:
            L10n.string("detail.episodes.state.next")
        case .pending:
            L10n.string("detail.episodes.state.pending")
        }
    }

    private var stateTitleColor: Color {
        switch effectiveRelativeState {
        case .watched:
            AVBrandColor.textSecondary
        case .current, .next, .pending:
            AVBrandColor.accent
        }
    }

    private var stateIconSize: CGFloat {
        switch effectiveRelativeState {
        case .watched:
            13
        case .current, .next, .pending:
            15
        }
    }

    private var stateIconColor: Color {
        switch effectiveRelativeState {
        case .watched:
            AVBrandColor.textSecondary
        case .current, .next, .pending:
            Color.black.opacity(0.84)
        }
    }

    private var stateIconBackground: Color {
        switch effectiveRelativeState {
        case .watched:
            Color(.secondarySystemGroupedBackground)
        case .current, .next, .pending:
            AVBrandColor.accent
        }
    }

    private var cursorColor: Color {
        switch effectiveRelativeState {
        case .watched:
            AVBrandColor.textSecondary
        case .current, .next, .pending:
            AVBrandColor.accent
        }
    }

    private var rowBackground: Color {
        switch effectiveRelativeState {
        case .watched:
            Color(.tertiarySystemGroupedBackground).opacity(0.44)
        case .current, .next:
            AVBrandColor.accent.opacity(0.11)
        case .pending:
            Color(.tertiarySystemGroupedBackground).opacity(0.62)
        }
    }

    private var rowBorderColor: Color {
        switch effectiveRelativeState {
        case .current, .next:
            AVBrandColor.accent.opacity(0.34)
        case .watched, .pending:
            Color.clear
        }
    }

    private var rowBorderWidth: CGFloat {
        switch effectiveRelativeState {
        case .current, .next:
            1
        case .watched, .pending:
            0
        }
    }

    private var effectiveRelativeState: SeriesEpisodeGuideRelativeState {
        guard let displayedLastWatchedEpisodeCursor else {
            return episode.cursor == SeriesEpisodeCursor(seasonNumber: 1, episodeNumber: 1) ? .next : .pending
        }

        if episode.cursor < displayedLastWatchedEpisodeCursor {
            return .watched
        }
        if episode.cursor == displayedLastWatchedEpisodeCursor {
            return .current
        }
        if episode.cursor == displayedLastWatchedEpisodeCursor.nextEpisode {
            return .next
        }
        return .pending
    }
}

private struct SeriesDetailGuideSkeleton: View {
    var body: some View {
        VStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { index in
                HStack(spacing: 10) {
                    skeletonLine(width: 54, height: 14)
                    VStack(alignment: .leading, spacing: 7) {
                        skeletonLine(width: index.isMultiple(of: 2) ? 180 : 132, height: 14)
                        skeletonLine(width: index.isMultiple(of: 2) ? 92 : 112, height: 11)
                    }
                    Spacer()
                }
                .padding(10)
                .background(Color(.tertiarySystemGroupedBackground).opacity(0.62), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .redacted(reason: .placeholder)
        .accessibilityHidden(true)
    }
}

private func skeletonLine(width: CGFloat, height: CGFloat) -> some View {
    RoundedRectangle(cornerRadius: height / 2, style: .continuous)
        .fill(Color(.tertiarySystemGroupedBackground))
        .frame(width: width, height: height)
}
