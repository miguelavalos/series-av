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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
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
        .overlay(alignment: .bottom) {
            if let pendingProgressUndo {
                SeriesUndoBar(
                    title: String(format: L10n.string(pendingProgressUndo.messageKey), pendingProgressUndo.title),
                    undo: {
                        store.restoreProgress(
                            status: pendingProgressUndo.status,
                            lastWatchedEpisodeCursor: pendingProgressUndo.lastWatchedEpisodeCursor,
                            isPinnedHomeSeries: pendingProgressUndo.isPinnedHomeSeries,
                            for: pendingProgressUndo.entryId
                        )
                        self.pendingProgressUndo = nil
                    },
                    dismiss: {
                        self.pendingProgressUndo = nil
                    }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, horizontalSizeClass == .compact ? 88 : 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.25), value: pendingProgressUndo != nil)
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
            lastWatchedEpisodeCursor: entry.lastWatchedEpisodeCursor,
            isPinnedHomeSeries: entry.isPinnedHomeSeries
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

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        AVAviGuidanceCard(
            title: L10n.string("avi.prepare.title"),
            detail: L10n.string("avi.prepare.detail")
        ) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 10) {
                    quickActionButtons
                }
            } else {
                HStack(spacing: 10) {
                    quickActionButtons
                }
            }

            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 8) {
                    metricPills
                }
            } else {
                HStack(spacing: 8) {
                    metricPills
                }
            }
        }
    }

    @ViewBuilder
    private var quickActionButtons: some View {
        SeriesAviIconActionButton(
            systemImage: "magnifyingglass",
            showsLabel: dynamicTypeSize.isAccessibilitySize,
            accessibilityLabel: L10n.string("search.title"),
            accessibilityIdentifier: "series.avi.search",
            action: openSearch
        )

        SeriesAviIconActionButton(
            systemImage: "rectangle.stack.fill",
            showsLabel: dynamicTypeSize.isAccessibilitySize,
            accessibilityLabel: L10n.string("library.title"),
            accessibilityIdentifier: "series.avi.library",
            action: openLibrary
        )
    }

    @ViewBuilder
    private var metricPills: some View {
        SeriesAviMetricPill(
            title: L10n.string("library.filter.watching"),
            value: watchingCount,
            systemImage: "play.circle.fill",
            accessibilityIdentifier: "series.avi.metric.watching"
        )
        SeriesAviMetricPill(
            title: L10n.string("library.filter.all"),
            value: activeCount,
            systemImage: "rectangle.stack.fill",
            accessibilityIdentifier: "series.avi.metric.active"
        )
        SeriesAviMetricPill(
            title: L10n.string("library.filter.archived.short"),
            value: archivedCount,
            systemImage: "archivebox",
            accessibilityIdentifier: "series.avi.metric.archived"
        )
    }
}

private struct SeriesAviMetricPill: View {
    let title: String
    let value: Int
    let systemImage: String
    let accessibilityIdentifier: String

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                HStack(spacing: 10) {
                    Label(title, systemImage: systemImage)
                        .font(.subheadline.weight(.semibold))
                        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                        .foregroundStyle(AVBrandColor.textPrimary)

                    Spacer(minLength: 8)

                    metricValue
                        .font(.headline.weight(.black))
                        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 52)
                .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                HStack(spacing: 6) {
                    Image(systemName: systemImage)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AVBrandColor.accent)

                    metricValue
                        .font(.subheadline.weight(.black))
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .background(Color(.tertiarySystemGroupedBackground), in: Capsule())
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value)")
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var metricValue: some View {
        Text("\(value)")
            .monospacedDigit()
            .foregroundStyle(AVBrandColor.textPrimary)
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

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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

                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 10) {
                        focusActions(for: currentEntry)
                    }
                } else {
                    HStack(spacing: 10) {
                        focusActions(for: currentEntry)
                    }
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

    @ViewBuilder
    private func focusActions(for currentEntry: SeriesLibraryEntry) -> some View {
        SeriesAviIconActionButton(
            systemImage: currentEntry.status == .wantToWatch ? "play.fill" : "checkmark",
            isPrimary: true,
            showsLabel: dynamicTypeSize.isAccessibilitySize,
            accessibilityLabel: "\(currentEntry.status == .wantToWatch ? L10n.string("avi.action.start") : L10n.string("avi.action.next")) \(cursorLabel(currentEntry.nextEpisodeCursor))",
            accessibilityIdentifier: "series.avi.focus.primary",
            action: currentEntry.status == .wantToWatch ? startWatching : markNext
        )

        if currentEntry.lastWatchedEpisodeCursor?.canStepBackQuickly == true {
            SeriesAviIconActionButton(
                systemImage: "arrow.uturn.backward",
                showsLabel: dynamicTypeSize.isAccessibilitySize,
                accessibilityLabel: L10n.string("avi.action.previous"),
                accessibilityIdentifier: "series.avi.focus.previous",
                action: markPrevious
            )
        }

        SeriesAviIconActionButton(
            systemImage: currentEntry.isPinnedHomeSeries == true ? "pin.slash" : "pin",
            showsLabel: dynamicTypeSize.isAccessibilitySize,
            accessibilityLabel: currentEntry.isPinnedHomeSeries == true ? L10n.string("avi.action.unpin") : L10n.string("avi.action.pin"),
            accessibilityIdentifier: "series.avi.focus.pin",
            action: togglePinned
        )
    }
}

private struct SeriesAviIconActionButton: View {
    let systemImage: String
    var isPrimary = false
    var showsLabel = false
    let accessibilityLabel: String
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if showsLabel {
                Label(accessibilityLabel, systemImage: systemImage)
                    .font(.headline.weight(.bold))
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                    .lineLimit(2)
                    .foregroundStyle(isPrimary ? Color.black.opacity(0.84) : AVBrandColor.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .padding(.horizontal, 14)
                    .background(
                        isPrimary ? AVBrandColor.accent : Color(.tertiarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
            } else {
                Image(systemName: systemImage)
                    .font(isPrimary ? .headline.weight(.black) : .body.weight(.black))
                    .foregroundStyle(isPrimary ? Color.black.opacity(0.84) : AVBrandColor.textPrimary)
                    .frame(width: isPrimary ? 48 : 44, height: isPrimary ? 48 : 44)
                    .background(isPrimary ? AVBrandColor.accent : Color(.tertiarySystemGroupedBackground), in: Circle())
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}
