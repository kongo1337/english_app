import StudyCore
import SwiftUI

/// The current card with the next one peeking out from behind, draggable to either side.
/// With accessibility text sizes the screen scrolls and the buttons replace the swipes.
struct FlashCardStack<Model: FlashCardModel>: View {
    let model: Model
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ZStack {
            if model.hasNextCard {
                CardSurface()
                    .scaleEffect(0.94)
                    .offset(y: 16)
                    .opacity(0.7)
                    .accessibilityHidden(true)
            }
            if let word = model.currentWord {
                let drag = model.dragOffset(for: word.id)
                WordCardView(model: model, word: word)
                    .offset(x: drag.width, y: drag.height)
                    .rotationEffect(.degrees(SwipeDecision.rotation(forWidth: drag.width)))
                    .gesture(dragGesture, including: typeSize.isAccessibilitySize ? .subviews : .all)
                    .transition(.identity)
                    // Outermost on purpose: a new word is a brand-new card with its own offset,
                    // rotation and animations, nothing is carried over from the previous one.
                    .id(word.id)
            }
        }
        .frame(maxWidth: .infinity, minHeight: typeSize.isAccessibilitySize ? 460 : 340, maxHeight: typeSize.isAccessibilitySize ? nil : 470)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                model.dragChanged(width: value.translation.width, height: value.translation.height)
            }
            .onEnded { value in
                Task {
                    await model.dragEnded(
                        width: value.translation.width, predictedEndWidth: value.predictedEndTranslation.width)
                }
            }
    }
}
