import StudyCore
import SwiftUI

enum CardSide { case english, russian }

/// The state and actions of the Learn screen: which side of the card is up, how far the card
/// is dragged, and what each button does. The study rules themselves live in `StudyEngine`.
@MainActor
@Observable
final class LearnViewModel {
    let study: StudyService
    let settings: SettingsStore
    private let speech: any Speaking
    private let haptics: HapticsService

    var isFlipped = false
    var dragWidth: CGFloat = 0
    var dragHeight: CGFloat = 0
    private(set) var isBusy = false

    /// How long the card flies off screen before the action is applied; tests set it to 0.
    @ObservationIgnored var flyOutDuration: Double = 0.2
    @ObservationIgnored private var thresholdHapticFired = false

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

    var direction: CardDirection { settings.values.direction }
    var currentWord: Word? { study.currentWord }
    var frontSide: CardSide { direction == .enToRu ? .english : .russian }
    var backSide: CardSide { direction == .enToRu ? .russian : .english }
    /// Whether the English word is on screen right now (and may be read aloud).
    var englishVisible: Bool { (isFlipped ? backSide : frontSide) == .english }
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

    // MARK: Card

    func flip() {
        guard currentWord != nil, !isBusy else { return }
        haptics.soft()
        withAnimation(.spring(duration: 0.45, bounce: 0.15)) { isFlipped.toggle() }
        speakIfNeeded()
    }

    /// Applies an action: the card flies out, then the study state moves on.
    func decide(_ action: LearnAction) async {
        guard !isBusy, currentWord != nil else { return }
        isBusy = true
        if flyOutDuration > 0 {
            let exit = exitOffset(for: action)
            withAnimation(.easeIn(duration: flyOutDuration)) {
                dragWidth = exit.width
                dragHeight = exit.height
            }
            try? await Task.sleep(for: .seconds(flyOutDuration))
        }
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

    func toggleDirection() {
        settings.update { $0.direction = $0.direction == .enToRu ? .ruToEn : .enToRu }
        resetCard()
        speakIfNeeded()
    }

    func toggleFavorite() {
        guard let word = currentWord else { return }
        study.toggleFavorite(word.id)
    }

    /// Called when a different card comes up (also after undo or a new day).
    func cardDidChange() {
        resetCard()
        speakIfNeeded()
    }

    // MARK: Dragging

    func dragChanged(width: CGFloat, height: CGFloat) {
        guard !isBusy else { return }
        dragWidth = width
        dragHeight = height * 0.2
        let reached = abs(width) >= SwipeDecision.distanceThreshold
        if reached, !thresholdHapticFired { haptics.soft() }
        thresholdHapticFired = reached
    }

    func dragEnded(width: CGFloat, predictedEndWidth: CGFloat) async {
        guard !isBusy else { return }
        thresholdHapticFired = false
        if let action = SwipeDecision.action(forWidth: width, predictedEndWidth: predictedEndWidth) {
            await decide(action)
        } else {
            withAnimation(.spring(duration: 0.35, bounce: 0.3)) {
                dragWidth = 0
                dragHeight = 0
            }
        }
    }

    // MARK: Round and day

    func continueRound() { study.continueRound() }
    func finishForToday() { study.finishForToday() }
    func addMoreWords() { study.addMoreWords() }

    // MARK: Speech

    func speakLemma() {
        guard let word = currentWord else { return }
        speech.speak(word.lemma, accent: settings.values.speechAccent, speed: settings.values.speechSpeed)
    }

    func speakExample() {
        guard let example = currentWord?.exampleEN else { return }
        speech.speak(example, accent: settings.values.speechAccent, speed: settings.values.speechSpeed)
    }

    private func speakIfNeeded() {
        guard settings.values.autoSpeak, englishVisible, currentWord != nil else { return }
        speakLemma()
    }

    func markHelpSeen() {
        guard !settings.values.hasSeenHelp else { return }
        settings.update { $0.hasSeenHelp = true }
    }

    // MARK: Plumbing

    private func resetCard() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isFlipped = false
            dragWidth = 0
            dragHeight = 0
        }
    }

    private func exitOffset(for action: LearnAction) -> CGSize {
        switch action {
        case .learned: CGSize(width: 600, height: 0)
        case .stillLearning: CGSize(width: -600, height: 0)
        case .known: CGSize(width: 0, height: -700)
        }
    }
}
