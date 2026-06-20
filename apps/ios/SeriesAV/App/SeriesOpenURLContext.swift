import SwiftUI

private struct SeriesPendingOpenURLEnvironmentKey: EnvironmentKey {
    static let defaultValue: Binding<URL?> = .constant(nil)
}

extension EnvironmentValues {
    var seriesPendingOpenURL: Binding<URL?> {
        get { self[SeriesPendingOpenURLEnvironmentKey.self] }
        set { self[SeriesPendingOpenURLEnvironmentKey.self] = newValue }
    }
}
