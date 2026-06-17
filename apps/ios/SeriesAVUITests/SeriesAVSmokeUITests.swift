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
            homeTitle: "Segueix la primera serie",
            searchTab: "Cerca",
            searchTitle: "Cercar series",
            libraryTab: "Biblioteca",
            libraryTitle: "Biblioteca",
            accountTitle: "Compte",
            paywallTitle: "Segueix mes series"
        ),
        LocaleSmokeConfiguration(
            language: "fr",
            locale: "fr_FR",
            homeTitle: "Suivez votre premiere serie",
            searchTab: "Recherche",
            searchTitle: "Rechercher des series",
            libraryTab: "Bibliotheque",
            libraryTitle: "Bibliotheque",
            accountTitle: "Compte",
            paywallTitle: "Suivez plus de series"
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

        let firstInfoButton = app.buttons["Ver info"].firstMatch
        XCTAssertTrue(firstInfoButton.waitForExistence(timeout: 5))
        firstInfoButton.tap()
        XCTAssertTrue(app.staticTexts["Info de serie"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Seguimiento"].exists)
        XCTAssertTrue(app.staticTexts["Episodios"].exists)
        app.buttons["Cerrar"].tap()

        let firstFollowButton = app.buttons.matching(identifier: "plus").firstMatch
        XCTAssertTrue(firstFollowButton.waitForExistence(timeout: 5))
        firstFollowButton.tap()

        XCTAssertTrue(app.staticTexts["\"The Last of Us\" seguida"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Último episodio visto"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.staticTexts["Elige el último episodio visto. Los anteriores quedan vistos y los posteriores pendientes."]
                .waitForExistence(timeout: 10)
        )
        XCTAssertTrue(app.buttons["Episodio 1"].exists)
        XCTAssertTrue(app.buttons["Episodio 2"].exists)
        XCTAssertFalse(app.staticTexts["Añadir serie"].exists)

        app.buttons["Cancelar"].tap()
        XCTAssertTrue(app.buttons["Ajustar episodio"].waitForExistence(timeout: 5))

        app.buttons["Biblioteca"].tap()
        XCTAssertTrue(app.staticTexts["Todo · 1"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["The Last of Us"].exists)
        XCTAssertTrue(app.staticTexts["Por ver · Empezar por S1 E1"].exists)

        app.buttons["Inicio"].tap()
        XCTAssertTrue(app.staticTexts["Lista para empezar"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Siguiente S1 E1"].exists)
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label == %@", "The Last of Us")).count, 1)
        XCTAssertFalse(app.staticTexts["Sigue tu primera serie"].exists)
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
        XCTAssertFalse(
            staticText(
                matchingLabel: "Series AV Pro es una suscripción mensual con renovación automática. Se te cobrará 4,99 € por cada periodo de 1 mes hasta que canceles en los ajustes del App Store.",
                in: app
            ).exists
        )
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
        XCTAssertTrue(app.buttons["Fijar hasta S1 E2"].exists)
        XCTAssertTrue(app.buttons["Sin empezar"].exists)
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
