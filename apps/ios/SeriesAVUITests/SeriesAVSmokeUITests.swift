import XCTest

final class SeriesAVSmokeUITests: XCTestCase {
    private struct LocaleSmokeConfiguration {
        let language: String
        let locale: String
        let homeTitle: String
        let searchTab: String
        let searchTitle: String
        let libraryTab: String
        let libraryTitle: String
        let accountTitle: String
        let paywallTitle: String
    }

    private let localeSmokeConfigurations = [
        LocaleSmokeConfiguration(
            language: "es",
            locale: "es_ES",
            homeTitle: "Sigue tu primera serie",
            searchTab: "Buscar",
            searchTitle: "Buscar series",
            libraryTab: "Biblioteca",
            libraryTitle: "Biblioteca",
            accountTitle: "Cuenta",
            paywallTitle: "Sigue más series"
        ),
        LocaleSmokeConfiguration(
            language: "ca",
            locale: "ca_ES",
            homeTitle: "Segueix la primera sèrie",
            searchTab: "Cerca",
            searchTitle: "Cercar sèries",
            libraryTab: "Biblioteca",
            libraryTitle: "Biblioteca",
            accountTitle: "Compte",
            paywallTitle: "Segueix més sèries"
        ),
        LocaleSmokeConfiguration(
            language: "fr",
            locale: "fr_FR",
            homeTitle: "Suivez votre première série",
            searchTab: "Recherche",
            searchTitle: "Rechercher des séries",
            libraryTab: "Bibliothèque",
            libraryTitle: "Bibliothèque",
            accountTitle: "Compte",
            paywallTitle: "Suivez plus de séries"
        ),
        LocaleSmokeConfiguration(
            language: "de",
            locale: "de_DE",
            homeTitle: "Erster Serie folgen",
            searchTab: "Suche",
            searchTitle: "Serien suchen",
            libraryTab: "Bibliothek",
            libraryTitle: "Bibliothek",
            accountTitle: "Konto",
            paywallTitle: "Verfolge mehr Serien"
        )
    ]

    @MainActor
    private func makeApp(
        environment: [String: String] = [:],
        language: String = "es",
        locale: String = "es_ES",
        contentSizeCategory: String? = nil
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["SERIESAV_UI_TESTS"] = "1"
        app.launchEnvironment["SERIESAV_UI_TESTS_FORCE_GUEST"] = "1"
        app.launchEnvironment["SERIESAV_UI_TESTS_RESET_STATE"] = "1"
        app.launchEnvironment["SERIESAV_DISABLE_SPLASH"] = "1"
        app.launchEnvironment["SERIESAV_DISABLE_ONBOARDING"] = "1"
        for (key, value) in environment {
            app.launchEnvironment[key] = value
        }
        app.launchArguments += ["-AppleLanguages", "(\(language))", "-AppleLocale", locale]
        if let contentSizeCategory {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", contentSizeCategory]
        }
        return app
    }

