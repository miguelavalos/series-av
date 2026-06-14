import AVAviFoundation
import AVBrandFoundation
import AVPaywallFoundation
import SwiftUI

struct SeriesProPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    let accessController: SeriesAccessController
    let startSignInFlow: () -> Void

    var body: some View {
        AVPaywallSheetScaffold(
            navigationTitle: L10n.string("paywall.navigationTitle"),
            closeTitle: L10n.string("paywall.close"),
            backgroundStyle: AnyShapeStyle(AVBrandSurface.shellBackground),
            onClose: { dismiss() }
        ) {
            AVPaywallHeader(
                eyebrow: L10n.string("paywall.eyebrow"),
                title: L10n.string("paywall.title"),
                subtitle: L10n.string("paywall.subtitle")
            )

            AVPaywallOfferCard(
                title: L10n.string("paywall.scene.title"),
                detail: L10n.string("paywall.scene.detail"),
                primaryButtonTitle: primaryButtonTitle,
                primaryButtonIsDisabled: primaryButtonIsDisabled,
                primaryAccessibilityIdentifier: "paywall.purchase",
                primaryAction: primaryAction
            ) {
                proAvatar
            } restoreButton: {
                if accessController.isSignedIn {
                    AVPaywallRestoreButton(
                        title: restoreTitle,
                        isDisabled: accessController.isSubscriptionOperationInProgress
                    ) {
                        Task { await accessController.restorePurchases() }
                    }
                } else {
                    EmptyView()
                }
            }

            subscriptionTermsRow

            if accessController.isWaitingForSubscriptionReconciliation {
                AVPaywallStatusRow(systemImage: "clock.arrow.circlepath", message: reconciliationStatus)
            } else if let error = accessController.subscriptionError?.errorDescription {
                AVPaywallStatusRow(systemImage: "exclamationmark.triangle", message: error)
            }

            AVPaywallBenefitList(items: benefitItems)
            AVPaywallLegalLinks(links: legalLinkItems)
        }
        .task {
            await accessController.loadMonthlySubscriptionOffer()
        }
        .onChange(of: accessController.accessMode) { _, mode in
            if mode == .signedInPro {
                dismiss()
            }
        }
    }

    private var proAvatar: some View {
        AVAviAssetAvatarBadge(
            assetName: "AviOnboardingCTA",
            imageSize: 54,
            badgeSize: 68,
            padding: 7,
            backgroundStyle: .accentSoft,
            strokeStyle: .accentSoft
        )
    }

    @ViewBuilder
    private var subscriptionTermsRow: some View {
        if accessController.isSignedIn, let offer = accessController.subscriptionOffer {
            AVPaywallStatusRow(
                systemImage: "calendar.badge.clock",
                message: L10n.string("paywall.subscriptionTerms", offer.localizedPrice)
            )
            .accessibilityIdentifier("paywall.subscriptionTerms")
        }
    }

    private func primaryAction() {
        if accessController.isSignedIn {
            Task { await accessController.purchaseMonthlyPro() }
        } else {
            dismiss()
            startSignInFlow()
        }
    }

    private var primaryButtonTitle: String {
        guard accessController.isSignedIn else {
            return L10n.string("profile.pro.signIn")
        }
        if accessController.isSubscriptionOperationInProgress {
            return L10n.string("paywall.purchase.loading")
        }
        guard let offer = accessController.subscriptionOffer else {
            return L10n.string("paywall.purchase.loadingOffer")
        }
        return L10n.string("paywall.purchase.price", offer.localizedPrice)
    }

    private var primaryButtonIsDisabled: Bool {
        if !accessController.isSignedIn {
            return !accessController.accountIsAvailable
        }
        return accessController.isSubscriptionOperationInProgress || accessController.subscriptionOffer == nil
    }

    private var restoreTitle: String {
        accessController.isSubscriptionOperationInProgress
            ? L10n.string("paywall.restore.loading")
            : L10n.string("paywall.restore")
    }

    private var reconciliationStatus: String {
        switch accessController.subscriptionReconciliationSource {
        case .restore:
            L10n.string("paywall.status.restorePending")
        case .purchase, .none:
            L10n.string("paywall.status.purchasePending")
        }
    }

    private var benefitItems: [AVPaywallBenefitItem] {
        [
            AVPaywallBenefitItem(
                id: "sync",
                systemImage: "icloud",
                title: L10n.string("paywall.benefit.sync.title"),
                detail: L10n.string("paywall.benefit.sync")
            ),
            AVPaywallBenefitItem(
                id: "library",
                systemImage: "rectangle.stack.badge.person.crop",
                title: L10n.string("paywall.benefit.library.title"),
                detail: L10n.string("paywall.benefit.library")
            ),
            AVPaywallBenefitItem(
                id: "avi",
                systemImage: "sparkles",
                title: L10n.string("paywall.benefit.avi.title"),
                detail: L10n.string("paywall.benefit.avi")
            )
        ]
    }

    private var legalLinkItems: [AVPaywallLegalLink] {
        [
            AVPaywallLegalLink(title: L10n.string("paywall.terms"), accessibilityIdentifier: "paywall.terms") {
                openURL(AppConfig.termsURL)
            },
            AVPaywallLegalLink(title: L10n.string("paywall.privacy"), accessibilityIdentifier: "paywall.privacy") {
                openURL(AppConfig.privacyURL)
            }
        ]
    }
}
