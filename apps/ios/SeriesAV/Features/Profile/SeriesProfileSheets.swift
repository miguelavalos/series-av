import AVBrandFoundation
import AVSettingsFoundation
import SwiftUI

enum SeriesProfileSheetDestination: Identifiable {
    case proPaywall
    case accountDeletion
    case localDataMaintenance
    case inAppBrowser(URL)

    var id: String {
        switch self {
        case .proPaywall: "pro-paywall"
        case .accountDeletion: "account-deletion"
        case .localDataMaintenance: "local-data-maintenance"
        case .inAppBrowser(let url): "in-app-browser:\(url.absoluteString)"
        }
    }
}

struct SeriesLocalDataMaintenanceSheet: View {
    @Environment(\.dismiss) private var dismiss

    let seriesCount: Int
    let clearLocalData: () -> Void

    @State private var isShowingDeleteConfirmation = false

    var body: some View {
        AVSettingsSheetScaffold(
            backgroundStyle: AnyShapeStyle(AVBrandSurface.shellBackground),
            closeTitle: L10n.string("common.cancel"),
            closeAccessibilityIdentifier: "profile.localDataSheet.close",
            onClose: { dismiss() }
        ) {
            AVSettingsSheetHeader(
                title: L10n.string("profile.localDataSheet.title"),
                subtitle: L10n.string("profile.localDataSheet.subtitle"),
                titleAccessibilityIdentifier: "profile.localDataSheet.title"
            )
            AVSettingsDestructiveActionCard(
                sectionTitle: L10n.string("profile.localDataSheet.dangerTitle"),
                systemImage: "trash",
                title: L10n.string("profile.local.delete.title"),
                detail: localDeleteDetail,
                action: { isShowingDeleteConfirmation = true }
            )
            .accessibilityIdentifier("profile.local.delete")
        }
        .alert(L10n.string("profile.local.delete.confirm.title"), isPresented: $isShowingDeleteConfirmation) {
            Button(L10n.string("common.cancel"), role: .cancel) {}
            Button(L10n.string("profile.local.delete.confirm.action"), role: .destructive) {
                clearLocalData()
                dismiss()
            }
        } message: {
            Text(L10n.string("profile.local.delete.confirm.detail"))
        }
    }

    private var localDeleteDetail: String {
        guard seriesCount > 0 else {
            return L10n.string("profile.local.delete.empty")
        }
        return L10n.string("profile.local.delete.detail", seriesCount)
    }
}
