import SwiftUI

/// The thin progress line under the Learn header.
struct ProgressBar: View {
    /// 0…1
    var value: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.surfaceMuted)
                Capsule()
                    .fill(Theme.accent)
                    .frame(width: max(0, min(1, value)) * proxy.size.width)
            }
        }
        .frame(height: 6)
        .animation(.easeOut(duration: 0.25), value: value)
        // The subtitle above says the same in words ("Выучено 3 из 60"), so the bar is decorative.
        .accessibilityHidden(true)
    }
}
