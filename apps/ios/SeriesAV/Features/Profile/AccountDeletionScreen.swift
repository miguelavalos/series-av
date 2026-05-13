import SwiftUI

struct AccountDeletionScreen: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AccountDeletionViewModel

    init(viewModel: AccountDeletionViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    stateContent
                }
                .padding(24)
            }
            .scrollIndicators(.hidden)
            .background(SeriesTheme.shellBackground.ignoresSafeArea())
            .navigationTitle("Delete Apps AV account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .task {
                await viewModel.load()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Delete Apps AV account")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(SeriesTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Apps AV account is shared across Apps AV apps. Deleting it removes the shared sign-in identity, while local-only data on this device is separate.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(SeriesTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var stateContent: some View {
        switch viewModel.state {
        case .loading:
            statusCard(systemImage: "arrow.triangle.2.circlepath", title: "Checking account status", detail: "Apps AV is checking whether this shared account can be deleted safely.") {
                ProgressView()
                    .tint(SeriesTheme.textPrimary)
            }
        case .blocked(let blockers, let warnings, let canUnlinkCurrentApp):
            blockedCard(blockers, warnings: warnings, canUnlinkCurrentApp: canUnlinkCurrentApp)
        case .eligible(let warnings):
            eligibleCard(warnings: warnings)
        case .inProgress(let job, let warnings):
            inProgressCard(job, warnings: warnings)
        case .completed:
            statusCard(systemImage: "checkmark.circle", title: "Account deleted", detail: "Apps AV has deleted the shared account. This app is returning to guest mode.")
        case .unlinked(let message):
            statusCard(systemImage: "link.badge.minus", title: "App unlinked", detail: message)
        case .failed(let message):
            failedCard(message)
        }
    }

    private func blockedCard(
        _ blockers: [AccountDeletionBlocker],
        warnings: [AccountDeletionBlocker],
        canUnlinkCurrentApp: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            statusHeader(
                systemImage: "exclamationmark.shield",
                title: "Deletion is blocked",
                detail: "Apps AV cannot complete deletion here because a required deletion dependency is unavailable. Provider billing and linked apps are normally warnings, not blockers."
            )

            VStack(spacing: 12) {
                ForEach(blockers) { blocker in
                    blockerRow(blocker)
                }
            }

            warningRows(warnings)

            Button {
                Task { await viewModel.load() }
            } label: {
                Label("Check again", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(AccountDeletionSecondaryButtonStyle())

            if canUnlinkCurrentApp {
                Button {
                    Task { await viewModel.unlinkCurrentApp() }
                } label: {
                    HStack {
                        Text(viewModel.isSubmitting ? "Unlinking..." : "Unlink this app")
                        Spacer()
                        if viewModel.isSubmitting {
                            ProgressView()
                                .tint(SeriesTheme.textPrimary)
                        }
                    }
                }
                .buttonStyle(AccountDeletionSecondaryButtonStyle())
                .disabled(!viewModel.canUnlinkCurrentApp)
            }

            if let accountURL = AppConfig.deleteAccountURL {
                Link(destination: accountURL) {
                    Label("Manage on Apps AV account website", systemImage: "safari")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AccountDeletionSecondaryButtonStyle())
            }
        }
        .padding(20)
        .background(cardBackground)
    }

    private func eligibleCard(warnings: [AccountDeletionBlocker]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            statusHeader(
                systemImage: "trash",
                title: "Ready to delete",
                detail: "Review any warnings below, then type DELETE to request deletion of the shared Apps AV account."
            )

            warningRows(warnings)

            TextField("DELETE", text: $viewModel.confirmationText)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .padding(16)
                .foregroundStyle(SeriesTheme.textPrimary)
                .background(SeriesTheme.mutedSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(SeriesTheme.borderSubtle, lineWidth: 1)
                }

            Button(role: .destructive) {
                Task { await viewModel.requestDeletion() }
            } label: {
                HStack {
                    Text(viewModel.isSubmitting ? "Deleting..." : "Delete Apps AV account")
                    Spacer()
                    if viewModel.isSubmitting {
                        ProgressView()
                            .tint(Color(red: 0.84, green: 0.16, blue: 0.22))
                    }
                }
            }
            .buttonStyle(AccountDeletionDangerButtonStyle())
            .disabled(!viewModel.canRequestDeletion)
        }
        .padding(20)
        .background(cardBackground)
    }

    private func inProgressCard(_ job: AccountDeletionJob?, warnings: [AccountDeletionBlocker]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            statusHeader(
                systemImage: "hourglass",
                title: "Deletion in progress",
                detail: job?.message ?? "Apps AV is processing deletion for the shared account."
            )

            warningRows(warnings)

            if job?.status == .awaitingIdentityDeletion {
                Button {
                    Task { await viewModel.finalizeDeletion() }
                } label: {
                    HStack {
                        Text(viewModel.isSubmitting ? "Finalizing..." : "Finalize deletion")
                        Spacer()
                        if viewModel.isSubmitting {
                            ProgressView()
                                .tint(SeriesTheme.textPrimary)
                        }
                    }
                }
                .buttonStyle(AccountDeletionSecondaryButtonStyle())
                .disabled(viewModel.isSubmitting)
            }

            Button {
                Task { await viewModel.load() }
            } label: {
                Label("Refresh status", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(AccountDeletionSecondaryButtonStyle())
        }
        .padding(20)
        .background(cardBackground)
    }

    private func failedCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            statusHeader(
                systemImage: "xmark.octagon",
                title: "Deletion could not continue",
                detail: message
            )

            Button {
                Task { await viewModel.load() }
            } label: {
                Label("Check status", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(AccountDeletionSecondaryButtonStyle())
        }
        .padding(20)
        .background(cardBackground)
    }

    private func statusCard<Accessory: View>(
        systemImage: String,
        title: String,
        detail: String,
        @ViewBuilder accessory: () -> Accessory = { EmptyView() }
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            statusHeader(systemImage: systemImage, title: title, detail: detail)
            accessory()
        }
        .padding(20)
        .background(cardBackground)
    }

    private func statusHeader(systemImage: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(SeriesTheme.highlight)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(SeriesTheme.textPrimary)
                Text(detail)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(SeriesTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func blockerRow(_ blocker: AccountDeletionBlocker) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: blockerIcon(for: blocker.type))
                    .foregroundStyle(Color(red: 0.84, green: 0.16, blue: 0.22))
                    .frame(width: 20)
                Text(blocker.label)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(SeriesTheme.textPrimary)
            }

            if let detail = blocker.detail, !detail.isEmpty {
                Text(detail)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(SeriesTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let managementUrl = blocker.managementUrl {
                Link("Open management", destination: managementUrl)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(SeriesTheme.highlight)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(SeriesTheme.mutedSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private func warningRows(_ warnings: [AccountDeletionBlocker]) -> some View {
        if !warnings.isEmpty {
            VStack(spacing: 12) {
                ForEach(warnings) { warning in
                    warningRow(warning)
                }
            }
        }
    }

    private func warningRow(_ warning: AccountDeletionBlocker) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: blockerIcon(for: warning.type))
                    .foregroundStyle(SeriesTheme.highlight)
                    .frame(width: 20)
                Text(warning.label)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(SeriesTheme.textPrimary)
            }

            if let detail = warning.detail, !detail.isEmpty {
                Text(detail)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(SeriesTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let managementUrl = warning.managementUrl {
                Link("Open management", destination: managementUrl)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(SeriesTheme.highlight)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(SeriesTheme.mutedSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func blockerIcon(for type: AccountDeletionBlockerType) -> String {
        switch type {
        case .linkedApp: "app.connected.to.app.below.fill"
        case .activeProAccess: "sparkles"
        case .activeBillingSubscription: "creditcard"
        case .identityProvider: "person.badge.key"
        case .deletionInProgress: "hourglass"
        case .unavailable, .unknown: "exclamationmark.triangle"
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(SeriesTheme.cardSurface)
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(SeriesTheme.borderSubtle, lineWidth: 1)
            }
    }
}

private struct AccountDeletionSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(SeriesTheme.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .padding(.horizontal, 16)
            .background(SeriesTheme.cardSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(SeriesTheme.borderSubtle, lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

private struct AccountDeletionDangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(Color(red: 0.84, green: 0.16, blue: 0.22))
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .padding(.horizontal, 16)
            .background(SeriesTheme.cardSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(red: 0.84, green: 0.16, blue: 0.22).opacity(0.24), lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}
