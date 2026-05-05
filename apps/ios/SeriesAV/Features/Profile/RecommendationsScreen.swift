import SwiftUI

struct RecommendationsScreen: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var socialStore: SeriesSocialStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                InlineBackButton(title: "Profile") {
                    dismiss()
                }

                ShellBrandHeader(
                    statusTitle: socialStore.recommendations.contains(where: { $0.status == "pending" })
                        ? "Pending"
                        : "Inbox"
                )
                SectionHeading(
                    eyebrow: "Social",
                    title: "Recommendations",
                    subtitle: "Incoming picks from the Account AV layer, styled with the same shell used everywhere else in the app."
                )

                dashboardCard

                if socialStore.recommendations.isEmpty {
                    EmptyStateCard(
                        title: "No recommendations",
                        detail: "Incoming suggestions will appear here once the social layer is active."
                    )
                } else {
                    ForEach(socialStore.recommendations) { recommendation in
                        let metadata = socialStore.seriesMetadataById[recommendation.seriesId]

                        VStack(alignment: .leading, spacing: 18) {
                            HStack(alignment: .top, spacing: 16) {
                                SeriesPosterView(
                                    imageURL: metadata?.imageURL,
                                    title: metadata?.title ?? recommendation.seriesId,
                                    width: 84,
                                    height: 122
                                )

                                VStack(alignment: .leading, spacing: 12) {
                                    Text(metadata?.title ?? recommendation.seriesId)
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundStyle(SeriesTheme.textPrimary)

                                    if let message = recommendation.message, !message.isEmpty {
                                        Text(message)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(SeriesTheme.textSecondary)
                                            .lineLimit(5)
                                            .fixedSize(horizontal: false, vertical: true)
                                    } else {
                                        Text("No message attached.")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(SeriesTheme.textSecondary)
                                    }

                                    ShellRow(
                                        systemImage: "paperplane",
                                        title: "Status",
                                        detail: recommendation.status.capitalized
                                    )
                                }
                            }

                            if recommendation.status == "pending" {
                                HStack(spacing: 12) {
                                    Button {
                                        Task {
                                            _ = await socialStore.updateRecommendationStatus(
                                                recommendationId: recommendation.id,
                                                status: "saved"
                                            )
                                        }
                                    } label: {
                                        recommendationPrimaryButtonLabel("Save")
                                    }
                                    .buttonStyle(.plain)

                                    Button {
                                        Task {
                                            _ = await socialStore.updateRecommendationStatus(
                                                recommendationId: recommendation.id,
                                                status: "dismissed"
                                            )
                                        }
                                    } label: {
                                        recommendationSecondaryButtonLabel("Dismiss")
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(22)
                        .background(recommendationCardBackground)
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
    }

    private var dashboardCard: some View {
        HStack(spacing: 12) {
            statCard(title: "Pending", value: pendingCount)
            statCard(title: "Saved", value: savedCount)
            statCard(title: "Dismissed", value: dismissedCount)
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
        .background(recommendationMutedCardBackground)
    }

    private var pendingCount: Int {
        socialStore.recommendations.filter { $0.status == "pending" }.count
    }

    private var savedCount: Int {
        socialStore.recommendations.filter { $0.status == "saved" }.count
    }

    private var dismissedCount: Int {
        socialStore.recommendations.filter { $0.status == "dismissed" }.count
    }

    private func recommendationPrimaryButtonLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(SeriesTheme.brandBlack)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(SeriesTheme.highlight, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func recommendationSecondaryButtonLabel(_ title: String) -> some View {
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

    private var recommendationCardBackground: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(SeriesTheme.cardSurface)
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(SeriesTheme.borderSubtle, lineWidth: 1)
            }
    }

    private var recommendationMutedCardBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(SeriesTheme.mutedSurface)
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(SeriesTheme.borderSubtle, lineWidth: 1)
            }
    }
}
