import Foundation

enum SeriesAccessMode: String, CaseIterable, Codable, Identifiable {
    case guest
    case signedInFree
    case signedInPro

    var id: String { rawValue }
}

enum SeriesPlanTier: String, Codable {
    case free
    case pro
}

struct SeriesResolvedAccess: Equatable {
    let platformUserId: String?
    let planTier: SeriesPlanTier
    let accessMode: SeriesAccessMode
    let capabilities: SeriesAccessCapabilities
    let limits: SeriesAccessLimits

    static let guest = SeriesResolvedAccess.localFallback(for: .guest)

    static func localFallback(for accessMode: SeriesAccessMode) -> SeriesResolvedAccess {
        SeriesResolvedAccess(
            platformUserId: nil,
            planTier: accessMode == .signedInPro ? .pro : .free,
            accessMode: accessMode,
            capabilities: .forMode(accessMode),
            limits: .forMode(accessMode)
        )
    }
}

struct SeriesAccountUser: Codable, Equatable {
    let id: String
    let displayName: String
    let emailAddress: String?
}

struct SeriesAccountSession: Equatable {
    let user: SeriesAccountUser
    let access: SeriesResolvedAccess
}

struct SeriesAccessCapabilities: Codable, Equatable {
    let isSignedIn: Bool
    let canUseBackend: Bool
    let canUsePremiumFeatures: Bool
    let canUseCloudSync: Bool
    let canManagePlan: Bool

    var isLocalOnly: Bool {
        !canUseCloudSync
    }

    var canUpgradeToPro: Bool {
        isSignedIn && !canUsePremiumFeatures
    }

    static func forMode(_ accessMode: SeriesAccessMode) -> SeriesAccessCapabilities {
        switch accessMode {
        case .guest:
            SeriesAccessCapabilities(
                isSignedIn: false,
                canUseBackend: true,
                canUsePremiumFeatures: false,
                canUseCloudSync: false,
                canManagePlan: false
            )
        case .signedInFree:
            SeriesAccessCapabilities(
                isSignedIn: true,
                canUseBackend: true,
                canUsePremiumFeatures: false,
                canUseCloudSync: false,
                canManagePlan: true
            )
        case .signedInPro:
            SeriesAccessCapabilities(
                isSignedIn: true,
                canUseBackend: true,
                canUsePremiumFeatures: true,
                canUseCloudSync: true,
                canManagePlan: true
            )
        }
    }
}

struct SeriesAccessLimits: Codable, Equatable {
    let activeLibrarySeries: Int?

    static func forMode(_ accessMode: SeriesAccessMode) -> SeriesAccessLimits {
        switch accessMode {
        case .guest:
            SeriesAccessLimits(activeLibrarySeries: 25)
        case .signedInFree:
            SeriesAccessLimits(activeLibrarySeries: 75)
        case .signedInPro:
            SeriesAccessLimits(activeLibrarySeries: 1_000)
        }
    }
}
