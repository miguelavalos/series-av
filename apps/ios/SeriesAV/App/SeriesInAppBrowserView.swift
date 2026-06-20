import SafariServices
import SwiftUI

struct SeriesInAppBrowserDestination: Identifiable {
    let url: URL

    var id: URL { url }
}

struct SeriesInAppBrowserView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
