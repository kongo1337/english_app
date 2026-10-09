import StudyCore
import SwiftUI

enum CardSide { case english, russian }

/// A button-like action shown in the card menu or offered to VoiceOver.
struct CardAction: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let run: @MainActor () -> Void
}

/// The label that fades in on the card while it is dragged to one side.
struct SwipeHint {
    let text: String
    let color: Color
}

/// What the Learn and Review screens share: which side of the card is up, how far it is
/// dragged, speech and haptics. The screens differ only in what a swipe means.
@MainActor
protocol FlashCardModel: AnyObject, Observable {
    var settings: SettingsStore { get }
    var speech: any Speaking { get }
    var haptics: HapticsService { get }

    // Card state. Each model stores these itself so that `@Observable` tracks them.
    var isFlipped: Bool { get set }
    var dragWidth: CGFloat { get set }
    var dragHeight: CGFloat { get set }
    /// The card the drag state belongs to. Any other card ignores it, so a leftover offset can
    /// never show up on the next card.
    var dragOwnerId: String? { get set }
    var isBusy: Bool { get set }
    var flyOutDuration: Double { get set }
    var thresholdHapticFired: Bool { get set }

    var currentWord: Word? { get }
    var isFavorite: Bool { get }
    var hasNextCard: Bool { get }

    var rightHint: SwipeHint { get }
    var leftHint: SwipeHint { get }
    /// Decisions VoiceOver users can trigger without swiping.
    var decisionActions: [CardAction] { get }
    /// Entries of the "…" menu on the card.
    var menuActions: [CardAction] { get }

    /// The card was thrown to a side (by a swipe, a button or a VoiceOver action).
    func swiped(_ direction: SwipeDirection) async
    func toggleFavorite()
}

extension FlashCardModel {
    // MARK: What is shown

    var direction: CardDirection { settings.values.direction }
    var frontSide: CardSide { direction == .enToRu ? .english : .russian }
    var backSide: CardSide { direction == .enToRu ? .russian : .english }
    /// Whether the English word is on screen right now (and may be read aloud).
    var englishVisible: Bool { (isFlipped ? backSide : frontSide) == .english }

    // MARK: Card

    /// How far the card with this id is dragged (zero for every other card).
    func dragOffset(for wordId: String) -> CGSize {
        dragOwnerId == wordId ? CGSize(width: dragWidth, height: dragHeight) : .zero
    }

    func flip() {
        guard currentWord != nil, !isBusy else { return }
        haptics.soft()
        withAnimation(.spring(duration: 0.45, bounce: 0.15)) { isFlipped.toggle() }
        speakIfNeeded()
    }

    /// Moves the card off screen, towards `offset`, and returns once the animation has really
    /// finished. Resetting the card while the animation is still running leaves SwiftUI drawing
    /// the old position (a stale "Выучил" label, or a card stuck beyond the screen edge), so the
    /// caller must not touch the card before this returns.
    func flyOut(to offset: CGSize) async {
        guard flyOutDuration > 0 else { return }
        dragOwnerId = currentWord?.id
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let gate = ResumeOnce(continuation)
            withAnimation(.easeIn(duration: flyOutDuration), completionCriteria: .logicallyComplete) {
                dragWidth = offset.width
                dragHeight = offset.height
            } completion: {
                MainActor.assumeIsolated { gate.fire() }
            }
            // Safety net: never leave the screen waiting if the completion is not delivered.
            let timeout = flyOutDuration + 0.5
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(timeout))
                gate.fire()
            }
        }
    }

    func swipeOffset(for direction: SwipeDirection) -> CGSize {
        CGSize(width: direction == .right ? 600 : -600, height: 0)
    }

    /// Puts the card back face-up in the middle, without animation.
    func resetCard() {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isFlipped = false
            dragWidth = 0
            dragHeight = 0
            dragOwnerId = nil
        }
    }

    /// Called when a different card comes up (also after undo or a new day).
    func cardDidChange() {
        resetCard()
        speakIfNeeded()
    }

    func toggleDirection() {
        settings.update { $0.direction = $0.direction == .enToRu ? .ruToEn : .enToRu }
        resetCard()
        speakIfNeeded()
    }

    // MARK: Dragging

    func dragChanged(width: CGFloat, height: CGFloat) {
        guard !isBusy, let id = currentWord?.id else { return }
        dragOwnerId = id
        dragWidth = width
        dragHeight = height * 0.2
        let reached = abs(width) >= SwipeDecision.distanceThreshold
        if reached, !thresholdHapticFired { haptics.soft() }
        thresholdHapticFired = reached
    }

    func dragEnded(width: CGFloat, predictedEndWidth: CGFloat) async {
        guard !isBusy else { return }
        thresholdHapticFired = false
        if let direction = SwipeDecision.direction(forWidth: width, predictedEndWidth: predictedEndWidth) {
            await swiped(direction)
        } else {
            withAnimation(.spring(duration: 0.35, bounce: 0.3)) {
                dragWidth = 0
                dragHeight = 0
            }
        }
    }

    // MARK: Speech

    func speakLemma() {
        guard let word = currentWord else { return }
        speech.speak(word.lemma, accent: settings.values.speechAccent, speed: settings.values.speechSpeed)
    }

    func speakExample() {
        guard let example = currentWord?.exampleEN else { return }
        speech.speak(example, accent: settings.values.speechAccent, speed: settings.values.speechSpeed)
    }

    func speakIfNeeded() {
        guard settings.values.autoSpeak, englishVisible, currentWord != nil else { return }
        speakLemma()
    }
}

/// Resumes a continuation exactly once, whichever of two callers gets there first.
@MainActor
private final class ResumeOnce {
    private var continuation: CheckedContinuation<Void, Never>?

    init(_ continuation: CheckedContinuation<Void, Never>) {
        self.continuation = continuation
    }

    func fire() {
        continuation?.resume()
        continuation = nil
    }
}