    @MainActor
    private func staticText(matchingLabel label: String, in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    @MainActor
    private func waitForLabel(
        _ label: String,
        on element: XCUIElement,
        timeout: TimeInterval = 2
    ) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", label),
            object: element
        )
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    @MainActor
    func testFollowCatalogSeriesFromSearchAppearsInLibraryAndHome() throws {
        continueAfterFailure = false
        let app = makeApp(contentSizeCategory: "UICTContentSizeCategoryL")
        app.launch()

        XCTAssertTrue(app.staticTexts["Sigue tu primera serie"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Buscar serie"].exists)
        XCTAssertFalse(app.staticTexts["Añade tu primera serie"].exists)

        app.buttons["Buscar"].tap()

        XCTAssertTrue(app.staticTexts["Buscar series"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.textFields["Buscar por título"].exists)
        XCTAssertTrue(app.staticTexts["The Last of Us"].waitForExistence(timeout: 10))

        let firstResultButton = app.buttons["The Last of Us"].firstMatch
        XCTAssertTrue(firstResultButton.waitForExistence(timeout: 5))
        firstResultButton.tap()
        XCTAssertTrue(app.staticTexts["Info de serie"].waitForExistence(timeout: 10))
        let detailTitle = app.staticTexts["series-detail-title"]
        let detailSummary = app.staticTexts["series-detail-summary"]
        XCTAssertTrue(detailTitle.exists)
        XCTAssertTrue(detailSummary.exists)
        XCTAssertEqual(detailTitle.frame.minX, detailSummary.frame.minX, accuracy: 2)
        XCTAssertTrue(app.staticTexts["Seguimiento"].exists)
        XCTAssertTrue(app.staticTexts["Episodios"].exists)
        let notFollowedText = app.staticTexts["series-detail-not-followed"]
        let detailFollowButton = app.buttons["series-detail-follow"]
        XCTAssertTrue(notFollowedText.exists)
        XCTAssertTrue(detailFollowButton.exists)
        for _ in 0..<4 where !detailFollowButton.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(detailFollowButton.isHittable)
        XCTAssertEqual(detailFollowButton.label, "Seguir serie")
        XCTAssertGreaterThanOrEqual(detailFollowButton.frame.height, 44)
        XCTAssertLessThan(detailFollowButton.frame.height, 70)
        XCTAssertLessThan(detailFollowButton.frame.width, app.frame.width * 0.55)
        XCTAssertLessThan(notFollowedText.frame.maxX, detailFollowButton.frame.minX)
        let summaryToggle = app.buttons["series-detail-summary-toggle"]
        XCTAssertTrue(summaryToggle.waitForExistence(timeout: 5))
        XCTAssertEqual(summaryToggle.label, "Ver más")
        summaryToggle.tap()
        XCTAssertTrue(waitForLabel("Ver menos", on: summaryToggle))
        summaryToggle.tap()
        XCTAssertTrue(waitForLabel("Ver más", on: summaryToggle))
        app.buttons["Cerrar"].tap()

        let firstFollowButton = app.buttons["Seguir serie"].firstMatch
        XCTAssertTrue(firstFollowButton.waitForExistence(timeout: 5))
        firstFollowButton.tap()

        XCTAssertTrue(app.staticTexts["\"The Last of Us\" seguida"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Último episodio visto"].exists)
        XCTAssertFalse(app.staticTexts["Añadir serie"].exists)

        app.buttons["Biblioteca"].tap()
        XCTAssertTrue(app.staticTexts["Todo · 1"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["The Last of Us"].exists)
        XCTAssertTrue(app.staticTexts["Por ver · Empezar por S1 E1"].exists)

        app.buttons["Inicio"].tap()
        XCTAssertTrue(app.staticTexts["Lista para empezar"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Siguiente S1 E1"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Empezar, S1 E1"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label == %@", "The Last of Us")).count, 1)
        XCTAssertFalse(app.staticTexts["Sigue tu primera serie"].exists)
    }

    @MainActor
    func testNotFollowedTrackingCardAdaptsAtAccessibilityTextSize() throws {
        continueAfterFailure = false
        let app = makeApp(contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL")
        app.launch()

        app.buttons["Buscar"].tap()
        XCTAssertTrue(app.staticTexts["Buscar series"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["The Last of Us"].waitForExistence(timeout: 10))

        let firstResultButton = app.buttons["The Last of Us"].firstMatch
        XCTAssertTrue(firstResultButton.waitForExistence(timeout: 10))
        firstResultButton.tap()

        let notFollowedText = app.staticTexts["series-detail-not-followed"]
        let followButton = app.buttons["series-detail-follow"]
        XCTAssertTrue(notFollowedText.waitForExistence(timeout: 10))
        XCTAssertTrue(followButton.exists)
        for _ in 0..<6 where !followButton.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(followButton.isHittable)
        XCTAssertEqual(followButton.label, "Seguir serie")
        XCTAssertGreaterThan(followButton.frame.width, app.frame.width - 100)
        XCTAssertGreaterThanOrEqual(followButton.frame.height, 44)
        XCTAssertLessThan(followButton.frame.height, 80)
        XCTAssertLessThan(notFollowedText.frame.maxY, followButton.frame.minY)
        XCTAssertFalse(notFollowedText.frame.intersects(followButton.frame))
    }

    @MainActor
    func testShareComposerUsesCompactSemanticLayout() throws {
        continueAfterFailure = false
        let app = makeApp(
            environment: [
                "SERIESAV_UI_TESTS_FORCE_GUEST": "0",
                "SERIESAV_UI_TESTS_ACCOUNT_MODE": "free",
                "SERIESAV_UI_TESTS_SAMPLE_LIBRARY": "1",
                "SERIESAV_UI_TESTS_INITIAL_TAB": "home",
                "SERIESAV_UI_TESTS_EPISODE_GUIDE": "empty"
            ],
            contentSizeCategory: "UICTContentSizeCategoryL"
        )
        app.launch()

        let detailButton = app.buttons["Current Series"].firstMatch
        XCTAssertTrue(detailButton.waitForExistence(timeout: 10))
        detailButton.tap()

        let shareButton = app.buttons["Compartir serie"]
        XCTAssertTrue(shareButton.waitForExistence(timeout: 10))
        shareButton.tap()

        let title = app.staticTexts["series-share-composer-title"]
        let detail = app.staticTexts["series-share-composer-detail"]
        let editor = app.textViews["series-share-composer-editor"]
        let count = app.staticTexts["series-share-composer-count"]
        let createButton = app.buttons["series-share-composer-create"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertTrue(detail.exists)
        XCTAssertTrue(editor.exists)
        XCTAssertTrue(count.exists)
        XCTAssertTrue(createButton.exists)
        XCTAssertEqual(title.label, "Current Series")
        XCTAssertEqual(editor.label, "¿Por qué la recomiendas?")
        XCTAssertEqual(count.label, "0 de 280")
        XCTAssertEqual(createButton.label, "Compartir enlace")
        XCTAssertGreaterThan(editor.frame.height, 100)
        XCTAssertLessThan(editor.frame.height, 180)
        XCTAssertGreaterThanOrEqual(createButton.frame.height, 44)
        XCTAssertLessThan(createButton.frame.height, 80)
    }

    @MainActor
    func testShareComposerRemainsReadableAtAccessibilityTextSize() throws {
        continueAfterFailure = false
        let app = makeApp(
            environment: [
                "SERIESAV_UI_TESTS_FORCE_GUEST": "0",
                "SERIESAV_UI_TESTS_ACCOUNT_MODE": "free",
                "SERIESAV_UI_TESTS_SAMPLE_LIBRARY": "1",
                "SERIESAV_UI_TESTS_INITIAL_TAB": "home",
                "SERIESAV_UI_TESTS_EPISODE_GUIDE": "empty"
            ],
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL"
        )
        app.launch()

        let detailButton = app.buttons["Current Series"].firstMatch
        XCTAssertTrue(detailButton.waitForExistence(timeout: 10))
        detailButton.tap()

        let shareButton = app.buttons["Compartir serie"]
        XCTAssertTrue(shareButton.waitForExistence(timeout: 10))
        shareButton.tap()

        let title = app.staticTexts["series-share-composer-title"]
        let detail = app.staticTexts["series-share-composer-detail"]
        let editor = app.textViews["series-share-composer-editor"]
        let count = app.staticTexts["series-share-composer-count"]
        let createButton = app.buttons["series-share-composer-create"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertTrue(detail.exists)
        XCTAssertTrue(editor.exists)
        XCTAssertTrue(count.exists)
        XCTAssertTrue(createButton.exists)
        for _ in 0..<4 where !createButton.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(createButton.isHittable)
        XCTAssertGreaterThan(title.frame.height, 30)
        XCTAssertGreaterThan(detail.frame.height, 50)
        XCTAssertGreaterThanOrEqual(editor.frame.height, 139)
        XCTAssertLessThan(editor.frame.height, 220)
        XCTAssertEqual(count.label, "0 de 280")
        XCTAssertGreaterThan(createButton.frame.width, app.frame.width - 80)
        XCTAssertGreaterThanOrEqual(createButton.frame.height, 44)
        XCTAssertLessThan(createButton.frame.height, 90)
        XCTAssertLessThan(editor.frame.maxY, count.frame.minY)
        XCTAssertLessThan(count.frame.maxY, createButton.frame.minY)
    }

    @MainActor
    func testShareResultUsesCompactSemanticLayout() throws {
        continueAfterFailure = false
        let app = makeApp(
            environment: [
                "SERIESAV_UI_TESTS_FORCE_GUEST": "0",
                "SERIESAV_UI_TESTS_ACCOUNT_MODE": "free",
                "SERIESAV_UI_TESTS_SAMPLE_LIBRARY": "1",
                "SERIESAV_UI_TESTS_INITIAL_TAB": "home",
                "SERIESAV_UI_TESTS_EPISODE_GUIDE": "empty",
                "SERIESAV_UI_TESTS_SHARE_INVITE": "success"
            ],
            contentSizeCategory: "UICTContentSizeCategoryL"
        )
        app.launch()

        let detailButton = app.buttons["Current Series"].firstMatch
        XCTAssertTrue(detailButton.waitForExistence(timeout: 10))
        detailButton.tap()

        let shareButton = app.buttons["Compartir serie"]
        XCTAssertTrue(shareButton.waitForExistence(timeout: 10))
        shareButton.tap()
        let createButton = app.buttons["series-share-composer-create"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 5))
        createButton.tap()

        let title = app.staticTexts["series-share-result-title"]
        let action = app.buttons["series-share-result-action"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertTrue(action.exists)
        XCTAssertTrue(action.isHittable)
        XCTAssertEqual(title.label, "Current Series")
        XCTAssertEqual(action.label, "Compartir serie")
        XCTAssertGreaterThan(action.frame.width, app.frame.width - 80)
        XCTAssertGreaterThanOrEqual(action.frame.height, 44)
        XCTAssertLessThan(action.frame.height, 80)
        XCTAssertLessThan(title.frame.maxY, action.frame.minY)
    }

    @MainActor
    func testShareResultRemainsReadableAtAccessibilityTextSize() throws {
        continueAfterFailure = false
        let app = makeApp(
            environment: [
                "SERIESAV_UI_TESTS_FORCE_GUEST": "0",
                "SERIESAV_UI_TESTS_ACCOUNT_MODE": "free",
                "SERIESAV_UI_TESTS_SAMPLE_LIBRARY": "1",
                "SERIESAV_UI_TESTS_INITIAL_TAB": "home",
                "SERIESAV_UI_TESTS_EPISODE_GUIDE": "empty",
                "SERIESAV_UI_TESTS_SHARE_INVITE": "success"
            ],
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL"
        )
        app.launch()

        let detailButton = app.buttons["Current Series"].firstMatch
        XCTAssertTrue(detailButton.waitForExistence(timeout: 10))
        detailButton.tap()

        let shareButton = app.buttons["Compartir serie"]
        XCTAssertTrue(shareButton.waitForExistence(timeout: 10))
        shareButton.tap()
        let createButton = app.buttons["series-share-composer-create"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 5))
        createButton.tap()

        let title = app.staticTexts["series-share-result-title"]
        let action = app.buttons["series-share-result-action"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertTrue(action.exists)
        XCTAssertTrue(action.isHittable)
        XCTAssertGreaterThan(title.frame.height, 25)
        XCTAssertGreaterThan(action.frame.width, app.frame.width - 80)
        XCTAssertGreaterThanOrEqual(action.frame.height, 44)
        XCTAssertLessThan(action.frame.height, 100)
        XCTAssertLessThan(title.frame.maxY, action.frame.minY)
        XCTAssertLessThan(action.frame.maxY, app.frame.maxY - 10)
    }

    @MainActor
    func testShareInviteAcceptanceGuestPromptUsesReadableScrollableLayout() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = makeApp(
            environment: [
                "SERIESAV_UI_TESTS_SHARE_INVITE_ACCEPTANCE": "guest"
            ],
            contentSizeCategory: "UICTContentSizeCategoryL"
        )
        app.launch()

        let scrollView = app.scrollViews["series-share-invite-scroll"]
        let heading = app.staticTexts["series-share-invite-heading"]
        let detail = app.staticTexts["series-share-invite-detail"]
        let signIn = app.buttons["series-share-invite-sign-in"]
        XCTAssertTrue(scrollView.waitForExistence(timeout: 10))
        XCTAssertTrue(heading.exists)
        XCTAssertTrue(detail.exists)
        XCTAssertTrue(signIn.exists)
        XCTAssertTrue(signIn.isHittable)
        XCTAssertEqual(heading.label, "Aceptar serie compartida")
        XCTAssertEqual(signIn.label, "Iniciar sesión")
        XCTAssertGreaterThan(signIn.frame.width, app.frame.width - 80)
        XCTAssertGreaterThanOrEqual(signIn.frame.height, 50)
        XCTAssertLessThan(detail.frame.maxY, signIn.frame.minY)
        XCTAssertTrue(app.buttons["series-share-invite-done"].exists)
    }

    @MainActor
    func testShareInviteAcceptanceErrorRemainsReachableAtAccessibilityTextSize() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = makeApp(
            environment: [
                "SERIESAV_UI_TESTS_SHARE_INVITE_ACCEPTANCE": "error"
            ],
            language: "de",
            locale: "de_DE",
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL"
        )
        app.launch()

        let scrollView = app.scrollViews["series-share-invite-scroll"]
        let heading = app.staticTexts["series-share-invite-heading"]
        let detail = app.staticTexts["series-share-invite-detail"]
        let message = app.descendants(matching: .any)["series-share-invite-error-message"]
        let retry = app.buttons["series-share-invite-retry"]
        XCTAssertTrue(scrollView.waitForExistence(timeout: 10))
        XCTAssertTrue(heading.exists)
        XCTAssertTrue(detail.exists)
        XCTAssertTrue(message.exists)
        XCTAssertTrue(retry.exists)
        XCTAssertEqual(heading.label, "Geteilte Serie annehmen")
        XCTAssertEqual(retry.label, "Erneut versuchen")
        XCTAssertGreaterThan(heading.frame.height, 50)
        XCTAssertGreaterThan(detail.frame.height, 100)
        XCTAssertGreaterThan(message.frame.height, 100)

        for _ in 0..<4 where !retry.isHittable {
            scrollView.swipeUp()
        }

        XCTAssertTrue(retry.isHittable)
        XCTAssertGreaterThan(retry.frame.width, app.frame.width - 80)
        XCTAssertGreaterThanOrEqual(retry.frame.height, 50)
        XCTAssertLessThan(message.frame.maxY, retry.frame.minY)
    }

    @MainActor
    func testDetailSummaryExpansionRemainsUsableWithAccessibilityTextSize() throws {
        continueAfterFailure = false
        let app = makeApp(contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL")
        app.launch()

        XCTAssertTrue(app.staticTexts["Sigue tu primera serie"].waitForExistence(timeout: 10))
        app.buttons["Buscar"].tap()

        let firstResultButton = app.buttons["The Last of Us"].firstMatch
        XCTAssertTrue(firstResultButton.waitForExistence(timeout: 10))
        firstResultButton.tap()

        XCTAssertTrue(app.staticTexts["Info de serie"].waitForExistence(timeout: 10))
        let header = app.otherElements["series-detail-header"]
        let detailTitle = app.staticTexts["series-detail-title"]
        let detailSummary = app.staticTexts["series-detail-summary"]
        let guideCoverage = app.descendants(matching: .any)
            .matching(identifier: "series-detail-guide-coverage")
            .firstMatch
        XCTAssertTrue(header.exists)
        XCTAssertTrue(detailTitle.exists)
        XCTAssertTrue(detailSummary.exists)
        XCTAssertTrue(guideCoverage.exists)
        XCTAssertLessThan(detailSummary.frame.minX, detailTitle.frame.minX - 20)
        XCTAssertGreaterThan(detailSummary.frame.width, app.frame.width * 0.65)
        XCTAssertLessThan(detailSummary.frame.height, 180)
        XCTAssertLessThan(detailSummary.frame.maxY, guideCoverage.frame.minY)

        let summaryToggle = app.buttons["series-detail-summary-toggle"]
        XCTAssertTrue(summaryToggle.waitForExistence(timeout: 5))
        XCTAssertTrue(summaryToggle.isHittable)
        XCTAssertEqual(summaryToggle.label, "Ver más")

        summaryToggle.tap()
        XCTAssertTrue(waitForLabel("Ver menos", on: summaryToggle))
        summaryToggle.tap()
        XCTAssertTrue(waitForLabel("Ver más", on: summaryToggle))
    }

    @MainActor
    func testGuestPaywallShowsSignInOnly() throws {
        continueAfterFailure = false
        let app = makeApp(environment: [
            "SERIESAV_UI_TESTS_SHOW_PAYWALL": "1"
        ])
        app.launch()

        XCTAssertTrue(app.staticTexts["Sigue más series"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Iniciar sesión"].exists)
        XCTAssertFalse(app.buttons["Restaurar compras"].exists)
        let redeemButton = app.buttons["paywall.redeemCode"].firstMatch
        for _ in 0..<5 where !redeemButton.exists || !redeemButton.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(redeemButton.waitForExistence(timeout: 3))
        redeemButton.tap()
        XCTAssertTrue(app.buttons["series.onboarding.auth.apple"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["series.onboarding.auth.google"].exists)
        XCTAssertFalse(
            staticText(
                matchingLabel: "Series AV Pro es una suscripción mensual con renovación automática. Se te cobrará 4,99 € por cada periodo de 1 mes hasta que canceles en los ajustes del App Store.",
                in: app
            ).exists
        )
    }

    @MainActor
    func testRedeemCodeSheetUsesCompactLayoutAtStandardTextSize() throws {
        continueAfterFailure = false
        let app = makeApp(
            environment: [
                "SERIESAV_UI_TESTS_FORCE_GUEST": "0",
                "SERIESAV_UI_TESTS_ACCOUNT_MODE": "free",
                "SERIESAV_UI_TESTS_SHOW_PAYWALL": "1",
                "SERIESAV_UI_TESTS_SHOW_REDEEM_CODE": "1",
                "SERIESAV_UI_TESTS_SUBSCRIPTION_PRICE": "4,99 €"
            ],
            contentSizeCategory: "UICTContentSizeCategoryL"
        )
        app.launch()

        let title = app.staticTexts["paywall.redeemCode.title"]
        let detail = app.staticTexts["paywall.redeemCode.detail"]
        let field = app.textFields["paywall.redeemCode.field"]
        let claimButton = app.buttons["paywall.redeemCode.claim"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertTrue(detail.exists)
        XCTAssertTrue(field.exists)
        XCTAssertTrue(claimButton.exists)
        XCTAssertEqual(claimButton.label, "Canjear código")
        XCTAssertEqual(field.frame.midY, claimButton.frame.midY, accuracy: 2)
        XCTAssertLessThanOrEqual(claimButton.frame.width, 50)
        XCTAssertGreaterThanOrEqual(claimButton.frame.height, 44)
        XCTAssertFalse(field.frame.intersects(claimButton.frame))
    }

    @MainActor
    func testRedeemCodeSheetUsesReadableStackAtAccessibilityTextSize() throws {
        continueAfterFailure = false
        let app = makeApp(
            environment: [
                "SERIESAV_UI_TESTS_FORCE_GUEST": "0",
                "SERIESAV_UI_TESTS_ACCOUNT_MODE": "free",
                "SERIESAV_UI_TESTS_SHOW_PAYWALL": "1",
                "SERIESAV_UI_TESTS_SHOW_REDEEM_CODE": "1",
                "SERIESAV_UI_TESTS_SUBSCRIPTION_PRICE": "4,99 €"
            ],
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL"
        )
        app.launch()

        let title = app.staticTexts["paywall.redeemCode.title"]
        let detail = app.staticTexts["paywall.redeemCode.detail"]
        let field = app.textFields["paywall.redeemCode.field"]
        let claimButton = app.buttons["paywall.redeemCode.claim"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertTrue(detail.exists)
        XCTAssertTrue(field.exists)
        XCTAssertTrue(claimButton.exists)
        XCTAssertEqual(claimButton.label, "Canjear código")
        XCTAssertGreaterThanOrEqual(field.frame.height, 55.5)
        XCTAssertGreaterThanOrEqual(claimButton.frame.height, 55.5)
        XCTAssertGreaterThan(claimButton.frame.width, app.frame.width - 100)
        XCTAssertLessThan(field.frame.maxY, claimButton.frame.minY)
        XCTAssertFalse(field.frame.intersects(claimButton.frame))
        XCTAssertLessThan(detail.frame.maxY, field.frame.minY)
    }

    @MainActor
    func testInitialOnboardingExpandedAuthOptions() throws {
        continueAfterFailure = false
        let app = makeApp(
            environment: [
                "SERIESAV_UI_TESTS_FORCE_GUEST": "0",
                "SERIESAV_UI_TESTS_ACCOUNT_MODE": "guest_available",
                "SERIESAV_UI_TESTS_SHOW_ONBOARDING": "1",
                "SERIESAV_UI_TESTS_SHOW_AUTH_OPTIONS": "1"
            ],
            contentSizeCategory: "UICTContentSizeCategoryL"
        )
        app.launch()

        let title = app.staticTexts["Conecta tu cuenta"]
        let subtitle = app.staticTexts["Usa tu cuenta AV para gestionar tu acceso Pro."]
        let appleButton = app.buttons["series.onboarding.auth.apple"]
        let googleButton = app.buttons["series.onboarding.auth.google"]
        let skipButton = app.buttons["Omitir por ahora"]
        let consent = app.staticTexts["Al continuar, aceptas los Términos y la Política de privacidad de Series AV."]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertTrue(subtitle.exists)
        XCTAssertTrue(appleButton.exists)
        XCTAssertTrue(googleButton.exists)
        XCTAssertTrue(skipButton.exists)
        XCTAssertTrue(consent.exists)
        XCTAssertGreaterThanOrEqual(appleButton.frame.height, 44)
        XCTAssertLessThan(appleButton.frame.height, 64)
        XCTAssertGreaterThanOrEqual(googleButton.frame.height, 44)
        XCTAssertLessThan(googleButton.frame.height, 64)
        XCTAssertLessThan(appleButton.frame.maxY, googleButton.frame.minY)
        XCTAssertLessThan(googleButton.frame.maxY, skipButton.frame.minY)
        XCTAssertLessThan(skipButton.frame.maxY, consent.frame.minY)
        XCTAssertLessThan(consent.frame.maxY, app.frame.maxY)
    }

    @MainActor
    func testInitialOnboardingAuthOptionsRemainReachableWithAccessibilityTextSize() throws {
        continueAfterFailure = false
        let app = makeApp(
            environment: [
                "SERIESAV_UI_TESTS_FORCE_GUEST": "0",
                "SERIESAV_UI_TESTS_ACCOUNT_MODE": "guest_available",
                "SERIESAV_UI_TESTS_SHOW_ONBOARDING": "1",
                "SERIESAV_UI_TESTS_SHOW_AUTH_OPTIONS": "1"
            ],
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL"
        )
        app.launch()

        let title = app.staticTexts["Conecta tu cuenta"]
        let subtitle = app.staticTexts["Usa tu cuenta AV para gestionar tu acceso Pro."]
        let appleButton = app.buttons["series.onboarding.auth.apple"]
        let googleButton = app.buttons["series.onboarding.auth.google"]
        let skipButton = app.buttons["Omitir por ahora"]
        let consent = app.staticTexts["Al continuar, aceptas los Términos y la Política de privacidad de Series AV."]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertTrue(subtitle.exists)
        XCTAssertTrue(appleButton.exists)
        XCTAssertTrue(googleButton.exists)
        XCTAssertTrue(skipButton.exists)
        XCTAssertTrue(consent.exists)
        XCTAssertGreaterThan(appleButton.frame.width, app.frame.width - 80)
        XCTAssertGreaterThanOrEqual(appleButton.frame.height, 56)
        XCTAssertGreaterThanOrEqual(googleButton.frame.height, 56)
        XCTAssertGreaterThanOrEqual(skipButton.frame.height, 55.5)
        XCTAssertLessThan(appleButton.frame.maxY, googleButton.frame.minY)
        XCTAssertLessThan(googleButton.frame.maxY, skipButton.frame.minY)

        for _ in 0..<4 where consent.frame.maxY > app.frame.maxY - 8 {
            app.swipeUp()
        }
        XCTAssertLessThanOrEqual(consent.frame.maxY, app.frame.maxY - 8)
        XCTAssertGreaterThanOrEqual(consent.frame.minY, app.frame.minY)
    }

    @MainActor
    func testInitialOnboardingSkipContinuesToHomeShell() throws {
        continueAfterFailure = false
        let app = makeApp(environment: [
            "SERIESAV_UI_TESTS_SHOW_ONBOARDING": "1"
        ])
        app.launch()

        XCTAssertTrue(app.staticTexts["Sigue series y ponte al día"].waitForExistence(timeout: 10))
        app.buttons["OMITIR POR AHORA"].tap()

        XCTAssertTrue(app.staticTexts["Sigue tu primera serie"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Sigue series y ponte al día"].exists)
        XCTAssertFalse(app.staticTexts["Conecta tu cuenta"].exists)
        XCTAssertTrue(app.buttons["series.tab.home"].exists)
    }

    @MainActor
    func testCompactShellRemainsAvailableForNarrowLayouts() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = makeApp()
        app.launch()

        XCTAssertTrue(app.staticTexts["Sigue tu primera serie"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.otherElements["series.shell.compact"].exists)
        XCTAssertFalse(app.otherElements["series.shell.tablet"].exists)
    }

    @MainActor
    func testEmptyHomeUsesReadableVerticalLayoutAtAccessibilityTextSize() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = makeApp(contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL")
        app.launch()

        let title = app.staticTexts["Sigue tu primera serie"]
        let subtitle = app.staticTexts["Elige la serie, fija el último episodio visto y sigue desde Home."]
        let searchButton = app.buttons["home.empty.search"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertTrue(subtitle.exists)
        XCTAssertTrue(searchButton.exists)
        XCTAssertTrue(searchButton.isHittable)
        XCTAssertGreaterThan(title.frame.height, 30)
        XCTAssertGreaterThan(subtitle.frame.height, 40)
        XCTAssertGreaterThanOrEqual(searchButton.frame.minY, subtitle.frame.maxY)
        XCTAssertGreaterThanOrEqual(searchButton.frame.height, 56)
        XCTAssertLessThan(searchButton.frame.height, 100)
        XCTAssertGreaterThan(searchButton.frame.width, 280)
        XCTAssertEqual(
            app.buttons.matching(NSPredicate(format: "label == %@", "Buscar serie")).count,
            1
        )
    }

    @MainActor
    func testHomeAviBriefUsesReadableCardAtAccessibilityTextSize() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = makeApp(contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL")
        app.launch()

        let searchButton = app.buttons["home.empty.search"]
        let aviBrief = app.buttons["home.aviBrief.open"]
        XCTAssertTrue(searchButton.waitForExistence(timeout: 10))
        XCTAssertTrue(aviBrief.exists)
        XCTAssertTrue(aviBrief.isHittable)
        XCTAssertEqual(
            aviBrief.value as? String,
            "Busca una serie, fija el último episodio visto y deja Home lista para seguir."
        )
        XCTAssertGreaterThanOrEqual(aviBrief.frame.minY, searchButton.frame.maxY)
        XCTAssertGreaterThan(aviBrief.frame.height, 100)
        XCTAssertLessThan(aviBrief.frame.height, 220)
        XCTAssertGreaterThan(aviBrief.frame.width, 280)
    }

    @MainActor
    func testAviUsesLabelledActionsAndReadableMetricsAtAccessibilityTextSize() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = makeApp(
            environment: [
                "SERIESAV_UI_TESTS_FORCE_GUEST": "0",
                "SERIESAV_UI_TESTS_SAMPLE_LIBRARY": "1"
            ],
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL"
        )
        app.launch()

        let aviTab = app.buttons["series.tab.avi"]
        XCTAssertTrue(aviTab.waitForExistence(timeout: 10))
        aviTab.tap()

        let primaryAction = app.buttons["series.avi.focus.primary"]
        let previousAction = app.buttons["series.avi.focus.previous"]
        let pinAction = app.buttons["series.avi.focus.pin"]
        XCTAssertTrue(primaryAction.waitForExistence(timeout: 10))
        XCTAssertTrue(previousAction.exists)
        XCTAssertTrue(pinAction.exists)
        XCTAssertEqual(primaryAction.label, "Visto S1 E3")
        XCTAssertEqual(previousAction.label, "Volver uno")
        XCTAssertEqual(pinAction.label, "Soltar primera")
        XCTAssertGreaterThan(primaryAction.frame.width, 250)
        XCTAssertGreaterThanOrEqual(primaryAction.frame.height, 56)
        XCTAssertGreaterThanOrEqual(previousAction.frame.minY, primaryAction.frame.maxY)
        XCTAssertGreaterThanOrEqual(pinAction.frame.minY, previousAction.frame.maxY)

        let searchAction = app.buttons["series.avi.search"]
        for _ in 0..<4 where !searchAction.isHittable {
            app.swipeUp()
        }

        let libraryAction = app.buttons["series.avi.library"]
        XCTAssertTrue(searchAction.waitForExistence(timeout: 5))
        XCTAssertTrue(libraryAction.exists)
        XCTAssertEqual(searchAction.label, "Buscar series")
        XCTAssertEqual(libraryAction.label, "Biblioteca")
        XCTAssertGreaterThan(searchAction.frame.width, 250)
        XCTAssertGreaterThanOrEqual(searchAction.frame.height, 56)
        XCTAssertGreaterThanOrEqual(libraryAction.frame.minY, searchAction.frame.maxY)

        let watchingMetric = app.descendants(matching: .any)["series.avi.metric.watching"]
        let activeMetric = app.descendants(matching: .any)["series.avi.metric.active"]
        let archivedMetric = app.descendants(matching: .any)["series.avi.metric.archived"]
        XCTAssertTrue(watchingMetric.exists)
        XCTAssertTrue(activeMetric.exists)
        XCTAssertTrue(archivedMetric.exists)
        XCTAssertEqual(watchingMetric.label, "Viendo: 2")
        XCTAssertEqual(activeMetric.label, "Todo: 3")
        XCTAssertEqual(archivedMetric.label, "Archivo: 0")
        XCTAssertGreaterThan(watchingMetric.frame.width, 250)
        XCTAssertGreaterThanOrEqual(activeMetric.frame.minY, watchingMetric.frame.maxY)
        XCTAssertGreaterThanOrEqual(archivedMetric.frame.minY, activeMetric.frame.maxY)
    }

    @MainActor
    func testAviKeepsCompactActionRowsAtNormalTextSize() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = makeApp(environment: [
            "SERIESAV_UI_TESTS_FORCE_GUEST": "0",
            "SERIESAV_UI_TESTS_SAMPLE_LIBRARY": "1"
        ])
        app.launch()

        let aviTab = app.buttons["series.tab.avi"]
        XCTAssertTrue(aviTab.waitForExistence(timeout: 10))
        aviTab.tap()

        let primaryAction = app.buttons["series.avi.focus.primary"]
        let previousAction = app.buttons["series.avi.focus.previous"]
        let pinAction = app.buttons["series.avi.focus.pin"]
        XCTAssertTrue(primaryAction.waitForExistence(timeout: 10))
        XCTAssertTrue(previousAction.exists)
        XCTAssertTrue(pinAction.exists)
        XCTAssertLessThanOrEqual(primaryAction.frame.width, 50)
        XCTAssertLessThanOrEqual(previousAction.frame.width, 46)
        XCTAssertLessThan(abs(primaryAction.frame.midY - previousAction.frame.midY), 2)
        XCTAssertLessThan(abs(previousAction.frame.midY - pinAction.frame.midY), 2)

        let searchAction = app.buttons["series.avi.search"]
        for _ in 0..<3 where !searchAction.isHittable {
            app.swipeUp()
        }

        let libraryAction = app.buttons["series.avi.library"]
        XCTAssertTrue(searchAction.waitForExistence(timeout: 5))
        XCTAssertTrue(libraryAction.exists)
        XCTAssertLessThanOrEqual(searchAction.frame.width, 46)
        XCTAssertLessThan(abs(searchAction.frame.midY - libraryAction.frame.midY), 2)
    }

    @MainActor
    func testHomeDiscoveryCardsRemainReadableAtAccessibilityTextSize() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = makeApp(contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL")
        app.launch()

        XCTAssertTrue(app.staticTexts["Populares"].waitForExistence(timeout: 10))

        let firstCard = app.buttons["The Last of Us"].firstMatch
        let firstAction = app.buttons["Seguir serie"].firstMatch
        XCTAssertTrue(firstCard.waitForExistence(timeout: 10))
        XCTAssertTrue(firstAction.exists)

        for _ in 0..<4 where !firstCard.isHittable || !firstAction.isHittable {
            app.swipeUp()
        }

        XCTAssertTrue(firstCard.isHittable)
        XCTAssertTrue(firstAction.isHittable)
        XCTAssertEqual(firstCard.value as? String, "2023 · Action")
        XCTAssertGreaterThan(firstCard.frame.width, 135)
        XCTAssertGreaterThan(firstCard.frame.height, 280)
        XCTAssertGreaterThanOrEqual(firstAction.frame.width, 44)
        XCTAssertGreaterThanOrEqual(firstAction.frame.height, 44)
        XCTAssertTrue(firstCard.frame.contains(firstAction.frame))

        if app.frame.width > 600 {
            let secondCard = app.buttons["House of the Dragon"].firstMatch
            let thirdCard = app.buttons["Fallout"].firstMatch
            let fourthCard = app.buttons["Daredevil: Born Again"].firstMatch
            XCTAssertTrue(secondCard.exists)
            XCTAssertTrue(thirdCard.exists)
            XCTAssertTrue(fourthCard.exists)
            XCTAssertLessThan(abs(secondCard.frame.minY - firstCard.frame.minY), 8)
            XCTAssertLessThan(abs(thirdCard.frame.minY - firstCard.frame.minY), 8)
            XCTAssertGreaterThan(fourthCard.frame.minY, firstCard.frame.maxY)
        }
    }

    @MainActor
    func testHomeDiscoveryFailureOffersReadableRetryAndRecovers() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = makeApp(
            environment: ["SERIESAV_UI_TESTS_HOME_DISCOVERY": "failed_once"],
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL"
        )
        app.launch()

        let failure = app.otherElements["home.discovery.failure"]
        let failureMessage = app.staticTexts[
            "No se pudieron cargar las sugerencias. Comprueba tu conexión."
        ]
        let retryButton = app.buttons["home.discovery.retry"]
        XCTAssertTrue(failure.waitForExistence(timeout: 10))
        XCTAssertTrue(failureMessage.exists)
        XCTAssertTrue(retryButton.exists)
        XCTAssertFalse(app.staticTexts["Populares"].exists)

        for _ in 0..<4 where !retryButton.isHittable {
            app.swipeUp()
        }

        XCTAssertTrue(retryButton.isHittable)
        XCTAssertGreaterThan(failure.frame.height, 100)
        XCTAssertLessThan(failure.frame.height, 240)
        XCTAssertGreaterThan(failure.frame.width, 280)
        XCTAssertGreaterThanOrEqual(retryButton.frame.height, 52)
        XCTAssertFalse(failureMessage.frame.intersects(retryButton.frame))

        retryButton.tap()

        XCTAssertTrue(app.staticTexts["Populares"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["The Last of Us"].firstMatch.waitForExistence(timeout: 10))
        XCTAssertFalse(failure.exists)
    }

    @MainActor
    func testTabletShellAppearsForWideLayouts() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = makeApp()
        app.launch()

        XCTAssertTrue(app.staticTexts["Sigue tu primera serie"].waitForExistence(timeout: 10))

        let windowWidth = app.windows.firstMatch.frame.width
        guard windowWidth >= 820 else {
            throw XCTSkip("Runner delivered compact width \(windowWidth); tablet shell is only expected in regular-width iPad layouts.")
        }

        XCTAssertTrue(app.descendants(matching: .any)["series.sidebar.home"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["series.sidebar.search"].exists)
        XCTAssertFalse(app.otherElements["series.shell.compact"].exists)
    }

    @MainActor
    func testTabletSidebarScalesAtAccessibilityTextSize() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = makeApp(contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL")
        app.launch()

        let windowWidth = app.windows.firstMatch.frame.width
        guard windowWidth > 600 else {
            throw XCTSkip("This accessibility sidebar check only applies to iPad.")
        }

        let sidebarItems = [
            "series.sidebar.home",
            "series.sidebar.library",
            "series.sidebar.search",
            "series.sidebar.avi",
            "series.sidebar.settings",
            "series.sidebar.account"
        ].map { app.descendants(matching: .any)[$0] }

        XCTAssertTrue(sidebarItems[0].waitForExistence(timeout: 10))
        for item in sidebarItems {
            XCTAssertTrue(item.exists)
            XCTAssertTrue(item.isHittable)
            XCTAssertGreaterThanOrEqual(item.frame.height, 56)
            XCTAssertGreaterThan(item.frame.width, 240)
        }

        XCTAssertTrue(sidebarItems[0].isSelected)
        XCTAssertLessThan(sidebarItems[0].frame.maxX, app.frame.midX)
    }

    @MainActor
    func testSignedInFreePaywallShowsPriceRestoreAndTerms() throws {
        continueAfterFailure = false
        let app = makeApp(environment: [
            "SERIESAV_UI_TESTS_FORCE_GUEST": "0",
            "SERIESAV_UI_TESTS_ACCOUNT_MODE": "free",
            "SERIESAV_UI_TESTS_SHOW_PAYWALL": "1",
            "SERIESAV_UI_TESTS_SUBSCRIPTION_PRICE": "4,99 €"
        ])
        app.launch()

        XCTAssertTrue(app.staticTexts["Sigue más series"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Continuar por 4,99 €"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Restaurar compras"].exists)
        XCTAssertTrue(
            staticText(
                matchingLabel: "Series AV Pro es una suscripción mensual con renovación automática. Se te cobrará 4,99 € por cada periodo de 1 mes hasta que canceles en los ajustes del App Store.",
                in: app
            ).exists
        )
    }

    @MainActor
    func testProAccountShowsActivePlanInsteadOfUpgradeCTA() throws {
        continueAfterFailure = false
        let app = makeApp(environment: [
            "SERIESAV_UI_TESTS_FORCE_GUEST": "0",
            "SERIESAV_UI_TESTS_ACCOUNT_MODE": "pro",
            "SERIESAV_UI_TESTS_INITIAL_CHROME": "account"
        ])
        app.launch()

        XCTAssertTrue(app.staticTexts["Mi cuenta"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Series AV Pro"].exists)
        XCTAssertTrue(app.staticTexts["Pro activo"].exists)
        XCTAssertTrue(app.buttons["Gestionar suscripción"].exists)
        XCTAssertFalse(app.buttons["Iniciar sesión"].exists)
    }

    @MainActor
    func testSettingsHeaderStaysCompactAndTappableOnIPhone() throws {
        continueAfterFailure = false
        let app = makeApp(environment: [
            "SERIESAV_UI_TESTS_INITIAL_CHROME": "settings"
        ])
        app.launch()

        guard app.frame.width <= 600 else {
            throw XCTSkip("This compact header check only applies to iPhone.")
        }

        let header = app.otherElements["profile.compactBrandHeader"]
        let title = app.staticTexts["Ajustes"]
        let settingsButton = app.buttons["header.settings"]
        let accountButton = app.buttons["header.account"]

        XCTAssertTrue(header.waitForExistence(timeout: 10))
        XCTAssertTrue(title.exists)
        XCTAssertTrue(settingsButton.exists)
        XCTAssertTrue(accountButton.exists)
        XCTAssertLessThanOrEqual(header.frame.height, 46)
        XCTAssertLessThanOrEqual(title.frame.minY - header.frame.maxY, 20)
        XCTAssertGreaterThanOrEqual(settingsButton.frame.width, 44)
        XCTAssertGreaterThanOrEqual(settingsButton.frame.height, 44)
        XCTAssertGreaterThanOrEqual(accountButton.frame.width, 44)
        XCTAssertGreaterThanOrEqual(accountButton.frame.height, 44)
    }

    @MainActor
    func testSettingsSelectorsStayCompactAtStandardTextSize() throws {
        continueAfterFailure = false
        let app = makeApp(
            environment: ["SERIESAV_UI_TESTS_INITIAL_CHROME": "settings"],
            contentSizeCategory: "UICTContentSizeCategoryL"
        )
        app.launch()

        guard app.frame.width <= 600 else {
            throw XCTSkip("This compact selector check only applies to iPhone.")
        }

        let language = app.descendants(matching: .any)["profile.settings.language.selector"]
        let systemTheme = app.buttons["profile.settings.theme.system"]
        let lightTheme = app.buttons["profile.settings.theme.light"]
        let darkTheme = app.buttons["profile.settings.theme.dark"]

        XCTAssertTrue(language.waitForExistence(timeout: 10))
        XCTAssertTrue(systemTheme.exists)
        XCTAssertTrue(lightTheme.exists)
        XCTAssertTrue(darkTheme.exists)
        XCTAssertLessThan(language.frame.height, 80)
        XCTAssertEqual(systemTheme.frame.midY, lightTheme.frame.midY, accuracy: 3)
        XCTAssertEqual(lightTheme.frame.midY, darkTheme.frame.midY, accuracy: 3)
        XCTAssertLessThan(systemTheme.frame.height, 80)
        XCTAssertLessThan(lightTheme.frame.height, 80)
        XCTAssertLessThan(darkTheme.frame.height, 80)
    }

    @MainActor
    func testSettingsSelectorsStackAtAccessibilityTextSize() throws {
        continueAfterFailure = false
        let app = makeApp(
            environment: ["SERIESAV_UI_TESTS_INITIAL_CHROME": "settings"],
            language: "de",
            locale: "de_DE",
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL"
        )
        app.launch()

        guard app.frame.width <= 600 else {
            throw XCTSkip("This accessibility selector check only applies to iPhone.")
        }

        let language = app.descendants(matching: .any)["profile.settings.language.selector"]
        let systemTheme = app.buttons["profile.settings.theme.system"]
        let lightTheme = app.buttons["profile.settings.theme.light"]
        let darkTheme = app.buttons["profile.settings.theme.dark"]

        XCTAssertTrue(language.waitForExistence(timeout: 10))
        for _ in 0..<4 where !darkTheme.isHittable {
            app.swipeUp()
        }

        XCTAssertTrue(systemTheme.exists)
        XCTAssertTrue(lightTheme.exists)
        XCTAssertTrue(darkTheme.isHittable)
        XCTAssertGreaterThanOrEqual(systemTheme.frame.height, 56)
        XCTAssertGreaterThanOrEqual(lightTheme.frame.height, 56)
        XCTAssertGreaterThanOrEqual(darkTheme.frame.height, 56)
        XCTAssertLessThan(systemTheme.frame.maxY, lightTheme.frame.minY)
        XCTAssertLessThan(lightTheme.frame.maxY, darkTheme.frame.minY)
        XCTAssertGreaterThan(systemTheme.frame.width, app.frame.width - 100)

        let inAppMode = app.buttons["profile.settings.webOpenMode.inApp"]
        let systemMode = app.buttons["profile.settings.webOpenMode.system"]
        for _ in 0..<8 where !systemMode.isHittable {
            app.swipeUp()
        }

        XCTAssertTrue(inAppMode.exists)
        XCTAssertTrue(systemMode.isHittable)
        XCTAssertGreaterThanOrEqual(inAppMode.frame.height, 56)
        XCTAssertGreaterThanOrEqual(systemMode.frame.height, 56)
        XCTAssertLessThan(inAppMode.frame.maxY, systemMode.frame.minY)
        XCTAssertGreaterThan(inAppMode.frame.width, app.frame.width - 100)

        let searchEngine = app.descendants(matching: .any)["profile.settings.searchEngine.selector"]
        XCTAssertTrue(searchEngine.exists)
        XCTAssertGreaterThanOrEqual(searchEngine.frame.height, 56)
    }

    @MainActor
    func testLocalDataMaintenanceSheetStaysCompactAtStandardTextSize() throws {
        continueAfterFailure = false
        let app = makeApp(
            environment: [
                "SERIESAV_UI_TESTS_INITIAL_CHROME": "settings",
                "SERIESAV_UI_TESTS_SAMPLE_LIBRARY": "1",
                "SERIESAV_UI_TESTS_SHOW_LOCAL_DATA_MAINTENANCE": "1"
            ],
            contentSizeCategory: "UICTContentSizeCategoryL"
        )
        app.launch()

        guard app.frame.width <= 600 else {
            throw XCTSkip("This compact maintenance-sheet check only applies to iPhone.")
        }

        let title = app.staticTexts["profile.localDataSheet.title"]
        let close = app.buttons["profile.localDataSheet.close"]
        let deleteAction = app.buttons["profile.local.delete"]

        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertTrue(close.exists)
        XCTAssertTrue(deleteAction.exists)
        XCTAssertGreaterThan(title.frame.minY, app.frame.height * 0.4)
        XCTAssertLessThan(deleteAction.frame.height, 100)
        XCTAssertEqual(close.label, "Cancelar")
        XCTAssertGreaterThanOrEqual(close.frame.width, 70)
        XCTAssertGreaterThanOrEqual(close.frame.height, 44)
    }

    @MainActor
    func testLocalDataMaintenanceSheetUsesReadableFullHeightAtAccessibilityTextSize() throws {
        continueAfterFailure = false
        let app = makeApp(
            environment: [
                "SERIESAV_UI_TESTS_INITIAL_CHROME": "settings",
                "SERIESAV_UI_TESTS_SAMPLE_LIBRARY": "1",
                "SERIESAV_UI_TESTS_SHOW_LOCAL_DATA_MAINTENANCE": "1"
            ],
            language: "de",
            locale: "de_DE",
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL"
        )
        app.launch()

        guard app.frame.width <= 600 else {
            throw XCTSkip("This accessibility maintenance-sheet check only applies to iPhone.")
        }

        let title = app.staticTexts["profile.localDataSheet.title"]
        let close = app.buttons["profile.localDataSheet.close"]
        let deleteAction = app.buttons["profile.local.delete"]

        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertTrue(close.exists)
        XCTAssertTrue(deleteAction.exists)
        XCTAssertLessThan(title.frame.minY, app.frame.height * 0.35)
        XCTAssertLessThanOrEqual(title.frame.maxX, app.frame.maxX - 20)
        XCTAssertGreaterThanOrEqual(deleteAction.frame.height, 100)
        XCTAssertLessThan(deleteAction.frame.height, 180)
        XCTAssertTrue(deleteAction.isHittable)
        XCTAssertGreaterThanOrEqual(close.frame.height, 44)
    }

    @MainActor
    func testHelpAndLegalLastActionRemainsReachableAtAccessibilityTextSize() throws {
        continueAfterFailure = false
        let app = makeApp(
            environment: ["SERIESAV_UI_TESTS_INITIAL_CHROME": "settings"],
            language: "de",
            locale: "de_DE",
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL"
        )
        app.launch()

        guard app.frame.width <= 600 else {
            throw XCTSkip("This accessibility legal-action check only applies to iPhone.")
        }

        let accountDeletion = app.staticTexts["Apps AV-Konto löschen"]
        XCTAssertTrue(app.staticTexts["Einstellungen"].waitForExistence(timeout: 10))
        for _ in 0..<10 where !accountDeletion.isHittable {
            app.swipeUp()
        }

        XCTAssertTrue(accountDeletion.exists)
        XCTAssertTrue(accountDeletion.isHittable)
        XCTAssertGreaterThan(accountDeletion.frame.width, 140)
        XCTAssertLessThanOrEqual(accountDeletion.frame.maxX, app.frame.maxX - 24)
    }

    @MainActor
    func testHelpLinkUsesConfiguredInAppBrowser() throws {
        continueAfterFailure = false
        let app = makeApp(
            environment: ["SERIESAV_UI_TESTS_INITIAL_CHROME": "settings"],
            contentSizeCategory: "UICTContentSizeCategoryL"
        )
        app.launch()

        let sourceCode = app.staticTexts["Código fuente"]
        XCTAssertTrue(app.staticTexts["Ajustes"].waitForExistence(timeout: 10))
        for _ in 0..<10 where !sourceCode.isHittable {
            app.swipeUp()
        }

        XCTAssertTrue(sourceCode.isHittable)
        sourceCode.tap()
        XCTAssertTrue(app.otherElements["browser.inApp"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testInAppBrowserUsesFullScreenAtAccessibilityTextSize() throws {
        continueAfterFailure = false
        let app = makeApp(
            environment: [
                "SERIESAV_UI_TESTS_INITIAL_CHROME": "settings",
                "SERIESAV_UI_TESTS_IN_APP_BROWSER_URL": "https://invalid.invalid"
            ],
            language: "de",
            locale: "de_DE",
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL"
        )
        app.launch()

        guard app.frame.width <= 600 else {
            throw XCTSkip("This accessibility browser check only applies to iPhone.")
        }

        let browser = app.otherElements["browser.inApp"]
        XCTAssertTrue(browser.waitForExistence(timeout: 10))
        XCTAssertEqual(browser.frame.minX, app.frame.minX, accuracy: 2)
        XCTAssertEqual(browser.frame.maxX, app.frame.maxX, accuracy: 2)
        XCTAssertGreaterThan(browser.frame.height, app.frame.height * 0.8)
    }

    @MainActor
    func testUnavailableAccountUsesCompactStatusInsteadOfDisabledCTAs() throws {
        continueAfterFailure = false
        let app = makeApp(environment: [
            "SERIESAV_UI_TESTS_INITIAL_CHROME": "account"
        ])
        app.launch()

        let status = app.descendants(matching: .any)["profile.account.unavailable"]
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        XCTAssertEqual(status.label, "El acceso a la cuenta no está disponible ahora")
        XCTAssertGreaterThanOrEqual(status.frame.height, 44)
        XCTAssertLessThan(status.frame.height, 70)
        XCTAssertLessThanOrEqual(status.frame.maxX, app.frame.maxX - 16)
        XCTAssertTrue(app.staticTexts["Podrás consultar Series AV Pro cuando el acceso a la cuenta vuelva a estar disponible."].exists)
        XCTAssertFalse(app.buttons["profile.account.signIn"].exists)
        XCTAssertFalse(app.buttons["profile.pro.signIn"].exists)
    }

    @MainActor
    func testSampleLibraryRendersPopulatedLibrary() throws {
        continueAfterFailure = false
        let app = makeApp(environment: [
            "SERIESAV_UI_TESTS_SAMPLE_LIBRARY": "1",
            "SERIESAV_UI_TESTS_INITIAL_TAB": "library"
        ])
        app.launch()

        XCTAssertTrue(app.staticTexts["Biblioteca"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Todo · 3"].exists)
        XCTAssertTrue(app.staticTexts["Current Series"].exists)
        XCTAssertTrue(app.staticTexts["Slow Weekend Show"].exists)
        XCTAssertTrue(app.staticTexts["Later List"].exists)
        XCTAssertFalse(app.staticTexts["Sin series todavía"].exists)
    }

    @MainActor
    func testSampleLibraryStacksRowActionsBelowReadableInfoOnIPhone() throws {
        continueAfterFailure = false
        let app = makeApp(environment: [
            "SERIESAV_UI_TESTS_SAMPLE_LIBRARY": "1",
            "SERIESAV_UI_TESTS_INITIAL_TAB": "library"
        ])
        app.launch()

        guard app.frame.width <= 600 else {
            throw XCTSkip("This compact row check only applies to iPhone.")
        }

        let title = app.staticTexts["Current Series"]
        let primaryAction = app.buttons["Marcar S1 E3 visto"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertTrue(primaryAction.exists)
        XCTAssertGreaterThan(title.frame.width, 90)
        XCTAssertGreaterThanOrEqual(primaryAction.frame.minY, title.frame.maxY)
        XCTAssertGreaterThanOrEqual(primaryAction.frame.height, 44)
    }

    @MainActor
    func testSampleLibraryRowsExpandAtAccessibilityTextSize() throws {
        continueAfterFailure = false
        let app = makeApp(
            environment: [
                "SERIESAV_UI_TESTS_SAMPLE_LIBRARY": "1",
                "SERIESAV_UI_TESTS_INITIAL_TAB": "library"
            ],
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL"
        )
        app.launch()

        let detailButton = app.buttons["Current Series"]
        let primaryAction = app.buttons["Marcar S1 E3 visto"]
        let managementMenu = app.descendants(matching: .any)["Acciones de serie"].firstMatch
        XCTAssertTrue(detailButton.waitForExistence(timeout: 10))
        XCTAssertTrue(primaryAction.exists)
        XCTAssertTrue(managementMenu.exists)
        XCTAssertGreaterThan(detailButton.frame.height, 60)
        XCTAssertGreaterThanOrEqual(primaryAction.frame.minY, detailButton.frame.maxY)
        XCTAssertGreaterThanOrEqual(primaryAction.frame.height, 52)
        XCTAssertGreaterThan(primaryAction.frame.width, 250)
        XCTAssertGreaterThanOrEqual(managementMenu.frame.minY, primaryAction.frame.maxY)
        XCTAssertGreaterThanOrEqual(managementMenu.frame.height, 44)

        let filterSelector = app.buttons["library.filter.selector"]
        XCTAssertTrue(filterSelector.exists)
        XCTAssertTrue(filterSelector.isHittable)
        XCTAssertGreaterThan(filterSelector.frame.width, 250)
        XCTAssertEqual(filterSelector.value as? String, "Todo")

        filterSelector.tap()
        for label in ["Todo", "Viendo", "Por ver", "Vista", "Archivadas"] {
            XCTAssertTrue(app.buttons[label].waitForExistence(timeout: 5), "Missing accessible filter: \(label)")
        }
        let wantToWatchFilter = app.buttons["Por ver"]
        wantToWatchFilter.tap()
        XCTAssertEqual(filterSelector.value as? String, "Por ver")
        XCTAssertTrue(app.staticTexts["Later List"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testUpcomingLibraryRowsRemainReadableAtAccessibilityTextSize() throws {
        continueAfterFailure = false
        let app = makeApp(
            environment: [
                "SERIESAV_UI_TESTS_SAMPLE_LIBRARY": "1",
                "SERIESAV_UI_TESTS_INITIAL_TAB": "library",
                "SERIESAV_UI_TESTS_UPCOMING_EPISODES": "sample"
            ],
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL"
        )
        app.launch()

        let sectionTitle = app.staticTexts["series-upcoming-section-title"]
        for _ in 0..<12 where !sectionTitle.exists {
            app.swipeUp()
        }
        XCTAssertTrue(sectionTitle.waitForExistence(timeout: 10))

        let subtitle = app.staticTexts["series-upcoming-section-subtitle"]
        let dateBadge = app.descendants(matching: .any)["series-upcoming-sample-1-date"]
        let seriesTitle = app.staticTexts["series-upcoming-sample-1-title"]
        let detail = app.staticTexts["series-upcoming-sample-1-detail"]
        let action = app.buttons["series-upcoming-episode-1-3-set-progress"]

        for _ in 0..<4 where !action.isHittable {
            app.swipeUp()
        }

        XCTAssertTrue(subtitle.exists)
        XCTAssertTrue(dateBadge.exists)
        XCTAssertTrue(seriesTitle.exists)
        XCTAssertTrue(detail.exists)
        XCTAssertTrue(action.exists)
        XCTAssertGreaterThanOrEqual(dateBadge.frame.width, 60)
        XCTAssertGreaterThanOrEqual(dateBadge.frame.height, 60)
        XCTAssertLessThan(seriesTitle.frame.maxY, detail.frame.minY)
        XCTAssertLessThanOrEqual(dateBadge.frame.maxX, seriesTitle.frame.minX)
        XCTAssertLessThan(detail.frame.maxY, action.frame.minY)
        XCTAssertGreaterThan(action.frame.width, app.frame.width * 0.70)
        XCTAssertGreaterThanOrEqual(action.frame.height, 44)
        XCTAssertTrue(action.isHittable)
    }

    @MainActor
    func testSampleLibraryShowsEveryFilterWithinIPhoneViewport() throws {
        continueAfterFailure = false
        let app = makeApp(environment: [
            "SERIESAV_UI_TESTS_SAMPLE_LIBRARY": "1",
            "SERIESAV_UI_TESTS_INITIAL_TAB": "library"
        ])
        app.launch()

        guard app.frame.width <= 600 else {
            throw XCTSkip("This compact filter check only applies to iPhone.")
        }

        let filterLabels = ["Todo", "Viendo", "Por ver", "Vista", "Archivo"]
        XCTAssertFalse(app.buttons["library.filter.selector"].exists)
        for label in filterLabels {
            let filter = app.buttons[label]
            XCTAssertTrue(filter.waitForExistence(timeout: 10), "Missing filter: \(label)")
            XCTAssertTrue(filter.isHittable, "Filter is clipped: \(label)")
        }

        let firstFilter = app.buttons[filterLabels[0]]
        let lastFilter = app.buttons[filterLabels[4]]
        XCTAssertGreaterThanOrEqual(firstFilter.frame.minX, app.frame.minX + 16)
        XCTAssertLessThanOrEqual(lastFilter.frame.maxX, app.frame.maxX - 16)
    }

    @MainActor
    func testSampleLibraryLastActionClearsFloatingFooterAfterScroll() throws {
        continueAfterFailure = false
        let app = makeApp(environment: [
            "SERIESAV_UI_TESTS_SAMPLE_LIBRARY": "1",
            "SERIESAV_UI_TESTS_INITIAL_TAB": "library"
        ])
        app.launch()

        guard app.frame.width <= 600 else {
            throw XCTSkip("This floating footer check only applies to iPhone.")
        }

        let lastAction = app.buttons["Empezar S1 E1"]
        let footerTab = app.buttons["series.tab.library"]
        XCTAssertTrue(lastAction.waitForExistence(timeout: 10))
        XCTAssertTrue(footerTab.exists)

        for _ in 0..<3 where lastAction.frame.maxY >= footerTab.frame.minY - 12 {
            app.swipeUp()
        }

        XCTAssertTrue(lastAction.isHittable)
        XCTAssertLessThanOrEqual(lastAction.frame.maxY, footerTab.frame.minY - 12)
    }

    @MainActor
    func testSampleLibraryFilterCountMatchesVisibleRows() throws {
        continueAfterFailure = false
        let app = makeApp(environment: [
            "SERIESAV_UI_TESTS_SAMPLE_LIBRARY": "1",
            "SERIESAV_UI_TESTS_INITIAL_TAB": "library"
        ])
        app.launch()

        XCTAssertTrue(app.staticTexts["Biblioteca"].waitForExistence(timeout: 10))
        app.buttons["Por ver"].tap()

        XCTAssertTrue(app.staticTexts["Por ver · 1"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Later List"].exists)
        XCTAssertTrue(app.buttons["Empezar S1 E1"].exists)
        XCTAssertFalse(app.buttons["Marcar S1 E1 visto"].exists)
        XCTAssertFalse(app.staticTexts["Current Series"].exists)
        XCTAssertFalse(app.staticTexts["Slow Weekend Show"].exists)
    }

    @MainActor
    func testSampleSearchReadySeriesUsesStartAction() throws {
        continueAfterFailure = false
        let app = makeApp(environment: [
            "SERIESAV_UI_TESTS_SAMPLE_LIBRARY": "1",
            "SERIESAV_UI_TESTS_INITIAL_TAB": "search"
        ])
        app.launch()

        XCTAssertTrue(app.staticTexts["Buscar series"].waitForExistence(timeout: 10))
        app.textFields["Buscar por título"].tap()
        app.textFields["Buscar por título"].typeText("Later")

        XCTAssertTrue(app.staticTexts["Later List"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Empezar S1 E1"].exists)
        XCTAssertFalse(app.buttons["Marcar S1 E1 visto"].exists)
    }

    @MainActor
    func testSearchCatalogRemainsReadableAtAccessibilityTextSize() throws {
        continueAfterFailure = false
        let app = makeApp(
            environment: ["SERIESAV_UI_TESTS_INITIAL_TAB": "search"],
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL"
        )
        app.launch()

        let title = app.staticTexts["series-search-title"]
        let subtitle = app.staticTexts["series-search-subtitle"]
        let searchField = app.textFields["series-search-field"]
        let popularFilter = app.buttons["series-search-filter-popular"]
        let limit = app.staticTexts["series-search-limit"]
        let resultsTitle = app.staticTexts["series-search-results-title"]
        let resultsSubtitle = app.staticTexts["series-search-results-subtitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertTrue(subtitle.exists)
        XCTAssertTrue(searchField.exists)
        XCTAssertTrue(popularFilter.exists)
        XCTAssertTrue(limit.exists)
        XCTAssertTrue(resultsTitle.exists)
        XCTAssertTrue(resultsSubtitle.exists)
        XCTAssertGreaterThanOrEqual(searchField.frame.height, 44)
        XCTAssertGreaterThanOrEqual(popularFilter.frame.height, 44)
        XCTAssertLessThan(title.frame.maxY, subtitle.frame.minY)
        XCTAssertLessThan(subtitle.frame.maxY, searchField.frame.minY)

        let firstResult = app.buttons["The Last of Us"].firstMatch
        let firstFollowAction = app.buttons["Seguir serie"].firstMatch
        XCTAssertTrue(firstResult.waitForExistence(timeout: 10))
        XCTAssertTrue(firstFollowAction.exists)
        for _ in 0..<6 where !firstResult.isHittable || !firstFollowAction.isHittable {
            app.swipeUp()
        }

        XCTAssertTrue(firstResult.isHittable)
        XCTAssertTrue(firstFollowAction.isHittable)
        let resultMetadata = firstResult.value as? String
        XCTAssertTrue(resultMetadata?.contains("2023") == true)
        XCTAssertTrue(resultMetadata?.contains("episodios") == true)
        XCTAssertLessThan(firstResult.frame.maxY, firstFollowAction.frame.minY)
        XCTAssertFalse(firstResult.frame.intersects(firstFollowAction.frame))
        XCTAssertGreaterThan(firstFollowAction.frame.width, app.frame.width * 0.70)
        XCTAssertGreaterThanOrEqual(firstFollowAction.frame.height, 52)
    }

    @MainActor
    func testSearchLibraryResultUsesReadableActionsAtAccessibilityTextSize() throws {
        continueAfterFailure = false
        let app = makeApp(
            environment: [
                "SERIESAV_UI_TESTS_SAMPLE_LIBRARY": "1",
                "SERIESAV_UI_TESTS_INITIAL_TAB": "search"
            ],
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL"
        )
        app.launch()

        let searchField = app.textFields["series-search-field"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 10))
        searchField.tap()
        searchField.typeText("Later")
        let keyboardSearchAction = app.keyboards.buttons["Search"]
        if keyboardSearchAction.exists {
            keyboardSearchAction.tap()
        }

        let result = app.buttons["series-search-library-sample-3-open"]
        let editAction = app.buttons["series-search-sample-3-edit-progress"]
        let quickAction = app.buttons["series-search-sample-3-quick-progress"]
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        XCTAssertTrue(editAction.exists)
        XCTAssertTrue(quickAction.exists)
        for _ in 0..<4 where !editAction.isHittable || !quickAction.isHittable {
            app.swipeUp()
        }

        XCTAssertTrue(editAction.isHittable)
        XCTAssertTrue(quickAction.isHittable)
        XCTAssertLessThan(result.frame.maxY, editAction.frame.minY)
        XCTAssertFalse(result.frame.intersects(editAction.frame))
        XCTAssertFalse(editAction.frame.intersects(quickAction.frame))
        XCTAssertLessThan(editAction.frame.maxY, quickAction.frame.minY)
        XCTAssertGreaterThan(editAction.frame.width, app.frame.width * 0.70)
        XCTAssertGreaterThan(quickAction.frame.width, app.frame.width * 0.70)
        XCTAssertGreaterThanOrEqual(editAction.frame.height, 52)
        XCTAssertGreaterThanOrEqual(quickAction.frame.height, 52)
    }

    @MainActor
    func testSearchCatalogCardsRemainCompactOnIPad() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = makeApp(environment: ["SERIESAV_UI_TESTS_INITIAL_TAB": "search"])
        app.launch()

        guard app.frame.width > 600 else {
            throw XCTSkip("This compact-density assertion is intended for iPad.")
        }

        let firstResult = app.buttons["The Last of Us"].firstMatch
        let firstFollowAction = app.buttons["Seguir serie"].firstMatch
        XCTAssertTrue(firstResult.waitForExistence(timeout: 10))
        XCTAssertTrue(firstFollowAction.exists)
        for _ in 0..<4 where !firstResult.isHittable || !firstFollowAction.isHittable {
            app.swipeUp()
        }

        XCTAssertTrue(firstResult.isHittable)
        XCTAssertTrue(firstFollowAction.isHittable)
        XCTAssertLessThanOrEqual(firstResult.frame.maxX, firstFollowAction.frame.minX)
        XCTAssertFalse(firstResult.frame.intersects(firstFollowAction.frame))
        XCTAssertGreaterThanOrEqual(firstFollowAction.frame.width, 44)
        XCTAssertLessThanOrEqual(firstFollowAction.frame.width, 48)
        XCTAssertGreaterThanOrEqual(firstFollowAction.frame.height, 44)
        XCTAssertLessThanOrEqual(firstFollowAction.frame.height, 48)
        XCTAssertLessThan(firstResult.frame.height, 120)
    }

    @MainActor
    func testProgressEditorOpensForSampleCurrentSeries() throws {
        continueAfterFailure = false
        let app = makeApp(environment: [
            "SERIESAV_UI_TESTS_SAMPLE_LIBRARY": "1",
            "SERIESAV_UI_TESTS_INITIAL_TAB": "home",
            "SERIESAV_UI_TESTS_SHOW_PROGRESS_EDITOR": "1"
        ])
        app.launch()

        XCTAssertTrue(app.staticTexts["Current Series"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Ajustar episodio"].exists)
        XCTAssertTrue(app.staticTexts["S1 E2"].exists)
        XCTAssertTrue(app.staticTexts["Toca el último episodio visto para guardarlo."].exists)
        XCTAssertFalse(app.buttons["Guardar S1 E2"].exists)
        XCTAssertFalse(app.buttons["series-progress-editor-save"].exists)
        XCTAssertTrue(app.buttons["Sin empezar"].exists)
    }

    @MainActor
    func testProgressEditorRemainsReadableAtAccessibilityTextSize() throws {
        continueAfterFailure = false
        let app = makeApp(
            environment: [
                "SERIESAV_UI_TESTS_SAMPLE_LIBRARY": "1",
                "SERIESAV_UI_TESTS_INITIAL_TAB": "home",
                "SERIESAV_UI_TESTS_SHOW_PROGRESS_EDITOR": "1"
            ],
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL"
        )
        app.launch()

        let prompt = app.staticTexts["series-progress-editor-prompt"]
        let cursor = app.staticTexts["series-progress-editor-cursor"]
        let watchedThrough = app.staticTexts["series-progress-editor-watched-through"]
        let nextEpisode = app.staticTexts["series-progress-editor-next"]
        let coverage = app.staticTexts["series-progress-editor-coverage"]
        let saveHint = app.staticTexts["series-progress-editor-save-hint"]

        XCTAssertTrue(prompt.waitForExistence(timeout: 10))
        XCTAssertTrue(cursor.exists)
        XCTAssertTrue(watchedThrough.exists)
        XCTAssertTrue(nextEpisode.exists)
        XCTAssertTrue(coverage.exists)
        XCTAssertTrue(saveHint.exists)
        XCTAssertGreaterThan(cursor.frame.height, 40)
        XCTAssertLessThan(prompt.frame.maxY, cursor.frame.maxY)
        XCTAssertLessThan(cursor.frame.maxY, watchedThrough.frame.minY)
        XCTAssertLessThan(watchedThrough.frame.maxY, nextEpisode.frame.minY)
        XCTAssertLessThan(nextEpisode.frame.maxY, coverage.frame.minY)
        XCTAssertGreaterThan(saveHint.frame.width, app.frame.width * 0.75)

        let seasonTitle = app.staticTexts["series-progress-editor-season-title"]
        for _ in 0..<4 where !seasonTitle.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(seasonTitle.exists)

        let seasonButton = app.buttons["Temporada 1"]
        XCTAssertTrue(seasonButton.exists)
        XCTAssertGreaterThanOrEqual(seasonButton.frame.height, 44)
        XCTAssertTrue(seasonButton.isHittable)

        let episodeTitle = app.staticTexts["series-progress-editor-episode-title"]
        for _ in 0..<4 where !episodeTitle.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(episodeTitle.exists)

        let episodeButton = app.buttons["Episodio 1"]
        XCTAssertTrue(episodeButton.exists)
        XCTAssertGreaterThanOrEqual(episodeButton.frame.height, 44)
        XCTAssertTrue(episodeButton.isHittable)
    }

    @MainActor
    func testProgressEditorEpisodeTapSavesAndReturnsHome() throws {
        continueAfterFailure = false
        let app = makeApp(environment: [
            "SERIESAV_UI_TESTS_SAMPLE_LIBRARY": "1",
            "SERIESAV_UI_TESTS_INITIAL_TAB": "home",
            "SERIESAV_UI_TESTS_SHOW_PROGRESS_EDITOR": "1"
        ])
        app.launch()

        XCTAssertTrue(app.staticTexts["Ajustar episodio"].waitForExistence(timeout: 10))
        app.buttons["Episodio 3"].tap()

        XCTAssertTrue(app.staticTexts["Current Series"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Siguiente S1 E4"].exists)
        XCTAssertFalse(app.buttons["Cancelar"].exists)
        XCTAssertFalse(app.buttons["series-progress-editor-save"].exists)
    }

    @MainActor
    func testProgressEditorExplainsReadySeriesMovesToWatching() throws {
        continueAfterFailure = false
        let app = makeApp(environment: [
            "SERIESAV_UI_TESTS_SAMPLE_LIBRARY": "1",
            "SERIESAV_UI_TESTS_INITIAL_TAB": "home",
            "SERIESAV_UI_TESTS_SHOW_PROGRESS_EDITOR": "1",
            "SERIESAV_UI_TESTS_PROGRESS_EDITOR_ENTRY_ID": "sample-3"
        ])
        app.launch()

        XCTAssertTrue(app.staticTexts["Later List"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Último episodio visto"].exists)
        XCTAssertTrue(app.staticTexts["S1 E1"].exists)
        XCTAssertTrue(app.staticTexts["Al guardar pasará a Viendo ahora. El siguiente será S1 E2."].exists)
        XCTAssertTrue(app.staticTexts["Toca el último episodio visto para guardarlo."].exists)
        XCTAssertFalse(app.buttons["Guardar S1 E1"].exists)
        XCTAssertFalse(app.buttons["series-progress-editor-save"].exists)
        XCTAssertTrue(app.buttons["Cancelar"].exists)
    }

    @MainActor
    func testProgressEditorKeepsStartedReadySeriesVisibleOnHome() throws {
        continueAfterFailure = false
        let app = makeApp(environment: [
            "SERIESAV_UI_TESTS_SAMPLE_LIBRARY": "1",
            "SERIESAV_UI_TESTS_INITIAL_TAB": "home",
            "SERIESAV_UI_TESTS_SHOW_PROGRESS_EDITOR": "1",
            "SERIESAV_UI_TESTS_PROGRESS_EDITOR_ENTRY_ID": "sample-3"
        ])
        app.launch()

        XCTAssertTrue(app.staticTexts["Later List"].waitForExistence(timeout: 10))
        app.buttons["Episodio 1"].tap()

        XCTAssertTrue(app.staticTexts["Viendo ahora"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Later List"].exists)
        XCTAssertTrue(app.staticTexts["Siguiente S1 E2"].exists)
        XCTAssertTrue(app.buttons["Marcar S1 E2 visto"].exists)
        XCTAssertTrue(app.staticTexts["\"Later List\" salió de Listas para empezar y ahora está en Viendo ahora"].exists)
    }

    @MainActor
    func testSampleHomeShowsReadyToStartBeforeSecondaryWatchingQueue() throws {
        continueAfterFailure = false
        let app = makeApp(environment: [
            "SERIESAV_UI_TESTS_SAMPLE_LIBRARY": "1",
            "SERIESAV_UI_TESTS_INITIAL_TAB": "home"
        ])
        app.launch()

        XCTAssertTrue(app.staticTexts["Current Series"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Viendo ahora"].exists)
        XCTAssertTrue(app.staticTexts["Siguiente S1 E3"].exists)
        XCTAssertTrue(app.buttons["home.aviBrief.open"].exists)
        XCTAssertGreaterThan(
            app.buttons["home.aviBrief.open"].frame.minY,
            app.buttons["Marcar S1 E3 visto"].frame.maxY
        )

        if !app.staticTexts["También viendo"].waitForExistence(timeout: 2) {
            app.swipeUp()
        }

        let readyToStartTitle = app.staticTexts["Listas para empezar"]
        let secondaryQueueTitle = app.staticTexts["También viendo"]
        XCTAssertTrue(readyToStartTitle.waitForExistence(timeout: 5))
        XCTAssertTrue(secondaryQueueTitle.waitForExistence(timeout: 5))
        XCTAssertLessThan(readyToStartTitle.frame.minY, secondaryQueueTitle.frame.minY)

        XCTAssertTrue(app.staticTexts["Slow Weekend Show"].exists)
        XCTAssertTrue(app.staticTexts["S2 E7 → S2 E8"].exists)
        XCTAssertTrue(app.staticTexts["Later List"].exists)
        XCTAssertTrue(app.staticTexts["Empezar por S1 E1"].exists)
        XCTAssertTrue(app.buttons["Empezar S1 E1"].exists)
        XCTAssertFalse(app.buttons["Marcar S1 E1 visto"].exists)
        XCTAssertFalse(app.staticTexts["Sigue tu primera serie"].exists)
    }

    @MainActor
    func testHomeWatchingQueuesStackReadableActionsAtAccessibilityTextSize() throws {
        continueAfterFailure = false
        let app = makeApp(
            environment: [
                "SERIESAV_UI_TESTS_SAMPLE_LIBRARY": "1",
                "SERIESAV_UI_TESTS_INITIAL_TAB": "home"
            ],
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL"
        )
        app.launch()

        let readyTitle = app.staticTexts["series-queue-sample-3-title"]
        let readyProgress = app.staticTexts["series-queue-sample-3-progress"]
        let readyDetail = app.buttons["series-queue-sample-3-detail"]
        let readyPrimary = app.buttons["series-queue-sample-3-quick-progress"]
        let readyActions = app.buttons["series-queue-sample-3-actions"]

        for _ in 0..<8 where !readyTitle.exists {
            app.swipeUp()
        }

        XCTAssertTrue(readyTitle.waitForExistence(timeout: 10))
        XCTAssertTrue(readyProgress.exists)
        XCTAssertTrue(readyDetail.exists)
        XCTAssertTrue(readyPrimary.exists)
        XCTAssertTrue(readyActions.exists)
        XCTAssertEqual(readyTitle.label, "Later List")
        XCTAssertEqual(readyProgress.label, "Empezar por S1 E1")
        XCTAssertEqual(readyPrimary.label, "Empezar S1 E1")
        XCTAssertEqual(readyActions.label, "Acciones de serie")
        XCTAssertLessThanOrEqual(readyDetail.frame.maxY, readyPrimary.frame.minY)
        XCTAssertLessThan(readyPrimary.frame.maxY, readyActions.frame.minY)
        XCTAssertGreaterThan(readyPrimary.frame.width, 250)
        XCTAssertEqual(readyPrimary.frame.width, readyActions.frame.width, accuracy: 2)
        XCTAssertGreaterThanOrEqual(readyPrimary.frame.height, 56)
        XCTAssertGreaterThanOrEqual(readyActions.frame.height, 56)

        let watchingTitle = app.staticTexts["series-queue-sample-2-title"]
        let watchingProgress = app.staticTexts["series-queue-sample-2-progress"]
        let watchingDetail = app.buttons["series-queue-sample-2-detail"]
        let watchingPrimary = app.buttons["series-queue-sample-2-quick-progress"]
        let watchingActions = app.buttons["series-queue-sample-2-actions"]

        for _ in 0..<4 where !watchingTitle.exists {
            app.swipeUp()
        }

        XCTAssertTrue(watchingTitle.waitForExistence(timeout: 5))
        XCTAssertTrue(watchingProgress.exists)
        XCTAssertTrue(watchingDetail.exists)
        XCTAssertTrue(watchingPrimary.exists)
        XCTAssertTrue(watchingActions.exists)
        XCTAssertEqual(watchingTitle.label, "Slow Weekend Show")
        XCTAssertEqual(watchingProgress.label, "S2 E7 → S2 E8")
        XCTAssertEqual(watchingPrimary.label, "Marcar S2 E8 visto")
        XCTAssertEqual(watchingActions.label, "Acciones de serie")
        XCTAssertLessThanOrEqual(watchingDetail.frame.maxY, watchingPrimary.frame.minY)
        XCTAssertLessThan(watchingPrimary.frame.maxY, watchingActions.frame.minY)
        XCTAssertEqual(watchingPrimary.frame.width, watchingActions.frame.width, accuracy: 2)
    }

    @MainActor
    func testHomeWatchingQueuesRemainCompactAtNormalTextSize() throws {
        continueAfterFailure = false
        let app = makeApp(environment: [
            "SERIESAV_UI_TESTS_SAMPLE_LIBRARY": "1",
            "SERIESAV_UI_TESTS_INITIAL_TAB": "home"
        ])
        app.launch()

        guard app.frame.width <= 600 else {
            throw XCTSkip("This two-level queue layout only applies to iPhone.")
        }

        let detail = app.buttons["series-queue-sample-3-detail"]
        let primary = app.buttons["series-queue-sample-3-quick-progress"]
        let actions = app.buttons["series-queue-sample-3-actions"]

        for _ in 0..<5 where !detail.exists {
            app.swipeUp()
        }

        XCTAssertTrue(detail.waitForExistence(timeout: 10))
        XCTAssertTrue(primary.exists)
        XCTAssertTrue(actions.exists)
        XCTAssertLessThanOrEqual(detail.frame.maxY, primary.frame.minY)
        XCTAssertLessThanOrEqual(primary.frame.maxX, actions.frame.minX)
        XCTAssertGreaterThan(primary.frame.width, 200)
        XCTAssertEqual(primary.label, "Empezar S1 E1")
        XCTAssertLessThan(actions.frame.width, 70)
        XCTAssertGreaterThanOrEqual(actions.frame.width, 44)
        XCTAssertGreaterThanOrEqual(actions.frame.height, 44)
    }

    @MainActor
    func testHomeWatchingQueuesRemainDenseOnIPad() throws {
        continueAfterFailure = false
        let app = makeApp(environment: [
            "SERIESAV_UI_TESTS_SAMPLE_LIBRARY": "1",
            "SERIESAV_UI_TESTS_INITIAL_TAB": "home"
        ])
        app.launch()

        guard app.frame.width > 600 else {
            throw XCTSkip("This horizontal queue layout only applies to iPad.")
        }

        let detail = app.buttons["series-queue-sample-3-detail"]
        let primary = app.buttons["series-queue-sample-3-quick-progress"]
        let actions = app.buttons["series-queue-sample-3-actions"]

        XCTAssertTrue(detail.waitForExistence(timeout: 10))
        XCTAssertTrue(primary.exists)
        XCTAssertTrue(actions.exists)
        XCTAssertLessThanOrEqual(detail.frame.maxX, primary.frame.minX)
        XCTAssertLessThanOrEqual(primary.frame.maxX, actions.frame.minX)
        XCTAssertLessThan(primary.frame.width, 150)
        XCTAssertLessThan(actions.frame.width, 70)
        XCTAssertGreaterThanOrEqual(actions.frame.width, 44)
        XCTAssertGreaterThanOrEqual(actions.frame.height, 44)
    }

    @MainActor
    func testUpcomingHomeCardRemainsReadableAtAccessibilityTextSize() throws {
        continueAfterFailure = false
        let app = makeApp(
            environment: [
                "SERIESAV_UI_TESTS_SAMPLE_LIBRARY": "1",
                "SERIESAV_UI_TESTS_INITIAL_TAB": "home",
                "SERIESAV_UI_TESTS_UPCOMING_EPISODES": "sample"
            ],
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL"
        )
        app.launch()

        let cardTitle = app.staticTexts["series-home-upcoming-title"]
        for _ in 0..<12 where !cardTitle.exists {
            app.swipeUp()
        }
        XCTAssertTrue(cardTitle.waitForExistence(timeout: 10))
        for _ in 0..<8 where !cardTitle.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(cardTitle.isHittable)
        app.swipeUp()

        let openLibrary = app.buttons["series-home-upcoming-open-library"]
        let dateBadge = app.descendants(matching: .any)["series-home-upcoming-sample-1-date"]
        let seriesTitle = app.staticTexts["series-home-upcoming-sample-1-title"]
        let detail = app.staticTexts["series-home-upcoming-sample-1-detail"]

        XCTAssertTrue(openLibrary.exists)
        XCTAssertTrue(dateBadge.exists)
        XCTAssertTrue(seriesTitle.exists)
        XCTAssertTrue(detail.exists)
        XCTAssertLessThan(cardTitle.frame.maxY, openLibrary.frame.minY)
        XCTAssertGreaterThanOrEqual(openLibrary.frame.height, 44)
        XCTAssertTrue(openLibrary.isHittable)
        XCTAssertLessThanOrEqual(dateBadge.frame.maxX, seriesTitle.frame.minX)
        XCTAssertLessThan(seriesTitle.frame.maxY, detail.frame.minY)
        XCTAssertGreaterThanOrEqual(dateBadge.frame.width, 60)
        XCTAssertGreaterThanOrEqual(dateBadge.frame.height, 60)
    }

    @MainActor
    func testHomeOnlyShowsBottomBarWhileUndoIsPending() throws {
        continueAfterFailure = false
        let app = makeApp(environment: [
            "SERIESAV_UI_TESTS_SAMPLE_LIBRARY": "1",
            "SERIESAV_UI_TESTS_INITIAL_TAB": "home"
        ])
        app.launch()

        let primaryAction = app.buttons["Marcar S1 E3 visto"]
        let undoBar = app.otherElements["series.undo.bar"]
        let homeTab = app.buttons["series.tab.home"]
        XCTAssertTrue(primaryAction.waitForExistence(timeout: 10))
        XCTAssertFalse(undoBar.exists)

        primaryAction.tap()

        XCTAssertTrue(undoBar.waitForExistence(timeout: 5))
        let undoButton = app.buttons["series.undo.action"]
        let dismissButton = app.buttons["series.undo.dismiss"]
        XCTAssertTrue(undoButton.exists)
        XCTAssertTrue(dismissButton.exists)
        XCTAssertTrue(undoButton.isHittable)
        XCTAssertTrue(dismissButton.isHittable)
        XCTAssertGreaterThanOrEqual(undoBar.frame.height, 44)
        XCTAssertLessThan(undoBar.frame.height, 90)
        XCTAssertGreaterThanOrEqual(undoButton.frame.height, 44)
        XCTAssertGreaterThanOrEqual(dismissButton.frame.width, 44)
        XCTAssertGreaterThanOrEqual(dismissButton.frame.height, 44)
        XCTAssertLessThan(abs(undoButton.frame.midY - dismissButton.frame.midY), 4)
        XCTAssertLessThanOrEqual(undoBar.frame.maxY, homeTab.frame.minY)
        dismissButton.tap()
        XCTAssertFalse(undoBar.waitForExistence(timeout: 1))
    }

    @MainActor
    func testHomeUndoBarStacksReadableControlsAtAccessibilityTextSize() throws {
        continueAfterFailure = false
        let app = makeApp(
            environment: [
                "SERIESAV_UI_TESTS_SAMPLE_LIBRARY": "1",
                "SERIESAV_UI_TESTS_INITIAL_TAB": "home"
            ],
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL"
        )
        app.launch()

        let primaryAction = app.buttons["Marcar S1 E3 visto"]
        XCTAssertTrue(primaryAction.waitForExistence(timeout: 10))
        primaryAction.tap()

        let undoBar = app.otherElements["series.undo.bar"]
        let message = app.staticTexts["series.undo.message"]
        let undoButton = app.buttons["series.undo.action"]
        let dismissButton = app.buttons["series.undo.dismiss"]
        let homeTab = app.buttons["series.tab.home"]
        XCTAssertTrue(undoBar.waitForExistence(timeout: 5))
        XCTAssertTrue(message.exists)
        XCTAssertTrue(undoButton.exists)
        XCTAssertTrue(dismissButton.exists)
        XCTAssertTrue(undoButton.isHittable)
        XCTAssertTrue(dismissButton.isHittable)
        XCTAssertGreaterThan(message.frame.height, 30)
        XCTAssertGreaterThanOrEqual(undoButton.frame.height, 44)
        XCTAssertGreaterThanOrEqual(dismissButton.frame.width, 44)
        XCTAssertGreaterThanOrEqual(dismissButton.frame.height, 44)
        XCTAssertGreaterThanOrEqual(undoButton.frame.minY, message.frame.maxY)
        XCTAssertGreaterThan(undoBar.frame.height, 90)
        XCTAssertTrue(undoBar.frame.contains(undoButton.frame))
        XCTAssertTrue(undoBar.frame.contains(dismissButton.frame))
        XCTAssertLessThanOrEqual(undoBar.frame.maxY, homeTab.frame.minY)
        dismissButton.tap()
        XCTAssertFalse(undoBar.waitForExistence(timeout: 1))
    }

    @MainActor
    func testCurrentHeroUsesReadableHierarchyAtAccessibilityTextSize() throws {
        continueAfterFailure = false
        let app = makeApp(
            environment: [
                "SERIESAV_UI_TESTS_SAMPLE_LIBRARY": "1",
                "SERIESAV_UI_TESTS_INITIAL_TAB": "home"
            ],
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL"
        )
        app.launch()

        let currentCard = app.otherElements["home-current-card"]
        let status = app.staticTexts["home-current-status"]
        let progress = app.staticTexts["home-current-progress"]
        let title = app.staticTexts["home-current-series-title"]
        let nextEpisode = app.staticTexts["home-current-next-episode"]
        let primaryAction = app.buttons["home-current-primary-action"]
        let adjustAction = app.buttons["home-current-adjust-progress"]
        let previousAction = app.buttons["home-current-previous-action"]

        XCTAssertTrue(currentCard.waitForExistence(timeout: 10))
        XCTAssertTrue(status.exists)
        XCTAssertTrue(progress.exists)
        XCTAssertTrue(title.exists)
        XCTAssertTrue(nextEpisode.exists)
        XCTAssertTrue(primaryAction.exists)
        XCTAssertTrue(adjustAction.exists)
        XCTAssertTrue(previousAction.exists)
        XCTAssertEqual(status.label, "Viendo ahora")
        XCTAssertEqual(progress.label, "S1 E2")
        XCTAssertEqual(title.label, "Current Series")
        XCTAssertEqual(nextEpisode.label, "Siguiente S1 E3")
        XCTAssertEqual(primaryAction.label, "Marcar S1 E3 visto")
        XCTAssertEqual(adjustAction.label, "Ajustar episodio")
        XCTAssertEqual(previousAction.label, "Atrás · S1 E1")
        XCTAssertGreaterThan(status.frame.height, 30)
        XCTAssertGreaterThan(title.frame.height, 40)
        XCTAssertLessThan(status.frame.maxY, progress.frame.minY)
        XCTAssertLessThan(progress.frame.maxY, title.frame.minY)
        XCTAssertLessThan(title.frame.maxY, nextEpisode.frame.minY)
        XCTAssertLessThan(nextEpisode.frame.maxY, primaryAction.frame.minY)
        XCTAssertLessThan(primaryAction.frame.maxY, adjustAction.frame.minY)
        XCTAssertLessThan(adjustAction.frame.maxY, previousAction.frame.minY)
        XCTAssertGreaterThan(primaryAction.frame.width, currentCard.frame.width - 50)
        XCTAssertEqual(primaryAction.frame.width, adjustAction.frame.width, accuracy: 2)
        XCTAssertEqual(adjustAction.frame.width, previousAction.frame.width, accuracy: 2)
        XCTAssertGreaterThanOrEqual(primaryAction.frame.height, 56)
        XCTAssertGreaterThanOrEqual(adjustAction.frame.height, 56)
        XCTAssertGreaterThanOrEqual(previousAction.frame.height, 56)
    }

    @MainActor
    func testCurrentHeroPrimaryActionIsCompactOnIPad() throws {
        continueAfterFailure = false
        let app = makeApp(environment: [
            "SERIESAV_UI_TESTS_SAMPLE_LIBRARY": "1",
            "SERIESAV_UI_TESTS_INITIAL_TAB": "home"
        ])
        app.launch()

        guard app.frame.width > 600 else {
            throw XCTSkip("This width check only applies to iPad.")
        }

        let currentCard = app.otherElements["home-current-card"]
        let primaryAction = app.buttons["home-current-primary-action"]
        XCTAssertTrue(currentCard.waitForExistence(timeout: 10))
        XCTAssertTrue(primaryAction.exists)
        XCTAssertTrue(primaryAction.isHittable)
        XCTAssertGreaterThanOrEqual(primaryAction.frame.height, 44)
        XCTAssertLessThan(primaryAction.frame.width, currentCard.frame.width * 0.55)
        XCTAssertLessThan(primaryAction.frame.maxX, currentCard.frame.maxX - 80)
    }

    @MainActor
    func testSampleDetailTrackingActionsUseVisibleActionLabels() throws {
        continueAfterFailure = false
        let app = makeApp(environment: [
            "SERIESAV_UI_TESTS_SAMPLE_LIBRARY": "1",
            "SERIESAV_UI_TESTS_INITIAL_TAB": "home"
        ])
        app.launch()

        XCTAssertTrue(app.staticTexts["Current Series"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Marcar S1 E3 visto"].exists)

        let detailButton = app.buttons["Current Series"].firstMatch
        XCTAssertTrue(detailButton.waitForExistence(timeout: 5))
        detailButton.tap()

        XCTAssertTrue(app.staticTexts["Seguimiento"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Marcar S1 E3 visto"].exists)
        XCTAssertTrue(app.buttons["Ajustar episodio"].exists)
        XCTAssertTrue(app.buttons["Quitar fijado"].exists)

        let trackingStatus = app.descendants(matching: .any)["series-detail-tracking-status"]
        let trackingDetail = app.descendants(matching: .any)["series-detail-tracking-detail"]
        XCTAssertTrue(trackingStatus.exists)
        XCTAssertTrue(trackingDetail.exists)
        XCTAssertEqual(trackingStatus.label, "Viendo")
        XCTAssertEqual(trackingDetail.label, "S1 E2 · Siguiente S1 E3")
        XCTAssertEqual(trackingStatus.frame.midY, trackingDetail.frame.midY, accuracy: 2)

        let primaryAction = app.buttons["series-detail-tracking-primary"]
        let adjustAction = app.buttons["series-detail-tracking-adjust"]
        let pinAction = app.buttons["series-detail-tracking-pin"]
        XCTAssertEqual(primaryAction.frame.midY, adjustAction.frame.midY, accuracy: 2)
        XCTAssertEqual(primaryAction.frame.midY, pinAction.frame.midY, accuracy: 2)
        XCTAssertGreaterThanOrEqual(primaryAction.frame.height, 44)
        XCTAssertGreaterThanOrEqual(adjustAction.frame.height, 44)
        XCTAssertGreaterThanOrEqual(pinAction.frame.height, 44)

        XCTAssertTrue(app.staticTexts["Episodios"].waitForExistence(timeout: 5))
        XCTAssertLessThan(app.staticTexts["Seguimiento"].frame.minY, app.staticTexts["Episodios"].frame.minY)
        XCTAssertLessThan(app.staticTexts["Episodios"].frame.minY, app.staticTexts["Más opciones"].frame.minY)

        let setProgressButton = app.buttons["series-detail-episode-1-2-set-progress"]
        for _ in 0..<6 where !setProgressButton.exists {
            app.swipeUp()
        }
        XCTAssertTrue(setProgressButton.exists)
        XCTAssertGreaterThanOrEqual(setProgressButton.frame.height, 44)
        XCTAssertLessThan(setProgressButton.frame.height, 110)
        XCTAssertEqual(setProgressButton.value as? String, "Episodio 2, 2026-07-10, Último visto")
        XCTAssertFalse(app.staticTexts["Fijar"].exists)
        XCTAssertFalse(app.staticTexts["Guardar S1 E3"].exists)
    }

    @MainActor
    func testSampleDetailTrackingActionsRemainUsableWithAccessibilityTextSize() throws {
        continueAfterFailure = false
        let app = makeApp(
            environment: [
                "SERIESAV_UI_TESTS_SAMPLE_LIBRARY": "1",
                "SERIESAV_UI_TESTS_INITIAL_TAB": "home"
            ],
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL"
        )
        app.launch()

        let detailButton = app.buttons["Current Series"].firstMatch
        XCTAssertTrue(detailButton.waitForExistence(timeout: 10))
        detailButton.tap()

        XCTAssertTrue(app.staticTexts["Seguimiento"].waitForExistence(timeout: 10))
        let trackingSummary = app.descendants(matching: .any)["series-detail-tracking-summary"]
        let trackingStatus = app.descendants(matching: .any)["series-detail-tracking-status"]
        let trackingDetail = app.descendants(matching: .any)["series-detail-tracking-detail"]
        let primaryAction = app.buttons["series-detail-tracking-primary"]
        let adjustAction = app.buttons["series-detail-tracking-adjust"]
        let pinAction = app.buttons["series-detail-tracking-pin"]
        for _ in 0..<4 where !pinAction.isHittable {
            app.swipeUp()
        }

        XCTAssertEqual(primaryAction.label, "Marcar S1 E3 visto")
        XCTAssertEqual(adjustAction.label, "Ajustar episodio")
        XCTAssertEqual(pinAction.label, "Quitar fijado")
        XCTAssertTrue(trackingSummary.exists)
        XCTAssertTrue(trackingStatus.exists)
        XCTAssertTrue(trackingDetail.exists)
        XCTAssertEqual(trackingStatus.label, "Viendo")
        XCTAssertEqual(trackingDetail.label, "S1 E2 · Siguiente S1 E3")
        XCTAssertLessThan(trackingStatus.frame.maxY, trackingDetail.frame.minY)
        XCTAssertEqual(trackingStatus.frame.minX, trackingDetail.frame.minX, accuracy: 4)
        XCTAssertGreaterThan(trackingStatus.frame.height, 20)
        XCTAssertGreaterThan(trackingDetail.frame.height, 20)
        XCTAssertTrue(primaryAction.isHittable)
        XCTAssertTrue(adjustAction.isHittable)
        XCTAssertTrue(pinAction.isHittable)
        XCTAssertGreaterThanOrEqual(primaryAction.frame.height, 44)
        XCTAssertGreaterThanOrEqual(adjustAction.frame.height, 44)
        XCTAssertGreaterThanOrEqual(pinAction.frame.height, 44)
        XCTAssertLessThan(primaryAction.frame.maxY, adjustAction.frame.minY)
        XCTAssertLessThan(adjustAction.frame.maxY, pinAction.frame.minY)
        XCTAssertEqual(primaryAction.frame.minX, adjustAction.frame.minX, accuracy: 2)
        XCTAssertEqual(adjustAction.frame.minX, pinAction.frame.minX, accuracy: 2)
        XCTAssertEqual(primaryAction.frame.width, adjustAction.frame.width, accuracy: 2)
        XCTAssertEqual(adjustAction.frame.width, pinAction.frame.width, accuracy: 2)
        XCTAssertFalse(primaryAction.frame.intersects(adjustAction.frame))
        XCTAssertFalse(primaryAction.frame.intersects(pinAction.frame))
        XCTAssertFalse(adjustAction.frame.intersects(pinAction.frame))
    }

    @MainActor
    func testSampleDetailEpisodeRowsStackMetadataAtAccessibilityTextSize() throws {
        continueAfterFailure = false
        let app = makeApp(
            environment: [
                "SERIESAV_UI_TESTS_SAMPLE_LIBRARY": "1",
                "SERIESAV_UI_TESTS_INITIAL_TAB": "home"
            ],
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL"
        )
        app.launch()

        let detailButton = app.buttons["Current Series"].firstMatch
        XCTAssertTrue(detailButton.waitForExistence(timeout: 10))
        detailButton.tap()

        let currentEpisode = app.buttons["series-detail-episode-1-2-set-progress"]
        for _ in 0..<10 where !currentEpisode.exists || !currentEpisode.isHittable {
            app.swipeUp()
        }

        XCTAssertTrue(currentEpisode.exists)
        XCTAssertTrue(currentEpisode.isHittable)
        XCTAssertGreaterThan(currentEpisode.frame.height, 120)
        XCTAssertEqual(currentEpisode.value as? String, "Episodio 2, 2026-07-10, Último visto")
        XCTAssertGreaterThanOrEqual(currentEpisode.frame.minX, app.frame.minX + 16)
        XCTAssertLessThanOrEqual(currentEpisode.frame.maxX, app.frame.maxX - 16)

        let nextEpisode = app.buttons["series-detail-episode-1-3-set-progress"]
        XCTAssertTrue(nextEpisode.exists)
        XCTAssertFalse(currentEpisode.frame.intersects(nextEpisode.frame))
    }

    @MainActor
    func testFailedEpisodeGuideUsesCompactRetryState() throws {
        continueAfterFailure = false
        let app = makeApp(environment: [
            "SERIESAV_UI_TESTS_SAMPLE_LIBRARY": "1",
            "SERIESAV_UI_TESTS_INITIAL_TAB": "home",
            "SERIESAV_UI_TESTS_EPISODE_GUIDE": "failed_once"
        ])
        app.launch()

        let detailButton = app.buttons["Current Series"].firstMatch
        XCTAssertTrue(detailButton.waitForExistence(timeout: 10))
        detailButton.tap()

        let guideState = app.otherElements["series-detail-guide-state"]
        XCTAssertTrue(guideState.waitForExistence(timeout: 10))
        XCTAssertLessThan(guideState.frame.height, 90)
        XCTAssertTrue(app.staticTexts["No se pudo cargar la guía ahora mismo."].exists)

        let retryButton = app.buttons["series-detail-guide-retry"]
        XCTAssertTrue(retryButton.exists)
        XCTAssertTrue(retryButton.isHittable)
        XCTAssertGreaterThanOrEqual(retryButton.frame.height, 44)
        retryButton.tap()

        XCTAssertTrue(app.buttons["series-detail-episode-1-2-set-progress"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["No se pudo cargar la guía ahora mismo."].exists)
    }

    @MainActor
    func testFailedEpisodeGuideRetryRemainsUsableWithAccessibilityTextSize() throws {
        continueAfterFailure = false
        let app = makeApp(
            environment: [
                "SERIESAV_UI_TESTS_SAMPLE_LIBRARY": "1",
                "SERIESAV_UI_TESTS_INITIAL_TAB": "home",
                "SERIESAV_UI_TESTS_EPISODE_GUIDE": "failed_once"
            ],
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL"
        )
        app.launch()

        let detailButton = app.buttons["Current Series"].firstMatch
        XCTAssertTrue(detailButton.waitForExistence(timeout: 10))
        detailButton.tap()

        let failureDetail = app.staticTexts["No se pudo cargar la guía ahora mismo."]
        XCTAssertTrue(failureDetail.waitForExistence(timeout: 10))
        let failureTitle = app.staticTexts["series-detail-guide-state-title"]

        let retryButton = app.buttons["series-detail-guide-retry"]
        XCTAssertTrue(retryButton.exists)
        for _ in 0..<4 where !retryButton.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(retryButton.isHittable)
        XCTAssertGreaterThanOrEqual(retryButton.frame.height, 44)
        XCTAssertLessThan(failureTitle.frame.maxY, failureDetail.frame.minY)
        XCTAssertLessThan(failureDetail.frame.maxY, retryButton.frame.minY)
        XCTAssertEqual(failureDetail.frame.minX, retryButton.frame.minX, accuracy: 2)
        XCTAssertFalse(failureDetail.frame.intersects(retryButton.frame))
        retryButton.tap()

        XCTAssertTrue(app.buttons["series-detail-episode-1-2-set-progress"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testEmptyEpisodeGuideUsesCompactInformationalStateWithoutRetry() throws {
        continueAfterFailure = false
        let app = makeApp(environment: [
            "SERIESAV_UI_TESTS_SAMPLE_LIBRARY": "1",
            "SERIESAV_UI_TESTS_INITIAL_TAB": "home",
            "SERIESAV_UI_TESTS_EPISODE_GUIDE": "empty"
        ])
        app.launch()

        let detailButton = app.buttons["Current Series"].firstMatch
        XCTAssertTrue(detailButton.waitForExistence(timeout: 10))
        detailButton.tap()

        let guideState = app.otherElements["series-detail-guide-state"]
        XCTAssertTrue(guideState.waitForExistence(timeout: 10))
        XCTAssertLessThan(guideState.frame.height, 80)
        XCTAssertTrue(app.staticTexts["Esta serie todavía no tiene una guía fiable."].exists)
        XCTAssertFalse(app.buttons["series-detail-guide-retry"].exists)
    }

    @MainActor
    func testEmptyEpisodeGuideStacksMessageAtAccessibilityTextSize() throws {
        continueAfterFailure = false
        let app = makeApp(
            environment: [
                "SERIESAV_UI_TESTS_SAMPLE_LIBRARY": "1",
                "SERIESAV_UI_TESTS_INITIAL_TAB": "home",
                "SERIESAV_UI_TESTS_EPISODE_GUIDE": "empty"
            ],
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL"
        )
        app.launch()

        let detailButton = app.buttons["Current Series"].firstMatch
        XCTAssertTrue(detailButton.waitForExistence(timeout: 10))
        detailButton.tap()

        let guideState = app.otherElements["series-detail-guide-state"]
        let title = app.staticTexts["series-detail-guide-state-title"]
        let detail = app.staticTexts["series-detail-guide-state-detail"]
        XCTAssertTrue(guideState.waitForExistence(timeout: 10))
        XCTAssertTrue(title.exists)
        XCTAssertTrue(detail.exists)
        XCTAssertEqual(title.label, "Guía no disponible")
        XCTAssertEqual(detail.label, "Esta serie todavía no tiene una guía fiable.")
        XCTAssertLessThan(title.frame.maxY, detail.frame.minY)
        XCTAssertEqual(title.frame.minX, detail.frame.minX, accuracy: 2)
        XCTAssertFalse(title.frame.intersects(detail.frame))
        XCTAssertGreaterThan(title.frame.height, 20)
        XCTAssertGreaterThan(detail.frame.height, 40)
        XCTAssertLessThan(guideState.frame.height, 260)
        XCTAssertFalse(app.buttons["series-detail-guide-retry"].exists)
        for _ in 0..<6 where !title.isHittable || !detail.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(title.isHittable)
        XCTAssertTrue(detail.isHittable)
    }

    @MainActor
    func testEmptyPrivateNoteUsesCompactAddRowAndExpandsAfterSaving() throws {
        continueAfterFailure = false
        let app = makeApp(environment: [
            "SERIESAV_UI_TESTS_SAMPLE_LIBRARY": "1",
            "SERIESAV_UI_TESTS_INITIAL_TAB": "home",
            "SERIESAV_UI_TESTS_EPISODE_GUIDE": "empty"
        ])
        app.launch()

        let detailButton = app.buttons["Current Series"].firstMatch
        XCTAssertTrue(detailButton.waitForExistence(timeout: 10))
        detailButton.tap()

        let addNoteButton = app.buttons["series-detail-private-note-add"]
        XCTAssertTrue(addNoteButton.waitForExistence(timeout: 10))
        for _ in 0..<4 where !addNoteButton.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(addNoteButton.isHittable)
        XCTAssertEqual(addNoteButton.label, "Añadir nota privada")
        XCTAssertGreaterThanOrEqual(addNoteButton.frame.height, 44)
        XCTAssertLessThan(addNoteButton.frame.height, 70)
        addNoteButton.tap()

        let editor = app.textViews["series-private-note-editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("Ver el final con Ana")
        app.buttons["Guardar"].tap()

        let savedNote = app.staticTexts["series-detail-private-note-body"]
        XCTAssertTrue(savedNote.waitForExistence(timeout: 5))
        XCTAssertEqual(savedNote.label, "Ver el final con Ana")
        XCTAssertFalse(app.buttons["series-detail-private-note-add"].exists)
        let editNoteButton = app.buttons["series-detail-private-note-edit"]
        XCTAssertTrue(editNoteButton.isHittable)
        XCTAssertGreaterThanOrEqual(editNoteButton.frame.width, 44)
        XCTAssertGreaterThanOrEqual(editNoteButton.frame.height, 44)
    }

    @MainActor
    func testEmptyPrivateNoteAddRowRemainsUsableWithAccessibilityTextSize() throws {
        continueAfterFailure = false
        let app = makeApp(
            environment: [
                "SERIESAV_UI_TESTS_SAMPLE_LIBRARY": "1",
                "SERIESAV_UI_TESTS_INITIAL_TAB": "home",
                "SERIESAV_UI_TESTS_EPISODE_GUIDE": "empty"
            ],
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL"
        )
        app.launch()

        let detailButton = app.buttons["Current Series"].firstMatch
        XCTAssertTrue(detailButton.waitForExistence(timeout: 10))
        detailButton.tap()

        let addNoteButton = app.buttons["series-detail-private-note-add"]
        XCTAssertTrue(addNoteButton.waitForExistence(timeout: 10))
        for _ in 0..<6 where !addNoteButton.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(addNoteButton.isHittable)
        XCTAssertEqual(addNoteButton.label, "Añadir nota privada")
        XCTAssertGreaterThanOrEqual(addNoteButton.frame.height, 44)
        XCTAssertGreaterThan(addNoteButton.frame.height, 70)
        XCTAssertLessThan(addNoteButton.frame.height, 140)
        XCTAssertGreaterThan(addNoteButton.frame.width, app.frame.width - 100)
        addNoteButton.tap()

        let editor = app.textViews["series-private-note-editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("Ver el final con Ana")
        app.buttons["Guardar"].tap()

        let savedNote = app.staticTexts["series-detail-private-note-body"]
        XCTAssertTrue(savedNote.waitForExistence(timeout: 5))
        XCTAssertEqual(savedNote.label, "Ver el final con Ana")
        XCTAssertGreaterThan(savedNote.frame.height, 30)

        let editNoteButton = app.buttons["series-detail-private-note-edit"]
        XCTAssertTrue(editNoteButton.isHittable)
        XCTAssertGreaterThanOrEqual(editNoteButton.frame.width, 44)
        XCTAssertGreaterThanOrEqual(editNoteButton.frame.height, 44)
        XCTAssertLessThan(editNoteButton.frame.width, 70)
        XCTAssertLessThan(editNoteButton.frame.height, 70)
    }

    @MainActor
    func testGuideFeedbackIsIntegratedInEpisodeCardAndShowsStatusOnlyAfterSending() throws {
        continueAfterFailure = false
        let app = makeApp(environment: [
            "SERIESAV_UI_TESTS_SAMPLE_LIBRARY": "1",
            "SERIESAV_UI_TESTS_INITIAL_TAB": "home",
            "SERIESAV_UI_TESTS_EPISODE_GUIDE": "empty",
            "SERIESAV_UI_TESTS_GUIDE_FEEDBACK": "sent"
        ])
        app.launch()

        let detailButton = app.buttons["Current Series"].firstMatch
        XCTAssertTrue(detailButton.waitForExistence(timeout: 10))
        detailButton.tap()

        let feedbackButton = app.buttons["series-detail-guide-feedback"]
        XCTAssertTrue(feedbackButton.waitForExistence(timeout: 10))
        for _ in 0..<6 where !feedbackButton.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(feedbackButton.isHittable)
        XCTAssertEqual(feedbackButton.label, "Reportar guía")
        XCTAssertGreaterThanOrEqual(feedbackButton.frame.height, 44)
        XCTAssertLessThan(feedbackButton.frame.height, 70)
        let unavailableTitle = app.staticTexts["Guía no disponible"]
        XCTAssertTrue(unavailableTitle.exists)
        XCTAssertLessThan(feedbackButton.frame.minY - unavailableTitle.frame.maxY, 100)
        XCTAssertFalse(app.staticTexts["Recibido. Lo usaremos para priorizar el enriquecimiento de esta serie."].exists)
        feedbackButton.tap()

        let status = app.staticTexts["series-detail-guide-feedback-status"]
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        XCTAssertEqual(feedbackButton.label, "Reportado")
        XCTAssertFalse(feedbackButton.isEnabled)
        XCTAssertEqual(status.label, "Recibido. Lo usaremos para priorizar el enriquecimiento de esta serie.")
        XCTAssertGreaterThanOrEqual(status.frame.minX, feedbackButton.frame.minX + 36)
        XCTAssertLessThan(feedbackButton.frame.maxY, status.frame.minY)
    }

    @MainActor
    func testGuideFeedbackCompactRowRemainsUsableWithAccessibilityTextSize() throws {
        continueAfterFailure = false
        let app = makeApp(
            environment: [
                "SERIESAV_UI_TESTS_SAMPLE_LIBRARY": "1",
                "SERIESAV_UI_TESTS_INITIAL_TAB": "home",
                "SERIESAV_UI_TESTS_EPISODE_GUIDE": "empty",
                "SERIESAV_UI_TESTS_GUIDE_FEEDBACK": "failed"
            ],
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL"
        )
        app.launch()

        let detailButton = app.buttons["Current Series"].firstMatch
        XCTAssertTrue(detailButton.waitForExistence(timeout: 10))
        detailButton.tap()

        let feedbackButton = app.buttons["series-detail-guide-feedback"]
        XCTAssertTrue(feedbackButton.waitForExistence(timeout: 10))
        for _ in 0..<8 where !feedbackButton.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(feedbackButton.isHittable)
        XCTAssertEqual(feedbackButton.label, "Reportar guía")
        XCTAssertGreaterThanOrEqual(feedbackButton.frame.height, 44)
        XCTAssertGreaterThan(feedbackButton.frame.height, 70)
        XCTAssertLessThan(feedbackButton.frame.height, 140)
        XCTAssertGreaterThan(feedbackButton.frame.width, app.frame.width - 100)
        feedbackButton.tap()

        let status = app.staticTexts["series-detail-guide-feedback-status"]
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        XCTAssertEqual(status.label, "No se pudo enviar. Inténtalo de nuevo.")
        XCTAssertGreaterThan(status.frame.height, 20)
        XCTAssertEqual(status.frame.minX, feedbackButton.frame.minX, accuracy: 2)
        XCTAssertLessThan(feedbackButton.frame.maxY, status.frame.minY)
        XCTAssertFalse(feedbackButton.frame.intersects(status.frame))
        XCTAssertEqual(feedbackButton.label, "Reportar guía")
        XCTAssertTrue(feedbackButton.isEnabled)
    }

    @MainActor
    func testEpisodeGuideRemainderRemainsReadableWithAccessibilityTextSize() throws {
        continueAfterFailure = false
        let app = makeApp(
            environment: [
                "SERIESAV_UI_TESTS_HIGH_SEASON_LIBRARY": "1",
                "SERIESAV_UI_TESTS_INITIAL_TAB": "home"
            ],
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL"
        )
        app.launch()

        let detailButton = app.buttons["Re: ZERO, Starting Life in Another World"].firstMatch
        XCTAssertTrue(detailButton.waitForExistence(timeout: 10))
        detailButton.tap()

        let remainder = app.staticTexts["series-detail-episodes-more"]
        XCTAssertTrue(remainder.waitForExistence(timeout: 10))
        for _ in 0..<20 where !remainder.isHittable {
            app.swipeUp()
        }

        XCTAssertTrue(remainder.isHittable)
        XCTAssertEqual(remainder.label, "71 episodios más")
        XCTAssertGreaterThan(remainder.frame.height, 20)
        XCTAssertLessThan(remainder.frame.height, 60)
        XCTAssertGreaterThanOrEqual(remainder.frame.minX, app.frame.minX + 16)
        XCTAssertLessThanOrEqual(remainder.frame.maxX, app.frame.maxX - 16)

        let feedbackButton = app.buttons["series-detail-guide-feedback"]
        XCTAssertTrue(feedbackButton.exists)
        XCTAssertLessThan(remainder.frame.maxY, feedbackButton.frame.minY)
        XCTAssertFalse(remainder.frame.intersects(feedbackButton.frame))
    }

    @MainActor
    func testSecondaryOptionsGroupsSourcesAndManagementMenus() throws {
        continueAfterFailure = false
        let app = makeApp(environment: [
            "SERIESAV_UI_TESTS_SAMPLE_LIBRARY": "1",
            "SERIESAV_UI_TESTS_INITIAL_TAB": "home",
            "SERIESAV_UI_TESTS_EPISODE_GUIDE": "empty"
        ])
        app.launch()

        let detailButton = app.buttons["Current Series"].firstMatch
        XCTAssertTrue(detailButton.waitForExistence(timeout: 10))
        detailButton.tap()

        let sourcesMenu = app.buttons["series-detail-sources-menu"]
        XCTAssertTrue(sourcesMenu.waitForExistence(timeout: 10))
        for _ in 0..<6 where !sourcesMenu.isHittable {
            app.swipeUp()
        }
        let secondaryOptions = app.otherElements["series-detail-secondary-options"]
        let managementMenu = app.buttons["series-detail-management-menu"]
        XCTAssertTrue(secondaryOptions.exists)
        XCTAssertTrue(app.staticTexts["Más opciones"].exists)
        XCTAssertTrue(managementMenu.exists)
        XCTAssertTrue(secondaryOptions.frame.contains(sourcesMenu.frame))
        XCTAssertTrue(secondaryOptions.frame.contains(managementMenu.frame))
        XCTAssertLessThan(managementMenu.frame.minY - sourcesMenu.frame.maxY, 12)
        XCTAssertTrue(sourcesMenu.isHittable)
        XCTAssertEqual(sourcesMenu.label, "Abrir fuente")
        XCTAssertEqual(managementMenu.label, "Gestionar serie")
        XCTAssertGreaterThanOrEqual(sourcesMenu.frame.height, 44)
        XCTAssertLessThan(sourcesMenu.frame.height, 70)
        sourcesMenu.tap()

        XCTAssertTrue(app.buttons["IMDb"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Wikipedia"].exists)
        XCTAssertTrue(app.buttons["Buscar en web"].exists)
    }

    @MainActor
    func testSeriesDetailUsesWidePagePresentationOnIPad() throws {
        continueAfterFailure = false
        let app = makeApp(environment: [
            "SERIESAV_UI_TESTS_SAMPLE_LIBRARY": "1",
            "SERIESAV_UI_TESTS_INITIAL_TAB": "home",
            "SERIESAV_UI_TESTS_EPISODE_GUIDE": "empty"
        ])
        app.launch()

        guard app.frame.width > 600 else {
            throw XCTSkip("This presentation check only applies to iPad.")
        }

        let detailButton = app.buttons["Current Series"].firstMatch
        XCTAssertTrue(detailButton.waitForExistence(timeout: 10))
        detailButton.tap()

        let detailScroll = app.scrollViews["series-detail-scroll"]
        XCTAssertTrue(detailScroll.waitForExistence(timeout: 10))
        XCTAssertGreaterThan(detailScroll.frame.width, app.frame.width * 0.75)

        let trackingTitle = app.staticTexts["Seguimiento"]
        let episodesTitle = app.staticTexts["Episodios"]
        XCTAssertTrue(trackingTitle.exists)
        XCTAssertTrue(episodesTitle.exists)
        XCTAssertGreaterThan(abs(episodesTitle.frame.midX - trackingTitle.frame.midX), 160)
    }

    @MainActor
    func testSourcesCompactMenuRemainsUsableWithAccessibilityTextSize() throws {
        continueAfterFailure = false
        let app = makeApp(
            environment: [
                "SERIESAV_UI_TESTS_SAMPLE_LIBRARY": "1",
                "SERIESAV_UI_TESTS_INITIAL_TAB": "home",
                "SERIESAV_UI_TESTS_EPISODE_GUIDE": "empty"
            ],
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL"
        )
        app.launch()

        let detailButton = app.buttons["Current Series"].firstMatch
        XCTAssertTrue(detailButton.waitForExistence(timeout: 10))
        detailButton.tap()

        let sourcesMenu = app.buttons["series-detail-sources-menu"]
        XCTAssertTrue(sourcesMenu.waitForExistence(timeout: 10))
        for _ in 0..<8 where !sourcesMenu.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(sourcesMenu.isHittable)
        XCTAssertEqual(sourcesMenu.label, "Abrir fuente")
        XCTAssertGreaterThanOrEqual(sourcesMenu.frame.height, 44)
        XCTAssertGreaterThan(sourcesMenu.frame.height, 70)
        XCTAssertLessThan(sourcesMenu.frame.height, 140)
        XCTAssertGreaterThan(sourcesMenu.frame.width, app.frame.width - 100)

        let managementMenu = app.buttons["series-detail-management-menu"]
        XCTAssertTrue(managementMenu.exists)
        XCTAssertEqual(managementMenu.label, "Gestionar serie")
        XCTAssertEqual(sourcesMenu.frame.height, managementMenu.frame.height, accuracy: 2)
        XCTAssertEqual(sourcesMenu.frame.width, managementMenu.frame.width, accuracy: 2)
        XCTAssertLessThan(sourcesMenu.frame.maxY, managementMenu.frame.minY)
        XCTAssertFalse(sourcesMenu.frame.intersects(managementMenu.frame))
        sourcesMenu.tap()

        XCTAssertTrue(app.buttons["IMDb"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Wikipedia"].exists)
        XCTAssertTrue(app.buttons["Buscar en web"].exists)
    }

    @MainActor
    func testLibraryManagementUsesCompactMenuAndKeepsDeleteConfirmation() throws {
        continueAfterFailure = false
        let app = makeApp(environment: [
            "SERIESAV_UI_TESTS_SAMPLE_LIBRARY": "1",
            "SERIESAV_UI_TESTS_INITIAL_TAB": "home",
            "SERIESAV_UI_TESTS_EPISODE_GUIDE": "empty"
        ])
        app.launch()

        let detailButton = app.buttons["Current Series"].firstMatch
        XCTAssertTrue(detailButton.waitForExistence(timeout: 10))
        detailButton.tap()

        let managementMenu = app.buttons["series-detail-management-menu"]
        XCTAssertTrue(managementMenu.waitForExistence(timeout: 10))
        for _ in 0..<6 where !managementMenu.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(managementMenu.isHittable)
        XCTAssertGreaterThanOrEqual(managementMenu.frame.height, 44)
        XCTAssertLessThan(managementMenu.frame.height, 70)
        managementMenu.tap()

        XCTAssertTrue(app.buttons["Archivar serie"].waitForExistence(timeout: 5))
        let deleteButton = app.buttons["Eliminar serie"]
        XCTAssertTrue(deleteButton.exists)
        deleteButton.tap()

        XCTAssertTrue(app.staticTexts["La serie saldrá de tu biblioteca local. Podrás deshacerlo justo después."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Eliminar serie"].exists)
    }

    @MainActor
    func testLibraryManagementCompactMenuRemainsUsableWithAccessibilityTextSize() throws {
        continueAfterFailure = false
        let app = makeApp(
            environment: [
                "SERIESAV_UI_TESTS_SAMPLE_LIBRARY": "1",
                "SERIESAV_UI_TESTS_INITIAL_TAB": "home",
                "SERIESAV_UI_TESTS_EPISODE_GUIDE": "empty"
            ],
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL"
        )
        app.launch()

        let detailButton = app.buttons["Current Series"].firstMatch
        XCTAssertTrue(detailButton.waitForExistence(timeout: 10))
        detailButton.tap()

        let managementMenu = app.buttons["series-detail-management-menu"]
        XCTAssertTrue(managementMenu.waitForExistence(timeout: 10))
        for _ in 0..<8 where !managementMenu.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(managementMenu.isHittable)
        XCTAssertEqual(managementMenu.label, "Gestionar serie")
        XCTAssertGreaterThanOrEqual(managementMenu.frame.height, 44)
        XCTAssertGreaterThan(managementMenu.frame.height, 70)
        XCTAssertLessThan(managementMenu.frame.height, 140)
        XCTAssertGreaterThan(managementMenu.frame.width, app.frame.width - 100)
        managementMenu.tap()

        XCTAssertTrue(app.buttons["Archivar serie"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Eliminar serie"].exists)
    }

    @MainActor
    func testHighSeasonDetailFocusesEpisodeGuideAroundCurrentProgress() throws {
        continueAfterFailure = false
        let app = makeApp(environment: [
            "SERIESAV_UI_TESTS_HIGH_SEASON_LIBRARY": "1",
            "SERIESAV_UI_TESTS_INITIAL_TAB": "home"
        ])
        app.launch()

        XCTAssertTrue(app.staticTexts["Re: ZERO, Starting Life in Another World"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Siguiente S4 E6"].exists)
        XCTAssertTrue(app.buttons["Marcar S4 E6 visto"].exists)

        let detailButton = app.buttons["Re: ZERO, Starting Life in Another World"].firstMatch
        XCTAssertTrue(detailButton.waitForExistence(timeout: 5))
        detailButton.tap()

        XCTAssertTrue(app.staticTexts["Seguimiento"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["S4 E5 · Siguiente S4 E6"].exists)
        XCTAssertLessThan(app.staticTexts["Seguimiento"].frame.minY, app.staticTexts["Episodios"].frame.minY)
        XCTAssertLessThan(app.staticTexts["Episodios"].frame.minY, app.staticTexts["Más opciones"].frame.minY)

        let currentEpisodeButton = app.buttons["series-detail-episode-4-5-set-progress"]
        let nextEpisodeButton = app.buttons["series-detail-episode-4-6-set-progress"]
        let firstEpisodeButton = app.buttons["series-detail-episode-1-1-set-progress"]

        for _ in 0..<8 where !currentEpisodeButton.exists && !firstEpisodeButton.exists {
            app.swipeUp()
        }

        XCTAssertTrue(app.staticTexts["Episodios"].exists)
        XCTAssertTrue(currentEpisodeButton.exists)
        XCTAssertTrue(nextEpisodeButton.exists)
        XCTAssertFalse(firstEpisodeButton.exists)
        XCTAssertTrue(app.staticTexts["Último visto"].exists)
        XCTAssertTrue(app.staticTexts["Siguiente"].exists)
    }

    @MainActor
    func testSampleDetailReadySeriesUsesStartAction() throws {
        continueAfterFailure = false
        let app = makeApp(environment: [
            "SERIESAV_UI_TESTS_SAMPLE_LIBRARY": "1",
            "SERIESAV_UI_TESTS_INITIAL_TAB": "search"
        ])
        app.launch()

        XCTAssertTrue(app.staticTexts["Buscar series"].waitForExistence(timeout: 10))
        app.textFields["Buscar por título"].tap()
        app.textFields["Buscar por título"].typeText("Later")
        XCTAssertTrue(app.staticTexts["Later List"].waitForExistence(timeout: 5))
        app.buttons["Later List"].tap()

        XCTAssertTrue(app.staticTexts["Seguimiento"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Empezar S1 E1"].exists)
        XCTAssertFalse(app.buttons["Marcar S1 E1 visto"].exists)
        XCTAssertTrue(app.buttons["Ajustar episodio"].exists)
    }

    @MainActor
    func testLocalizedHomeSearchAndLibraryRenderWithLargeDynamicType() throws {
        continueAfterFailure = false

        for configuration in localeSmokeConfigurations {
            let app = makeApp(
                language: configuration.language,
                locale: configuration.locale,
                contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL"
            )
            app.launch()

            XCTAssertTrue(app.staticTexts[configuration.homeTitle].waitForExistence(timeout: 10))

            app.buttons[configuration.searchTab].tap()
            XCTAssertTrue(app.staticTexts[configuration.searchTitle].waitForExistence(timeout: 10))

            app.buttons[configuration.libraryTab].tap()
            XCTAssertTrue(app.staticTexts[configuration.libraryTitle].waitForExistence(timeout: 10))

            app.terminate()
        }
    }

    @MainActor
    func testLocalizedAccountAndPaywallRenderWithLargeDynamicType() throws {
        continueAfterFailure = false

        for configuration in localeSmokeConfigurations {
            let paywallApp = makeApp(
                environment: [
                    "SERIESAV_UI_TESTS_SHOW_PAYWALL": "1"
                ],
                language: configuration.language,
                locale: configuration.locale,
                contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL"
            )
            paywallApp.launch()
            XCTAssertTrue(paywallApp.staticTexts[configuration.paywallTitle].waitForExistence(timeout: 10))
            paywallApp.terminate()

            let accountApp = makeApp(
                environment: [
                    "SERIESAV_UI_TESTS_FORCE_GUEST": "0",
                    "SERIESAV_UI_TESTS_ACCOUNT_MODE": "pro",
                    "SERIESAV_UI_TESTS_INITIAL_CHROME": "account"
                ],
                language: configuration.language,
                locale: configuration.locale,
                contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL"
            )
            accountApp.launch()
            XCTAssertTrue(accountApp.staticTexts[configuration.accountTitle].waitForExistence(timeout: 10))
            XCTAssertTrue(accountApp.staticTexts["Series AV Pro"].exists)
            accountApp.terminate()
        }
    }
}
