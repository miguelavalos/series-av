import Foundation

@MainActor
final class SeriesSocialStore: ObservableObject {
    @Published private(set) var recommendations: [RemoteRecommendation] = []
    @Published private(set) var sharedLists: [RemoteSharedListSummary] = []
    @Published private(set) var seriesMetadataById: [String: SocialSeriesMetadata] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var isHydrated = false

    private var cloudService: SeriesAVCloudService?
    private var previewSnapshotsById: [String: ShowSnapshot] = [:]

    func setCloudService(_ cloudService: SeriesAVCloudService?) {
        self.cloudService = cloudService
        if cloudService == nil {
            if AppConfig.debugSeedSocialPreview {
                loadDebugPreviewData()
            } else {
                recommendations = []
                sharedLists = []
                seriesMetadataById = [:]
                previewSnapshotsById = [:]
            }
            isLoading = false
            isHydrated = true
        }
    }

    func refresh() async {
        guard let cloudService else {
            if AppConfig.debugSeedSocialPreview {
                loadDebugPreviewData()
            } else {
                recommendations = []
                sharedLists = []
                seriesMetadataById = [:]
                previewSnapshotsById = [:]
            }
            isHydrated = true
            return
        }
        isLoading = true
        defer {
            isLoading = false
            isHydrated = true
        }
        do {
            async let recommendationsEnvelope = cloudService.getRecommendations()
            async let sharedListsEnvelope = cloudService.getSharedLists()
            let (recommendationsEnvelopeValue, sharedListsEnvelopeValue) = try await (recommendationsEnvelope, sharedListsEnvelope)
            recommendations = recommendationsEnvelopeValue.recommendations
            sharedLists = sharedListsEnvelopeValue.lists
            seriesMetadataById = try await hydrateMetadata(from: cloudService, recommendations: recommendations, sharedLists: sharedLists)
        } catch {
            recommendations = []
            sharedLists = []
            seriesMetadataById = [:]
        }
    }

    func createSharedList(title: String, description: String? = nil) async -> RemoteSharedListSummary? {
        guard let cloudService else { return nil }
        isLoading = true
        defer { isLoading = false; isHydrated = true }
        do {
            let created = try await cloudService.createSharedList(title: title, description: description)
            sharedLists = [created] + sharedLists.filter { $0.list.id != created.list.id }
            return created
        } catch {
            return nil
        }
    }

    func addShowToSharedList(listId: String, seriesId: String, note: String? = nil) async -> RemoteSharedListSummary? {
        guard let cloudService else { return nil }
        isLoading = true
        defer { isLoading = false; isHydrated = true }
        do {
            let updated = try await cloudService.addSharedListItem(listId: listId, seriesId: seriesId, note: note)
            sharedLists = sharedLists.map { $0.list.id == updated.list.id ? updated : $0 }
            await ensureMetadata(for: seriesId, cloudService: cloudService)
            return updated
        } catch {
            return nil
        }
    }

    func removeShowFromSharedList(listId: String, itemId: String) async -> RemoteSharedListSummary? {
        guard let cloudService else { return nil }
        isLoading = true
        defer { isLoading = false; isHydrated = true }
        do {
            let updated = try await cloudService.removeSharedListItem(listId: listId, itemId: itemId)
            sharedLists = sharedLists.map { $0.list.id == updated.list.id ? updated : $0 }
            return updated
        } catch {
            return nil
        }
    }

    func createRecommendation(recipientUserId: String, seriesId: String, message: String? = nil) async -> RemoteRecommendation? {
        guard let cloudService else { return nil }
        isLoading = true
        defer { isLoading = false; isHydrated = true }
        do {
            let created = try await cloudService.createRecommendation(recipientUserId: recipientUserId, seriesId: seriesId, message: message)
            recommendations = [created] + recommendations
            await ensureMetadata(for: seriesId, cloudService: cloudService)
            return created
        } catch {
            return nil
        }
    }

