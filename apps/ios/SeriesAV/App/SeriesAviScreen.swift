import AVAviFoundation
import AVAppShellFoundation
import AVBrandFoundation
import SwiftUI

struct SeriesAviScreen: View {
    @Bindable var store: SeriesLibraryStore
    let accessController: SeriesAccessController
    let startSignInFlow: () -> Void
    let openSearch: () -> Void
    let openLibrary: () -> Void

    @Environment(\.avCommonAppExperience) private var appExperience
    @State private var pendingProgressUndo: PendingProgressUndo?

    var body: some View {
        AVAviGuidanceScreenScaffold(
            identity: appExperience.identity,
            summary: L10n.string("avi.summary"),
            status: aviStatus,
            headerAccessibilityIdentifier: "series.avi.header",
            landingContent: landingContent,
            backgroundStyle: AnyShapeStyle(AVBrandSurface.shellBackground)
        ) {
            EmptyView()
        } heroAvatar: {
            Image("AviFullBody")
                .resizable()
                .scaledToFit()
                .frame(width: 82, height: 82)
                .accessibilityLabel("Avi")
        } content: {
            if accessController.accessMode == .guest {
                SeriesAviSignInCard(
                    accountIsAvailable: accessController.accountIsAvailable,
                    startSignInFlow: startSignInFlow
                )
            }

            SeriesAviPreparationCard(openSearch: openSearch)

            SeriesAviCurrentFocusCard(
                currentEntry: currentEntry,
                startWatching: startWatching,
                markNext: markNextEpisode,
                markPrevious: markPreviousEpisode,
                togglePinned: togglePinnedCurrent
            )

            SeriesAviLibraryGuidanceCard(
                activeCount: store.activeEntries.count,
                watchingCount: store.watchingEntries.count,
                archivedCount: store.archivedEntries.count,
                openLibrary: openLibrary
            )

            SeriesAviTrackingHelpCard()
        }
        .safeAreaInset(edge: .bottom) {
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
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.regularMaterial)
            }
        }
    }

    private var landingContent: AVAviLandingContent {
        AVAviLandingContent(
            eyebrow: "Series AV",
            title: L10n.string("avi.landing.title"),
            detail: L10n.string("avi.hero.detail"),
            chips: [
                AVAviLandingChip(title: L10n.string("search.title"), systemImage: "magnifyingglass"),
                AVAviLandingChip(title: L10n.string("avi.action.next"), systemImage: "checkmark.circle"),
                AVAviLandingChip(title: L10n.string("library.title"), systemImage: "rectangle.stack.fill")
            ],
            accessibilityIdentifier: "series.avi.hero"
        )
    }

    private var currentEntry: SeriesLibraryEntry? {
        store.homeEntries.first
    }

    private var aviStatus: String {
        guard let currentEntry else {
            return L10n.string("avi.status.empty")
        }
        return "\(currentEntry.title) · \(currentEntry.progressLabel)"
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

    private func markNextEpisode() {
        guard let currentEntry else {
            return
        }
        pendingProgressUndo = progressUndo(for: currentEntry)
        store.markNextEpisodeWatched(for: currentEntry.id)
    }

    private func startWatching() {
        guard let currentEntry else {
            return
        }
        pendingProgressUndo = progressUndo(for: currentEntry, messageKey: "home.undo.status")
        store.setStatus(.watching, for: currentEntry.id)
    }

    private func markPreviousEpisode() {
        guard let currentEntry else {
            return
        }
        pendingProgressUndo = progressUndo(for: currentEntry)
        store.markPreviousEpisodeWatched(for: currentEntry.id)
    }

    private func togglePinnedCurrent() {
        guard let currentEntry else {
            return
        }
        store.setPinned(currentEntry.isPinnedHomeSeries != true, for: currentEntry.id)
    }
}

private struct SeriesAviPreparationCard: View {
    let openSearch: () -> Void

    var body: some View {
        AVAviGuidanceCard(
            title: L10n.string("avi.prepare.title"),
            detail: L10n.string("avi.prepare.detail")
        ) {
            AVAviInfoRow(
                title: L10n.string("avi.prepare.search.title"),
                detail: L10n.string("avi.prepare.search.detail"),
                systemImage: "magnifyingglass"
            )
            AVAviInfoRow(
                title: L10n.string("avi.prepare.progress.title"),
                detail: L10n.string("avi.prepare.progress.detail"),
                systemImage: "scope"
            )
            AVAviActionInfoRow(
                title: L10n.string("avi.prepare.action.title"),
                detail: L10n.string("avi.prepare.action.detail"),
                systemImage: "plus.app",
                buttonTitle: L10n.string("avi.prepare.action.button"),
                action: openSearch
            )
        }
    }
}

