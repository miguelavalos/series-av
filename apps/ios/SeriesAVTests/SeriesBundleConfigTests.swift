import Foundation
import XCTest
@testable import SeriesAV

final class SeriesBundleConfigTests: XCTestCase {
    func testLocalizableStringsAreValidPropertyLists() throws {
        let resourcesURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("SeriesAV/Resources", isDirectory: true)

        let localizableURLs = try FileManager.default.contentsOfDirectory(
            at: resourcesURL,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension == "lproj" }
        .map { $0.appendingPathComponent("Localizable.strings") }
        .filter { FileManager.default.fileExists(atPath: $0.path) }

        XCTAssertFalse(localizableURLs.isEmpty, "Expected at least one Localizable.strings file.")

        for url in localizableURLs {
            let data = try Data(contentsOf: url)
            XCTAssertNoThrow(
                try PropertyListSerialization.propertyList(from: data, format: nil),
                "Invalid strings file: \(url.path)"
            )
        }
    }

    func testStringValueIgnoresMissingEmptyAndInheritedPlaceholders() {
        let bundle = BundleConfigFixture.bundle(values: [
            "Empty": "   ",
            "Inherited": "$(inherited)",
            "Configured": " https://series-av.avalsys.com "
        ])

        XCTAssertEqual(BundleConfig.stringValue(for: "Missing", in: bundle), "")
        XCTAssertNil(BundleConfig.nonEmptyStringValue(for: "Empty", in: bundle))
        XCTAssertNil(BundleConfig.nonEmptyStringValue(for: "Inherited", in: bundle))
        XCTAssertEqual(BundleConfig.stringValue(for: "Configured", in: bundle), "https://series-av.avalsys.com")
    }

    func testBoolValueParsesKnownValuesAndUsesFallbackForUnknownValues() {
        let bundle = BundleConfigFixture.bundle(values: [
            "Enabled": "enabled",
            "Disabled": "0",
            "Unknown": "maybe"
        ])

        XCTAssertTrue(BundleConfig.boolValue(for: "Enabled", in: bundle))
        XCTAssertFalse(BundleConfig.boolValue(for: "Disabled", in: bundle, default: true))
        XCTAssertTrue(BundleConfig.boolValue(for: "Unknown", in: bundle, default: true))
        XCTAssertFalse(BundleConfig.boolValue(for: "Missing", in: bundle))
    }

    func testDeleteAccountURLPrefersSeriesSpecificURLThenAccountURL() {
        let seriesURL = URL(string: "https://series-av.avalsys.com/delete-account")!
        let accountURL = URL(string: "https://account-av.avalsys.com/account/delete")!
        let managementURL = URL(string: "https://account-av.avalsys.com")!

        XCTAssertEqual(
            BundleConfig.deleteAccountURL(
                explicitURL: seriesURL,
                accountURL: accountURL,
                accountManagementURL: managementURL
            ),
            seriesURL
        )

        XCTAssertEqual(
            BundleConfig.deleteAccountURL(
                explicitURL: nil,
                accountURL: accountURL,
                accountManagementURL: managementURL
            ),
            accountURL
        )
    }

    func testDeleteAccountURLFallsBackToAccountManagementPath() {
        let managementURL = URL(string: "https://account-av.avalsys.com")!

        XCTAssertEqual(
            BundleConfig.deleteAccountURL(
                explicitURL: nil,
                accountURL: nil,
                accountManagementURL: managementURL
            )?.absoluteString,
            "https://account-av.avalsys.com/account/delete"
        )
    }

    @MainActor
    func testAccountServiceUITestGuestMatchesTuneTokenPolicy() {
        let guestEnvironment = SeriesUITestEnvironment(environment: [
            "SERIESAV_UI_TESTS": "1"
        ])
        let signedInEnvironment = SeriesUITestEnvironment(environment: [
            "SERIESAV_UI_TESTS": "1",
            "SERIESAV_UI_TESTS_ACCOUNT_MODE": "free"
        ])
        let guestAvailableEnvironment = SeriesUITestEnvironment(environment: [
            "SERIESAV_UI_TESTS": "1",
            "SERIESAV_UI_TESTS_ACCOUNT_MODE": "guest_available"
        ])

        XCTAssertTrue(DefaultSeriesAVAccountService.shouldUseGuestTokenForUITests(environment: guestEnvironment))
        XCTAssertFalse(DefaultSeriesAVAccountService.shouldUseGuestTokenForUITests(environment: signedInEnvironment))
        XCTAssertFalse(guestAvailableEnvironment.hasAccountOverride)
        XCTAssertTrue(guestAvailableEnvironment.shouldUseAvailableGuestAccount)
        XCTAssertTrue(DefaultSeriesAVAccountService.shouldUseGuestTokenForUITests(environment: guestAvailableEnvironment))
    }

    @MainActor
    func testAccountServiceUITestForceGuestDisablesAccountAvailability() {
        let forceGuestEnvironment = SeriesUITestEnvironment(environment: [
            "SERIESAV_UI_TESTS": "1",
            "SERIESAV_UI_TESTS_FORCE_GUEST": "1"
        ])

        XCTAssertTrue(DefaultSeriesAVAccountService.shouldForceGuestForUITests(environment: forceGuestEnvironment))
    }
}

private enum BundleConfigFixture {
    static func bundle(values: [String: String]) -> Bundle {
        let bundleURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("bundle")
        try! FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)
        NSDictionary(dictionary: values).write(to: bundleURL.appendingPathComponent("Info.plist"), atomically: true)
        return Bundle(url: bundleURL)!
    }
}
