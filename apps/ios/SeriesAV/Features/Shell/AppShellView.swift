import SwiftUI

struct AppShellView: View {
    let startSignInFlow: (Bool) -> Void

    private let service = TVMazeService()

    @State private var selectedTab: AppShellTab = .home
    @State private var navigationPath = NavigationPath()
    @State private var navigationRootID = UUID()

    init(startSignInFlow: @escaping (Bool) -> Void = { _ in }) {
        self.startSignInFlow = startSignInFlow
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
            SearchScreen(service: service, bottomContentPadding: AppShellMetrics.rootContentBottomPadding)
        case .library:
            LibraryScreen(bottomContentPadding: AppShellMetrics.rootContentBottomPadding)
        case .discover:
            UpcomingScreen(bottomContentPadding: AppShellMetrics.rootContentBottomPadding)
        case .profile:
            ProfileScreen(startSignInFlow: startSignInFlow, bottomContentPadding: AppShellMetrics.rootContentBottomPadding)
        }
    }
}
