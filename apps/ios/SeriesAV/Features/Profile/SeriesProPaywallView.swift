import AVAviFoundation
import AVBrandFoundation
import AVPaywallFoundation
import SwiftUI

struct SeriesProPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let accessController: SeriesAccessController
    let startSignInFlow: () -> Void

    @State private var isShowingRedeemCodeSheet = SeriesUITestEnvironment.current.shouldShowRedeemCodeSheet
    @State private var redeemCode = ""
    @State private var redeemStatusMessage: String?
    @State private var isRedeemingCode = false

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
                AVPaywallStatusRow(systemImage: "arrow.triangle.2.circlepath", message: reconciliationStatus)
            } else if let error = accessController.subscriptionError?.errorDescription {
                AVPaywallStatusRow(systemImage: "exclamationmark.triangle", message: error)
            }

            AVPaywallBenefitList(items: benefitItems)
            AVPaywallFooterActions(actions: footerActionItems)
        }
        .task {
            await accessController.loadMonthlySubscriptionOffer()
        }
        .sheet(isPresented: $isShowingRedeemCodeSheet) {
            redeemCodeSheet
        }
        .onChange(of: accessController.accessMode) { _, mode in
            if mode == .signedInPro {
                dismiss()
            }
        }
    }

    private var redeemCodeSheet: some View {
        NavigationStack {
            ScrollView {
                redeemCodeContent
                    .frame(maxWidth: 620)
                    .padding(dynamicTypeSize.isAccessibilitySize ? 20 : 24)
                    .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background {
                Rectangle()
                    .fill(AVBrandSurface.shellBackground)
                    .ignoresSafeArea()
            }
            .navigationTitle(L10n.string("paywall.promo.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("common.done")) {
                        isShowingRedeemCodeSheet = false
                    }
                    .accessibilityIdentifier("paywall.redeemCode.done")
                }
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.medium])
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("paywall.redeemCode.sheet")
    }

    private var redeemCodeContent: some View {
        VStack(alignment: .leading, spacing: AVBrandSpacing.sm) {
            sectionHeader(title: L10n.string("paywall.promo.title"), detail: L10n.string("paywall.promo.detail"))

            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: AVBrandSpacing.sm) {
                    redeemCodeField
                    redeemCodeClaimButton(showsLabel: true)
                }
            } else {
                HStack(spacing: AVBrandSpacing.sm) {
                    Image(systemName: "gift.fill")
                        .font(.body.weight(.black))
                        .foregroundStyle(AVBrandColor.accent)

                    redeemCodeField
                    redeemCodeClaimButton(showsLabel: false)
                }
            }

            Text(L10n.string("paywall.promo.optional"))
                .font(AVBrandTypography.captionStrong)
                .foregroundStyle(AVBrandColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let redeemStatusMessage {
                HStack(alignment: .firstTextBaseline, spacing: AVBrandSpacing.xs) {
                    Image(systemName: "info.circle.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AVBrandColor.textSecondary)

                    Text(redeemStatusMessage)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AVBrandColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 2)
                .accessibilityIdentifier("paywall.redeemCode.status")
            }
        }
        .padding(AVBrandSpacing.md)
        .background(AVBrandColor.mutedSurface, in: RoundedRectangle(cornerRadius: AVBrandRadius.card, style: .continuous))
    }

    private func sectionHeader(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline.weight(.black))
                .foregroundStyle(AVBrandColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("paywall.redeemCode.title")

            Text(detail)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AVBrandColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("paywall.redeemCode.detail")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var redeemCodeField: some View {
        TextField(L10n.string("paywall.promo.placeholder"), text: $redeemCode)
            .keyboardType(.asciiCapable)
            .textContentType(.oneTimeCode)
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
            .onChange(of: redeemCode) { _, newValue in
                let sanitized = sanitizedRedeemCodeInput(newValue)
                if sanitized != newValue {
                    redeemCode = sanitized
                }
            }
            .font(.body.weight(.semibold))
            .padding(.horizontal, AVBrandSpacing.md)
            .frame(minHeight: dynamicTypeSize.isAccessibilitySize ? 56 : 46)
            .background(AVBrandColor.cardSurface, in: RoundedRectangle(cornerRadius: AVBrandRadius.control, style: .continuous))
            .accessibilityIdentifier("paywall.redeemCode.field")
    }

    private func redeemCodeClaimButton(showsLabel: Bool) -> some View {
        Button(action: claimRedeemCode) {
            Group {
                if isRedeemingCode {
                    ProgressView()
                        .tint(AVBrandColor.textInverse)
                        .frame(maxWidth: showsLabel ? .infinity : nil)
                } else if showsLabel {
                    Label(L10n.string("paywall.promo.claim"), systemImage: "arrow.right")
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                } else {
                    Image(systemName: "arrow.right")
                        .font(.body.weight(.black))
                }
            }
            .foregroundStyle(AVBrandColor.textInverse)
            .frame(
                maxWidth: showsLabel ? .infinity : nil,
                minHeight: showsLabel ? 56 : 46
            )
            .frame(width: showsLabel ? nil : 46)
            .background(
                redeemButtonIsDisabled ? Color(.tertiarySystemFill) : AVBrandColor.accent,
                in: RoundedRectangle(cornerRadius: AVBrandRadius.control, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .disabled(redeemButtonIsDisabled)
        .accessibilityLabel(L10n.string("paywall.promo.claim"))
        .accessibilityIdentifier("paywall.redeemCode.claim")
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
        if accessController.isWaitingForSubscriptionReconciliation {
            return L10n.string("paywall.purchase.refreshingAccess")
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
        return accessController.isWaitingForSubscriptionReconciliation ||
            accessController.isSubscriptionOperationInProgress ||
            accessController.subscriptionOffer == nil
    }

    private var restoreTitle: String {
        accessController.isSubscriptionOperationInProgress
            ? L10n.string("paywall.restore.loading")
            : L10n.string("paywall.restore")
    }

    private var normalizedRedeemCode: String {
        redeemCode.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func sanitizedRedeemCodeInput(_ code: String) -> String {
        var sanitized = ""
        for character in code {
            switch character {
            case " ", "\n", "\t":
                continue
            case "\u{2010}", "\u{2011}", "\u{2012}", "\u{2013}", "\u{2014}", "\u{2015}", "\u{2212}", "\u{2018}", "\u{2019}":
                sanitized.append("-")
            case _ where isASCIIAlphanumeric(character) || character == "-" || character == "_":
                sanitized.append(character)
            default:
                continue
            }
        }
        return sanitized.uppercased()
    }

    private func isASCIIAlphanumeric(_ character: Character) -> Bool {
        guard character.unicodeScalars.count == 1,
              let value = character.unicodeScalars.first?.value else {
            return false
        }
        return (48...57).contains(value) || (65...90).contains(value) || (97...122).contains(value)
    }

    private var redeemButtonIsDisabled: Bool {
        normalizedRedeemCode.isEmpty ||
            isRedeemingCode ||
            accessController.isSubscriptionOperationInProgress
    }

    private var reconciliationStatus: String {
        switch accessController.subscriptionReconciliationSource {
        case .redeemCode:
            L10n.string("paywall.status.redeemingCode")
        case .restore:
            L10n.string("paywall.status.restorePending")
        case .purchase, .none:
            L10n.string("paywall.status.purchasePending")
        }
    }

    private var benefitItems: [AVPaywallBenefitItem] {
        [
            AVPaywallBenefitItem(
                id: "avi",
                systemImage: "sparkles",
                title: L10n.string("paywall.benefit.avi.title"),
                detail: L10n.string("paywall.benefit.avi")
            ),
            AVPaywallBenefitItem(
                id: "library",
                systemImage: "rectangle.stack.badge.person.crop",
                title: L10n.string("paywall.benefit.library.title"),
                detail: L10n.string("paywall.benefit.library")
            ),
            AVPaywallBenefitItem(
                id: "sync",
                systemImage: "icloud",
                title: L10n.string("paywall.benefit.sync.title"),
                detail: L10n.string("paywall.benefit.sync")
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

    private var footerActionItems: [AVPaywallFooterAction] {
        var actions = [
            AVPaywallFooterAction(
                title: L10n.string("paywall.redeemCode"),
                accessibilityIdentifier: "paywall.redeemCode",
                action: showRedeemCodeSheet
            )
        ]

        for link in legalLinkItems {
            actions.append(
                AVPaywallFooterAction(
                    title: link.title,
                    accessibilityIdentifier: link.accessibilityIdentifier,
                    action: link.action
                )
            )
        }

        return actions
    }

    private func showRedeemCodeSheet() {
        guard !accessController.isSubscriptionOperationInProgress else { return }
        if accessController.isSignedIn {
            redeemStatusMessage = nil
            isShowingRedeemCodeSheet = true
        } else {
            dismiss()
            startSignInFlow()
        }
    }

    private func claimRedeemCode() {
        let code = normalizedRedeemCode
        guard !code.isEmpty, !isRedeemingCode else { return }
        isRedeemingCode = true
        redeemStatusMessage = nil

        Task {
            do {
                try await accessController.claimPromotionCode(code)
                redeemStatusMessage = L10n.string("paywall.promo.claimed")
                redeemCode = ""
                isShowingRedeemCodeSheet = false
            } catch {
                redeemStatusMessage = error.localizedDescription
            }
            isRedeemingCode = false
        }
    }
}
