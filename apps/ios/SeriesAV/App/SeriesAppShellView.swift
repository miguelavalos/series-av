import AVAppShellFoundation
import AVSettingsFoundation
import SwiftUI

struct SeriesAppShellView: View {
    @Binding var selectedTab: SeriesRootTab
    let accessController: SeriesAccessController
    let startSignInFlow: () -> Void

    @Environment(\.avCommonAppExperience) private var appExperience
    @State private var store = SeriesLibraryStore.persisted()
    @State private var librarySync = SeriesLibrarySyncCoordinator()
    @State private var chromeItem: AVAppShellChromeItem?
    @State private var isShowingUITestPaywall = SeriesUITestEnvironment.current.shouldShowPaywall

    init(
        selectedTab: Binding<SeriesRootTab>,
        accessController: SeriesAccessController,
        startSignInFlow: @escaping () -> Void
    ) {
        _selectedTab = selectedTab
        self.accessController = accessController
        self.startSignInFlow = startSignInFlow
        _chromeItem = State(initialValue: SeriesUITestEnvironment.current.initialChromeItem)
    }

    var body: some View {
        AVAppShellConfiguredScaffold(
            selectedTabID: footerSelectedTab,
            tabs: SeriesRootTab.footerTabs.map(\.shellTab),
            assistantID: .avi,
            assistant: footerAssistant,
            hasAssistantActiveContext: false,
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
            await librarySync.refresh(accessController: accessController, store: store)
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

    private var footerAssistant: AVAppShellConfiguredAssistant {
        AVAppShellConfiguredAssistant(
            name: appExperience.identity.assistantName,
            accessibilityIdentifier: "series.tab.avi",
            assetName: appExperience.visualAssets?.footerAssistantName ?? "AviFooterIcon",
            activeContextSystemImage: "play.circle.fill"
        )
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
                openSettings: { self.chromeItem = .settings },
                openAccount: { self.chromeItem = .account },
                accessController: accessController,
                startSignInFlow: startSignInFlow
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
                    store: store
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
