import Foundation

struct SeriesShareInviteDeepLink: Equatable {
    private static let allowedWebHosts = Set([
        "app.series-av-preview.avalsys.com",
        "app.series-av.avalsys.com",
    ])

    let token: String
    private let originalWebURL: URL?

    init?(url: URL) {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        let sharePath = Self.sharePathComponents(from: url, components: components, pathComponents: pathComponents)

        guard sharePath.count == 3,
              sharePath[0] == "i",
              sharePath[1] == "r",
              sharePath[2].isEmpty == false else {
            return nil
        }

        token = sharePath[2]
        originalWebURL = Self.isAllowedWebURL(url, components: components) ? url : nil
    }

    func webURL(baseURL: URL = AppConfig.seriesWebBaseURL) -> URL {
        if let originalWebURL {
            return originalWebURL
        }

        return baseURL
            .appending(path: "i")
            .appending(path: "r")
            .appending(path: token)
    }

    private static func sharePathComponents(
        from url: URL,
        components: URLComponents?,
        pathComponents: [String]
    ) -> [String] {
        if isWebURL(url) {
            guard isAllowedWebURL(url, components: components) else {
                return []
            }

            return pathComponents
        }

        guard let host = components?.host, host.isEmpty == false else {
            return pathComponents
        }

        return [host] + pathComponents
    }

    private static func isAllowedWebURL(_ url: URL, components: URLComponents?) -> Bool {
        guard isWebURL(url),
              let host = components?.host?.lowercased() else {
            return false
        }

        return allowedWebHosts.contains(host)
    }

    private static func isWebURL(_ url: URL) -> Bool {
        let scheme = url.scheme?.lowercased()
        return scheme == "http" || scheme == "https"
    }
}
