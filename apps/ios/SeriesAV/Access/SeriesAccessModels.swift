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

/// What the current access mode can do. Cloud sync of the library is the only Pro-exclusive capability;
/// the backend contract may carry more fields, which are ignored here.
struct SeriesAccessCapabilities: Codable, Equatable {
    let isSignedIn: Bool
    let canUseBackend: Bool
    let canUseCloudSync: Bool
    let canManagePlan: Bool

    var isLocalOnly: Bool {
        !canUseCloudSync
    }

    static func forMode(_ accessMode: SeriesAccessMode) -> SeriesAccessCapabilities {
        switch accessMode {
        case .guest:
            SeriesAccessCapabilities(
                isSignedIn: false,
                canUseBackend: true,
                canUseCloudSync: false,
                canManagePlan: false
            )
        case .signedInFree:
            SeriesAccessCapabilities(
                isSignedIn: true,
                canUseBackend: true,
                canUseCloudSync: false,
                canManagePlan: true
            )
        case .signedInPro:
            SeriesAccessCapabilities(
                isSignedIn: true,
                canUseBackend: true,
                canUseCloudSync: true,
                canManagePlan: true
            )
        }
    }
}

/// Plan limits the app enforces. Guest 25, Free 75, Pro 1000 active series; `nil` is unlimited.
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
