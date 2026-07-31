import Foundation

enum SeriesSubscriptionEntitlementPolicy {
    static let proEntitlementIdentifier = "pro"

    static func hasActiveProEntitlement(_ activeEntitlementIdentifiers: Set<String>) -> Bool {
        activeEntitlementIdentifiers.contains(proEntitlementIdentifier)
    }
}
