import SafariServices
import SwiftUI

struct SeriesInAppBrowserDestination: Identifiable {
    let url: URL

    var id: URL { url }
}

struct SeriesInAppBrowserView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let configuration = SFSafariViewController.Configuration()
        configuration.barCollapsingEnabled = false

        let controller = SFSafariViewController(url: url, configuration: configuration)
        controller.dismissButtonStyle = .close
        controller.view.accessibilityIdentifier = "browser.inApp"
        return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
