import XCTest
@testable import SeriesAV

final class SeriesAppDataSyncClientTests: XCTestCase {
    func testPullLibraryUsesSeriesLibraryResourceAndCarriesETagHeader() async throws {
        let response = """
        {
          "data": {
            "appId": "seriesav",
            "resource": "seriesLibrary",
            "deviceId": "ios-device",
            "sentAt": "2026-06-12T10:00:00Z",
            "entries": []
          },
          "updatedAt": "2026-06-12T10:00:00Z",
          "revision": 4
        }
        """.data(using: .utf8)!

        let client = SeriesAppDataSyncClient(deviceId: "ios-device") { path, method, body, headers in
            XCTAssertEqual(path, "/v1/apps/seriesav/data/seriesLibrary")
            XCTAssertEqual(method, "GET")
            XCTAssertNil(body)
            XCTAssertTrue(headers.isEmpty)
            return (response, "\"revision-4\"")
        }

        let document = try await client.pullLibrary()

        XCTAssertEqual(document.data.resource, "seriesLibrary")
        XCTAssertEqual(document.revision, 4)
        XCTAssertEqual(document.etag, "\"revision-4\"")
    }

    func testPushLibrarySendsIfMatchAndV1Envelope() async throws {
        let response = """
        {
          "data": {
            "appId": "seriesav",
            "resource": "seriesLibrary",
            "deviceId": "ios-device",
            "sentAt": "2026-06-12T10:00:00Z",
            "entries": []
          },
          "updatedAt": "2026-06-12T10:00:00Z",
          "revision": 5,
          "etag": "\\\"revision-5\\\""
        }
        """.data(using: .utf8)!

        let client = SeriesAppDataSyncClient(deviceId: "ios-device") { path, method, body, headers in
            XCTAssertEqual(path, "/v1/apps/seriesav/data/seriesLibrary")
            XCTAssertEqual(method, "PUT")
            XCTAssertEqual(headers["If-Match"], "\"revision-4\"")
            XCTAssertEqual(headers["Content-Type"], "application/json")

            let payload = try XCTUnwrap(body)
            let json = try JSONSerialization.jsonObject(with: payload) as? [String: Any]
            XCTAssertEqual(json?["appId"] as? String, "seriesav")
            XCTAssertEqual(json?["resource"] as? String, "seriesLibrary")
            XCTAssertEqual(json?["deviceId"] as? String, "ios-device")

            return (response, "\"revision-5\"")
        }

        let document = try await client.pushLibrary(entries: [], expectedETag: "\"revision-4\"")

        XCTAssertEqual(document.revision, 5)
        XCTAssertEqual(document.etag, "\"revision-5\"")
    }

    func testPushLibraryWithoutExpectedETagOmitsIfMatchForOverwrite() async throws {
        let response = """
        {
          "data": {
            "appId": "seriesav",
            "resource": "seriesLibrary",
            "deviceId": "ios-device",
            "sentAt": "2026-06-12T10:00:00Z",
            "entries": []
          },
          "updatedAt": "2026-06-12T10:00:00Z",
          "revision": 6,
          "etag": "\\\"revision-6\\\""
        }
        """.data(using: .utf8)!

        let client = SeriesAppDataSyncClient(deviceId: "ios-device") { _, method, body, headers in
            XCTAssertEqual(method, "PUT")
            XCTAssertNotNil(body)
            XCTAssertNil(headers["If-Match"])
            XCTAssertEqual(headers["Content-Type"], "application/json")
            return (response, "\"revision-6\"")
        }

        let document = try await client.pushLibrary(entries: [], expectedETag: nil)

        XCTAssertEqual(document.revision, 6)
        XCTAssertEqual(document.etag, "\"revision-6\"")
    }
}
