import SwiftUI

struct SharedListsScreen: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var socialStore: SeriesSocialStore

    @State private var isShowingCreateSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                InlineBackButton(title: "Profile") {
                    dismiss()
                }

                ShellBrandHeader(
                    statusTitle: socialStore.sharedLists.isEmpty
                        ? "Lists"
                        : "\(socialStore.sharedLists.count) Active"
                )
                SectionHeading(
                    eyebrow: "Social",
                    title: "Shared Lists",
                    subtitle: "Collaborative watchlists with the same shell, spacing, and card density used across Series AV."
                )

                HStack(spacing: 12) {
                    statCard(title: "Lists", value: socialStore.sharedLists.count)
                    statCard(title: "Members", value: socialStore.sharedLists.reduce(0) { $0 + $1.members.count })
                    statCard(title: "Shows", value: socialStore.sharedLists.reduce(0) { $0 + $1.items.count })
                }

                Button {
                    isShowingCreateSheet = true
                } label: {
                    primaryButtonLabel("Create shared list")
                }
                .buttonStyle(.plain)

                if socialStore.sharedLists.isEmpty {
                    EmptyStateCard(
                        title: "No shared lists",
                        detail: "Create one to start curating collaborative watchlists."
                    )
                } else {
                    ForEach(socialStore.sharedLists) { listSummary in
                        NavigationLink {
                            SharedListDetailScreen(listID: listSummary.list.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 16) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(listSummary.list.title)
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundStyle(SeriesTheme.textPrimary)

                                    Text(listSummary.list.description ?? "Collaborative series curation for your AV Account circle.")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(SeriesTheme.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                ShellRow(
                                    systemImage: "person.2",
                                    title: "Members",
                                    detail: "\(listSummary.members.count) active collaborators"
                                )

                                ShellRow(
                                    systemImage: "rectangle.stack",
                                    title: "Shows",
                                    detail: "\(listSummary.items.count) series saved"
                                )

                                if !listSummary.items.isEmpty {
                                    Text(
                                        listSummary.items.prefix(2)
                                            .map { socialStore.seriesMetadataById[$0.seriesId]?.title ?? $0.seriesId }
                                            .joined(separator: "  ·  ")
                                    )
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(SeriesTheme.highlight)
                                    .lineLimit(2)
                                }
                            }
                            .padding(20)
                            .background(cardBackground)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, AppShellMetrics.secondaryTopPadding)
            .padding(.bottom, AppShellMetrics.deepContentBottomPadding)
        }
        .scrollIndicators(.hidden)
        .background(SeriesTheme.shellBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await socialStore.refresh()
        }
        .sheet(isPresented: $isShowingCreateSheet) {
            SharedListCreateSheet(isPresented: $isShowingCreateSheet)
        }
    }

    private func statCard(title: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(SeriesTheme.textSecondary)
            Text(String(value))
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(SeriesTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(SeriesTheme.mutedSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(SeriesTheme.borderSubtle, lineWidth: 1)
                }
        )
    }

    private func primaryButtonLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(SeriesTheme.brandBlack)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(SeriesTheme.highlight, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(SeriesTheme.cardSurface)
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(SeriesTheme.borderSubtle, lineWidth: 1)
            }
    }
}