    func updateRecommendationStatus(recommendationId: String, status: String) async -> RemoteRecommendation? {
        guard let cloudService else { return nil }
        isLoading = true
        defer { isLoading = false; isHydrated = true }
        do {
            let updated = try await cloudService.updateRecommendationStatus(recommendationId: recommendationId, status: status)
            recommendations = recommendations.map { $0.id == updated.id ? updated : $0 }
            return updated
        } catch {
            return nil
        }
    }

    func searchPeople(query: String? = nil) async -> [RemoteSocialUser] {
        guard let cloudService else { return [] }
        do {
            return try await cloudService.getSocialUsers(query: query).users
        } catch {
            return []
        }
    }

    func addSharedListMember(listId: String, userId: String, role: String) async -> RemoteSharedListSummary? {
        guard let cloudService else { return nil }
        isLoading = true
        defer { isLoading = false; isHydrated = true }
        do {
            let updated = try await cloudService.addSharedListMember(listId: listId, userId: userId, role: role)
            sharedLists = sharedLists.map { $0.list.id == updated.list.id ? updated : $0 }
            return updated
        } catch {
            return nil
        }
    }

    func removeSharedListMember(listId: String, userId: String) async -> RemoteSharedListSummary? {
        guard let cloudService else { return nil }
        isLoading = true
        defer { isLoading = false; isHydrated = true }
        do {
            let updated = try await cloudService.removeSharedListMember(listId: listId, userId: userId)
            sharedLists = sharedLists.map { $0.list.id == updated.list.id ? updated : $0 }
            return updated
        } catch {
            return nil
        }
    }

    func getSeriesSnapshot(seriesId: String) async -> ShowSnapshot? {
        if cloudService == nil, let previewSnapshot = previewSnapshotsById[seriesId] {
            return previewSnapshot
        }
        guard let cloudService else { return nil }
        do {
            guard let record = try await cloudService.getCatalogRecord(seriesId: seriesId) else { return nil }
            return mapRemoteRecordToShowSnapshot(record)
        } catch {
            return nil
        }
    }

    func enrichSeriesSnapshot(seriesId: String?, providerRefs: [RemoteSeriesProviderRef]) async -> ShowSnapshot? {
        guard let cloudService, !providerRefs.isEmpty else { return nil }
        do {
            let record = try await cloudService.enrichCatalog(seriesId: seriesId, providerRefs: providerRefs)
            return mapRemoteRecordToShowSnapshot(record)
        } catch {
            return nil
        }
    }

    private func hydrateMetadata(
        from cloudService: SeriesAVCloudService,
        recommendations: [RemoteRecommendation],
        sharedLists: [RemoteSharedListSummary]
    ) async throws -> [String: SocialSeriesMetadata] {
        let seriesIds = Set(recommendations.map(\.seriesId) + sharedLists.flatMap { $0.items.map(\.seriesId) })
        var metadata: [String: SocialSeriesMetadata] = [:]
        for seriesId in seriesIds {
            if let record = try await cloudService.getCatalogRecord(seriesId: seriesId) {
                metadata[seriesId] = SocialSeriesMetadata(
                    title: record.series.title,
                    imageURL: URL(string: record.series.posterURL ?? "")
                )
            }
        }
        return metadata
    }

    private func ensureMetadata(for seriesId: String, cloudService: SeriesAVCloudService) async {
        guard seriesMetadataById[seriesId] == nil else { return }
        guard let record = try? await cloudService.getCatalogRecord(seriesId: seriesId) else {
            return
        }
        seriesMetadataById[seriesId] = SocialSeriesMetadata(
            title: record.series.title,
            imageURL: URL(string: record.series.posterURL ?? "")
        )
    }

