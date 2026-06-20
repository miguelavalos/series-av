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
            visualAssets: visualAssets,
            splashTagline: L10n.string("app.splash.tagline"),
            splashStatus: L10n.string("app.splash.status"),
            onboardingTitle: L10n.string("app.onboarding.title"),
            onboardingSubtitle: L10n.string("app.onboarding.subtitle"),
            onboardingPrimaryTitle: L10n.string("app.onboarding.signIn"),
            onboardingSecondaryTitle: L10n.string("app.onboarding.skip"),
            onboardingBackgroundStart: .init(red: 0.97, green: 0.94, blue: 0.86),
            onboardingBackgroundMid: AVBrandColor.neutral50,
            onboardingBackgroundEnd: .init(red: 0.9, green: 0.93, blue: 0.89)
        )
    }

    static var identity: AVAppIdentity {
        appIdentity
    }

    static var visualAssets: AVCommonAppVisualAssets {
        AVCommonAppVisualAssets(
            headerLogoName: "SeriesHeaderWordmark",
            splashLogoName: "SeriesAVLogo",
            splashHeroName: "SeriesSplashHero",
            onboardingBrandName: "SeriesOnboardingWordmark",
            onboardingHeroName: "SeriesOnboardingHero",
            onboardingCTACompanionName: "AviOnboardingCTA",
            onboardingAuthPanelCompanionName: "AviLoginSheetPeek",
            footerAssistantName: "AviFooterIcon"
        )
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
