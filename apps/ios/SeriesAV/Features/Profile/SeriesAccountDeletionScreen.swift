import AVBrandFoundation
import AVSettingsFoundation
import SwiftUI

struct SeriesAccountDeletionScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.avBrandPalette) private var brandPalette
    @StateObject private var viewModel: SeriesAccountDeletionViewModel
    @FocusState private var isConfirmationFocused: Bool

    init(viewModel: SeriesAccountDeletionViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        AVSettingsSheetScaffold(
            spacing: 18,
            horizontalPadding: 24,
            topPadding: 24,
            bottomPadding: 24,
            backgroundStyle: AnyShapeStyle(AVBrandSurface.shellBackground),
            closeTitle: L10n.string("common.cancel"),
            closeAccessibilityIdentifier: "accountDeletion.cancel",
            onClose: { dismiss() }
        ) {
            header

            if viewModel.isLoading {
                AVSettingsLoadingState(L10n.string("accountDeletion.loading"))
            } else if viewModel.errorContext == .load {
                loadErrorContent
            } else {
                if viewModel.resolvedEligibility?.status != .eligible {
                    sharedAccountNotice
                }
                stateContent
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(L10n.string("accountDeletion.title"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
        }
        .onChange(of: viewModel.didCompleteDeletion) { _, didComplete in
            guard didComplete else { return }
            dismiss()
        }
        .accessibilityIdentifier("accountDeletion.sheet")
    }

    private var header: some View {
        AVSettingsSheetHeader(
            title: L10n.string("accountDeletion.title"),
            subtitle: L10n.string("accountDeletion.subtitle"),
            titleAccessibilityIdentifier: "accountDeletion.title"
        )
    }

    private var sharedAccountNotice: some View {
        AVSettingsNoticeCard(
            systemImage: "person.2.badge.gearshape",
            title: L10n.string("accountDeletion.shared.title"),
            detail: L10n.string("accountDeletion.shared.detail")
        )
        .accessibilityIdentifier("accountDeletion.shared")
    }

    private var loadErrorContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            AVSettingsStatusCard(
                systemImage: "exclamationmark.triangle",
                title: L10n.string("accountDeletion.error.title"),
                detail: viewModel.errorMessage ?? L10n.string("accountDeletion.error.load")
            )
            .accessibilityIdentifier("accountDeletion.status.error")

            AVSettingsButton(
                title: L10n.string("common.retry"),
                style: .primary
            ) {
                Task { await viewModel.load() }
            }
            .accessibilityIdentifier("accountDeletion.retry")

            if let accountDeletionURL = AppConfig.accountDeletionURL {
                AVSettingsLinkButton(
                    title: L10n.string("accountDeletion.accountWebsiteLink"),
                    systemImage: "safari",
                    destination: accountDeletionURL
                )
                .accessibilityIdentifier("accountDeletion.accountWebsiteLink")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("accountDeletion.loadError")
    }

    @ViewBuilder
    private var stateContent: some View {
        if viewModel.didUnlinkCurrentApp {
            AVSettingsStatusCard(
                systemImage: "link.badge.minus",
                title: L10n.string("accountDeletion.unlinked.title"),
                detail: viewModel.unlinkMessage ?? L10n.string("accountDeletion.unlinked.detail")
            )
            .accessibilityIdentifier("accountDeletion.status.unlinked")
        } else {
            switch viewModel.resolvedEligibility?.status {
            case .eligible:
                eligibleContent
            case .blocked:
                blockedContent(title: L10n.string("accountDeletion.blocked.title"))
            case .inProgress:
                inProgressContent
            case .completed:
                AVSettingsStatusCard(
                    systemImage: "checkmark.circle",
                    title: L10n.string("accountDeletion.completed.title"),
                    detail: L10n.string("accountDeletion.completed.detail")
                )
                .accessibilityIdentifier("accountDeletion.status.completed")
            case .unavailable, .none:
                unavailableContent
            }
        }
    }

    private var eligibleContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            eligibleAccountSummary

            irreversibleImpactNotice
            warningList

            finalConfirmationPanel
        }
    }

    private var finalConfirmationPanel: some View {
        AVSettingsCard(spacing: 14, padding: 18) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(brandPalette.destructive)
                    .frame(width: 24)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.string("accountDeletion.confirm.title"))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AVBrandColor.textPrimary)
                        .accessibilityIdentifier("accountDeletion.confirm.title")

                    Text(L10n.string("accountDeletion.confirm.instructions"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AVBrandColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            operationErrorNotice(for: .requestDeletion)

            AVSettingsTextField(
                "DELETE",
                text: $viewModel.confirmationText,
                accessibilityIdentifier: "accountDeletion.confirmation"
            )
            .focused($isConfirmationFocused)
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
            .submitLabel(.done)
            .accessibilityLabel(L10n.string("accountDeletion.confirm.fieldLabel"))
            .accessibilityValue(
                viewModel.confirmationText.isEmpty
                    ? L10n.string("accountDeletion.confirm.fieldValueEmpty")
                    : viewModel.confirmationText
            )
            .accessibilityHint(L10n.string("accountDeletion.confirm.fieldHint"))
            .onSubmit {
                isConfirmationFocused = false
            }

            AVSettingsButton(
                title: viewModel.isSubmitting
                    ? L10n.string("accountDeletion.deleting")
                    : L10n.string("accountDeletion.deleteButton"),
                style: .destructivePrimary,
                isLoading: viewModel.isSubmitting
            ) {
                isConfirmationFocused = false
                Task { await viewModel.requestDeletion() }
            }
            .disabled(!viewModel.canRequestDeletion || viewModel.isSubmitting)
            .opacity(viewModel.canRequestDeletion ? 1 : 0.68)
            .accessibilityIdentifier("accountDeletion.deleteButton")
        }
        .overlay {
            RoundedRectangle(cornerRadius: AVBrandRadius.sheet, style: .continuous)
                .stroke(brandPalette.destructive.opacity(0.18), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("accountDeletion.confirm.panel")
    }

    private var eligibleAccountSummary: some View {
        AVSettingsCard(spacing: 12, padding: 16) {
            Label(L10n.string("accountDeletion.shared.title"), systemImage: "person.2.badge.gearshape")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(AVBrandColor.textPrimary)

            Text(L10n.string("accountDeletion.shared.detail"))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AVBrandColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 14, weight: .semibold))

                Text(L10n.string("accountDeletion.eligible.title"))
                    .font(.system(size: 13, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .foregroundStyle(brandPalette.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                brandPalette.accent.opacity(0.08),
                in: RoundedRectangle(cornerRadius: AVBrandRadius.md, style: .continuous)
            )
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isStaticText)
            .accessibilityRemoveTraits(.isSelected)
            .accessibilityIdentifier("accountDeletion.status.eligible")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("accountDeletion.eligible.summary")
    }

    @ViewBuilder
    private var irreversibleImpactNotice: some View {
        if viewModel.hasHighImpactDeletionWarnings {
            highImpactNotice
        } else if viewModel.hasLinkedAppDeletionWarnings {
            AVSettingsStatusCard(
                systemImage: "exclamationmark.triangle.fill",
                title: L10n.string("accountDeletion.impact.linkedApps.title"),
                detail: L10n.string("accountDeletion.impact.linkedApps.detail")
            )
            .accessibilityIdentifier("accountDeletion.impact.linkedApps")
        }
    }

    private var highImpactNotice: some View {
        AVSettingsCard(spacing: 12, padding: 18) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.octagon.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(brandPalette.destructive)
                    .frame(width: 24)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.string("accountDeletion.impact.high.title"))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AVBrandColor.textPrimary)

                    Text(L10n.string("accountDeletion.impact.high.intro"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AVBrandColor.textSecondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                highImpactItem(
                    key: "accountDeletion.impact.high.item.access",
                    identifier: "accountDeletion.impact.high.item.access"
                )
                highImpactItem(
                    key: "accountDeletion.impact.high.item.credits",
                    identifier: "accountDeletion.impact.high.item.credits"
                )
                highImpactItem(
                    key: "accountDeletion.impact.high.item.data",
                    identifier: "accountDeletion.impact.high.item.data"
                )
            }

            Text(L10n.string("accountDeletion.impact.high.footer"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(brandPalette.destructive)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("accountDeletion.impact.high.footer")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("accountDeletion.impact.high")
    }

    private func highImpactItem(key: String, identifier: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(brandPalette.destructive.opacity(0.75))
                .frame(width: 5, height: 5)
                .padding(.top, 6)
                .accessibilityHidden(true)

            Text(L10n.string(key))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AVBrandColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }

    private var inProgressContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            AVSettingsStatusCard(
                systemImage: "clock.badge.exclamationmark",
                title: L10n.string("accountDeletion.inProgress.title"),
                detail: L10n.string("accountDeletion.inProgress.detail")
            )
            .accessibilityIdentifier("accountDeletion.status.inProgress")
            blockerList
            warningList

            if viewModel.canFinalizeDeletion {
                operationErrorNotice(for: .finalizeDeletion)

                AVSettingsButton(
                    title: viewModel.isSubmitting
                        ? L10n.string("accountDeletion.finalizing")
                        : L10n.string("accountDeletion.finalizeButton"),
                    style: .primary,
                    isLoading: viewModel.isSubmitting
                ) {
                    Task { await viewModel.finalizeDeletion() }
                }
                .disabled(viewModel.isSubmitting)
                .accessibilityIdentifier("accountDeletion.finalizeButton")
            }
        }
    }

    private func blockedContent(title: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            AVSettingsStatusCard(
                systemImage: "lock.shield",
                title: title,
                detail: L10n.string("accountDeletion.blocked.detail")
            )
            .accessibilityIdentifier("accountDeletion.status.blocked")
            blockerList
            warningList

            if viewModel.canUnlinkCurrentApp {
                operationErrorNotice(for: .unlink)

                AVSettingsButton(
                    title: viewModel.isSubmitting
                        ? L10n.string("accountDeletion.unlinking")
                        : L10n.string("accountDeletion.unlinkButton"),
                    style: .secondary,
                    isLoading: viewModel.isSubmitting
                ) {
                    Task { await viewModel.unlinkCurrentApp() }
                }
                .disabled(!viewModel.canUnlinkCurrentApp)
                .accessibilityIdentifier("accountDeletion.unlinkButton")
            }

            if let accountDeletionURL = AppConfig.accountDeletionURL {
                AVSettingsLinkButton(
                    title: L10n.string("accountDeletion.accountWebsiteLink"),
                    systemImage: "safari",
                    destination: accountDeletionURL
                )
                .accessibilityIdentifier("accountDeletion.accountWebsiteLink")
            }
        }
    }

    private var unavailableContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            AVSettingsStatusCard(
                systemImage: "safari",
                title: L10n.string("accountDeletion.unavailable.title"),
                detail: L10n.string("accountDeletion.unavailable.detail")
            )
            .accessibilityIdentifier("accountDeletion.status.unavailable")
            warningList

            if let accountDeletionURL = AppConfig.accountDeletionURL {
                AVSettingsLinkButton(
                    title: L10n.string("accountDeletion.accountWebsiteLink"),
                    systemImage: "safari",
                    destination: accountDeletionURL
                )
                .accessibilityIdentifier("accountDeletion.accountWebsiteLink")
            }
        }
    }

    @ViewBuilder
    private func operationErrorNotice(for context: SeriesAccountDeletionViewModel.ErrorContext) -> some View {
        if viewModel.errorContext == context, let errorMessage = viewModel.errorMessage {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(brandPalette.destructive)
                    .frame(width: 18)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.string("accountDeletion.error.title"))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AVBrandColor.textPrimary)

                    Text(errorMessage)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AVBrandColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(
                brandPalette.destructive.opacity(0.06),
                in: RoundedRectangle(cornerRadius: AVBrandRadius.md, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AVBrandRadius.md, style: .continuous)
                    .stroke(brandPalette.destructive.opacity(0.16), lineWidth: 1)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("accountDeletion.operationError.\(context.rawValue)")
        }
    }

    private var blockerList: some View {
        AVSettingsDetailList(items: viewModel.blockers.map { blocker in
            AVSettingsDetailListItem(
                id: blocker.type.rawValue,
                title: blocker.label,
                detail: blockerDetail(for: blocker),
                linkTitle: blocker.managementUrl == nil ? nil : L10n.string("accountDeletion.manageLink"),
                linkDestination: blocker.managementUrl,
                accessibilityIdentifier: "accountDeletion.blocker.\(blocker.type.rawValue)"
            )
        })
    }

    private func blockerDetail(for blocker: AccountDeletionBlocker) -> String? {
        switch blocker.type {
        case .eligibilityUnavailable:
            return L10n.string("accountDeletion.blocked.detail")
        case .deletionInProgress:
            return blocker.detail
        case .linkedApp, .activeAiCredits, .activeProAccess, .activeBillingSubscription, .identityProvider:
            return blocker.detail
        }
    }

    @ViewBuilder
    private var warningList: some View {
        if !viewModel.warnings.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(viewModel.warnings) { warning in
                    compactWarningRow(warning)

                    if warning.id != viewModel.warnings.last?.id {
                        Divider()
                            .overlay(AVBrandColor.borderSubtle)
                            .padding(.leading, 42)
                    }
                }
            }
            .background(
                AVBrandColor.mutedSurface,
                in: RoundedRectangle(cornerRadius: AVBrandRadius.footerSelection, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AVBrandRadius.footerSelection, style: .continuous)
                    .stroke(AVBrandColor.borderSubtle, lineWidth: 1)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("accountDeletion.warning.list")
        }
    }

    private func compactWarningRow(_ warning: AccountDeletionBlocker) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: warningIcon(for: warning.type))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(brandPalette.destructive.opacity(0.82))
                .frame(width: 18)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(warning.label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AVBrandColor.textPrimary)
                    .accessibilityIdentifier("accountDeletion.warning.\(warning.type.rawValue)")

                if let detail = warning.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AVBrandColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let managementURL = warning.managementUrl {
                    Link(L10n.string("accountDeletion.manageLink"), destination: managementURL)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(brandPalette.accent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func warningIcon(for type: AccountDeletionBlocker.BlockerType) -> String {
        switch type {
        case .linkedApp:
            "rectangle.stack.badge.person.crop"
        case .activeAiCredits:
            "sparkles"
        case .activeProAccess:
            "checkmark.seal"
        case .activeBillingSubscription:
            "creditcard"
        case .identityProvider:
            "person.badge.key"
        case .deletionInProgress:
            "clock"
        case .eligibilityUnavailable:
            "exclamationmark.triangle"
        }
    }
}
