import StudyCore
import SwiftUI

/// The current card with the next one peeking out from behind, draggable to either side.
struct FlashCardStack<Model: FlashCardModel>: View {
    let model: Model

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
                WordCardView(model: model, word: word)
                    .id(word.id)
                    .offset(x: model.dragWidth, y: model.dragHeight)
                    .rotationEffect(.degrees(SwipeDecision.rotation(forWidth: model.dragWidth)))
                    .gesture(drag)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 340, maxHeight: 470)
    }

    private var drag: some Gesture {
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
