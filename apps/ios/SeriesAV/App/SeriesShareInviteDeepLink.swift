import Foundation

struct SeriesShareInviteDeepLink: Equatable {
    private static let allowedWebHosts = Set([
        "app.series-av-preview.avalsys.com",
        "app.series-av.avalsys.com",
    ])

    let token: String

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
    }

    func webURL(baseURL: URL = AppConfig.seriesWebBaseURL) -> URL {
        baseURL
            .appending(path: "i")
            .appending(path: "r")
            .appending(path: token)
    }

    private static func sharePathComponents(
        from url: URL,
        components: URLComponents?,
        pathComponents: [String]
    ) -> [String] {
        let scheme = url.scheme?.lowercased()

        if scheme == "http" || scheme == "https" {
            guard let host = components?.host?.lowercased(),
                  allowedWebHosts.contains(host) else {
                return []
            }

            return pathComponents
        }

        guard let host = components?.host, host.isEmpty == false else {
            return pathComponents
        }

        return [host] + pathComponents
    }
}
