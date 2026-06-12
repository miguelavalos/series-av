import SwiftUI

struct RootView: View {
    private enum ProfileMode: String, Identifiable {
        case settings
        case account

        var id: String { rawValue }
    }

    @State private var store = SeriesLibraryStore.sample()
    @State private var profileMode: ProfileMode?
    let accessController: SeriesAccessController
    let startSignInFlow: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(accessTitle)
                                .font(.headline)
                            Text(accessSubtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Menu {
                            Button(L10n.string("shell.settings")) {
                                profileMode = .settings
                            }
                            Button(L10n.string("shell.account")) {
                                profileMode = .account
                            }
                        } label: {
                            Image(systemName: "person.crop.circle")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Section(L10n.string("shell.watching")) {
                    ForEach(store.activeEntries) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(entry.title)
                                .font(.headline)
                            Text(entry.progressLabel)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(L10n.string("shell.watch.next")) {
                                store.markNextEpisodeWatched(for: entry.id)
                            }
                            .tint(.green)
                        }
                    }
                }
            }
            .navigationTitle("Series AV")
        }
        .sheet(item: $profileMode) { mode in
            SeriesProfileScreen(
                mode: mode == .settings ? .settings : .account,
                accessController: accessController,
                startSignInFlow: startSignInFlow
            )
        }
    }

    private var accessTitle: String {
        switch accessController.accessMode {
        case .guest:
            L10n.string("shell.mode.guest")
        case .signedInFree:
            L10n.string("shell.mode.free")
        case .signedInPro:
            L10n.string("shell.mode.pro")
        }
    }

    private var accessSubtitle: String {
        accessController.accountUser?.emailAddress ?? accessController.accountUser?.displayName ?? ""
    }
}

#Preview {
    RootView(accessController: SeriesAccessController(), startSignInFlow: {})
}
