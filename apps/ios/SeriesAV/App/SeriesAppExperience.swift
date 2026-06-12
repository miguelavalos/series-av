import AVBrandFoundation
import AVSettingsFoundation
import Foundation

enum SeriesAppExperience {
    private static let appIdentity = AVAppIdentity(
        displayName: "Series AV",
        assistantName: "Avi",
        accountName: "Account AV"
    )

    @MainActor
    static var experience: AVCommonAppExperience {
        AVCommonAppExperience(
            identity: appIdentity,
            legalLinks: legalLinks,
            brandPalette: .standard,
            splashTagline: L10n.string("app.splash.tagline"),
            splashStatus: L10n.string("app.splash.status"),
            onboardingTitle: L10n.string("app.onboarding.title"),
            onboardingSubtitle: L10n.string("app.onboarding.subtitle"),
            onboardingPrimaryTitle: L10n.string("app.onboarding.signIn"),
            onboardingSecondaryTitle: L10n.string("app.onboarding.skip"),
            onboardingBackgroundStart: .init(red: 0.95, green: 0.97, blue: 0.99),
            onboardingBackgroundMid: AVBrandColor.neutral50,
            onboardingBackgroundEnd: .init(red: 0.92, green: 0.95, blue: 0.91)
        )
    }

    static var identity: AVAppIdentity {
        appIdentity
    }

    @MainActor
    static var legalLinks: AVAppLegalLinks {
        AVAppLegalLinks(
            supportURL: AppConfig.supportURL,
            privacyURL: AppConfig.privacyURL,
            termsURL: AppConfig.termsURL,
            accountDeletionURL: AppConfig.accountDeletionURL
        )
    }
}
