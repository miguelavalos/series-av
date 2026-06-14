import AVAppShellFoundation
import Foundation

enum SeriesRootTab: String, CaseIterable, Identifiable {
    case home
    case library
    case search
    case avi
    case profile

    var id: String { rawValue }

    static var footerTabs: [SeriesRootTab] {
        [.home, .library, .search]
    }

    var shellTab: AVAppShellTab<SeriesRootTab> {
        switch self {
        case .home:
            AVAppShellTab(
                id: self,
                title: L10n.string("tab.home"),
                systemImage: "house.fill",
                accessibilityIdentifier: "series.tab.home"
            )
        case .library:
            AVAppShellTab(
                id: self,
                title: L10n.string("tab.library"),
                systemImage: "rectangle.stack.fill",
                accessibilityIdentifier: "series.tab.library"
            )
        case .search:
            AVAppShellTab(
                id: self,
                title: L10n.string("tab.search"),
                systemImage: "magnifyingglass",
                accessibilityIdentifier: "series.tab.search"
            )
        case .avi, .profile:
            AVAppShellTab(
                id: self,
                title: L10n.string("tab.avi"),
                systemImage: "sparkles",
                accessibilityIdentifier: "series.tab.avi"
            )
        }
    }
}
