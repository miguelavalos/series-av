import AVBrandFoundation
import AVSettingsFoundation
import SwiftUI

struct SeriesProCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.avBrandPalette) private var brandPalette

    let accessController: SeriesAccessController
    let isTabletLayout: Bool
    let showProPaywall: () -> Void
    let openSubscriptionManagement: () -> Void

    var body: some View {
        AVSettingsSectionCard(
            title: L10n.string("profile.pro.title"),
            subtitle: subtitle,
            spacing: usesCompactFreeLayout ? 12 : 18,
            padding: usesCompactFreeLayout ? 18 : 22
        ) {
            if accessController.accessMode == .signedInFree {
                actionButton
            }
            benefits
            if accessController.accessMode != .signedInFree {
                actionButton
            }
        }
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: isTabletLayout ? 18 : 10) {
            if isTabletLayout {
                benefitInfoRows
            } else {
                compactBenefitRow(
                    systemImage: "checkmark.seal.fill",
                    title: L10n.string("profile.pro.account.title"),
                    detail: L10n.string("profile.pro.account.detail")
                )
                compactBenefitRow(
                    systemImage: "rectangle.stack.badge.person.crop",
                    title: L10n.string("profile.pro.library.title"),
                    detail: L10n.string("profile.pro.library.detail")
                )
                compactBenefitRow(
                    systemImage: "sparkles",
                    title: L10n.string("profile.pro.avi.title"),
                    detail: L10n.string("profile.pro.avi.detail")
                )
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("profile.pro.benefits")
    }

    @ViewBuilder
    private var benefitInfoRows: some View {
        AVSettingsInfoRow(
            systemImage: "checkmark.seal.fill",
            title: L10n.string("profile.pro.account.title"),
            detail: L10n.string("profile.pro.account.detail")
        )
        AVSettingsInfoRow(
            systemImage: "rectangle.stack.badge.person.crop",
            title: L10n.string("profile.pro.library.title"),
            detail: L10n.string("profile.pro.library.detail")
        )
        AVSettingsInfoRow(
            systemImage: "sparkles",
            title: L10n.string("profile.pro.avi.title"),
            detail: L10n.string("profile.pro.avi.detail")
        )
    }

    private func compactBenefitRow(systemImage: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(brandPalette.accent)
                .frame(width: 18)
                .accessibilityHidden(true)
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AVBrandColor.textPrimary)
                    Text(detail)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AVBrandColor.textSecondary)
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                (
                    Text(title)
                        .fontWeight(.semibold)
                        .foregroundColor(AVBrandColor.textPrimary)
                    + Text(" · \(detail)")
                        .foregroundColor(AVBrandColor.textSecondary)
                )
                .font(.system(size: 13, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var actionButton: some View {
        switch accessController.accessMode {
        case .guest:
            EmptyView()
        case .signedInFree:
            tabletAlignedContent {
                AVSettingsButton(
                    title: L10n.string("profile.pro.upgrade"),
                    style: .primary,
                    action: showProPaywall
                )
            }
            .accessibilityIdentifier("profile.pro.upgrade")
        case .signedInPro:
            VStack(alignment: .leading, spacing: 12) {
                AVSettingsInfoRow(
                    systemImage: "checkmark.seal",
                    title: L10n.string("profile.pro.active.title"),
                    detail: L10n.string("profile.pro.active.detail")
                )
                tabletAlignedContent {
                    AVSettingsButton(
                        title: L10n.string("profile.pro.manage"),
                        style: .secondary,
                        action: openSubscriptionManagement
                    )
                }
                .accessibilityIdentifier("profile.pro.manage")
            }
        }
    }

    private func tabletAlignedContent<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: isTabletLayout ? 340 : .infinity, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var subtitle: String {
        switch accessController.accessMode {
        case .guest:
            accessController.accountIsAvailable
                ? L10n.string("profile.pro.subtitle.guest")
                : L10n.string("profile.pro.subtitle.unavailable")
        case .signedInFree: L10n.string("profile.pro.subtitle.free")
        case .signedInPro: L10n.string("profile.pro.subtitle.pro")
        }
    }

    private var usesCompactFreeLayout: Bool {
        accessController.accessMode == .signedInFree && !isTabletLayout
    }
}
