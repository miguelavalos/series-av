import XCTest

@MainActor
final class SeriesAVShellChromeUITests: XCTestCase {
    func testHeaderAccountAndSettingsChromeClearWhenSelectingTabs() {
        let app = launchHomeApp()

        XCTAssertTrue(app.staticTexts["Sigue tu primera serie"].waitForExistence(timeout: 10))

        app.buttons["header.account"].tap()
        XCTAssertTrue(app.staticTexts["Cuenta"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["profile.account.signIn"].exists)

        app.buttons["series.tab.search"].tap()
        XCTAssertTrue(app.staticTexts["Buscar series"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Cuenta"].exists)

        app.buttons["series.tab.home"].tap()
        XCTAssertTrue(app.staticTexts["Sigue tu primera serie"].waitForExistence(timeout: 5))

        app.buttons["header.settings"].tap()
        XCTAssertTrue(app.staticTexts["Ajustes"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Preferencias de Series AV"].exists)

        app.buttons["series.tab.library"].tap()
        XCTAssertTrue(app.staticTexts["Biblioteca"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Ajustes"].exists)
    }

    private func launchHomeApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["SERIESAV_UI_TESTS"] = "1"
        app.launchEnvironment["SERIESAV_UI_TESTS_FORCE_GUEST"] = "1"
        app.launchEnvironment["SERIESAV_UI_TESTS_RESET_STATE"] = "1"
        app.launchEnvironment["SERIESAV_DISABLE_SPLASH"] = "1"
        app.launchEnvironment["SERIESAV_DISABLE_ONBOARDING"] = "1"
        app.launchArguments += ["-AppleLanguages", "(es)", "-AppleLocale", "es_ES"]
        app.launch()

        addTeardownBlock {
            app.terminate()
        }

        return app
    }
}
