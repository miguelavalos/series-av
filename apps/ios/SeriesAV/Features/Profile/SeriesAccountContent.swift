import AVAppShellFoundation
import AVBrandFoundation
import AVSettingsFoundation
import SwiftUI

struct SeriesAccountContent: View {
    @Environment(\.avCommonAppExperience) private var appExperience
    @Environment(\.avBrandPalette) private var brandPalette
    @ScaledMetric(relativeTo: .body) private var compactRowTitleFontSize: CGFloat = 14
    @ScaledMetric(relativeTo: .subheadline) private var compactRowDetailFontSize: CGFloat = 12

    let accessController: SeriesAccessController
    @Bindable var librarySync: SeriesLibrarySyncCoordinator
    let isTabletLayout: Bool
    let isSigningOut: Bool
    let startSignInFlow: () -> Void
    let signOut: () -> Void
    let synchronizeLibraryNow: () async -> Void
    let keepDeviceLibraryNow: () async -> Void
    let showProPaywall: () -> Void
    let showAccountDeletion: () -> Void
    let openSubscriptionManagement: () -> Void

    var body: some View {
        accountCard
        SeriesProCard(
            accessController: accessController,
            isTabletLayout: isTabletLayout,
            showProPaywall: showProPaywall,
            openSubscriptionManagement: openSubscriptionManagement
        )
        if accessController.capabilities.canUseCloudSync {
            cloudSyncCard
        }
        if accessController.isSignedIn {
            accountSafetyCard
        }
    }

