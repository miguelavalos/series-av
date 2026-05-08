import SwiftUI

struct AppShellView: View {
    let startSignInFlow: (Bool) -> Void
    let cloudService: SeriesAVCloudService?

    private let service = TVMazeService()

    @State private var selectedTab: AppShellTab = .home
    @State private var navigationPath = NavigationPath()
    @State private var navigationRootID = UUID()
    @State private var searchFocusRequest = 0
    @StateObject private var searchState = SearchScreenState()

    init(
        startSignInFlow: @escaping (Bool) -> Void = { _ in },
        cloudService: SeriesAVCloudService? = nil
    ) {
        self.startSignInFlow = startSignInFlow
        self.cloudService = cloudService
    }

    var body: some View {
        AppShellScaffold(
            selectedTab: selectedTab,
            selectTab: { tab in
                if selectedTab != tab {
                    navigationPath = NavigationPath()
                    navigationRootID = UUID()
                }
                selectedTab = tab
                if tab == .search && ProcessInfo.processInfo.environment["SERIESAV_UI_TESTS"] != "1" {
                    searchFocusRequest += 1
                }
            },
            content: {
                NavigationStack(path: $navigationPath) {
                    currentScreen
                }
                .id(navigationRootID)
                .toolbar(.hidden, for: .navigationBar)
            }
        )
    }

    @ViewBuilder
    private var currentScreen: some View {
        switch selectedTab {
        case .home:
            HomeScreen(service: service, bottomContentPadding: AppShellMetrics.rootContentBottomPadding)
        case .search:
            SearchScreen(
                service: service,
                cloudService: cloudService,
                bottomContentPadding: AppShellMetrics.rootContentBottomPadding,
                focusRequest: searchFocusRequest,
                state: searchState
            )
        case .library:
            LibraryScreen(bottomContentPadding: AppShellMetrics.rootContentBottomPadding)
        case .discover:
            UpcomingScreen(bottomContentPadding: AppShellMetrics.rootContentBottomPadding)
        case .profile:
            ProfileScreen(startSignInFlow: startSignInFlow, bottomContentPadding: AppShellMetrics.rootContentBottomPadding)
        }
    }
}
