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
        XCTAssertTrue(app.staticTexts["Populares"].exists)
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
    func testSampleDetailTrackingActionsUseVisibleActionLabels() throws {
        continueAfterFailure = false
        let app = makeApp(environment: [
            "SERIESAV_UI_TESTS_SAMPLE_LIBRARY": "1",
            "SERIESAV_UI_TESTS_INITIAL_TAB": "home"
        ])
        app.launch()

        XCTAssertTrue(app.staticTexts["Current Series"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Marcar S1 E3 visto"].exists)

        app.buttons["Acciones de serie"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Ver info"].waitForExistence(timeout: 5))
        app.buttons["Ver info"].tap()

        XCTAssertTrue(app.staticTexts["Seguimiento"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Marcar S1 E3 visto"].exists)
        XCTAssertTrue(app.buttons["Ajustar episodio"].exists)
        XCTAssertTrue(app.buttons["Quitar fijado"].exists)
        XCTAssertTrue(app.staticTexts["Episodios"].waitForExistence(timeout: 5))

        let setProgressButton = app.buttons["series-detail-episode-1-2-set-progress"]
        for _ in 0..<6 where !setProgressButton.exists {
            app.swipeUp()
        }
        XCTAssertTrue(setProgressButton.exists)
        XCTAssertTrue(app.staticTexts["Fijar"].exists)
        XCTAssertFalse(app.staticTexts["Guardar S1 E3"].exists)
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
