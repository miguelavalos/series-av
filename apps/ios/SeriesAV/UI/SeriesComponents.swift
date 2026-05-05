import SwiftUI
import UIKit

enum AppShellMetrics {
    static let rootContentBottomPadding: CGFloat = 96
    static let secondaryTopPadding: CGFloat = 48
    static let deepContentBottomPadding: CGFloat = 168
}

struct AppBackground<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            SeriesTheme.shellBackground.ignoresSafeArea()
            content
        }
    }
}

struct ShellBrandHeader: View {
    let statusTitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image("OnboardingWordmark")
                .resizable()
                .scaledToFit()
                .frame(width: 160)

            Spacer()

            ShellStatusPill(title: statusTitle)
        }
    }
}

struct SectionHeading: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(eyebrow.uppercased())
                .font(.system(size: 12, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(SeriesTheme.highlight)
            Text(title)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(SeriesTheme.textPrimary)
            Text(subtitle)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(SeriesTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ShellSection<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(SeriesTheme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(SeriesTheme.textSecondary)
            }

            content()
        }
    }
}

struct ScreenHeroCard: View {
    let statusTitle: String
    let eyebrow: String
    let title: String
    let subtitle: String
    var titleLineLimit: Int? = nil
    var subtitleLineLimit: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ShellBrandHeader(statusTitle: statusTitle)

            VStack(alignment: .leading, spacing: 10) {
                Text(eyebrow.uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(SeriesTheme.highlight)

                Text(title)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(SeriesTheme.textPrimary)
                    .lineLimit(titleLineLimit)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(SeriesTheme.textSecondary)
                    .lineLimit(subtitleLineLimit)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(SeriesTheme.cardSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(SeriesTheme.borderSubtle, lineWidth: 1)
                }
        )
    }
}

struct InlineBackButton: View {
    let title: String
    let action: () -> Void

    init(title: String = "Back", action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                Text(title)
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundStyle(SeriesTheme.textPrimary)
            .padding(.horizontal, 15)
            .padding(.vertical, 11)
            .background(SeriesTheme.mutedSurface, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(SeriesTheme.borderSubtle, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

struct SearchField: View {
    @Binding var query: String
    let prompt: String
    let onSubmit: () -> Void
    let onClear: () -> Void
    let focusTrigger: Int?

    @FocusState private var isFocused: Bool

    init(
        query: Binding<String>,
        prompt: String = "Search",
        onSubmit: @escaping () -> Void = {},
        onClear: @escaping () -> Void = {},
        focusTrigger: Int? = nil
    ) {
        _query = query
        self.prompt = prompt
        self.onSubmit = onSubmit
        self.onClear = onClear
        self.focusTrigger = focusTrigger
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(SeriesTheme.textSecondary)

            TextField(
                text: $query,
                prompt: Text(prompt)
                    .foregroundStyle(SeriesTheme.textSecondary.opacity(0.68))
            ) {
            }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit(onSubmit)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(SeriesTheme.textPrimary)
                .tint(SeriesTheme.highlight)
                .focused($isFocused)

            if !query.isEmpty {
                Button("Clear") {
                    query = ""
                    onClear()
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(SeriesTheme.highlight)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(SeriesTheme.cardSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(SeriesTheme.borderSubtle, lineWidth: 1)
                }
        )
        .onChange(of: focusTrigger) { _, _ in
            isFocused = true
        }
    }
}

struct ShowRowCard: View {
    let show: CatalogShowSummary
    let libraryShow: LibraryShow?

    init(show: CatalogShowSummary, libraryShow: LibraryShow? = nil) {
        self.show = show
        self.libraryShow = libraryShow
    }

    var body: some View {
        HStack(spacing: 14) {
            SeriesPosterView(imageURL: show.imageURL, title: show.title, width: 74, height: 108)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Text(show.title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(SeriesTheme.textPrimary)
                        .lineLimit(2)
                    Spacer(minLength: 8)
                    if let libraryShow {
                        followedBadge(status: libraryShow.status)
                    } else if let year = show.year {
                        Text(String(year))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(SeriesTheme.textSecondary)
                    }
                }

                if !show.genres.isEmpty {
                    Text(show.genres.prefix(3).joined(separator: " • "))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(SeriesTheme.highlight)
                        .lineLimit(1)
                }

                Text(show.summary ?? "No synopsis available yet.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(SeriesTheme.textSecondary)
                    .lineLimit(3)
            }
        }
        .padding(18)
        .background(seriesCardBackground)
        .overlay {
            if libraryShow != nil {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(SeriesTheme.highlight.opacity(0.55), lineWidth: 1.2)
            }
        }
        .accessibilityHint(libraryShow == nil ? "" : "Already in your library")
    }

    private func followedBadge(status: ShowStatus) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12, weight: .bold))
            Text(status.title.uppercased())
                .font(.system(size: 10, weight: .black))
                .lineLimit(1)
        }
        .foregroundStyle(SeriesTheme.brandBlack)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(SeriesTheme.highlight, in: Capsule())
    }
}

struct LibraryRowCard: View {
    let show: LibraryShow

