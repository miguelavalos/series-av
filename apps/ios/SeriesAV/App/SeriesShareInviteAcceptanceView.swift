import AVBrandFoundation
import SwiftUI

struct SeriesShareInviteAcceptanceView: View {
    let deepLink: SeriesShareInviteDeepLink
    let accessController: SeriesAccessController
    let startSignInFlow: () -> Void
    let onDismiss: () -> Void

    @State private var state: InviteAcceptanceState = .idle

    init(
        deepLink: SeriesShareInviteDeepLink,
        accessController: SeriesAccessController,
        startSignInFlow: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.deepLink = deepLink
        self.accessController = accessController
        self.startSignInFlow = startSignInFlow
        self.onDismiss = onDismiss
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                header

                switch state {
                case .idle:
                    if accessController.isSignedIn {
                        actionButton
                    } else {
                        signInPrompt
                    }
                case .accepting:
                    HStack(spacing: 12) {
                        ProgressView()
                        Text(L10n.string("shareInvite.accepting"))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                case .accepted(let response):
                    acceptedContent(response.invite)
                case .failed(let message):
                    errorContent(message)
                }

                Spacer(minLength: 0)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(AVBrandSurface.shellBackground.ignoresSafeArea())
            .navigationTitle(L10n.string("shareInvite.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.string("common.done"), action: onDismiss)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.string("shareInvite.heading"))
                .font(.title2.bold())
                .foregroundStyle(.primary)
            Text(L10n.string("shareInvite.detail"))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var actionButton: some View {
        Button {
            Task { await acceptInvite() }
        } label: {
            Label(L10n.string("shareInvite.accept"), systemImage: "checkmark.circle.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    private var signInPrompt: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.string("shareInvite.signInRequired"))
                .font(.callout)
                .foregroundStyle(.secondary)
            Button {
                startSignInFlow()
            } label: {
                Label(L10n.string("shareInvite.signIn"), systemImage: "person.crop.circle.badge.checkmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private func acceptedContent(_ invite: SeriesShareInvitePreview) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(L10n.string("shareInvite.accepted"), systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(.green)
            if let title = invite.series?.title {
                Text(title)
                    .font(.title3.bold())
            }
            Text(L10n.string("shareInvite.acceptedDetail"))
                .font(.callout)
                .foregroundStyle(.secondary)
            Button(L10n.string("common.done"), action: onDismiss)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
    }

    private func errorContent(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(L10n.string("shareInvite.error"), systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
            Button {
                Task { await acceptInvite() }
            } label: {
                Label(L10n.string("common.retry"), systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }

    private func acceptInvite() async {
        state = .accepting
        do {
            let client = SeriesShareInviteClient(apiClient: accessController.authenticatedAPIClient())
            let response = try await client.accept(token: deepLink.token)
            state = .accepted(response)
        } catch SeriesAVAPIClientError.requestFailed(let statusCode) {
            state = .failed(Self.message(for: statusCode))
        } catch SeriesAVAPIClientError.missingToken {
            state = .idle
            startSignInFlow()
        } catch {
            state = .failed(L10n.string("shareInvite.errorGeneric"))
        }
    }

    private static func message(for statusCode: Int) -> String {
        switch statusCode {
        case 404:
            L10n.string("shareInvite.errorNotFound")
        case 410:
            L10n.string("shareInvite.errorExpired")
        default:
            L10n.string("shareInvite.errorGeneric")
        }
    }

    private enum InviteAcceptanceState: Equatable {
        case idle
        case accepting
        case accepted(SeriesShareInviteAcceptResponse)
        case failed(String)
    }
}
