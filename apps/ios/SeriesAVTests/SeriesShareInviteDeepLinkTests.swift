import Foundation
import XCTest
@testable import SeriesAV

final class SeriesShareInviteDeepLinkTests: XCTestCase {
    func testParsesCustomSchemeInviteURL() {
        let url = URL(string: "com.avalsys.seriesav://i/r/share-token-123")!

        XCTAssertEqual(SeriesShareInviteDeepLink(url: url)?.token, "share-token-123")
    }

    func testParsesWebInviteURL() {
        let url = URL(string: "https://app.series-av-preview.avalsys.com/i/r/share-token-123?lang=es")!

        XCTAssertEqual(SeriesShareInviteDeepLink(url: url)?.token, "share-token-123")
    }

    func testBuildsCanonicalWebInviteURL() {
        let link = SeriesShareInviteDeepLink(url: URL(string: "com.avalsys.seriesav://i/r/share-token-123")!)
        let baseURL = URL(string: "https://app.series-av-preview.avalsys.com")!

        XCTAssertEqual(link?.webURL(baseURL: baseURL).absoluteString, "https://app.series-av-preview.avalsys.com/i/r/share-token-123")
    }

    func testRejectsNonInviteURLs() {
        XCTAssertNil(SeriesShareInviteDeepLink(url: URL(string: "com.avalsys.seriesav://library")!))
        XCTAssertNil(SeriesShareInviteDeepLink(url: URL(string: "https://app.series-av-preview.avalsys.com/search")!))
        XCTAssertNil(SeriesShareInviteDeepLink(url: URL(string: "https://example.com/i/r/share-token-123")!))
    }
}