    var body: some View {
        HStack(spacing: 14) {
            SeriesPosterView(imageURL: show.imageURL, title: show.title, width: 74, height: 108)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Text(show.title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(SeriesTheme.textPrimary)
                        .lineLimit(2)
                    Spacer(minLength: 8)
                    Text(show.status.title.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(SeriesTheme.highlight)
                }

                if let nextEpisode = show.nextEpisode {
                    Text("S\(nextEpisode.season)E\(nextEpisode.episode)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(SeriesTheme.highlight)
                }

                Text(show.summary ?? "No synopsis available yet.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(SeriesTheme.textSecondary)
                    .lineLimit(3)
            }
        }
        .padding(18)
        .background(seriesCardBackground)
    }
}

struct EmptyStateCard: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(SeriesTheme.textPrimary)
            Text(detail)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(SeriesTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(seriesCardBackground)
    }
}

struct ShellRow: View {
    let systemImage: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(SeriesTheme.highlight)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(SeriesTheme.textPrimary)

                Text(detail)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(SeriesTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct ShellStatusPill: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(SeriesTheme.highlight)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(SeriesTheme.highlight.opacity(0.1), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(SeriesTheme.highlight.opacity(0.22), lineWidth: 1)
            }
    }
}

struct SeriesPosterView: View {
    let imageURL: URL?
    let title: String
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        Group {
            if let imageURL {
                CachedRemoteImage(url: imageURL) {
                    placeholder
                }
            } else {
                placeholder
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(SeriesTheme.borderSubtle.opacity(0.65), lineWidth: 1)
        }
    }

    private var placeholder: some View {
        ZStack {
            SeriesTheme.mutedSurface
            Text(initials)
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(SeriesTheme.highlight)
        }
    }

    private var initials: String {
        title.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined()
    }
}

struct CachedRemoteImage<Placeholder: View>: View {
    let url: URL
    @ViewBuilder let placeholder: () -> Placeholder

    @StateObject private var loader = RemoteImageLoader()

    var body: some View {
        Group {
            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            await loader.load(url)
        }
    }
}

@MainActor
final class RemoteImageLoader: ObservableObject {
    @Published private(set) var image: UIImage?

    private static let cache = NSCache<NSURL, UIImage>()
    private var currentURL: URL?

    func load(_ url: URL) async {
        guard currentURL != url || image == nil else { return }
        currentURL = url

        if let cached = Self.cache.object(forKey: url as NSURL) {
            image = cached
            return
        }

        do {
            let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 20)
            let (data, _) = try await URLSession.shared.data(for: request)
            guard currentURL == url, let decoded = UIImage(data: data) else { return }
            Self.cache.setObject(decoded, forKey: url as NSURL)
            image = decoded
        } catch {
            image = nil
        }
    }
}

enum AppShellTab: Equatable {
    case home
    case search
    case library
    case discover
    case profile
}

struct AppShellScaffold<Content: View>: View {
    let selectedTab: AppShellTab
    let selectTab: (AppShellTab) -> Void
    @ViewBuilder let content: () -> Content

    @Namespace private var footerSelectionAnimation

