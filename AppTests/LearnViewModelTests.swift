import Foundation
import StudyCore
import Testing

@testable import EnglishCards

@MainActor
@Suite struct LearnViewModelTests {
    private struct Rig {
        let model: LearnViewModel
        let study: StudyService
        let settings: SettingsStore
        let speech: SpySpeech
    }

    private func makeRig(autoSpeak: Bool = false) throws -> Rig {
        let now = TestNow(testDate(2026, 10, 8))
        let engine = try StudyEngine(
            catalog: makeTestCatalog(), repository: InMemoryProgressRepository(), settings: StudySettings(),
            clock: testClock(), now: { now.value })
        let study = StudyService(engine: engine)
        let settings = SettingsStore(defaults: makeTestDefaults())
        settings.update { $0.autoSpeak = autoSpeak }
        let speech = SpySpeech()
        let haptics = HapticsService()
        haptics.isEnabled = false
        let model = LearnViewModel(study: study, settings: settings, speech: speech, haptics: haptics)
        model.flyOutDuration = 0
        return Rig(model: model, study: study, settings: settings, speech: speech)
    }

    @Test func englishIsShownFirstByDefault() throws {
        let rig = try makeRig()
        #expect(rig.model.direction == .enToRu)
        #expect(rig.model.frontSide == .english && rig.model.backSide == .russian)
        #expect(rig.model.englishVisible)
        rig.model.flip()
        #expect(rig.model.isFlipped && !rig.model.englishVisible)
    }

    @Test func russianFirstDirectionSwapsTheSides() throws {
        let rig = try makeRig()
        rig.model.toggleDirection()
        #expect(rig.settings.values.direction == .ruToEn)
        #expect(rig.model.frontSide == .russian && !rig.model.englishVisible)
        rig.model.flip()
        #expect(rig.model.englishVisible)
        rig.model.toggleDirection()
        #expect(rig.settings.values.direction == .enToRu)
        #expect(!rig.model.isFlipped, "switching the direction shows the front again")
    }

    @Test func learnedAdvancesAndShowsTheFrontOfTheNextCard() async throws {
        let rig = try makeRig()
        let first = try #require(rig.model.currentWord)
        rig.model.flip()
        await rig.model.decide(.learned)
        #expect(rig.model.currentWord?.id != first.id)
        #expect(!rig.model.isFlipped)
        #expect(rig.study.plan.learnedCount == 1)
        #expect(rig.model.subtitle == "Выучено 1 из 60 за сегодня")
        #expect(rig.model.progressFraction == 1.0 / 60)
        #expect(rig.model.dragWidth == 0 && rig.model.dragHeight == 0)
        #expect(!rig.model.isBusy)
    }

    @Test func stillLearningAndKnownTakeEffect() async throws {
        let rig = try makeRig()
        let first = try #require(rig.model.currentWord)
        await rig.model.decide(.stillLearning)
        #expect(rig.study.status(of: first.id) == .learning)
        let second = try #require(rig.model.currentWord)
        await rig.model.decide(.known)
        #expect(rig.study.status(of: second.id) == .known)
        #expect(rig.study.plan.totalCount == 59)
    }

    @Test func undoRestoresTheCard() async throws {
        let rig = try makeRig()
        let first = try #require(rig.model.currentWord)
        await rig.model.decide(.learned)
        rig.model.undo()
        #expect(rig.model.currentWord?.id == first.id)
        #expect(rig.study.plan.learnedCount == 0)
        rig.model.undo()  // nothing left to undo: no crash, no change
        #expect(rig.model.currentWord?.id == first.id)
    }

    @Test func farDragsDecideAndShortOnesSpringBack() async throws {
        let rig = try makeRig()
        let first = try #require(rig.model.currentWord)

        rig.model.dragChanged(width: 60, height: 10)
        #expect(rig.model.dragWidth == 60)
        await rig.model.dragEnded(width: 60, predictedEndWidth: 80)
        #expect(rig.model.currentWord?.id == first.id, "a short drag keeps the card")
        #expect(rig.model.dragWidth == 0)

        rig.model.dragChanged(width: 140, height: 0)
        await rig.model.dragEnded(width: 140, predictedEndWidth: 200)
        #expect(rig.study.status(of: first.id) == .review, "dragging right means learned")

        let second = try #require(rig.model.currentWord)
        await rig.model.dragEnded(width: -130, predictedEndWidth: -130)
        #expect(rig.study.status(of: second.id) == .learning, "dragging left means still learning")
    }

