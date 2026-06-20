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
              "displayBackdrop": {
                "kind": "curated",
                "url": "https://artwork.example/demon-slayer-backdrop.jpg",
                "aspectRatio": 1.7777777778,
                "policy": {
                  "displayState": "fallbackOnly",
                  "reasonCode": "availableNotPromoted",
                  "evaluatedAt": "2026-06-15T15:02:03.456Z"
                }
              },
              "episodeGuideState": "available",
              "visibility": "public",
              "enrichmentStatus": "enriched",
              "artworkStatus": "provider",
              "externalLinks": [
                {
                  "kind": "imdb",
                  "label": "Open IMDb",
                  "url": "https://www.imdb.com/find/?q=Demon+Slayer+2019"
                },
                {
                  "kind": "wikipedia",
                  "label": "Open Wikipedia",
                  "url": "https://www.wikipedia.org/search-redirect.php?search=Demon+Slayer+2019"
                }
              ],
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
        XCTAssertEqual(result.results.first?.displayBackdrop?.url?.absoluteString, "https://artwork.example/demon-slayer-backdrop.jpg")
        XCTAssertEqual(result.results.first?.displayBackdrop?.policy.displayState, "fallbackOnly")
        XCTAssertEqual(result.results.first?.displayBackdrop?.policy.reasonCode, "availableNotPromoted")
        XCTAssertEqual(result.results.first?.externalLinks?.map(\.kind), ["imdb", "wikipedia"])
        XCTAssertEqual(result.results.first?.externalLinks?.last?.url.absoluteString, "https://www.wikipedia.org/search-redirect.php?search=Demon+Slayer+2019")
        let metadataUpdatedAt = try XCTUnwrap(result.results.first?.metadataUpdatedAt)
        XCTAssertEqual(metadataUpdatedAt.timeIntervalSince1970, 1_781_535_723.789, accuracy: 0.001)
        XCTAssertEqual(result.generatedAt.timeIntervalSince1970, 1_781_535_724.123, accuracy: 0.001)
    }

    func testShareInviteCreateSendsAuthenticatedPostAndDecodesResponse() async throws {
        let response = """
        {
          "invite": {
            "id": "invite_123",
            "kind": "recommendation",
            "seriesId": "thetvdb:348545",
            "message": "Watch this",
            "senderDisplayName": "Series User",
            "status": "active",
            "expiresAt": "2026-06-22T10:00:00.000Z",
            "createdAt": "2026-06-20T10:00:00.000Z",
            "series": {
              "title": "Demon Slayer",
              "startYear": 2019,
              "summary": "A reviewed summary.",
              "displayArtwork": {
                "kind": "providerPoster",
                "url": "https://artwork.example/demon.jpg",
                "assetName": null,
                "fallbackSeed": "Demon Slayer"
              }
            }
          },
          "token": "share-token-123",
          "generatedAt": "2026-06-20T10:00:01.250Z"
        }
        """.data(using: .utf8)!
        MockSeriesURLProtocol.response = (
            response,
            HTTPURLResponse(
                url: URL(string: "https://api-series-av.test/v1/series/share-invites")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
        )

        let client = SeriesShareInviteClient(
            apiClient: SeriesAVAPIClient(
                baseURL: URL(string: "https://api-series-av.test")!,
                urlSession: Self.mockSession(),
                tokenProvider: { "account-token" }
            )
        )

        let result = try await client.createRecommendation(seriesId: "thetvdb:348545", message: "Watch this")

        let request = try XCTUnwrap(MockSeriesURLProtocol.lastRequest)
        XCTAssertEqual(request.url?.path, "/v1/series/share-invites")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer account-token")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

        let body = try XCTUnwrap(MockSeriesURLProtocol.lastRequestBody)
        let payload = try JSONDecoder().decode(SeriesShareInviteCreateRequest.self, from: body)
        XCTAssertEqual(payload, SeriesShareInviteCreateRequest(seriesId: "thetvdb:348545", message: "Watch this"))

        XCTAssertEqual(result.token, "share-token-123")
        XCTAssertEqual(result.invite.id, "invite_123")
        XCTAssertEqual(result.invite.series?.title, "Demon Slayer")
        XCTAssertEqual(result.invite.series?.displayArtwork?.url?.absoluteString, "https://artwork.example/demon.jpg")
        XCTAssertEqual(result.generatedAt.timeIntervalSince1970, 1_781_949_601.25, accuracy: 0.001)
    }

    func testShareInviteCreateWithoutTokenFailsBeforeSendingRequest() async throws {
        let client = SeriesShareInviteClient(
            apiClient: SeriesAVAPIClient(
                baseURL: URL(string: "https://api-series-av.test")!,
                urlSession: Self.mockSession(),
                tokenProvider: { nil }
            )
        )

        do {
            _ = try await client.createRecommendation(seriesId: "thetvdb:348545")
            XCTFail("Expected missing token")
        } catch SeriesAVAPIClientError.missingToken {
            XCTAssertNil(MockSeriesURLProtocol.lastRequest)
        }
    }

    private static func mockSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockSeriesURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private final class MockSeriesURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var lastRequest: URLRequest?
    nonisolated(unsafe) static var lastRequestBody: Data?
    nonisolated(unsafe) static var response: (Data, HTTPURLResponse)?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.lastRequest = request
        Self.lastRequestBody = request.httpBody ?? request.httpBodyStream?.readAllData()
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
        lastRequestBody = nil
        response = nil
    }
}

private extension InputStream {
    func readAllData() -> Data {
        open()
        defer { close() }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while hasBytesAvailable {
            let count = read(&buffer, maxLength: buffer.count)
            if count > 0 {
                data.append(buffer, count: count)
            } else {
                break
            }
        }
        return data
    }
}
