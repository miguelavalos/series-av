import XCTest

@MainActor
final class SeriesAVProfileUITests: XCTestCase {
    func testSignedInFreeProfileStaysLocalFirstWithoutCloudSync() {
        let app = launchProfileApp(extraEnvironment: [
            "SERIESAV_UI_TESTS_ACCOUNT_MODE": "free"
        ])

        XCTAssertTrue(app.staticTexts["Series UI Test User"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["series-ui-test@example.test"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["profile.sync.card"].exists)
    }

    func testProProfileShowsLibrarySyncConflictResolution() {
        let app = launchProfileApp(extraEnvironment: [
            "SERIESAV_UI_TESTS_ACCOUNT_MODE": "pro",
            "SERIESAV_UI_TESTS_LIBRARY_SYNC_STATE": "conflict"
        ])

        XCTAssertTrue(app.descendants(matching: .any)["profile.sync.card"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["La sincronización necesita atención"].exists)
        XCTAssertTrue(app.staticTexts["Tu biblioteca cambió en otro dispositivo. Actualiza desde la nube antes de hacer más cambios."].exists)
        XCTAssertTrue(app.buttons["Actualizar"].exists)
        XCTAssertTrue(app.buttons["Mantener este dispositivo"].exists)
    }

    func testSignedInFreeCanOpenProPaywallWithRestoreAndLegalLinks() {
        let app = launchProfileApp(extraEnvironment: [
            "SERIESAV_UI_TESTS_ACCOUNT_MODE": "free",
            "SERIESAV_UI_TESTS_SUBSCRIPTION_PRICE": "4,99 €"
        ])

        openProPaywall(in: app)

        XCTAssertTrue(app.descendants(matching: .any)["paywall.sheet"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["paywall.purchase"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["paywall.restore"].exists)

        let redeemButton = app.buttons["paywall.redeemCode"].firstMatch
        let termsButton = app.buttons["paywall.terms"].firstMatch
        let privacyButton = app.buttons["paywall.privacy"].firstMatch
        for _ in 0..<5 where !redeemButton.exists || !termsButton.exists || !privacyButton.exists {
            app.swipeUp()
        }
        XCTAssertTrue(redeemButton.waitForExistence(timeout: 3))
        XCTAssertTrue(redeemButton.isHittable)
        redeemButton.tap()
        XCTAssertTrue(app.descendants(matching: .any)["paywall.redeemCode.sheet"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.textFields["paywall.redeemCode.field"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["paywall.redeemCode.claim"].exists)
        app.buttons["paywall.redeemCode.done"].tap()
        XCTAssertFalse(app.textFields["paywall.redeemCode.field"].waitForExistence(timeout: 3))

        XCTAssertTrue(termsButton.waitForExistence(timeout: 3))
        XCTAssertTrue(privacyButton.waitForExistence(timeout: 3))
    }

    func testGuestProActionOpensSignInInsteadOfPaywall() {
        let app = launchProfileApp(extraEnvironment: [
            "SERIESAV_UI_TESTS_ACCOUNT_MODE": "guest_available"
        ])

        let signInButton = app.buttons["profile.pro.signIn"].firstMatch
        for _ in 0..<6 where !signInButton.exists || !signInButton.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(signInButton.waitForExistence(timeout: 5))
        XCTAssertTrue(signInButton.isHittable)
        signInButton.tap()

        XCTAssertTrue(app.buttons["series.onboarding.auth.apple"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["series.onboarding.auth.google"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["paywall.sheet"].exists)
    }

    func testDeleteAccountEligibleFreeSeriesOnlyFlowSignsOutLocally() {
        let app = launchProfileApp(extraEnvironment: [
            "SERIESAV_UI_TESTS_ACCOUNT_MODE": "free",
            "SERIESAV_UI_TEST_ACCOUNT_DELETION": "eligible"
        ])

        openAccountDeletion(in: app)
        XCTAssertTrue(app.descendants(matching: .any)["accountDeletion.status.eligible"].waitForExistence(timeout: 5))

        let confirmation = app.textFields["accountDeletion.confirmation"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 3))
        confirmation.tap()
        confirmation.typeText("DELETE")
        app.buttons["accountDeletion.deleteButton"].tap()

        XCTAssertTrue(app.buttons["profile.account.signIn"].waitForExistence(timeout: 5))
    }

    func testDeleteAccountWarnsForLinkedApp() {
        let app = launchProfileApp(extraEnvironment: [
            "SERIESAV_UI_TESTS_ACCOUNT_MODE": "free",
            "SERIESAV_UI_TEST_ACCOUNT_DELETION": "blocked_series"
        ])

        openAccountDeletion(in: app)

        XCTAssertTrue(app.descendants(matching: .any)["accountDeletion.status.eligible"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["accountDeletion.impact.linkedApps"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["accountDeletion.warning.linkedApp"].exists)
        XCTAssertTrue(app.buttons["accountDeletion.deleteButton"].exists)
    }

    func testDeleteAccountWarnsForActivePro() {
        let app = launchProfileApp(extraEnvironment: [
            "SERIESAV_UI_TESTS_ACCOUNT_MODE": "pro",
            "SERIESAV_UI_TEST_ACCOUNT_DELETION": "blocked_pro"
        ])

        openAccountDeletion(in: app)

        XCTAssertTrue(app.descendants(matching: .any)["accountDeletion.status.eligible"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["accountDeletion.impact.high"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["accountDeletion.warning.activeProAccess"].exists)
        XCTAssertTrue(app.buttons["accountDeletion.deleteButton"].exists)
    }

    func testCompletedDeletionSignsOutLocally() {
        let app = launchProfileApp(extraEnvironment: [
            "SERIESAV_UI_TESTS_ACCOUNT_MODE": "free",
            "SERIESAV_UI_TEST_ACCOUNT_DELETION": "completed"
        ])

        tapAccountDeletionRow(in: app)

        XCTAssertTrue(app.buttons["profile.account.signIn"].waitForExistence(timeout: 5))
    }

    private func launchProfileApp(extraEnvironment: [String: String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["SERIESAV_UI_TESTS"] = "1"
        app.launchEnvironment["SERIESAV_UI_TESTS_FORCE_GUEST"] = "0"
        app.launchEnvironment["SERIESAV_UI_TESTS_RESET_STATE"] = "1"
        app.launchEnvironment["SERIESAV_DISABLE_SPLASH"] = "1"
        app.launchEnvironment["SERIESAV_DISABLE_ONBOARDING"] = "1"
        app.launchEnvironment["SERIESAV_UI_TESTS_INITIAL_CHROME"] = "account"
        for (key, value) in extraEnvironment {
            app.launchEnvironment[key] = value
        }
        app.launchArguments += ["-AppleLanguages", "(es)", "-AppleLocale", "es_ES"]
        app.launch()

        addTeardownBlock {
            app.terminate()
        }

        return app
    }

    private func openAccountDeletion(in app: XCUIApplication) {
        tapAccountDeletionRow(in: app)
        let sheet = app.descendants(matching: .any)["accountDeletion.sheet"]
        if !sheet.waitForExistence(timeout: 5) {
            tapAccountDeletionRow(in: app)
        }
        XCTAssertTrue(sheet.waitForExistence(timeout: 5))
    }

    private func openProPaywall(in app: XCUIApplication) {
        let upgradeButton = app.buttons["profile.pro.upgrade"].firstMatch
        for _ in 0..<6 where !upgradeButton.exists || !upgradeButton.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(upgradeButton.waitForExistence(timeout: 5))
        XCTAssertTrue(upgradeButton.isHittable)
        upgradeButton.tap()
    }

    private func tapAccountDeletionRow(in app: XCUIApplication) {
        let deleteRow = app.descendants(matching: .any)["profile.safety.delete"].firstMatch
        for _ in 0..<6 where !deleteRow.exists || !deleteRow.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(deleteRow.waitForExistence(timeout: 5))
        XCTAssertTrue(deleteRow.isHittable)
        deleteRow.tap()
    }
}