    @Test func autoSpeakReadsTheEnglishWordWhenItAppears() async throws {
        let rig = try makeRig(autoSpeak: true)
        await rig.model.decide(.learned)
        let word = try #require(rig.model.currentWord)
        #expect(rig.speech.spoken.last?.text == word.lemma)

        // Russian first: nothing is read until the English side is revealed.
        rig.model.toggleDirection()
        let before = rig.speech.spoken.count
        await rig.model.decide(.learned)
        #expect(rig.speech.spoken.count == before)
        rig.model.flip()
        #expect(rig.speech.spoken.last?.text == rig.model.currentWord?.lemma)
    }

    @Test func speechUsesTheChosenAccentAndSpeed() throws {
        let rig = try makeRig()
        rig.settings.update { $0.speechAccent = .uk; $0.speechSpeed = .slow }
        rig.model.speakLemma()
        let spoken = try #require(rig.speech.spoken.last)
        #expect(spoken.accent == .uk && spoken.speed == .slow)
    }

    @Test func nothingIsReadWhenAutoSpeakIsOff() async throws {
        let rig = try makeRig(autoSpeak: false)
        await rig.model.decide(.learned)
        rig.model.flip()
        #expect(rig.speech.spoken.isEmpty)
    }

    @Test func favouriteToggles() throws {
        let rig = try makeRig()
        #expect(!rig.model.isFavorite)
        rig.model.toggleFavorite()
        #expect(rig.model.isFavorite)
        rig.model.toggleFavorite()
        #expect(!rig.model.isFavorite)
    }

    @Test func helpIsMarkedAsSeenOnce() throws {
        let rig = try makeRig()
        #expect(!rig.settings.values.hasSeenHelp)
        rig.model.markHelpSeen()
        #expect(rig.settings.values.hasSeenHelp)
    }

    @Test func finishingTheWholePlanShowsTheDayCompleteState() async throws {
        let rig = try makeRig()
        var settings = rig.study.studySettings
        settings.newWordsPerDay = 3
        // A smaller plan for tomorrow does not change today's.
        rig.study.apply(settings)
        #expect(rig.study.plan.totalCount == 60)

        for _ in 0..<60 { await rig.model.decide(.learned) }
        #expect(rig.study.phase == .dayComplete)
        rig.model.addMoreWords()
        #expect(rig.study.plan.totalCount == 70)
        #expect(rig.model.currentWord != nil)
    }

    @Test func dragOffsetBelongsToOneCardOnly() async throws {
        let rig = try makeRig()
        let first = try #require(rig.model.currentWord)
        rig.model.dragChanged(width: 80, height: 10)
        #expect(rig.model.dragOffset(for: first.id).width == 80)
        #expect(rig.model.dragOffset(for: "another-word") == .zero, "other cards are never moved")

        await rig.model.decide(.learned)
        let second = try #require(rig.model.currentWord)
        #expect(second.id != first.id)
        #expect(rig.model.dragOffset(for: second.id) == .zero)
        #expect(rig.model.dragOffset(for: first.id) == .zero, "the owner is cleared with the reset")
    }

    @Test func aLeftoverOffsetNeverShowsOnTheNextCard() async throws {
        let rig = try makeRig()
        // Simulate stale state: an offset that still has a value but no owner.
        rig.model.dragWidth = 600
        let current = try #require(rig.model.currentWord)
        #expect(rig.model.dragOffset(for: current.id) == .zero)
    }

    @Test func hardWordsLeadToTheRoundCompleteState() async throws {
        let rig = try makeRig()
        // A card marked "still learning" comes back after 7 others, so pressing it on every card
        // would circle among the first eight forever. Keep only the first word unlearned.
        let hard = try #require(rig.model.currentWord).id
        var presses = 0
        while case .card = rig.study.phase, presses < 1000 {
            await rig.model.decide(rig.model.currentWord?.id == hard ? .stillLearning : .learned)
            presses += 1
        }
        #expect(presses < 1000)
        #expect(rig.study.phase == .roundComplete(remaining: 1))
        rig.model.continueRound()
        guard case .card = rig.study.phase else { Issue.record("expected a card after continuing"); return }
        rig.model.finishForToday()
        #expect(rig.study.phase == .dayComplete)
    }

    @Test func highlightingBoldsTheStudiedWord() {
        let result = ExampleHighlighter.attributed("They abandoned the car.", lemma: "abandon")
        #expect(String(result.characters) == "They abandoned the car.")
        let bold = result.runs.filter { $0.inlinePresentationIntent == .stronglyEmphasized }
        #expect(bold.map { String(result[$0.range].characters) } == ["abandoned"])
    }
}
