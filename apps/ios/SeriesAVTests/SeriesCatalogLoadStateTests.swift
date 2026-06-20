import XCTest
@testable import SeriesAV

final class SeriesCatalogLoadStateTests: XCTestCase {
    func testCurrentRequestFinishClearsLoadingState() {
        var state = SeriesCatalogLoadState()

        let token = state.begin()
        state.finish(token)

        XCTAssertFalse(state.isLoading)
        XCTAssertNil(state.activeToken)
    }

    func testStaleRequestFinishDoesNotClearCurrentLoadingState() {
        var state = SeriesCatalogLoadState()

        let staleToken = state.begin()
        let currentToken = state.begin()
        state.finish(staleToken)

        XCTAssertTrue(state.isLoading)
        XCTAssertEqual(state.activeToken, currentToken)

        state.finish(currentToken)

        XCTAssertFalse(state.isLoading)
        XCTAssertNil(state.activeToken)
    }
}
