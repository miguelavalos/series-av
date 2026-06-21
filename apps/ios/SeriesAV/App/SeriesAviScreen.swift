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
            SeriesAviCurrentFocusCard(
                currentEntry: currentEntry,
                startWatching: startWatching,
                markNext: markNextEpisode,
                markPrevious: markPreviousEpisode,
                togglePinned: togglePinnedCurrent
            )

            SeriesAviQuickActionsCard(
                activeCount: store.activeEntries.count,
                watchingCount: store.watchingEntries.count,
                archivedCount: store.archivedEntries.count,
                openSearch: openSearch,
                openLibrary: openLibrary
            )

            if accessController.accessMode == .guest {
                SeriesAviSignInCard(
                    accountIsAvailable: accessController.accountIsAvailable,
                    startSignInFlow: startSignInFlow
                )
            }
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

private struct SeriesAviQuickActionsCard: View {
    let activeCount: Int
    let watchingCount: Int
    let archivedCount: Int
    let openSearch: () -> Void
    let openLibrary: () -> Void

    var body: some View {
        AVAviGuidanceCard(
            title: L10n.string("avi.prepare.title"),
            detail: L10n.string("avi.prepare.detail")
        ) {
            HStack(spacing: 10) {
                SeriesAviIconActionButton(
                    systemImage: "magnifyingglass",
                    accessibilityLabel: L10n.string("search.title"),
                    action: openSearch
                )

                SeriesAviIconActionButton(
                    systemImage: "rectangle.stack.fill",
                    accessibilityLabel: L10n.string("library.title"),
                    action: openLibrary
                )
            }

            HStack(spacing: 8) {
                SeriesAviMetricPill(
                    title: L10n.string("library.filter.watching"),
                    value: watchingCount,
                    systemImage: "play.circle.fill"
                )
                SeriesAviMetricPill(
                    title: L10n.string("library.filter.all"),
                    value: activeCount,
                    systemImage: "rectangle.stack.fill"
                )
                SeriesAviMetricPill(
                    title: L10n.string("library.filter.archived.short"),
                    value: archivedCount,
                    systemImage: "archivebox"
                )
            }
        }
    }
}

private struct SeriesAviMetricPill: View {
    let title: String
    let value: Int
    let systemImage: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AVBrandColor.accent)

            Text("\(value)")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(AVBrandColor.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemGroupedBackground), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value)")
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

                HStack(spacing: 10) {
                    SeriesAviIconActionButton(
                        systemImage: currentEntry.status == .wantToWatch ? "play.fill" : "checkmark",
                        isPrimary: true,
                        accessibilityLabel: "\(currentEntry.status == .wantToWatch ? L10n.string("avi.action.start") : L10n.string("avi.action.next")) \(cursorLabel(currentEntry.nextEpisodeCursor))",
                        action: currentEntry.status == .wantToWatch ? startWatching : markNext
                    )

                    if currentEntry.lastWatchedEpisodeCursor?.canStepBackQuickly == true {
                        SeriesAviIconActionButton(
                            systemImage: "arrow.uturn.backward",
                            accessibilityLabel: L10n.string("avi.action.previous"),
                            action: markPrevious
                        )
                    }

                    SeriesAviIconActionButton(
                        systemImage: currentEntry.isPinnedHomeSeries == true ? "pin.slash" : "pin",
                        accessibilityLabel: currentEntry.isPinnedHomeSeries == true ? L10n.string("avi.action.unpin") : L10n.string("avi.action.pin"),
                        action: togglePinned
                    )
                }
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

private struct SeriesAviIconActionButton: View {
    let systemImage: String
    var isPrimary = false
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: isPrimary ? 18 : 16, weight: .black))
                .foregroundStyle(isPrimary ? Color.black.opacity(0.84) : AVBrandColor.textPrimary)
                .frame(width: isPrimary ? 48 : 44, height: isPrimary ? 48 : 44)
                .background(isPrimary ? AVBrandColor.accent : Color(.tertiarySystemGroupedBackground), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}
