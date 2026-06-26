import AVAppShellFoundation
import SwiftUI

typealias SeriesLayoutClass = AVAppShellLayoutClass
typealias SeriesLayoutContext = AVAppShellLayoutContext
typealias SeriesAdaptiveLayoutReader = AVAppShellAdaptiveLayoutReader

extension View {
    func seriesReadableContent(maxWidth: CGFloat?, alignment: Alignment = .topLeading) -> some View {
        avAppShellReadableContent(maxWidth: maxWidth, alignment: alignment)
    }
}
