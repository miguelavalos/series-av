import AVAppShellFoundation
import AVSettingsFoundation
import SwiftUI

struct SeriesAppShellView: View {
    @Binding var selectedTab: SeriesRootTab
    let accessController: SeriesAccessController
    let startSignInFlow: () -> Void

    @Environment(\.avCommonAppExperience) private var appExperience
    @State private var store = SeriesLibraryStore.persisted()
    @State private var chromeItem: AVAppShellChromeItem?

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
