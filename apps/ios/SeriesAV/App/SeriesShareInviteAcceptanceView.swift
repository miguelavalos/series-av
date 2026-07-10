import AVBrandFoundation
import SwiftUI

struct SeriesShareInviteAcceptanceView: View {
    let deepLink: SeriesShareInviteDeepLink
    let accessController: SeriesAccessController
    let store: SeriesLibraryStore
    let librarySync: SeriesLibrarySyncCoordinator
    let startSignInFlow: () -> Void
    let onDismiss: () -> Void

    @State private var state: InviteAcceptanceState = .idle

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(
        deepLink: SeriesShareInviteDeepLink,
        accessController: SeriesAccessController,
        store: SeriesLibraryStore,
        librarySync: SeriesLibrarySyncCoordinator,
        startSignInFlow: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.deepLink = deepLink
        self.accessController = accessController
        self.store = store
        self.librarySync = librarySync
        self.startSignInFlow = startSignInFlow
        self.onDismiss = onDismiss
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: dynamicTypeSize.isAccessibilitySize ? 24 : 20) {
                    header

                    Group {
                        switch state {
                        case .idle:
                            if accessController.isSignedIn {
                                actionButton
                            } else {
                                signInPrompt
                            }
                        case .accepting:
                            acceptingContent
                        case .accepted(let response):
                            acceptedContent(response.invite)
                        case .failed(let message):
                            errorContent(message)
                        }
                    }
                }
                .frame(maxWidth: 620, alignment: .leading)
                .padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? 20 : 24)
                .padding(.top, 24)
                .padding(.bottom, 40)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(AVBrandSurface.shellBackground.ignoresSafeArea())
            .accessibilityIdentifier("series-share-invite-scroll")
            .navigationTitle(L10n.string("shareInvite.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.string("common.done"), action: onDismiss)
                        .accessibilityIdentifier("series-share-invite-done")
                }
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .onAppear {
            if let forcedInitialState = Self.forcedInitialState {
                state = forcedInitialState
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.string("shareInvite.heading"))
                .font(.title2.bold())
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("series-share-invite-heading")
            Text(L10n.string("shareInvite.detail"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("series-share-invite-detail")
        }
    }

    private var actionButton: some View {
        Button {
            Task { await acceptInvite() }
        } label: {
            Label(L10n.string("shareInvite.accept"), systemImage: "checkmark.circle.fill")
                .frame(maxWidth: .infinity, minHeight: 50)
                .fixedSize(horizontal: false, vertical: true)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .accessibilityIdentifier("series-share-invite-accept")
    }

    private var signInPrompt: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.string("shareInvite.signInRequired"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                startSignInFlow()
            } label: {
                Label(L10n.string("shareInvite.signIn"), systemImage: "person.crop.circle.badge.checkmark")
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("series-share-invite-sign-in")
        }
    }

    private var acceptingContent: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text(L10n.string("shareInvite.accepting"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("series-share-invite-accepting")
    }

    private func acceptedContent(_ invite: SeriesShareInvitePreview) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(L10n.string("shareInvite.accepted"), systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(.green)
                .fixedSize(horizontal: false, vertical: true)
            if let title = invite.series?.title {
                Text(title)
                    .font(.title3.bold())
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(L10n.string("shareInvite.acceptedDetail"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(L10n.string("common.done"), action: onDismiss)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(minHeight: 50)
                .accessibilityIdentifier("series-share-invite-complete")
        }
    }

    private func errorContent(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(L10n.string("shareInvite.error"), systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("series-share-invite-error-message")
            Button {
                Task { await acceptInvite() }
            } label: {
                Label(L10n.string("common.retry"), systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .accessibilityIdentifier("series-share-invite-retry")
        }
    }

    private func acceptInvite() async {
        state = .accepting
        do {
            let client = SeriesShareInviteClient(apiClient: accessController.authenticatedAPIClient())
            let response = try await client.accept(token: deepLink.token)
            addAcceptedSeriesToLibraryIfNeeded(response.invite)
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

    private func addAcceptedSeriesToLibraryIfNeeded(_ invite: SeriesShareInvitePreview) {
        guard store.entries.contains(where: { SeriesLibraryIdentity.sameSeries($0, invite.seriesId) }) == false else {
            return
        }

        let title = invite.series?.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let title, title.isEmpty == false else {
            return
        }

        let now = Date()
        let entry = SeriesLibraryEntry(
            entryId: invite.seriesId,
            seriesId: invite.seriesId,
            title: title,
            status: .wantToWatch,
            lastWatchedEpisodeCursor: nil,
            displayArtworkRef: invite.series?.displayArtwork?.url?.absoluteString ?? invite.series?.displayArtwork?.assetName,
            fallbackVisualSeed: invite.series?.displayArtwork?.fallbackSeed ?? title,
            addedAt: now,
            updatedAt: now,
            lastInteractedAt: now
        )
        store.upsert(entry)
        librarySync.localEntriesDidChange(store.entries, accessController: accessController)
    }

    private enum InviteAcceptanceState: Equatable {
        case idle
        case accepting
        case accepted(SeriesShareInviteAcceptResponse)
        case failed(String)
    }

    private static var forcedInitialState: InviteAcceptanceState? {
        switch SeriesUITestEnvironment.current.shareInviteAcceptanceScenario {
        case "accepting":
            return .accepting
        case "error":
            return .failed([
                L10n.string("shareInvite.errorNotFound"),
                L10n.string("shareInvite.errorExpired"),
                L10n.string("shareInvite.errorGeneric")
            ].joined(separator: " "))
        default:
            return nil
        }
    }
}