    private var accountCard: some View {
        AVSettingsSectionCard(
            title: L10n.string("profile.account.title"),
            subtitle: accountIdentityDetail
        ) {
            Divider().overlay(AVBrandColor.borderSubtle)
            if accessController.isSignedIn {
                VStack(alignment: .leading, spacing: 12) {
                    AVSettingsInfoRow(
                        systemImage: "person.crop.circle",
                        title: L10n.string("profile.summary.account.title"),
                        detail: sessionDetail
                    )
                    if let emailAddress = accessController.accountUser?.emailAddress {
                        AVSettingsInfoRow(
                            systemImage: "envelope",
                            title: L10n.string("profile.account.email.title"),
                            detail: emailAddress
                        )
                    }
                    AVSettingsInfoRow(
                        systemImage: "sparkles.rectangle.stack",
                        title: L10n.string("profile.summary.plan.title"),
                        detail: accessDetail
                    )
                }
            } else {
                AVSettingsInfoRow(
                    systemImage: "internaldrive",
                    title: L10n.string("profile.summary.plan.detail.guest"),
                    detail: sessionDetail
                )
                .accessibilityIdentifier("profile.account.localMode")
            }
            accountActionButton
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("profile.account.card")
    }

    private var cloudSyncCard: some View {
        AVSettingsSectionCard(
            title: L10n.string("profile.sync.title"),
            subtitle: L10n.string("profile.sync.subtitle")
        ) {
            AVSettingsInfoRow(
                systemImage: cloudSyncIcon,
                title: cloudSyncHeadline,
                detail: cloudSyncDetail
            )
            .accessibilityIdentifier("profile.sync.status")
            AVSettingsButton(
                title: cloudSyncActionTitle,
                style: .secondary,
                isLoading: librarySync.state == .syncing,
                action: { Task { await synchronizeLibraryNow() } }
            )
            .disabled(librarySync.state == .syncing)
            .accessibilityIdentifier("profile.sync.retry")
            if librarySync.state == .conflict {
                AVSettingsButton(
                    title: L10n.string("profile.sync.keepDevice"),
                    style: .secondary,
                    action: { Task { await keepDeviceLibraryNow() } }
                )
                .accessibilityIdentifier("profile.sync.keepDevice")
            }
        }
        .accessibilityIdentifier("profile.sync.card")
    }

    private var accountSafetyCard: some View {
        AVSettingsSectionCard(
            title: L10n.string("profile.safety.title"),
            subtitle: L10n.string("profile.safety.subtitle"),
            spacing: 12
        ) {
            Button(action: showAccountDeletion) {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "exclamationmark.shield")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(brandPalette.destructive)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.string("profile.safety.delete.title"))
                            .font(.system(size: compactRowTitleFontSize, weight: .semibold))
                            .foregroundStyle(AVBrandColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(L10n.string("profile.safety.delete.detail"))
                            .font(.system(size: compactRowDetailFontSize, weight: .medium))
                            .foregroundStyle(AVBrandColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AVBrandColor.textSecondary.opacity(0.7))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    brandPalette.destructive.opacity(0.045),
                    in: RoundedRectangle(cornerRadius: AVBrandRadius.row, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: AVBrandRadius.row, style: .continuous)
                        .stroke(brandPalette.destructive.opacity(0.14), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("profile.safety.delete")
        }
    }

    @ViewBuilder
    private var accountActionButton: some View {
        if accessController.isSignedIn {
            tabletAlignedSettingsContent {
                AVSettingsButton(
                    title: isSigningOut ? L10n.string("profile.actions.signingOut") : L10n.string("profile.actions.signOut"),
                    style: .destructive,
                    isLoading: isSigningOut,
                    action: signOut
                )
                .frame(maxWidth: 200)
            }
            .disabled(isSigningOut)
            .accessibilityIdentifier("profile.account.signOut")
        } else if accessController.accountIsAvailable {
            tabletAlignedSettingsContent {
                AVSettingsButton(
                    title: L10n.string("profile.account.connect"),
                    style: .primary,
                    action: startSignInFlow
                )
            }
            .accessibilityIdentifier("profile.account.signIn")
        } else {
            accountUnavailableStatus
        }
    }

    private var accountUnavailableStatus: some View {
        tabletAlignedSettingsContent {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AVBrandColor.textSecondary)
                    .frame(width: 20, height: 20)
                Text(L10n.string("profile.account.connectUnavailable"))
                    .font(.system(size: compactRowTitleFontSize, weight: .semibold))
                    .foregroundStyle(AVBrandColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AVBrandColor.mutedSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AVBrandColor.borderSubtle, lineWidth: 1)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("profile.account.unavailable")
        }
    }

    private func tabletAlignedSettingsContent<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: isTabletLayout ? 340 : .infinity, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var accountIdentityDetail: String {
        if accessController.isSignedIn {
            return L10n.string("profile.account.connected", appExperience.identity.accountName)
        }
        return L10n.string("profile.account.identity.guest")
    }

    private var sessionDetail: String {
        if accessController.isSignedIn {
            return accessController.accountUser?.displayName
                ?? accessController.accountUser?.emailAddress
                ?? L10n.string("profile.summary.account.detail.signedIn")
        }
        return L10n.string("profile.summary.account.detail.guest")
    }

    private var accessDetail: String {
        switch accessController.accessMode {
        case .guest: L10n.string("profile.summary.plan.detail.guest")
        case .signedInFree: L10n.string("profile.summary.plan.detail.free")
        case .signedInPro: L10n.string("profile.summary.plan.detail.pro")
        }
    }

    private var cloudSyncHeadline: String {
        switch librarySync.state {
        case .disabled: L10n.string("profile.sync.headline.disabled")
        case .idle: L10n.string("profile.sync.headline.synced")
        case .syncing: L10n.string("profile.sync.headline.syncing")
        case .conflict: L10n.string("profile.sync.headline.conflict")
        case .failed: L10n.string("profile.sync.headline.failed")
        }
    }

    private var cloudSyncDetail: String {
        switch librarySync.state {
        case .disabled: L10n.string("profile.sync.detail.disabled")
        case .idle: L10n.string("profile.sync.detail.synced")
        case .syncing: L10n.string("profile.sync.detail.syncing")
        case .conflict: L10n.string("profile.sync.detail.conflict")
        case .failed: L10n.string("profile.sync.detail.failed")
        }
    }

    private var cloudSyncActionTitle: String {
        switch librarySync.state {
        case .syncing: L10n.string("profile.sync.retry.syncing")
        case .conflict: L10n.string("profile.sync.refresh")
        case .disabled, .idle, .failed: L10n.string("profile.sync.retry")
        }
    }

    private var cloudSyncIcon: String {
        switch librarySync.state {
        case .disabled: "icloud.slash"
        case .idle: "checkmark.icloud"
        case .syncing: "arrow.triangle.2.circlepath.icloud"
        case .conflict: "exclamationmark.icloud"
        case .failed: "xmark.icloud"
        }
    }

}
