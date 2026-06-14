import AVSettingsFoundation
import SwiftUI

struct SeriesAVSplashView: View {
    var body: some View {
        AVConfiguredSplashScreen()
    }
}

#Preview {
    SeriesAVSplashView()
        .avCommonAppExperience(SeriesAppExperience.experience)
}
