import StudyCore
import SwiftUI

/// The Review tab: the same card as on the Learn screen, but a swipe or a button grades how
/// well the word was remembered (right = "Помню", left = "Забыл").
@MainActor
@Observable
final class ReviewViewModel: FlashCardModel {
    let study: StudyService
    let settings: SettingsStore
    let speech: any Speaking
    let haptics: HapticsService

    var isFlipped = false
    var dragWidth: CGFloat = 0
    var dragHeight: CGFloat = 0
    var dragOwnerId: String?
    var isBusy = false

    @ObservationIgnored var flyOutDuration: Double = 0.2
    @ObservationIgnored var thresholdHapticFired = false

    init(study: StudyService, settings: SettingsStore, speech: any Speaking, haptics: HapticsService) {
        self.study = study
        self.settings = settings
        self.speech = speech
        self.haptics = haptics
    }

    convenience init(app: AppEnvironment) {
        self.init(study: app.study, settings: app.settings, speech: app.speech, haptics: app.haptics)
    }

    // MARK: What is shown

    var currentWord: Word? { study.currentReviewWord }
    var hasNextCard: Bool { study.reviewQueue.count > 1 }
    var remaining: Int { study.reviewDueCount }
    var subtitle: String { ReviewTexts.subtitle(remaining: remaining) }

    var progressFraction: Double {
        let answered = study.reviewsAnsweredToday
        let total = answered + remaining
        return total > 0 ? Double(answered) / Double(total) : 0
    }

    var isFavorite: Bool {
        currentWord.map { study.progress[$0.id]?.isFavorite ?? false } ?? false
    }

    /// What to say when the queue is empty: today's tally and when more words come back.
    var emptyMessage: String {
        let forecast = StatsCalculator.reviewForecast(progress: study.progress, today: study.today)
        return ReviewTexts.emptyMessage(forecast: forecast, answeredToday: study.reviewsAnsweredToday)
    }

    var rightHint: SwipeHint { SwipeHint(text: "Помню", color: Theme.success) }
    var leftHint: SwipeHint { SwipeHint(text: "Забыл", color: Theme.warning) }

    var decisionActions: [CardAction] {
        [
            CardAction(id: "remembered", title: "Помню", systemImage: "checkmark") { [self] in
                Task { await answer(.remembered) }
            },
            CardAction(id: "forgot", title: "Забыл", systemImage: "xmark") { [self] in
                Task { await answer(.forgot) }
            },
        ]
    }

    var menuActions: [CardAction] {
        [
            CardAction(
                id: "favorite",
                title: isFavorite ? "Убрать из избранного" : "В избранное",
                systemImage: isFavorite ? "star.slash" : "star"
            ) { [self] in toggleFavorite() }
        ]
    }

    // MARK: Actions

    func swiped(_ direction: SwipeDirection) async {
        await answer(direction == .right ? .remembered : .forgot)
    }

    func answer(_ answer: ReviewAnswer) async {
        guard !isBusy, currentWord != nil else { return }
        isBusy = true
        await flyOut(to: swipeOffset(for: answer == .remembered ? .right : .left))
        switch answer {
        case .remembered: haptics.success()
        case .forgot: haptics.warning()
        }
        study.answer(answer)
        resetCard()
        isBusy = false
        speakIfNeeded()
    }

    func undo() {
        guard study.canUndoReview, !isBusy else { return }
        haptics.light()
        study.undoReview()
        resetCard()
        speakIfNeeded()
    }

    func toggleFavorite() {
        guard let word = currentWord else { return }
        study.toggleFavorite(word.id)
    }
}
