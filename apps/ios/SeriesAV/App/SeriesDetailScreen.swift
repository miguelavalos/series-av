import AVAppShellFoundation
import AVBrandFoundation
import AVExternalLinkFoundation
import SwiftUI

struct SeriesDetailScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
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
    private let guideFeedbackClient: SeriesGuideFeedbackClient

    @State private var guideState: SeriesDetailGuideState = .loading
    @State private var resolvedCatalogItem: SeriesCatalogItem?
    @State private var isShowingProgressEditor = false
    @State private var isShowingPrivateNoteEditor = false
    @State private var displayedPinnedOverride: Bool?
    @State private var hasDisplayedPrivateNoteOverride = false
    @State private var displayedPrivateNote: String?
    @State private var displayedLastWatchedEpisodeCursor: SeriesEpisodeCursor?
    @State private var isShowingShareComposer = false
    @State private var isConfirmingDelete = false
    @State private var inAppBrowserDestination: SeriesInAppBrowserDestination?
    @State private var shareSheetItem: SeriesShareSheetItem?
    @State private var feedbackState: SeriesGuideFeedbackSubmissionState = .idle
    @State private var uiTestGuideLoadAttempts = 0

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
        shareInviteClient: SeriesShareInviteClient? = nil,
        guideFeedbackClient: SeriesGuideFeedbackClient = SeriesGuideFeedbackClient()
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
        self.guideFeedbackClient = guideFeedbackClient
        _displayedLastWatchedEpisodeCursor = State(initialValue: entry?.lastWatchedEpisodeCursor)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                detailContent
                    .padding(18)
                    .frame(maxWidth: usesWideLayout ? 1180 : .infinity, alignment: .topLeading)
                    .frame(maxWidth: .infinity, alignment: .top)
            }
            .accessibilityIdentifier("series-detail-scroll")
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
            .confirmationDialog(
                L10n.string("detail.delete.confirm.title"),
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                if let entry, let delete {
                    Button(L10n.string("detail.delete.confirm.action"), role: .destructive) {
                        delete(entry)
                        dismiss()
                    }
                }

                Button(L10n.string("common.cancel"), role: .cancel) {}
            } message: {
                Text(L10n.string("detail.delete.confirm.detail"))
            }
        }
        .presentationSizing(.page)
    }

    @ViewBuilder
    private var detailContent: some View {
        if usesWideLayout {
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    trackingSection
                    privateNoteSection
                }
                .frame(maxWidth: 430, alignment: .topLeading)

                VStack(alignment: .leading, spacing: 18) {
                    guideSection
                    secondaryOptionsSection
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        } else {
            VStack(alignment: .leading, spacing: 18) {
                header
                trackingSection
                guideSection
                privateNoteSection
                secondaryOptionsSection
            }
        }
    }

    private var usesWideLayout: Bool {
        horizontalSizeClass == .regular
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

                    SeriesExpandableSummaryText(
                        text: spoilerFreeSummaryText,
                        collapsedLineLimit: 4
                    )

                    if shouldShowProviderNumberingNote {
                        Label(L10n.string("detail.numbering.providerNote"), systemImage: "number")
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Label(guideCoverageText, systemImage: guideCoverageSystemImage)
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(AVBrandColor.accent)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                        .fixedSize(horizontal: false, vertical: true)
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

                    trackingActions(for: entry)
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

    private var secondaryOptionsSection: some View {
        AVAppShellCard {
            VStack(alignment: .leading, spacing: 0) {
                sectionTitle(L10n.string("detail.options.title"))
                    .padding(.bottom, 6)

                sourcesMenu

                if let entry, archive != nil || delete != nil {
                    Divider()
                        .padding(.vertical, 2)

                    libraryManagementMenu(for: entry)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("series-detail-secondary-options")
        }
    }

    private var sourcesMenu: some View {
        Menu {
            ForEach(sourceLinks) { source in
                Button {
                    openSource(source.url)
                } label: {
                    Label(source.title, systemImage: source.systemImage)
                }
            }
        } label: {
            secondaryOptionLabel(
                L10n.string("detail.sources.open"),
                systemImage: "link"
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("series-detail-sources-menu")
    }

    private func libraryManagementMenu(for entry: SeriesLibraryEntry) -> some View {
        Menu {
            if let archive {
                Button {
                    archive(entry)
                    dismiss()
                } label: {
                    Label(L10n.string("home.archiveSeries"), systemImage: "archivebox")
                }
            }

            if delete != nil {
                Button(role: .destructive) {
                    isConfirmingDelete = true
                } label: {
                    Label(L10n.string("home.deleteSeries"), systemImage: "trash")
                }
            }
        } label: {
            secondaryOptionLabel(
                L10n.string("detail.management.open"),
                systemImage: "ellipsis.circle"
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("series-detail-management-menu")
    }

    private func secondaryOptionLabel(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(AVBrandColor.accent)
                .frame(width: 28, height: 44)

            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AVBrandColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            Image(systemName: "chevron.up.chevron.down")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var privateNoteSection: some View {
        if entry != nil, setPrivateNote != nil {
            if let note = currentPrivateNote?.trimmingCharacters(in: .whitespacesAndNewlines),
               note.isEmpty == false {
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
                            .accessibilityIdentifier("series-detail-private-note-edit")
                        }

                        Text(note)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(AVBrandColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else {
                AVAppShellCard {
                    Button {
                        isShowingPrivateNoteEditor = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "note.text.badge.plus")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(AVBrandColor.accent)
                                .frame(width: 28, height: 44)

                            Text(L10n.string("detail.privateNote.add"))
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(AVBrandColor.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)

                            Spacer(minLength: 8)

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.tertiary)
                                .accessibilityHidden(true)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(L10n.string("detail.privateNote.empty"))
                    .accessibilityIdentifier("series-detail-private-note-add")
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
                        SeriesDetailGuideUnavailableState(
                            systemImage: "list.bullet.rectangle",
                            detail: L10n.string("detail.episodes.unavailable.detail")
                        )
                    } else {
                        let visibleEpisodes = focusedEpisodes(from: episodes)
                        VStack(spacing: 8) {
                            ForEach(visibleEpisodes, id: \.cursor) { episode in
                                SeriesDetailEpisodeRow(
                                    episode: episode,
                                    absoluteEpisodeNumber: absoluteEpisodeNumber(for: episode.cursor, in: episodes),
                                    displayedLastWatchedEpisodeCursor: displayedLastWatchedEpisodeCursor,
                                    markWatchedThrough: markEpisodeWatchedThroughAction(for: episode)
                                )
                            }
                        }

                        if episodes.count > visibleEpisodes.count {
                            Text(String(format: L10n.string("detail.episodes.more"), episodes.count - visibleEpisodes.count))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                    }
                case .failed:
                    SeriesDetailGuideUnavailableState(
                        systemImage: "wifi.exclamationmark",
                        detail: L10n.string("detail.episodes.retryLater"),
                        retryAction: {
                            Task {
                                await loadEpisodeGuide()
                            }
                        }
                    )
                }

                Divider()

                guideFeedbackContent
            }
        }
    }

    private var guideFeedbackContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                Task {
                    await submitGuideFeedback()
                }
            } label: {
                HStack(spacing: 12) {
                    Group {
                        if feedbackState == .sending {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: feedbackState == .sent ? "checkmark.circle.fill" : "exclamationmark.bubble")
                                .font(.body.weight(.semibold))
                        }
                    }
                    .foregroundStyle(feedbackState == .sent ? Color.green : AVBrandColor.accent)
                    .frame(width: 28, height: 44)

                    Text(guideFeedbackActionTitle)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AVBrandColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 8)

                    if feedbackState == .idle || feedbackState == .failed {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(seriesId.isEmpty || feedbackState == .sending || feedbackState == .sent)
            .accessibilityHint(L10n.string("detail.guideFeedback.detail"))
            .accessibilityIdentifier("series-detail-guide-feedback")

            if let message = guideFeedbackStatusMessage {
                Text(message)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(feedbackState == .failed ? Color.red : Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 40)
                    .accessibilityIdentifier("series-detail-guide-feedback-status")
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

    private func trackingActions(for entry: SeriesLibraryEntry) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                primaryTrackingAction(for: entry, allowsWrapping: false)
                adjustTrackingAction(expands: false)
                pinTrackingAction
            }

            VStack(spacing: 8) {
                primaryTrackingAction(for: entry, allowsWrapping: true)

                HStack(spacing: 8) {
                    adjustTrackingAction(expands: true)
                    pinTrackingAction
                }
            }
        }
    }

    private func primaryTrackingAction(
        for entry: SeriesLibraryEntry,
        allowsWrapping: Bool
    ) -> some View {
        Button {
            markNext?(entry)
        } label: {
            Label(
                compactNextActionTitle(for: entry),
                systemImage: quickProgressFilledSystemImage(for: entry)
            )
            .font(.subheadline.weight(.bold))
            .lineLimit(allowsWrapping ? 2 : 1)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: allowsWrapping == false, vertical: false)
            .frame(maxWidth: .infinity, minHeight: 30)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.regular)
        .tint(AVBrandColor.accent)
        .frame(minHeight: 44)
        .disabled(canMarkNextEpisode(from: entry) == false)
        .opacity(canMarkNextEpisode(from: entry) ? 1 : 0.42)
        .accessibilityLabel(nextActionTitle(for: entry))
        .accessibilityIdentifier("series-detail-tracking-primary")
    }

    private func adjustTrackingAction(expands: Bool) -> some View {
        Button {
            isShowingProgressEditor = true
        } label: {
            Label(L10n.string("detail.tracking.adjustCompact"), systemImage: "scope")
                .font(.caption.weight(.bold))
                .lineLimit(1)
                .fixedSize(horizontal: expands == false, vertical: false)
                .frame(maxWidth: expands ? .infinity : nil, minHeight: 30)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .frame(minHeight: 44)
        .accessibilityLabel(L10n.string("home.adjust"))
        .accessibilityIdentifier("series-detail-tracking-adjust")
    }

    @ViewBuilder
    private var pinTrackingAction: some View {
        if let setPinned, let entry {
            Button {
                let nextPinned = currentIsPinned == false
                displayedPinnedOverride = nextPinned
                setPinned(entry, nextPinned)
            } label: {
                Image(systemName: currentIsPinned ? "pin.slash" : "pin")
                    .font(.body.weight(.bold))
                    .frame(width: 20, height: 30)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel(pinTitle)
            .accessibilityIdentifier("series-detail-tracking-pin")
            .help(pinTitle)
        }
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

    private var spoilerFreeSummaryText: String {
        if let summary = effectiveCatalogItem?.summary?.trimmingCharacters(in: .whitespacesAndNewlines),
           summary.isEmpty == false {
            return summary
        }

        if let latestKnownEpisodeCursor {
            return String(
                format: L10n.string("detail.summary.guideOnly"),
                knownEpisodeLabel(
                    cursor: latestKnownEpisodeCursor,
                    absoluteEpisodeNumber: effectiveCatalogItem?.knownEpisodeCount ?? entry?.knownEpisodeCount
                )
            )
        }

        switch guideState {
        case .loaded(let episodes) where episodes.isEmpty == false:
            return String(
                format: L10n.string("detail.summary.guideCountOnly"),
                episodes.count
            )
        case .loading:
            return L10n.string("detail.summary.loadingGuide")
        case .loaded, .failed:
            return L10n.string("detail.summary.noGuide")
        }
    }

    private var shouldShowProviderNumberingNote: Bool {
        guard let latestKnownEpisodeCursor,
              let knownEpisodeCount = effectiveCatalogItem?.knownEpisodeCount ?? entry?.knownEpisodeCount else {
            return false
        }
        return knownEpisodeCount != latestKnownEpisodeCursor.episodeNumber
    }

    private var latestKnownEpisodeCursor: SeriesEpisodeCursor? {
        if let latestKnownEpisodeCursor = effectiveCatalogItem?.latestKnownEpisodeCursor ?? entry?.latestKnownEpisodeCursor {
            return latestKnownEpisodeCursor
        }
        guard case .loaded(let episodes) = guideState else {
            return nil
        }
        return episodes
            .map(\.cursor)
            .max()
    }

    private var guideFeedbackActionTitle: String {
        switch feedbackState {
        case .idle, .failed:
            L10n.string("detail.guideFeedback.action")
        case .sending:
            L10n.string("detail.guideFeedback.sending")
        case .sent:
            L10n.string("detail.guideFeedback.sent")
        }
    }

    private var guideFeedbackStatusMessage: String? {
        switch feedbackState {
        case .idle, .sending:
            nil
        case .sent:
            L10n.string("detail.guideFeedback.sent.detail")
        case .failed:
            L10n.string("detail.guideFeedback.failed")
        }
    }

    private var guideCoverageText: String {
        if let latestKnownEpisodeCursor {
            return String(
                format: L10n.string("detail.guideCoverage.latest"),
                knownEpisodeLabel(
                    cursor: latestKnownEpisodeCursor,
                    absoluteEpisodeNumber: effectiveCatalogItem?.knownEpisodeCount ?? entry?.knownEpisodeCount
                )
            )
        }

        switch guideState {
        case .loaded(let episodes) where episodes.isEmpty == false:
            return String(format: L10n.string("detail.guideCoverage.count"), episodes.count)
        case .loading:
            return L10n.string("detail.guideCoverage.loading")
        case .loaded, .failed:
            return L10n.string("detail.guideCoverage.unavailable")
        }
    }

    private var guideCoverageSystemImage: String {
        switch guideState {
        case .loading:
            "hourglass"
        case .loaded(let episodes) where episodes.isEmpty == false:
            "checkmark.seal.fill"
        default:
            latestKnownEpisodeCursor == nil ? "exclamationmark.triangle.fill" : "checkmark.seal.fill"
        }
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

    private func compactNextActionTitle(for entry: SeriesLibraryEntry) -> String {
        if entry.status == .wantToWatch {
            return nextActionTitle(for: entry)
        }
        return "\(L10n.string("home.next")) \(cursorLabel(entry.nextEpisodeCursor))"
    }

    private func canMarkNextEpisode(from entry: SeriesLibraryEntry) -> Bool {
        guard let latestKnownEpisodeCursor = latestKnownEpisodeCursor else {
            return true
        }
        return entry.nextEpisodeCursor <= latestKnownEpisodeCursor
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

    private func focusedEpisodes(from episodes: [SeriesEpisodeGuideItem]) -> [SeriesEpisodeGuideItem] {
        let sortedEpisodes = episodes.sorted {
            if $0.seasonNumber == $1.seasonNumber {
                return $0.episodeNumber < $1.episodeNumber
            }
            return $0.seasonNumber < $1.seasonNumber
        }
        let limit = min(14, sortedEpisodes.count)
        guard limit > 0 else { return [] }

        let focusCursor = displayedLastWatchedEpisodeCursor?.nextEpisode ?? displayedLastWatchedEpisodeCursor
        let focusIndex = focusCursor.flatMap { cursor in
            sortedEpisodes.firstIndex { $0.cursor >= cursor }
        } ?? sortedEpisodes.firstIndex { $0.relativeState == .next || $0.relativeState == .current }

        guard let focusIndex else {
            return Array(sortedEpisodes.prefix(limit))
        }

        let preferredLeadCount = 4
        let lowerBound = max(0, min(focusIndex - preferredLeadCount, sortedEpisodes.count - limit))
        let upperBound = min(sortedEpisodes.count, lowerBound + limit)
        return Array(sortedEpisodes[lowerBound..<upperBound])
    }

    private func absoluteEpisodeNumber(for cursor: SeriesEpisodeCursor, in episodes: [SeriesEpisodeGuideItem]) -> Int? {
        episodes
            .sorted {
                if $0.seasonNumber == $1.seasonNumber {
                    return $0.episodeNumber < $1.episodeNumber
                }
                return $0.seasonNumber < $1.seasonNumber
            }
            .firstIndex { $0.cursor == cursor }
            .map { $0 + 1 }
    }

    private func openSource(_ url: URL) {
        switch externalLinkPreferences.webOpenMode {
        case .inApp:
            inAppBrowserDestination = SeriesInAppBrowserDestination(url: url)
        case .system:
            openURL(url)
        }
    }

    @MainActor
    private func submitGuideFeedback() async {
        guard seriesId.isEmpty == false else { return }
        feedbackState = .sending

        if let scenario = SeriesUITestEnvironment.current.guideFeedbackScenario {
            await Task.yield()
            feedbackState = scenario == "sent" ? .sent : .failed
            return
        }

        do {
            _ = try await guideFeedbackClient.report(
                SeriesGuideFeedbackRequest(
                    seriesId: seriesId,
                    title: title,
                    reason: defaultGuideFeedbackReason,
                    note: nil,
                    userCursor: displayedLastWatchedEpisodeCursor,
                    latestKnownEpisodeCursor: latestKnownEpisodeCursor,
                    knownEpisodeCount: effectiveCatalogItem?.knownEpisodeCount ?? entry?.knownEpisodeCount,
                    appLocale: Locale.current.identifier
                )
            )
            feedbackState = .sent
        } catch {
            feedbackState = .failed
        }
    }

    private var defaultGuideFeedbackReason: SeriesGuideFeedbackReason {
        guard let displayedLastWatchedEpisodeCursor,
              let latestKnownEpisodeCursor else {
            return .other
        }
        if displayedLastWatchedEpisodeCursor > latestKnownEpisodeCursor {
            return .missingEpisodes
        }
        if shouldShowProviderNumberingNote {
            return .wrongNumbering
        }
        return .other
    }

    private func loadEpisodeGuide() async {
        guard seriesId.isEmpty == false else {
            guideState = .failed
            return
        }

        if SeriesUITestEnvironment.current.episodeGuideScenario == "empty" {
            guideState = .loaded([])
            return
        }

        if SeriesUITestEnvironment.current.episodeGuideScenario == "failed_once",
           uiTestGuideLoadAttempts == 0 {
            uiTestGuideLoadAttempts += 1
            guideState = .failed
            return
        }

        if SeriesUITestEnvironment.current.shouldUseHighSeasonSampleLibrary,
           seriesId == "thetvdb:305089" {
            guideState = .loaded(uiTestHighSeasonEpisodeGuide())
            return
        }

        guideState = .loading
        do {
            let response = try await episodeGuideClient.episodes(
                for: seriesId,
                lastWatchedEpisodeCursor: entry?.lastWatchedEpisodeCursor
            )
            guideState = .loaded(
                response.items.isEmpty && SeriesUITestEnvironment.current.isEnabled
                    ? uiTestFallbackEpisodeGuide()
                    : response.items
            )
        } catch {
            if SeriesUITestEnvironment.current.isEnabled {
                guideState = .loaded(uiTestFallbackEpisodeGuide())
            } else {
                guideState = .failed
            }
        }
    }

    private func uiTestFallbackEpisodeGuide() -> [SeriesEpisodeGuideItem] {
        (1...8).map { episode in
            let cursor = SeriesEpisodeCursor(seasonNumber: 1, episodeNumber: episode)
            return SeriesEpisodeGuideItem(
                seasonNumber: 1,
                episodeNumber: episode,
                title: String(format: L10n.string("home.editor.episode"), episode),
                airDate: nil,
                reliability: .partial,
                relativeState: uiTestRelativeState(for: cursor),
                supportedActions: []
            )
        }
    }

    private func uiTestHighSeasonEpisodeGuide() -> [SeriesEpisodeGuideItem] {
        let episodeCountsBySeason = [(1, 25), (2, 25), (3, 16), (4, 19)]
        return episodeCountsBySeason.flatMap { seasonInfo in
            let season = seasonInfo.0
            let episodeCount = seasonInfo.1
            return (1...episodeCount).map { episode in
                let cursor = SeriesEpisodeCursor(seasonNumber: season, episodeNumber: episode)
                return SeriesEpisodeGuideItem(
                    seasonNumber: season,
                    episodeNumber: episode,
                    title: String(format: L10n.string("home.editor.episode"), episode),
                    airDate: nil,
                    reliability: .reliable,
                    relativeState: uiTestRelativeState(for: cursor),
                    supportedActions: []
                )
            }
        }
    }

    private func uiTestRelativeState(for cursor: SeriesEpisodeCursor) -> SeriesEpisodeGuideRelativeState {
        guard let displayedLastWatchedEpisodeCursor else {
            return cursor == SeriesEpisodeCursor(seasonNumber: 1, episodeNumber: 1) ? .next : .pending
        }

        if cursor < displayedLastWatchedEpisodeCursor {
            return .watched
        }
        if cursor == displayedLastWatchedEpisodeCursor {
            return .current
        }
        if cursor == displayedLastWatchedEpisodeCursor.nextEpisode {
            return .next
        }
        return .pending
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

private enum SeriesGuideFeedbackSubmissionState: Equatable {
    case idle
    case sending
    case sent
    case failed
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
                    .accessibilityIdentifier("series-private-note-editor")
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
            .frame(maxWidth: 640, alignment: .topLeading)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
            .frame(maxWidth: 620, alignment: .topLeading)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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

private struct SeriesDetailGuideUnavailableState: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let systemImage: String
    let detail: String
    var retryAction: (() -> Void)? = nil

    var body: some View {
        Group {
            if let retryAction,
               dynamicTypeSize.isAccessibilitySize || horizontalSizeClass == .compact {
                HStack(alignment: .top, spacing: 8) {
                    message
                    Spacer(minLength: 4)
                    compactRetryButton(action: retryAction)
                }
            } else {
                HStack(alignment: .center, spacing: 10) {
                    message

                    if let retryAction {
                        Spacer(minLength: 6)
                        retryButton(action: retryAction)
                    }
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("series-detail-guide-state")
    }

    private var message: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AVBrandColor.accent)
                .frame(width: 28, height: 32)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.string("detail.episodes.unavailable"))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AVBrandColor.textPrimary)

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func retryButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(L10n.string("common.retry"), systemImage: "arrow.clockwise")
                .font(.caption.weight(.bold))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .frame(minHeight: 30)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .accessibilityIdentifier("series-detail-guide-retry")
    }

    private func compactRetryButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "arrow.clockwise")
                .font(.body.weight(.bold))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(L10n.string("common.retry"))
        .accessibilityIdentifier("series-detail-guide-retry")
    }
}

private struct SeriesExpandableSummaryText: View {
    let text: String
    let collapsedLineLimit: Int

    @State private var isExpanded = false
    @State private var collapsedHeight: CGFloat = 0
    @State private var fullHeight: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            summaryText(lineLimit: isExpanded ? nil : collapsedLineLimit)
                .accessibilityIdentifier("series-detail-summary")

            if isTruncated {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(toggleTitle)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9, weight: .black))
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AVBrandColor.accent)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("series-detail-summary-toggle")
                .accessibilityLabel(toggleTitle)
            }
        }
        .background(alignment: .topLeading) {
            measurementLayer
        }
        .onChange(of: text) {
            isExpanded = false
        }
    }

    private var isTruncated: Bool {
        fullHeight > collapsedHeight + 0.5
    }

    private var toggleTitle: String {
        L10n.string(isExpanded ? "detail.summary.collapse" : "detail.summary.expand")
    }

    private func summaryText(lineLimit: Int?) -> some View {
        Text(text)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(AVBrandColor.textSecondary)
            .lineLimit(lineLimit)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var measurementLayer: some View {
        ZStack(alignment: .topLeading) {
            summaryText(lineLimit: collapsedLineLimit)
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { newHeight in
                    collapsedHeight = newHeight
                }

            summaryText(lineLimit: nil)
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { newHeight in
                    fullHeight = newHeight
                }
        }
        .hidden()
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

private enum SeriesDetailGuideState {
    case loading
    case loaded([SeriesEpisodeGuideItem])
    case failed
}

private struct SeriesDetailEpisodeRow: View {
    let episode: SeriesEpisodeGuideItem
    let absoluteEpisodeNumber: Int?
    let displayedLastWatchedEpisodeCursor: SeriesEpisodeCursor?
    let markWatchedThrough: (() -> Void)?

    var body: some View {
        if let markWatchedThrough {
            Button(action: markWatchedThrough) {
                rowContent
            }
            .buttonStyle(.plain)
            .accessibilityLabel(actionTitle)
            .accessibilityIdentifier(actionIdentifier)
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

    private var actionTitle: String {
        String(format: L10n.string("detail.episodes.action.setPoint.accessibility"), cursorLabel(episode.cursor))
    }

    private var actionIdentifier: String {
        "series-detail-episode-\(episode.cursor.seasonNumber)-\(episode.cursor.episodeNumber)-set-progress"
    }

    private var rowContent: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(episodeNumberLabel)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(cursorColor)
                .monospacedDigit()
                .frame(width: 108, alignment: .leading)

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
                stateIconBadge
            }
        }
        .padding(10)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(rowBorderColor, lineWidth: rowBorderWidth)
        )
    }

    private var episodeNumberLabel: String {
        guard let absoluteEpisodeNumber else {
            return cursorLabel(episode.cursor)
        }
        return "E\(absoluteEpisodeNumber) · \(cursorLabel(episode.cursor))"
    }

    private var stateIconBadge: some View {
        Image(systemName: stateIconName)
            .font(.system(size: 14, weight: .black))
            .foregroundStyle(stateIconColor)
            .frame(width: 32, height: 32)
            .background(stateIconBackground, in: Circle())
            .overlay {
                Circle().stroke(stateIconStrokeColor, lineWidth: 1)
            }
            .accessibilityHidden(true)
    }

    private var stateIconName: String {
        switch effectiveRelativeState {
        case .watched:
            "checkmark"
        case .current:
            "checkmark.circle.fill"
        case .next:
            "play.circle.fill"
        case .pending:
            "circle.dashed"
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
        case .current, .next:
            AVBrandColor.accent
        case .pending:
            AVBrandColor.textSecondary
        }
    }

    private var stateIconColor: Color {
        switch effectiveRelativeState {
        case .watched, .pending:
            AVBrandColor.textSecondary
        case .current, .next:
            Color.black.opacity(0.84)
        }
    }

    private var stateIconBackground: Color {
        switch effectiveRelativeState {
        case .watched, .pending:
            Color(.secondarySystemGroupedBackground)
        case .current, .next:
            AVBrandColor.accent
        }
    }

    private var stateIconStrokeColor: Color {
        switch effectiveRelativeState {
        case .current, .next:
            Color.black.opacity(0.08)
        case .watched, .pending:
            Color.primary.opacity(0.06)
        }
    }

    private var cursorColor: Color {
        switch effectiveRelativeState {
        case .watched, .pending:
            AVBrandColor.textSecondary
        case .current, .next:
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
