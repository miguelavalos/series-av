import AVAppShellFoundation
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