private struct SeriesAviSignInCard: View {
    let accountIsAvailable: Bool
    let startSignInFlow: () -> Void

    var body: some View {
        AVAviGuidanceCard(
            title: L10n.string("profile.account.title"),
            detail: accountIsAvailable ? L10n.string("profile.summary.account.detail.guest") : L10n.string("profile.account.connectUnavailable")
        ) {
            AVAviActionButton(
                title: accountIsAvailable ? L10n.string("app.onboarding.signIn") : L10n.string("profile.account.connectUnavailable"),
                systemImage: "person.crop.circle.badge.plus",
                action: startSignInFlow
            )
            .disabled(!accountIsAvailable)
        }
    }
}

private struct SeriesAviCurrentFocusCard: View {
    let currentEntry: SeriesLibraryEntry?
    let startWatching: () -> Void
    let markNext: () -> Void
    let markPrevious: () -> Void
    let togglePinned: () -> Void

    var body: some View {
        AVAviGuidanceCard(
            title: title,
            detail: detail
        ) {
            if let currentEntry {
                AVAviInfoRow(
                    title: currentEntry.title,
                    detail: currentEntry.progressLabel,
                    systemImage: "play.circle.fill"
                )

                AVAviActionButton(
                    title: "\(currentEntry.status == .wantToWatch ? L10n.string("avi.action.start") : L10n.string("avi.action.next")) \(cursorLabel(currentEntry.nextEpisodeCursor))",
                    systemImage: "checkmark.circle",
                    action: currentEntry.status == .wantToWatch ? startWatching : markNext
                )

                if currentEntry.lastWatchedEpisodeCursor?.canStepBackQuickly == true {
                    AVAviActionButton(
                        title: L10n.string("avi.action.previous"),
                        systemImage: "arrow.uturn.backward.circle",
                        action: markPrevious
                    )
                }

                AVAviActionButton(
                    title: currentEntry.isPinnedHomeSeries == true ? L10n.string("avi.action.unpin") : L10n.string("avi.action.pin"),
                    systemImage: currentEntry.isPinnedHomeSeries == true ? "pin.slash" : "pin",
                    action: togglePinned
                )
            } else {
                AVAviInfoRow(
                    title: L10n.string("avi.current.empty.title"),
                    detail: L10n.string("avi.current.empty.detail"),
                    systemImage: "plus.circle"
                )
            }
        }
    }

    private var title: String {
        currentEntry == nil ? L10n.string("avi.current.empty.title") : L10n.string("avi.current.title")
    }

    private var detail: String {
        guard let currentEntry else {
            return L10n.string("avi.current.empty.detail")
        }
        return String(format: L10n.string("avi.current.next.detail"), cursorLabel(currentEntry.nextEpisodeCursor))
    }
}

private struct SeriesAviLibraryGuidanceCard: View {
    let activeCount: Int
    let watchingCount: Int
    let archivedCount: Int
    let openLibrary: () -> Void

    var body: some View {
        AVAviGuidanceCard(
            title: L10n.string("library.title"),
            detail: L10n.string("avi.library.detail")
        ) {
            AVAviInfoRow(
                title: L10n.string("library.filter.watching"),
                detail: "\(watchingCount)",
                systemImage: "play.circle.fill"
            )
            AVAviInfoRow(
                title: L10n.string("library.filter.all"),
                detail: "\(activeCount)",
                systemImage: "rectangle.stack.fill"
            )
            AVAviInfoRow(
                title: L10n.string("library.filter.archived"),
                detail: "\(archivedCount)",
                systemImage: "archivebox"
            )
            AVAviActionButton(
                title: L10n.string("library.title"),
                systemImage: "rectangle.stack.fill",
                action: openLibrary
            )
        }
    }
}

private struct SeriesAviTrackingHelpCard: View {
    var body: some View {
        AVAviGuidanceCard(
            title: L10n.string("avi.help.title"),
            detail: L10n.string("avi.help.detail")
        ) {
            AVAviInfoRow(
                title: L10n.string("avi.help.next.title"),
                detail: L10n.string("avi.help.next.detail"),
                systemImage: "checkmark.circle"
            )
            AVAviInfoRow(
                title: L10n.string("avi.help.previous.title"),
                detail: L10n.string("avi.help.previous.detail"),
                systemImage: "arrow.uturn.backward.circle"
            )
            AVAviInfoRow(
                title: L10n.string("avi.help.pin.title"),
                detail: L10n.string("avi.help.pin.detail"),
                systemImage: "pin"
            )
        }
    }
}
