import SwiftUI

/// Two faces on one card that turn around the vertical axis. It is `Animatable`, so while an
/// animation runs SwiftUI feeds it every intermediate angle: the front is drawn up to 90°,
/// then the (mirrored) back takes over, exactly at the moment the card is edge-on.
struct FlipView<Front: View, Back: View>: View, Animatable {
    var angle: Double
    private let front: Front
    private let back: Back

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    init(isFlipped: Bool, @ViewBuilder front: () -> Front, @ViewBuilder back: () -> Back) {
        angle = isFlipped ? 180 : 0
        self.front = front()
        self.back = back()
    }

    var body: some View {
        ZStack {
            if angle < 90 {
                front
            } else {
                back.rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            }
        }
        .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
    }
}
