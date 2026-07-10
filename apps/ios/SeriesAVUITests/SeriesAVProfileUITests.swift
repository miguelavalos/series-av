import XCTest

@MainActor
final class SeriesAVProfileUITests: XCTestCase {
    func testSignedInFreeProfileStaysLocalFirstWithoutCloudSync() {
        let app = launchProfileApp(extraEnvironment: [
            "SERIESAV_UI_TESTS_ACCOUNT_MODE": "free"
        ])

        XCTAssertTrue(app.staticTexts["Series UI Test User"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Conectado a Account AV."].exists)
        XCTAssertEqual(
            app.staticTexts.matching(NSPredicate(format: "label == %@", "series-ui-test@example.test")).count,
            1
        )
        XCTAssertTrue(app.staticTexts["Sesión"].exists)
        XCTAssertTrue(app.staticTexts["Acceso"].exists)
        XCTAssertTrue(app.staticTexts["Plan gratuito"].exists)
        XCTAssertFalse(app.staticTexts["Cuenta conectada"].exists)
        let accountCard = app.descendants(matching: .any)["profile.account.card"]
        let signOutButton = app.buttons["profile.account.signOut"]
        XCTAssertTrue(accountCard.exists)
        XCTAssertTrue(signOutButton.exists)
        XCTAssertTrue(signOutButton.isHittable)
        XCTAssertGreaterThanOrEqual(signOutButton.frame.height, 44)
        XCTAssertLessThanOrEqual(signOutButton.frame.width, 201.5)
        XCTAssertLessThan(signOutButton.frame.width, accountCard.frame.width - 32)
        let upgradeButton = app.buttons["profile.pro.upgrade"]
        let proBenefits = app.descendants(matching: .any)["profile.pro.benefits"]
        XCTAssertTrue(upgradeButton.exists)
        XCTAssertTrue(upgradeButton.isHittable)
        XCTAssertGreaterThanOrEqual(upgradeButton.frame.height, 44)
        XCTAssertTrue(proBenefits.exists)
        XCTAssertLessThan(upgradeButton.frame.minY, proBenefits.frame.minY)
        if app.frame.width <= 600 {
            XCTAssertLessThanOrEqual(proBenefits.frame.height, 160)
        }
        if app.frame.width <= 600 {
            let footerTab = app.buttons["series.tab.home"]
            XCTAssertTrue(footerTab.exists)
            XCTAssertLessThanOrEqual(upgradeButton.frame.maxY, footerTab.frame.minY - 12)
        }
        let safetyAction = app.buttons["profile.safety.delete"]
        XCTAssertTrue(safetyAction.exists)
        if app.frame.width <= 600 {
            XCTAssertLessThanOrEqual(safetyAction.frame.height, 84)
        }
        XCTAssertFalse(app.descendants(matching: .any)["profile.sync.card"].exists)
    }

    func testSignedInFreeProfileAdaptsAtAccessibilityTextSize() {
        let app = launchProfileApp(
            extraEnvironment: [
                "SERIESAV_UI_TESTS_ACCOUNT_MODE": "free"
            ],
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL"
        )

        let screenTitle = app.staticTexts["Mi cuenta"]
        let signOutButton = app.buttons["profile.account.signOut"]
        XCTAssertTrue(screenTitle.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(screenTitle.frame.height, 44)
        XCTAssertTrue(signOutButton.exists)
        for _ in 0..<3 where !signOutButton.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(signOutButton.isHittable)
        XCTAssertGreaterThanOrEqual(signOutButton.frame.height, 55.5)

        let upgradeButton = app.buttons["profile.pro.upgrade"]
        for _ in 0..<5 where !upgradeButton.exists || !upgradeButton.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(upgradeButton.isHittable)
        XCTAssertGreaterThanOrEqual(upgradeButton.frame.height, 55.5)
        XCTAssertTrue(app.staticTexts["Cuenta Pro"].exists)
        XCTAssertTrue(app.staticTexts["Mantén el acceso Pro vinculado a tu cuenta de Apps AV."].exists)

        let safetyAction = app.buttons["profile.safety.delete"]
        for _ in 0..<6 where !safetyAction.exists || !safetyAction.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(safetyAction.isHittable)
        XCTAssertGreaterThan(safetyAction.frame.height, 120)
        XCTAssertTrue(app.staticTexts["Eliminar cuenta de Apps AV"].exists)
        XCTAssertTrue(app.staticTexts["Solicita eliminar tu cuenta compartida de Apps AV."].exists)
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

    func testProProfileSyncConflictRemainsReadableAtAccessibilityTextSize() {
        let app = launchProfileApp(
            extraEnvironment: [
                "SERIESAV_UI_TESTS_ACCOUNT_MODE": "pro",
                "SERIESAV_UI_TESTS_LIBRARY_SYNC_STATE": "conflict"
            ],
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL"
        )

        let syncCard = app.descendants(matching: .any)["profile.sync.card"]
        let syncDetail = app.staticTexts[
            "Tu biblioteca cambió en otro dispositivo. Actualiza desde la nube antes de hacer más cambios."
        ]
        let refreshButton = app.buttons["Actualizar"]
        let keepDeviceButton = app.buttons["Mantener este dispositivo"]
        XCTAssertTrue(syncCard.waitForExistence(timeout: 5))
        XCTAssertTrue(syncDetail.exists)
        XCTAssertGreaterThan(syncDetail.frame.height, 100)

        for _ in 0..<8 where !refreshButton.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(refreshButton.isHittable)
        XCTAssertGreaterThanOrEqual(refreshButton.frame.height, 55.5)
        XCTAssertLessThan(syncDetail.frame.maxY, refreshButton.frame.minY)

        for _ in 0..<4 where !keepDeviceButton.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(keepDeviceButton.isHittable)
        XCTAssertGreaterThanOrEqual(keepDeviceButton.frame.height, 55.5)
        XCTAssertFalse(refreshButton.frame.intersects(keepDeviceButton.frame))
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

    func testGuestUsesSingleAccountActionToOpenSignInInsteadOfPaywall() {
        let app = launchProfileApp(extraEnvironment: [
            "SERIESAV_UI_TESTS_ACCOUNT_MODE": "guest_available"
        ])

        let signInButton = app.buttons["profile.account.signIn"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: 5))
        XCTAssertTrue(signInButton.isHittable)
        let accountCard = app.descendants(matching: .any)["profile.account.card"]
        XCTAssertTrue(accountCard.exists)
        XCTAssertLessThan(accountCard.frame.height, 270)
        XCTAssertTrue(app.descendants(matching: .any)["profile.account.localMode"].exists)
        XCTAssertTrue(app.staticTexts["Sin una cuenta conectada"].exists)
        XCTAssertTrue(app.staticTexts["Modo local"].exists)
        XCTAssertFalse(app.staticTexts["Sesión"].exists)
        XCTAssertFalse(app.staticTexts["Acceso"].exists)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label == %@", "Iniciar sesión")).count, 1)
        XCTAssertFalse(app.buttons["profile.pro.signIn"].exists)
        signInButton.tap()

        XCTAssertTrue(app.buttons["series.onboarding.auth.apple"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["series.onboarding.auth.google"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["paywall.sheet"].exists)
    }

    func testDeleteAccountCanBeCancelledWithoutSigningOut() {
        let app = launchProfileApp(extraEnvironment: [
            "SERIESAV_UI_TESTS_ACCOUNT_MODE": "free",
            "SERIESAV_UI_TEST_ACCOUNT_DELETION": "eligible"
        ])

        openAccountDeletion(in: app)

        let cancelButton = app.buttons["accountDeletion.cancel"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 3))
        XCTAssertEqual(cancelButton.label, "Cancelar")
        cancelButton.tap()

        XCTAssertFalse(app.descendants(matching: .any)["accountDeletion.sheet"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Series UI Test User"].exists)
        XCTAssertFalse(app.buttons["profile.account.signIn"].exists)
    }

    func testDeleteAccountLoadErrorIsExclusiveAndRetryRecovers() {
        let app = launchProfileApp(extraEnvironment: [
            "SERIESAV_UI_TESTS_ACCOUNT_MODE": "free",
            "SERIESAV_UI_TEST_ACCOUNT_DELETION": "load_error_once"
        ])

        openAccountDeletion(in: app)

        XCTAssertTrue(app.descendants(matching: .any)["accountDeletion.loadError"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["accountDeletion.status.error"].exists)
        XCTAssertTrue(app.buttons["accountDeletion.retry"].exists)
        XCTAssertTrue(app.buttons["accountDeletion.accountWebsiteLink"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["accountDeletion.shared"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["accountDeletion.status.unavailable"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["accountDeletion.confirm.panel"].exists)

        app.buttons["accountDeletion.retry"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["accountDeletion.status.eligible"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["accountDeletion.loadError"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["accountDeletion.confirm.panel"].exists)
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

    func testDeleteAccountConfirmationReturnDismissesKeyboard() {
        let app = launchProfileApp(extraEnvironment: [
            "SERIESAV_UI_TESTS_ACCOUNT_MODE": "free",
            "SERIESAV_UI_TEST_ACCOUNT_DELETION": "eligible"
        ])

        openAccountDeletion(in: app)

        let eligibilityStatus = app.staticTexts["accountDeletion.status.eligible"]
        XCTAssertTrue(eligibilityStatus.waitForExistence(timeout: 3))
        XCTAssertFalse(eligibilityStatus.isSelected)

        let confirmation = app.textFields["accountDeletion.confirmation"]
        XCTAssertEqual(confirmation.label, "Código de confirmación")
        XCTAssertEqual(confirmation.value as? String, "Vacío")
        confirmation.tap()
        confirmation.typeText("DELETE")
        XCTAssertEqual(confirmation.value as? String, "DELETE")

        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 3))
        let doneKey = keyboard.buttons["Done"]
        XCTAssertTrue(doneKey.waitForExistence(timeout: 3))
        doneKey.tap()

        XCTAssertFalse(keyboard.waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["accountDeletion.deleteButton"].isHittable)
    }

    func testDeleteAccountRequestErrorStaysWithConfirmationAction() {
        let app = launchProfileApp(extraEnvironment: [
            "SERIESAV_UI_TESTS_ACCOUNT_MODE": "free",
            "SERIESAV_UI_TEST_ACCOUNT_DELETION": "request_error"
        ])

        openAccountDeletion(in: app)
        XCTAssertTrue(app.descendants(matching: .any)["accountDeletion.status.eligible"].waitForExistence(timeout: 5))

        let confirmationPanel = app.descendants(matching: .any)["accountDeletion.confirm.panel"]
        let confirmation = app.textFields["accountDeletion.confirmation"]
        confirmation.tap()
        confirmation.typeText("DELETE")
        app.buttons["accountDeletion.deleteButton"].tap()

        let operationError = app.descendants(matching: .any)["accountDeletion.operationError.requestDeletion"]
        XCTAssertTrue(operationError.waitForExistence(timeout: 5))
        XCTAssertFalse(app.keyboards.firstMatch.waitForExistence(timeout: 2))
        XCTAssertFalse(app.descendants(matching: .any)["accountDeletion.status.error"].exists)
        XCTAssertGreaterThanOrEqual(operationError.frame.minY, confirmationPanel.frame.minY)
        XCTAssertLessThanOrEqual(operationError.frame.maxY, confirmationPanel.frame.maxY)
        XCTAssertLessThan(operationError.frame.maxY, confirmation.frame.minY)
    }

    func testDeleteAccountWarnsForLinkedApp() {
        let app = launchProfileApp(extraEnvironment: [
            "SERIESAV_UI_TESTS_ACCOUNT_MODE": "free",
            "SERIESAV_UI_TEST_ACCOUNT_DELETION": "blocked_series"
        ])

        openAccountDeletion(in: app)

        let summary = app.descendants(matching: .any)["accountDeletion.eligible.summary"]
        XCTAssertTrue(app.descendants(matching: .any)["accountDeletion.status.eligible"].waitForExistence(timeout: 5))
        XCTAssertTrue(summary.exists)
        XCTAssertLessThanOrEqual(summary.frame.height, 180)
        XCTAssertFalse(app.descendants(matching: .any)["accountDeletion.shared"].exists)
        let impact = app.descendants(matching: .any)["accountDeletion.impact.linkedApps"].firstMatch
        let warningList = app.descendants(matching: .any)["accountDeletion.warning.list"]
        let linkedAppWarning = app.descendants(matching: .any)["accountDeletion.warning.linkedApp"]
        let confirmationPanel = app.descendants(matching: .any)["accountDeletion.confirm.panel"]
        let confirmation = app.textFields["accountDeletion.confirmation"]
        XCTAssertTrue(impact.exists)
        XCTAssertTrue(warningList.exists)
        XCTAssertTrue(linkedAppWarning.exists)
        XCTAssertTrue(confirmationPanel.exists)
        XCTAssertTrue(app.descendants(matching: .any)["accountDeletion.confirm.title"].exists)
        XCTAssertLessThanOrEqual(warningList.frame.height, 100)
        XCTAssertLessThan(impact.frame.minY, linkedAppWarning.frame.minY)
        XCTAssertLessThan(linkedAppWarning.frame.minY, confirmation.frame.minY)
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
        XCTAssertTrue(app.descendants(matching: .any)["accountDeletion.impact.high.item.access"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["accountDeletion.impact.high.item.credits"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["accountDeletion.impact.high.item.data"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["accountDeletion.impact.high.footer"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["accountDeletion.warning.activeProAccess"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["accountDeletion.confirm.panel"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["accountDeletion.confirm.title"].exists)
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

    private func launchProfileApp(
        extraEnvironment: [String: String],
        contentSizeCategory: String? = nil
    ) -> XCUIApplication {
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
        if let contentSizeCategory {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", contentSizeCategory]
        }
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
