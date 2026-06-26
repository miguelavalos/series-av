import AVAppShellFoundation
import AVBrandFoundation
import AVSettingsFoundation
import SwiftUI

struct SeriesAppShellView: View {
    @Environment(\.scenePhase) private var scenePhase
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
                .safeAreaPadding(.bottom, 96)
            },
            footerPlayer: {
                EmptyView()
            }
        )
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
            .accessibilityIdentifier("series.shell.tablet")
        }
    }

    private var tabletSidebar: some View {
        VStack(alignment: .leading, spacing: 10) {
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
                isSelected: chromeItem == .settings
            ) {
                chromeItem = .settings
                selectedTab = .profile
            }

            tabletChromeButton(
                title: L10n.string("profile.accountScreen.title"),
                systemImage: "person.crop.circle.fill",
                isSelected: chromeItem == .account
            ) {
                chromeItem = .account
                selectedTab = .profile
            }
        }
        .padding(.horizontal, AVAppShellTabletSidebarMetric.horizontalPadding)
        .padding(.vertical, AVAppShellTabletSidebarMetric.verticalPadding)
        .frame(width: 238, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(.regularMaterial)
        .accessibilityIdentifier("series.shell.tablet.sidebar")
    }

    private var tabletSidebarBrandHeader: some View {
        AVAppShellTabletSidebarBrandHeader(
            logoAssetName: appExperience.visualAssets?.headerLogoName ?? "HeaderWordmark",
            accessibilityLabel: appExperience.identity.displayName,
            logoWidth: 132,
            logoHeight: 42
        )
    }

    private func tabletSidebarButton(tab: SeriesRootTab, isSelected: Bool) -> some View {
        AVAppShellTabletSidebarButton(
            title: tab.shellTab.title,
            systemImage: tab.shellTab.systemImage,
            isSelected: isSelected
        ) {
            chromeItem = nil
            selectedTab = tab
        }
        .accessibilityIdentifier("series.sidebar.\(tab.rawValue)")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tab.shellTab.title)
    }

    private func tabletChromeButton(title: String, systemImage: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        AVAppShellTabletSidebarButton(
            title: title,
            systemImage: systemImage,
            isSelected: isSelected,
            fontSize: 15,
            action: action
        )
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
    let lastLibrarySyncRequestedAt: Date?
    let now: Date

    init(
        canUseCloudSync: Bool,
        lastLibrarySyncRequestedAt: Date? = nil,
        now: Date = .now
    ) {
        self.canUseCloudSync = canUseCloudSync
        self.lastLibrarySyncRequestedAt = lastLibrarySyncRequestedAt
        self.now = now
    }

    var shouldScheduleLibrarySync: Bool {
        guard canUseCloudSync else { return false }
        guard let lastLibrarySyncRequestedAt else { return true }
        return now.timeIntervalSince(lastLibrarySyncRequestedAt) >= Self.automaticLibrarySyncInterval
    }
}