    var body: some View {
        ZStack {
            SeriesTheme.shellBackground.ignoresSafeArea()

            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .overlay(alignment: .bottom) {
            footer
        }
    }

    private var footer: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [
                    SeriesTheme.footerBackdrop.opacity(0),
                    SeriesTheme.footerBackdrop.opacity(0.94),
                    SeriesTheme.footerBackdrop
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 142)
            .allowsHitTesting(false)

            HStack(spacing: 18) {
                HStack {
                    AppShellFooterTabButton(
                        title: L10n.string("tab.home"),
                        systemImage: "house.fill",
                        isSelected: selectedTab == .home,
                        selectionNamespace: footerSelectionAnimation,
                        accessibilityIdentifier: "tab.home"
                    ) {
                        selectTab(.home)
                    }

                    AppShellFooterTabButton(
                        title: L10n.string("tab.library"),
                        systemImage: "heart.fill",
                        isSelected: selectedTab == .library,
                        selectionNamespace: footerSelectionAnimation,
                        accessibilityIdentifier: "tab.library"
                    ) {
                        selectTab(.library)
                    }

                    AppShellFooterTabButton(
                        title: L10n.string("tab.discover"),
                        systemImage: "calendar.badge.clock",
                        isSelected: selectedTab == .discover,
                        selectionNamespace: footerSelectionAnimation,
                        accessibilityIdentifier: "tab.discover"
                    ) {
                        selectTab(.discover)
                    }

                    AppShellFooterTabButton(
                        title: L10n.string("tab.profile"),
                        systemImage: "person.crop.circle.fill",
                        isSelected: selectedTab == .profile,
                        selectionNamespace: footerSelectionAnimation,
                        accessibilityIdentifier: "tab.profile"
                    ) {
                        selectTab(.profile)
                    }
                }
                .padding(.leading, 10)
                .padding(.trailing, 10)
                .padding(.vertical, 7)
                .background {
                    Capsule(style: .continuous)
                        .fill(SeriesTheme.footerGlass)
                        .background(.ultraThinMaterial.opacity(0.95), in: Capsule(style: .continuous))
                        .overlay {
                            Capsule(style: .continuous)
                                .stroke(SeriesTheme.glassStroke, lineWidth: 1)
                        }
                    }
                .shadow(color: SeriesTheme.glassShadow, radius: 18, y: 10)

                AppShellFooterSearchButton(isSelected: selectedTab == .search) {
                    selectTab(.search)
                }
                .shadow(color: SeriesTheme.glassShadow, radius: 18, y: 10)
            }
            .frame(maxWidth: 430)
            .padding(.horizontal, 18)
            .padding(.bottom, -8)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

private struct AppShellFooterTabButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let selectionNamespace: Namespace.ID
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(SeriesTheme.footerGlassSelected)
                        .matchedGeometryEffect(id: "footerSelection", in: selectionNamespace)
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(SeriesTheme.glassStroke, lineWidth: 0.8)
                        }
                }

                Image(systemName: displayedSystemImage)
                    .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                    .frame(width: 20, height: 20)
                    .symbolRenderingMode(.monochrome)
            }
            .foregroundStyle(isSelected ? SeriesTheme.highlight : SeriesTheme.textSecondary)
            .frame(width: 64, height: 46)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var displayedSystemImage: String {
        guard !isSelected else { return systemImage }
        return systemImage.replacingOccurrences(of: ".fill", with: "")
    }
}

private struct AppShellFooterSearchButton: View {
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(SeriesTheme.footerGlass)
                    .background(.ultraThinMaterial.opacity(0.95), in: Circle())
                    .overlay {
                        Circle()
                            .stroke(SeriesTheme.glassStroke, lineWidth: 1)
                    }

                if isSelected {
                    Circle()
                        .fill(SeriesTheme.footerGlassSelected)
                        .padding(4)
                }

                Image(systemName: "magnifyingglass")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isSelected ? SeriesTheme.highlight : SeriesTheme.textSecondary)
            }
            .frame(width: 62, height: 62)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.string("tab.search"))
        .accessibilityIdentifier("tab.search")
    }
}

private var seriesCardBackground: some View {
    RoundedRectangle(cornerRadius: 24, style: .continuous)
        .fill(SeriesTheme.cardSurface)
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(SeriesTheme.borderSubtle, lineWidth: 1)
        }
}
