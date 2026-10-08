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
        .accessibilityElement()
        .accessibilityLabel("Прогресс за сегодня")
        .accessibilityValue("\(Int((max(0, min(1, value)) * 100).rounded())) процентов")
    }
}
