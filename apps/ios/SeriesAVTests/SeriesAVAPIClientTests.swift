import Foundation
import XCTest
@testable import SeriesAV

final class SeriesAVAPIClientTests: XCTestCase {
    override func tearDown() {
        MockSeriesURLProtocol.reset()
        super.tearDown()
    }

    func testPopularBuildsQueryURLAndDecodesFractionalDates() async throws {
        let response = """
        {
          "results": [
            {
              "seriesId": "thetvdb:348545",
              "providerRef": {
                "provider": "thetvdb",
                "providerSeriesId": "348545",
                "isPrimary": true
              },
              "providerRefs": [
                {
                  "provider": "thetvdb",
                  "providerSeriesId": "348545",
                  "isPrimary": true
                }
              ],
              "title": "Demon Slayer: Kimetsu no Yaiba",
              "startYear": 2019,
              "statusText": "Running",
              "summary": "A reviewed English catalog summary.",
              "genres": ["Anime"],
              "displayArtwork": {
                "kind": "providerPoster",
                "url": "https://artwork.example/demon-slayer.jpg",
                "fallbackSeed": "Demon Slayer",
                "aspectRatio": 0.68,
                "policy": {
                  "displayState": "visible",
                  "reasonCode": null,
                  "evaluatedAt": "2026-06-15T15:02:03.456Z"
                }
              },
              "episodeGuideState": "available",
              "visibility": "public",
              "enrichmentStatus": "enriched",
              "artworkStatus": "provider",
              "metadataUpdatedAt": "2026-06-15T15:02:03.789Z"
            }
          ],
          "pagination": {
            "total": 1,
            "limit": 12,
            "returned": 1,
            "hasMore": false,
            "nextCursor": null,
            "totalIsExact": true
          },
          "source": "d1",
          "generatedAt": "2026-06-15T15:02:04.123Z"
        }
        """.data(using: .utf8)!
        MockSeriesURLProtocol.response = (
            response,
            HTTPURLResponse(
                url: URL(string: "https://api-series-av.test/v1/series/popular")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
        )

        let client = SeriesCatalogSearchClient(
            apiClient: SeriesAVAPIClient(
                baseURL: URL(string: "https://api-series-av.test")!,
                urlSession: Self.mockSession()
            )
        )

        let result = try await client.popular(locale: "es", surface: "upcoming")

        let requestURL = try XCTUnwrap(MockSeriesURLProtocol.lastRequest?.url)
        XCTAssertEqual(requestURL.path, "/v1/series/popular")
        XCTAssertEqual(URLComponents(url: requestURL, resolvingAgainstBaseURL: false)?.queryItems?.sorted(by: { $0.name < $1.name }), [
            URLQueryItem(name: "limit", value: "12"),
            URLQueryItem(name: "locale", value: "es"),
            URLQueryItem(name: "surface", value: "upcoming")
        ])
        XCTAssertEqual(result.results.first?.title, "Demon Slayer: Kimetsu no Yaiba")
        let metadataUpdatedAt = try XCTUnwrap(result.results.first?.metadataUpdatedAt)
        XCTAssertEqual(metadataUpdatedAt.timeIntervalSince1970, 1_781_535_723.789, accuracy: 0.001)
        XCTAssertEqual(result.generatedAt.timeIntervalSince1970, 1_781_535_724.123, accuracy: 0.001)
    }

    private static func mockSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockSeriesURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private final class MockSeriesURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var lastRequest: URLRequest?
    nonisolated(unsafe) static var response: (Data, HTTPURLResponse)?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.lastRequest = request
        guard let response = Self.response else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        client?.urlProtocol(self, didReceive: response.1, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: response.0)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    static func reset() {
        lastRequest = nil
        response = nil
    }
}