    private func loadDebugPreviewData() {
        recommendations = [
            RemoteRecommendation(
                id: "rec-preview-1",
                senderUserId: "user-ana",
                recipientUserId: "debug-preview-user",
                seriesId: "series-severance",
                message: "Sharp tone, beautiful design system, and a slow-burn mystery. This feels like your kind of series.",
                status: "pending",
                createdAt: "2026-04-27T16:00:00Z",
                updatedAt: "2026-04-27T16:00:00Z"
            ),
            RemoteRecommendation(
                id: "rec-preview-2",
                senderUserId: "user-lucas",
                recipientUserId: "debug-preview-user",
                seriesId: "series-bear",
                message: "Short seasons, fast pacing, and strong character work.",
                status: "saved",
                createdAt: "2026-04-26T12:00:00Z",
                updatedAt: "2026-04-26T13:00:00Z"
            )
        ]

        sharedLists = [
            RemoteSharedListSummary(
                list: RemoteSharedList(
                    id: "list-weekend",
                    ownerUserId: "debug-preview-user",
                    title: "Weekend Queue",
                    description: "Tighter dramas and one comfort rewatch for Sunday night.",
                    visibility: "private",
                    createdAt: "2026-04-20T12:00:00Z",
                    updatedAt: "2026-04-27T10:00:00Z"
                ),
                members: [
                    RemoteSharedListMember(
                        id: "member-owner",
                        listId: "list-weekend",
                        userId: "debug-preview-user",
                        displayName: "Series AV Preview",
                        email: AppConfig.debugPreviewEmail,
                        role: "owner",
                        invitedByUserId: nil,
                        createdAt: "2026-04-20T12:00:00Z"
                    ),
                    RemoteSharedListMember(
                        id: "member-editor",
                        listId: "list-weekend",
                        userId: "user-ana",
                        displayName: "Ana",
                        email: "ana@example.com",
                        role: "editor",
                        invitedByUserId: "debug-preview-user",
                        createdAt: "2026-04-21T09:00:00Z"
                    )
                ],
                items: [
                    RemoteSharedListItem(
                        id: "item-1",
                        listId: "list-weekend",
                        seriesId: "series-severance",
                        addedByUserId: "user-ana",
                        note: "Start here first.",
                        createdAt: "2026-04-21T10:00:00Z"
                    ),
                    RemoteSharedListItem(
                        id: "item-2",
                        listId: "list-weekend",
                        seriesId: "series-bear",
                        addedByUserId: "debug-preview-user",
                        note: "Keep this as the lighter pick after the thriller.",
                        createdAt: "2026-04-22T14:00:00Z"
                    )
                ]
            ),
            RemoteSharedListSummary(
                list: RemoteSharedList(
                    id: "list-shared",
                    ownerUserId: "user-lucas",
                    title: "Shared With Friends",
                    description: "Series the group keeps passing around.",
                    visibility: "shared",
                    createdAt: "2026-04-18T11:00:00Z",
                    updatedAt: "2026-04-25T18:00:00Z"
                ),
                members: [
                    RemoteSharedListMember(
                        id: "member-lucas",
                        listId: "list-shared",
                        userId: "user-lucas",
                        displayName: "Lucas",
                        email: "lucas@example.com",
                        role: "owner",
                        invitedByUserId: nil,
                        createdAt: "2026-04-18T11:00:00Z"
                    ),
                    RemoteSharedListMember(
                        id: "member-preview",
                        listId: "list-shared",
                        userId: "debug-preview-user",
                        displayName: "Series AV Preview",
                        email: AppConfig.debugPreviewEmail,
                        role: "viewer",
                        invitedByUserId: "user-lucas",
                        createdAt: "2026-04-18T12:30:00Z"
                    )
                ],
                items: [
                    RemoteSharedListItem(
                        id: "item-3",
                        listId: "list-shared",
                        seriesId: "series-andor",
                        addedByUserId: "user-lucas",
                        note: "Great production value and pacing.",
                        createdAt: "2026-04-19T09:00:00Z"
                    )
                ]
            )
        ]

        seriesMetadataById = [
            "series-severance": SocialSeriesMetadata(
                title: "Severance",
                imageURL: URL(string: "https://static.tvmaze.com/uploads/images/medium_portrait/414/1035331.jpg")
            ),
            "series-bear": SocialSeriesMetadata(
                title: "The Bear",
                imageURL: URL(string: "https://static.tvmaze.com/uploads/images/medium_portrait/420/1050519.jpg")
            ),
            "series-andor": SocialSeriesMetadata(
                title: "Andor",
                imageURL: URL(string: "https://static.tvmaze.com/uploads/images/medium_portrait/424/1062181.jpg")
            )
        ]

        previewSnapshotsById = [
            "series-severance": ShowSnapshot(
                source: .tvmaze,
                sourceId: "series-severance",
                canonicalSeriesId: "series-severance",
                title: "Severance",
                year: 2022,
                imageURL: URL(string: "https://static.tvmaze.com/uploads/images/medium_portrait/414/1035331.jpg"),
                summary: "Employees at Lumon undergo a procedure that surgically divides their work memories from their personal lives, creating a mystery about identity, control, and what gets hidden behind immaculate corporate design.",
                genres: ["Thriller", "Mystery", "Science-Fiction"],
                episodeCountBySeason: ["1": 9, "2": 10],
                totalEpisodeCountBySeason: ["1": 9, "2": 10],
                episodesBySeason: [
                    "1": [
                        EpisodeSnapshot(id: "sev-s1e1", season: 1, episode: 1, title: "Good News About Hell", summary: "Mark meets Helly and the strange rules of Lumon settle in fast.", imageURL: nil, airdate: "2022-02-18", isAired: true),
                        EpisodeSnapshot(id: "sev-s1e2", season: 1, episode: 2, title: "Half Loop", summary: "The severed floor starts revealing its rituals and sharp edges.", imageURL: nil, airdate: "2022-02-25", isAired: true)
                    ],
                    "2": [
                        EpisodeSnapshot(id: "sev-s2e1", season: 2, episode: 1, title: "Hello, Ms. Cobel", summary: "The team returns with new tensions and deeper fractures.", imageURL: nil, airdate: "2026-01-10", isAired: true)
                    ]
                ],
                nextEpisode: UpcomingEpisode(season: 2, episode: 2, airdate: "2026-05-02")
            ),
            "series-bear": ShowSnapshot(
                source: .tvmaze,
                sourceId: "series-bear",
                canonicalSeriesId: "series-bear",
                title: "The Bear",
                year: 2022,
                imageURL: URL(string: "https://static.tvmaze.com/uploads/images/medium_portrait/420/1050519.jpg"),
                summary: "A fine-dining chef returns home to run a chaotic Chicago sandwich shop, balancing grief, speed, and a kitchen culture that can either collapse or become a family.",
                genres: ["Drama", "Comedy"],
                episodeCountBySeason: ["1": 8, "2": 10, "3": 10],
                totalEpisodeCountBySeason: ["1": 8, "2": 10, "3": 10],
                episodesBySeason: [
                    "1": [
                        EpisodeSnapshot(id: "bear-s1e1", season: 1, episode: 1, title: "System", summary: "Carmy inherits the shop and the pressure hits immediately.", imageURL: nil, airdate: "2022-06-23", isAired: true)
                    ]
                ],
                nextEpisode: nil
            ),
            "series-andor": ShowSnapshot(
                source: .tvmaze,
                sourceId: "series-andor",
                canonicalSeriesId: "series-andor",
                title: "Andor",
                year: 2022,
                imageURL: URL(string: "https://static.tvmaze.com/uploads/images/medium_portrait/424/1062181.jpg"),
                summary: "Cassian Andor is pulled into the early rebellion through espionage, theft, and political pressure, with a colder and more grounded Star Wars tone.",
                genres: ["Science-Fiction", "Drama", "Adventure"],
                episodeCountBySeason: ["1": 12, "2": 12],
                totalEpisodeCountBySeason: ["1": 12, "2": 12],
                episodesBySeason: [
                    "1": [
                        EpisodeSnapshot(id: "andor-s1e1", season: 1, episode: 1, title: "Kassa", summary: "Cassian's history and a dangerous confrontation set the story in motion.", imageURL: nil, airdate: "2022-09-21", isAired: true)
                    ]
                ],
                nextEpisode: nil
            )
        ]
    }
}
