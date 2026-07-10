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
    func testFollowCatalogSeriesFromSearchAppearsInLibraryAndHome() throws {
        continueAfterFailure = false
        let app = makeApp()
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
        XCTAssertTrue(app.staticTexts["Seguimiento"].exists)
        XCTAssertTrue(app.staticTexts["Episodios"].exists)
        let summaryToggle = app.buttons["series-detail-summary-toggle"]
        XCTAssertTrue(summaryToggle.waitForExistence(timeout: 5))
        XCTAssertEqual(summaryToggle.label, "Ver más")
        summaryToggle.tap()
        XCTAssertEqual(summaryToggle.label, "Ver menos")
        summaryToggle.tap()
        XCTAssertEqual(summaryToggle.label, "Ver más")
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
        XCTAssertTrue(app.staticTexts["Siguiente S1 E1"].exists)
        XCTAssertTrue(app.buttons["Empezar, S1 E1"].exists)
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label == %@", "The Last of Us")).count, 1)
        XCTAssertFalse(app.staticTexts["Sigue tu primera serie"].exists)
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
        let summaryToggle = app.buttons["series-detail-summary-toggle"]
        XCTAssertTrue(summaryToggle.waitForExistence(timeout: 5))
        XCTAssertTrue(summaryToggle.isHittable)
        XCTAssertEqual(summaryToggle.label, "Ver más")

        summaryToggle.tap()
        XCTAssertEqual(summaryToggle.label, "Ver menos")
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
    func testInitialOnboardingExpandedAuthOptions() throws {
        continueAfterFailure = false
        let app = makeApp(environment: [
            "SERIESAV_UI_TESTS_FORCE_GUEST": "0",
            "SERIESAV_UI_TESTS_ACCOUNT_MODE": "guest_available",
            "SERIESAV_UI_TESTS_SHOW_ONBOARDING": "1",
            "SERIESAV_UI_TESTS_SHOW_AUTH_OPTIONS": "1"
        ])
        app.launch()

        XCTAssertTrue(app.staticTexts["Conecta tu cuenta"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Usa tu cuenta AV para gestionar tu acceso Pro."].exists)
        XCTAssertTrue(app.buttons["series.onboarding.auth.apple"].exists)
        XCTAssertTrue(app.buttons["series.onboarding.auth.google"].exists)
        XCTAssertTrue(app.buttons["Omitir por ahora"].exists)
        XCTAssertTrue(app.staticTexts["Al continuar, aceptas los Términos y la Política de privacidad de Series AV."].exists)
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
    func testHomeOnlyShowsBottomBarWhileUndoIsPending() throws {
        continueAfterFailure = false
        let app = makeApp(environment: [
            "SERIESAV_UI_TESTS_SAMPLE_LIBRARY": "1",
            "SERIESAV_UI_TESTS_INITIAL_TAB": "home"
        ])
        app.launch()

        let primaryAction = app.buttons["Marcar S1 E3 visto"]
        let undoBar = app.otherElements["series.undo.bar"]
        XCTAssertTrue(primaryAction.waitForExistence(timeout: 10))
        XCTAssertFalse(undoBar.exists)

        primaryAction.tap()

        XCTAssertTrue(undoBar.waitForExistence(timeout: 5))
        XCTAssertTrue(undoBar.buttons["Deshacer"].exists)
        XCTAssertTrue(undoBar.buttons["Cerrar"].exists)
        XCTAssertGreaterThanOrEqual(undoBar.frame.height, 44)
        undoBar.buttons["Cerrar"].tap()
        XCTAssertFalse(undoBar.waitForExistence(timeout: 1))
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
        let primaryAction = app.buttons["series-detail-tracking-primary"]
        let adjustAction = app.buttons["series-detail-tracking-adjust"]
        let pinAction = app.buttons["series-detail-tracking-pin"]
        XCTAssertTrue(primaryAction.isHittable)
        XCTAssertTrue(adjustAction.isHittable)
        XCTAssertTrue(pinAction.isHittable)
        XCTAssertFalse(primaryAction.frame.intersects(adjustAction.frame))
        XCTAssertFalse(primaryAction.frame.intersects(pinAction.frame))
        XCTAssertFalse(adjustAction.frame.intersects(pinAction.frame))
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

        let retryButton = app.buttons["series-detail-guide-retry"]
        XCTAssertTrue(retryButton.exists)
        for _ in 0..<4 where !retryButton.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(retryButton.isHittable)
        XCTAssertGreaterThanOrEqual(retryButton.frame.height, 44)
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
        XCTAssertGreaterThanOrEqual(addNoteButton.frame.height, 44)
        XCTAssertLessThan(addNoteButton.frame.height, 70)
        addNoteButton.tap()

        let editor = app.textViews["series-private-note-editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("Ver el final con Ana")
        app.buttons["Guardar"].tap()

        XCTAssertTrue(app.staticTexts["Ver el final con Ana"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["series-detail-private-note-add"].exists)
        XCTAssertTrue(app.buttons["series-detail-private-note-edit"].isHittable)
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
        XCTAssertGreaterThanOrEqual(addNoteButton.frame.height, 44)
        addNoteButton.tap()

        XCTAssertTrue(app.textViews["series-private-note-editor"].waitForExistence(timeout: 5))
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
        XCTAssertGreaterThanOrEqual(feedbackButton.frame.height, 44)
        feedbackButton.tap()

        XCTAssertTrue(app.staticTexts["No se pudo enviar. Inténtalo de nuevo."].waitForExistence(timeout: 5))
        XCTAssertTrue(feedbackButton.isEnabled)
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
        XCTAssertGreaterThanOrEqual(sourcesMenu.frame.height, 44)
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
        XCTAssertGreaterThanOrEqual(managementMenu.frame.height, 44)
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
