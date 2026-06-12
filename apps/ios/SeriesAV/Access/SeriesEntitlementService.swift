import Foundation
import OSLog

@MainActor
protocol SeriesEntitlementServicing: Sendable {
    func resolveAccess(for user: SeriesAccountUser?) -> SeriesResolvedAccess
    func refreshAccess(for user: SeriesAccountUser?) async -> SeriesResolvedAccess
}

@MainActor
struct SeriesLocalEntitlementService: SeriesEntitlementServicing {
    func resolveAccess(for user: SeriesAccountUser?) -> SeriesResolvedAccess {
        if AppConfig.isDebugForceProModeEnabled {
            return .localFallback(for: .signedInPro)
        }
        guard user != nil else { return .guest }
        return .localFallback(for: .signedInFree)
    }

    func refreshAccess(for user: SeriesAccountUser?) async -> SeriesResolvedAccess {
        resolveAccess(for: user)
    }
}

@MainActor
final class SeriesPlatformEntitlementService: SeriesEntitlementServicing {
    private let fallback: SeriesEntitlementServicing
    private let accessClient: SeriesAccountAccessProviding
    private let logger = Logger(subsystem: "com.avalsys.seriesav", category: "account-access")

    init(
        fallback: SeriesEntitlementServicing = SeriesLocalEntitlementService(),
        accessClient: SeriesAccountAccessProviding
    ) {
        self.fallback = fallback
        self.accessClient = accessClient
    }

    func resolveAccess(for user: SeriesAccountUser?) -> SeriesResolvedAccess {
        fallback.resolveAccess(for: user)
    }

    func refreshAccess(for user: SeriesAccountUser?) async -> SeriesResolvedAccess {
        guard user != nil else { return .guest }

        let fallbackAccess = await fallback.refreshAccess(for: user)
        guard accessClient.isConfigured() else {
            logger.error("Unable to refresh Series AV access: missing API base URL")
            return fallbackAccess
        }

        do {
            let payload = try await accessClient.fetchMeAccess()
            guard let seriesAccess = payload.apps.first(where: { $0.appId == "seriesav" }) else {
                logger.error("Unable to refresh Series AV access: seriesav entry missing")
                return fallbackAccess
            }

            return SeriesResolvedAccess(
                platformUserId: payload.viewer?.userId,
                planTier: seriesAccess.planTier,
                accessMode: seriesAccess.accessMode,
                capabilities: seriesAccess.capabilities,
                limits: seriesAccess.limits
            )
        } catch {
            logger.error("Unable to refresh Series AV access")
            return fallbackAccess
        }
    }
}
