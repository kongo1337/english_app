import StudyCore
import SwiftUI

/// The state and actions of the Learn screen: which side of the card is up, how far the card
/// is dragged, and what each button does. The study rules themselves live in `StudyEngine`.
@MainActor
@Observable
final class LearnViewModel: FlashCardModel {
    let study: StudyService
    let settings: SettingsStore
    let speech: any Speaking
    let haptics: HapticsService

    var isFlipped = false
    var dragWidth: CGFloat = 0
    var dragHeight: CGFloat = 0
    var dragOwnerId: String?
    var isBusy = false

    /// How long the card flies off screen before the action is applied; tests set it to 0.
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

    var currentWord: Word? { study.currentWord }
    var hasNextCard: Bool { study.plan.queue.count > 1 }

    var progressFraction: Double {
        study.plan.totalCount > 0 ? Double(study.plan.learnedCount) / Double(study.plan.totalCount) : 0
    }

    var isFavorite: Bool {
        currentWord.map { study.progress[$0.id]?.isFavorite ?? false } ?? false
    }

    var subtitle: String {
        LearnTexts.subtitle(learned: study.plan.learnedCount, total: study.plan.totalCount)
    }

    var rightHint: SwipeHint { SwipeHint(text: "Выучил", color: Theme.success) }
    var leftHint: SwipeHint { SwipeHint(text: "Ещё учу", color: Theme.warning) }

    var decisionActions: [CardAction] {
        [
            CardAction(id: "learned", title: "Выучил", systemImage: "checkmark") { [self] in
                Task { await decide(.learned) }
            },
            CardAction(id: "stillLearning", title: "Ещё учу", systemImage: "arrow.uturn.left") { [self] in
                Task { await decide(.stillLearning) }
            },
            CardAction(id: "known", title: "Уже знаю", systemImage: "checkmark.seal") { [self] in
                Task { await decide(.known) }
            },
        ]
    }

    var menuActions: [CardAction] {
        [
            CardAction(id: "known", title: "Уже знаю", systemImage: "checkmark.seal") { [self] in
                Task { await decide(.known) }
            },
            favoriteAction,
        ]
    }

    private var favoriteAction: CardAction {
        CardAction(
            id: "favorite",
            title: isFavorite ? "Убрать из избранного" : "В избранное",
            systemImage: isFavorite ? "star.slash" : "star"
        ) { [self] in toggleFavorite() }
    }

    // MARK: Actions

    func swiped(_ direction: SwipeDirection) async {
        await decide(direction == .right ? .learned : .stillLearning)
    }

    /// Applies an action: the card flies out, then the study state moves on.
    func decide(_ action: LearnAction) async {
        guard !isBusy, currentWord != nil else { return }
        isBusy = true
        await flyOut(to: exitOffset(for: action))
        switch action {
        case .learned, .known: haptics.success()
        case .stillLearning: haptics.light()
        }
        study.perform(action)
        resetCard()
        isBusy = false
        speakIfNeeded()
    }

    func undo() {
        guard study.canUndoLearn, !isBusy else { return }
        haptics.light()
        study.undoLearn()
        resetCard()
        speakIfNeeded()
    }

    func toggleFavorite() {
        guard let word = currentWord else { return }
        study.toggleFavorite(word.id)
    }

    // MARK: Round and day

    func continueRound() { study.continueRound() }
    func finishForToday() { study.finishForToday() }
    func addMoreWords() { study.addMoreWords() }

    func markHelpSeen() {
        guard !settings.values.hasSeenHelp else { return }
        settings.update { $0.hasSeenHelp = true }
    }

    // MARK: Plumbing

    private func exitOffset(for action: LearnAction) -> CGSize {
        switch action {
        case .learned: swipeOffset(for: .right)
        case .stillLearning: swipeOffset(for: .left)
        case .known: CGSize(width: 0, height: -700)
        }
    }
}
