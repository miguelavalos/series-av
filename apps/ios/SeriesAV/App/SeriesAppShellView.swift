import AVAppShellFoundation
import AVBrandFoundation
import AVSettingsFoundation
import SwiftUI

struct SeriesAppShellView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var selectedTab: SeriesRootTab
    let accessController: SeriesAccessController
    let store: SeriesLibraryStore
    let librarySync: SeriesLibrarySyncCoordinator
    let startSignInFlow: () -> Void

    @Environment(\.avCommonAppExperience) private var appExperience
    @State private var librarySyncTask: Task<Void, Never>?
    @State private var lastAutomaticLibrarySyncRequestedAt: Date?
    @State private var chromeItem: AVAppShellChromeItem?
    @State private var isShowingUITestPaywall = SeriesUITestEnvironment.current.shouldShowPaywall

    init(
        selectedTab: Binding<SeriesRootTab>,
        accessController: SeriesAccessController,
        store: SeriesLibraryStore,
        librarySync: SeriesLibrarySyncCoordinator,
        startSignInFlow: @escaping () -> Void
    ) {
        _selectedTab = selectedTab
        self.accessController = accessController
        self.store = store
        self.librarySync = librarySync
        self.startSignInFlow = startSignInFlow
        _chromeItem = State(initialValue: SeriesUITestEnvironment.current.initialChromeItem)
    }

    var body: some View {
        adaptiveShell
            .task(id: accessController.accessMode) {
                scheduleSignedInLibrarySync(after: .milliseconds(150))
            }
            .onChange(of: accessController.accountUser?.id) { _, _ in
                resetLibrarySyncForAccountIdentityChange()
            }
            .task(id: scenePhase) {
                guard scenePhase == .active else {
                    cancelScheduledLibrarySync()
                    return
                }
                scheduleSignedInLibrarySync(after: .milliseconds(350))
            }
            .onChange(of: store.entries) { _, entries in
                librarySync.localEntriesDidChange(entries, accessController: accessController)
            }
            .sheet(isPresented: $isShowingUITestPaywall) {
                SeriesProPaywallView(
                    accessController: accessController,
                    startSignInFlow: startSignInFlow
                )
            }
    }

    @ViewBuilder
    private var adaptiveShell: some View {
        SeriesAdaptiveLayoutReader { layout in
            if layout.layoutClass.isTabletLike {
                tabletShell
            } else {
                compactShell
            }
        }
    }

    private var compactShell: some View {
        AVAppShellConfiguredScaffold(
            selectedTabID: footerSelectedTab,
            tabs: SeriesRootTab.footerTabs.map(\.shellTab),
            assistantID: .avi,
            assistant: footerAssistant,
            hasAssistantActiveContext: hasAssistantActiveContext,
            footerConfiguration: appExperience.footerConfiguration,
            onSelectTab: { tab in
                chromeItem = nil
                selectedTab = tab
            },
            onSelectAssistant: {
                chromeItem = nil
                selectedTab = .avi
            },
            content: {
                NavigationStack {
                    screen(for: selectedTab)
                }
                .safeAreaPadding(.bottom, appExperience.footerConfiguration.backdropHeight)
            },
            footerPlayer: {
                EmptyView()
            }
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("series.shell.compact")
    }

    private var tabletShell: some View {
        NavigationStack {
            HStack(spacing: 0) {
                tabletSidebar

                Divider()

                screen(for: chromeItem == nil ? selectedTab : .profile)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(AVBrandSurface.shellBackground.ignoresSafeArea())
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("series.shell.tablet")
        }
    }

    private var tabletSidebar: some View {
        VStack(alignment: .leading, spacing: sidebarRowSpacing) {
            tabletSidebarBrandHeader
            .padding(.bottom, 12)

            ForEach([SeriesRootTab.home, .library, .search, .avi]) { tab in
                tabletSidebarButton(
                    tab: tab,
                    isSelected: chromeItem == nil && selectedTab == tab
                )
            }

            Spacer(minLength: 16)

            tabletChromeButton(
                title: L10n.string("profile.settingsScreen.title"),
                systemImage: "gearshape.fill",
                accessibilityIdentifier: "series.sidebar.settings",
                isSelected: chromeItem == .settings
            ) {
                chromeItem = .settings
                selectedTab = .profile
            }

            tabletChromeButton(
                title: L10n.string("profile.accountScreen.title"),
                systemImage: "person.crop.circle.fill",
                accessibilityIdentifier: "series.sidebar.account",
                isSelected: chromeItem == .account
            ) {
                chromeItem = .account
                selectedTab = .profile
            }
        }
        .padding(.horizontal, AVAppShellTabletSidebarMetric.horizontalPadding)
        .padding(.vertical, AVAppShellTabletSidebarMetric.verticalPadding)
        .frame(width: tabletSidebarWidth, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(.regularMaterial)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("series.shell.tablet.sidebar")
    }

    private var tabletSidebarBrandHeader: some View {
        AVAppShellTabletSidebarBrandHeader(
            logoAssetName: appExperience.visualAssets?.headerLogoName ?? "HeaderWordmark",
            accessibilityLabel: appExperience.identity.displayName,
            logoWidth: 132,
            logoHeight: 42,
            logoLeadingCorrection: -3
        )
    }

    private func tabletSidebarButton(tab: SeriesRootTab, isSelected: Bool) -> some View {
        tabletSidebarNavigationButton(
            title: tab.shellTab.title,
            systemImage: tab.shellTab.systemImage,
            isSelected: isSelected,
            action: {
                chromeItem = nil
                selectedTab = tab
            }
        )
        .accessibilityIdentifier("series.sidebar.\(tab.rawValue)")
    }

    private func tabletChromeButton(
        title: String,
        systemImage: String,
        accessibilityIdentifier: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        tabletSidebarNavigationButton(
            title: title,
            systemImage: systemImage,
            isSelected: isSelected,
            action: action
        )
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private func tabletSidebarNavigationButton(
        title: String,
        systemImage: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .frame(width: sidebarIconWidth, alignment: .center)

                Text(title)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .font(.body.weight(isSelected ? .semibold : .medium))
            .dynamicTypeSize(.xSmall ... .accessibility1)
            .frame(maxWidth: .infinity, minHeight: sidebarMinimumRowHeight, alignment: .leading)
            .padding(.horizontal, AVAppShellTabletSidebarMetric.rowHorizontalInset)
            .padding(.vertical, sidebarRowVerticalInset)
            .background(
                isSelected ? Color.primary.opacity(0.08) : Color.clear,
                in: RoundedRectangle(
                    cornerRadius: AVAppShellTabletSidebarMetric.rowCornerRadius,
                    style: .continuous
                )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var tabletSidebarWidth: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 300 : 238
    }

    private var sidebarMinimumRowHeight: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 56 : 44
    }

    private var sidebarRowVerticalInset: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 8 : AVAppShellTabletSidebarMetric.rowVerticalInset
    }

    private var sidebarRowSpacing: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 8 : 10
    }

    private var sidebarIconWidth: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 32 : 24
    }

    private func scheduleSignedInLibrarySync(after delay: Duration? = nil) {
        if let forcedState = SeriesUITestEnvironment.current.forcedLibrarySyncState {
            cancelScheduledLibrarySync()
            librarySync.setStateForUITests(forcedState)
            return
        }

        guard scenePhase == .active else {
            cancelScheduledLibrarySync()
            return
        }

        let syncPolicy = SeriesStartupSyncPolicy(
            canUseCloudSync: accessController.capabilities.canUseCloudSync,
            shouldRetryAfterFailure: librarySync.shouldRetryAfterFailure,
            lastLibrarySyncRequestedAt: lastAutomaticLibrarySyncRequestedAt,
            now: .now
        )

        guard syncPolicy.shouldScheduleLibrarySync else {
            cancelScheduledLibrarySync()
            if !accessController.capabilities.canUseCloudSync {
                librarySync.disable()
            }
            return
        }

        lastAutomaticLibrarySyncRequestedAt = syncPolicy.now
        scheduleLibrarySync(after: delay)
    }

    private func scheduleLibrarySync(after delay: Duration? = nil) {
        librarySyncTask?.cancel()
        librarySyncTask = Task { @MainActor in
            if let delay {
                do {
                    try await Task.sleep(for: delay)
                } catch {
                    return
                }
            }

            guard !Task.isCancelled else { return }
            await librarySync.refresh(accessController: accessController, store: store)
            guard !Task.isCancelled else { return }
            librarySyncTask = nil
        }
    }

    private func cancelScheduledLibrarySync() {
        librarySyncTask?.cancel()
        librarySyncTask = nil
    }

    private func resetLibrarySyncForAccountIdentityChange() {
        cancelScheduledLibrarySync()
        librarySync.disable()
        lastAutomaticLibrarySyncRequestedAt = nil
        scheduleSignedInLibrarySync(after: .milliseconds(150))
    }

    private var footerAssistant: AVAppShellConfiguredAssistant {
        AVAppShellConfiguredAssistant(
            name: appExperience.identity.assistantName,
            accessibilityIdentifier: "series.tab.avi",
            assetName: appExperience.visualAssets?.footerAssistantName ?? "AviFooterIcon",
            activeContextSystemImage: "play.circle.fill"
        )
    }

    private var hasAssistantActiveContext: Bool {
        selectedTab != .avi && store.homeEntries.isEmpty == false
    }

    private var footerSelectedTab: SeriesRootTab {
        chromeItem == nil ? selectedTab : .profile
    }

    @ViewBuilder
    private func screen(for tab: SeriesRootTab) -> some View {
        if let chromeItem {
            SeriesProfileScreen(
                mode: chromeItem,
                store: store,
                librarySync: librarySync,
                openSettings: { self.chromeItem = .settings },
                openAccount: { self.chromeItem = .account },
                accessController: accessController,
                startSignInFlow: startSignInFlow,
                synchronizeLibraryNow: {
                    await librarySync.refresh(accessController: accessController, store: store)
                },
                keepDeviceLibraryNow: {
                    await librarySync.overwriteCloudLibraryWithLocalData(accessController: accessController, store: store)
                }
            )
        } else {
            switch tab {
            case .home:
                RootView(
                    store: store,
                    accessController: accessController,
                    startSignInFlow: startSignInFlow,
                    openSettings: { chromeItem = .settings },
                    openAccount: { chromeItem = .account },
                    openLibraryTab: { selectedTab = .library },
                    openSearch: { selectedTab = .search },
                    openAvi: { selectedTab = .avi }
                )
            case .library:
                SeriesLibraryTabScreen(
                    store: store,
                    accessController: accessController
                )
            case .search:
                SeriesSearchScreen(
                    store: store,
                    accessController: accessController,
                    startSignInFlow: startSignInFlow
                )
            case .avi:
                SeriesAviScreen(
                    store: store,
                    accessController: accessController,
                    startSignInFlow: startSignInFlow,
                    openSearch: { selectedTab = .search },
                    openLibrary: { selectedTab = .library }
                )
            case .profile:
                EmptyView()
            }
        }
    }
}

struct SeriesStartupSyncPolicy: Equatable {
    static let automaticLibrarySyncInterval: TimeInterval = 300

    let canUseCloudSync: Bool
    let shouldRetryAfterFailure: Bool
    let lastLibrarySyncRequestedAt: Date?
    let now: Date

    init(
        canUseCloudSync: Bool,
        shouldRetryAfterFailure: Bool = false,
        lastLibrarySyncRequestedAt: Date? = nil,
        now: Date = .now
    ) {
        self.canUseCloudSync = canUseCloudSync
        self.shouldRetryAfterFailure = shouldRetryAfterFailure
        self.lastLibrarySyncRequestedAt = lastLibrarySyncRequestedAt
        self.now = now
    }

    var shouldScheduleLibrarySync: Bool {
        guard canUseCloudSync else { return false }
        guard shouldRetryAfterFailure == false else { return true }
        guard let lastLibrarySyncRequestedAt else { return true }
        return now.timeIntervalSince(lastLibrarySyncRequestedAt) >= Self.automaticLibrarySyncInterval
    }
}