struct SharedListDetailScreen: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var socialStore: SeriesSocialStore

    let listID: String

    @State private var isShowingMemberSheet = false
    @State private var selectedDetail: SelectedShowDetail?
    private let service = TVMazeService()

    private var listSummary: RemoteSharedListSummary? {
        socialStore.sharedLists.first(where: { $0.list.id == listID })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let listSummary {
                    InlineBackButton(title: "Lists") {
                        dismiss()
                    }

                    ShellBrandHeader(statusTitle: "Shared List")
                    SectionHeading(
                        eyebrow: "Collaboration",
                        title: listSummary.list.title,
                        subtitle: listSummary.list.description ?? "\(listSummary.members.count) members · \(listSummary.items.count) shows"
                    )

                    HStack(spacing: 12) {
                        detailStatCard(title: "Members", value: listSummary.members.count)
                        detailStatCard(title: "Shows", value: listSummary.items.count)
                        detailStatCard(title: "Visibility", value: listSummary.list.visibility.capitalized)
                    }

                    Button {
                        isShowingMemberSheet = true
                    } label: {
                        detailPrimaryButtonLabel("Invite member")
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Members")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(SeriesTheme.textPrimary)

                        ForEach(listSummary.members) { member in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(member.displayName ?? member.email ?? member.userId)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(SeriesTheme.textPrimary)

                                ShellRow(
                                    systemImage: "person.crop.circle",
                                    title: "Role",
                                    detail: member.role.capitalized
                                )

                                if let email = member.email {
                                    ShellRow(
                                        systemImage: "envelope",
                                        title: "Email",
                                        detail: email
                                    )
                                }

                                if member.role != "owner" {
                                    Button(role: .destructive) {
                                        Task {
                                            _ = await socialStore.removeSharedListMember(
                                                listId: listID,
                                                userId: member.userId
                                            )
                                        }
                                    } label: {
                                        destructiveButtonLabel("Remove member")
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(20)
                            .background(cardBackground)
                        }
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Shows")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(SeriesTheme.textPrimary)

                        if listSummary.items.isEmpty {
                            EmptyStateCard(
                                title: "No shows yet",
                                detail: "Add a series from its detail screen to populate this list."
                            )
                        } else {
                            ForEach(listSummary.items) { item in
                                let metadata = socialStore.seriesMetadataById[item.seriesId]

                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(alignment: .top, spacing: 14) {
                                        SeriesPosterView(
                                            imageURL: metadata?.imageURL,
                                            title: metadata?.title ?? item.seriesId,
                                            width: 72,
                                            height: 104
                                        )

                                        VStack(alignment: .leading, spacing: 8) {
                                            Text(metadata?.title ?? item.seriesId)
                                                .font(.system(size: 18, weight: .bold))
                                                .foregroundStyle(SeriesTheme.textPrimary)

                                            if let note = item.note, !note.isEmpty {
                                                Text(note)
                                                    .font(.system(size: 13, weight: .medium))
                                                    .foregroundStyle(SeriesTheme.textSecondary)
                                                    .lineLimit(4)
                                                    .fixedSize(horizontal: false, vertical: true)
                                            }
                                        }
                                    }

                                    HStack(spacing: 12) {
                                        Button {
                                            selectedDetail = .remote(seriesID: item.seriesId)
                                        } label: {
                                            secondaryButtonLabel("Open")
                                        }
                                        .buttonStyle(.plain)

                                        Button(role: .destructive) {
                                            Task {
                                                _ = await socialStore.removeShowFromSharedList(
                                                    listId: listID,
                                                    itemId: item.id
                                                )
                                            }
                                        } label: {
                                            destructiveButtonLabel("Remove")
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(20)
                                .background(cardBackground)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, AppShellMetrics.secondaryTopPadding)
            .padding(.bottom, AppShellMetrics.deepContentBottomPadding)
        }
        .scrollIndicators(.hidden)
        .background(SeriesTheme.shellBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await socialStore.refresh()
        }
        .sheet(isPresented: $isShowingMemberSheet) {
            SharedListMemberSheet(isPresented: $isShowingMemberSheet, listID: listID)
        }
        .sheet(item: $selectedDetail) { detail in
            ShowDetailScreen(
                libraryShowID: detail.libraryShowID,
                summary: detail.summary,
                remoteSeriesID: detail.remoteSeriesID,
                service: service
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private func detailStatCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(SeriesTheme.textSecondary)
            Text(value)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(SeriesTheme.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(SeriesTheme.mutedSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(SeriesTheme.borderSubtle, lineWidth: 1)
                }
        )
    }

    private func detailStatCard(title: String, value: Int) -> some View {
        detailStatCard(title: title, value: String(value))
    }

    private func detailPrimaryButtonLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(SeriesTheme.brandBlack)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(SeriesTheme.highlight, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func secondaryButtonLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(SeriesTheme.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(SeriesTheme.mutedSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(SeriesTheme.borderSubtle, lineWidth: 1)
            }
    }

    private func destructiveButtonLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color.red.opacity(0.82), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(SeriesTheme.cardSurface)
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(SeriesTheme.borderSubtle, lineWidth: 1)
            }
    }
}

struct SharedListCreateSheet: View {
    @EnvironmentObject private var socialStore: SeriesSocialStore
    @Binding var isPresented: Bool

    @State private var title = ""
    @State private var description = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                TextField("Description", text: $description, axis: .vertical)
            }
            .navigationTitle("Create List")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            _ = await socialStore.createSharedList(
                                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                                description: description.trimmingCharacters(in: .whitespacesAndNewlines)
                            )
                            isPresented = false
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct SharedListMemberSheet: View {
    @EnvironmentObject private var socialStore: SeriesSocialStore
    @Binding var isPresented: Bool

    let listID: String

    @State private var query = ""
    @State private var users: [RemoteSocialUser] = []

    var body: some View {
        NavigationStack {
            List {
                ForEach(users) { user in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(user.displayName ?? user.email ?? user.userId)
                            .font(.system(size: 15, weight: .bold))
                        Text(user.email ?? user.relationship)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(SeriesTheme.mutedText)
                        HStack {
                            Button("Viewer") {
                                Task {
                                    _ = await socialStore.addSharedListMember(listId: listID, userId: user.userId, role: "viewer")
                                    isPresented = false
                                }
                            }
                            .buttonStyle(.bordered)
                            Button("Editor") {
                                Task {
                                    _ = await socialStore.addSharedListMember(listId: listID, userId: user.userId, role: "editor")
                                    isPresented = false
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(SeriesTheme.brandGreen)
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "Search people")
            .navigationTitle("Invite Member")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { isPresented = false }
                }
            }
            .task { await loadUsers() }
            .task(id: query) { await loadUsers() }
        }
    }

    private func loadUsers() async {
        users = await socialStore.searchPeople(query: query)
    }
}
