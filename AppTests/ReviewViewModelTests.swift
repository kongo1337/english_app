import Foundation
import StudyCore
import Testing

@testable import EnglishCards

@MainActor
@Suite struct ReviewViewModelTests {
    private struct Rig {
        let model: ReviewViewModel
        let study: StudyService
        let speech: SpySpeech
        let today: DayKey
    }

    /// Three words in box 1, all due today.
    private func makeRig(due: Int = 3, autoSpeak: Bool = false) throws -> Rig {
        let now = TestNow(testDate(2026, 10, 8))
        let clock = testClock()
        let today = clock.dayKey(for: now.value)
        let repository = InMemoryProgressRepository()
        let seeded = (1...due).map {
            WordProgress(wordId: "w\($0)", status: .review, box: 1, dueDayKey: today, timesSeen: 1)
        }
        try repository.commit(StateChange(progress: seeded))
        let engine = try StudyEngine(
            catalog: makeTestCatalog(), repository: repository, settings: StudySettings(),
            clock: clock, now: { now.value })
        let study = StudyService(engine: engine)
        let settings = SettingsStore(defaults: makeTestDefaults())
        settings.update { $0.autoSpeak = autoSpeak }
        let speech = SpySpeech()
        let haptics = HapticsService()
        haptics.isEnabled = false
        let model = ReviewViewModel(study: study, settings: settings, speech: speech, haptics: haptics)
        model.flyOutDuration = 0
        return Rig(model: model, study: study, speech: speech, today: today)
    }

    @Test func showsTheDueWordsAndTheirCount() throws {
        let rig = try makeRig()
        #expect(rig.model.currentWord != nil)
        #expect(rig.model.remaining == 3)
        #expect(rig.model.subtitle == "Осталось 3 слова")
        #expect(rig.model.progressFraction == 0)
        #expect(rig.model.hasNextCard)
    }

    @Test func rememberedMovesTheWordToTheNextBox() async throws {
        let rig = try makeRig()
        let first = try #require(rig.model.currentWord)
        rig.model.flip()
        await rig.model.answer(.remembered)
        let progress = try #require(rig.study.progress[first.id])
        #expect(progress.box == 2)
        #expect(progress.dueDayKey == rig.today.adding(days: 3))
        #expect(rig.model.currentWord?.id != first.id)
        #expect(!rig.model.isFlipped)
        #expect(rig.model.remaining == 2)
        #expect(rig.model.progressFraction == 1.0 / 3)
        #expect(!rig.model.isBusy)
    }

    @Test func forgotReturnsTheWordToLearning() async throws {
        let rig = try makeRig()
        let first = try #require(rig.model.currentWord)
        await rig.model.answer(.forgot)
        #expect(rig.study.status(of: first.id) == .learning)
        #expect(rig.study.progress[first.id]?.lapses == 1)
        #expect(rig.model.remaining == 2)
    }

    @Test func swipesMapToAnswers() async throws {
        let rig = try makeRig()
        let first = try #require(rig.model.currentWord)
        await rig.model.swiped(.right)
        #expect(rig.study.progress[first.id]?.box == 2)
        let second = try #require(rig.model.currentWord)
        await rig.model.dragEnded(width: -150, predictedEndWidth: -200)
        #expect(rig.study.status(of: second.id) == .learning)
    }

    @Test func shortDragSnapsBack() async throws {
        let rig = try makeRig()
        let first = try #require(rig.model.currentWord)
        rig.model.dragChanged(width: 40, height: 5)
        #expect(rig.model.dragWidth == 40)
        await rig.model.dragEnded(width: 40, predictedEndWidth: 60)
        #expect(rig.model.currentWord?.id == first.id)
        #expect(rig.model.remaining == 3)
    }

    @Test func undoRestoresTheCardAndTheBox() async throws {
        let rig = try makeRig()
        let first = try #require(rig.model.currentWord)
        #expect(!rig.study.canUndoReview)
        await rig.model.answer(.remembered)
        #expect(rig.study.canUndoReview)
        rig.model.undo()
        #expect(rig.model.currentWord?.id == first.id)
        #expect(rig.study.progress[first.id]?.box == 1)
        #expect(rig.model.remaining == 3)
        #expect(!rig.study.canUndoReview)
    }

    @Test func emptyQueueTellsWhenWordsReturn() async throws {
        let rig = try makeRig(due: 1)
        await rig.model.answer(.remembered)
        #expect(rig.model.currentWord == nil)
        #expect(rig.model.remaining == 0)
        #expect(rig.model.emptyMessage == "Сегодня повторено 1 слово. Через 3 дня повторим 1 слово.")
    }

    @Test func favoriteIsToggledFromTheMenu() throws {
        let rig = try makeRig()
        let first = try #require(rig.model.currentWord)
        #expect(!rig.model.isFavorite)
        rig.model.toggleFavorite()
        #expect(rig.model.isFavorite)
        #expect(rig.study.progress[first.id]?.isFavorite == true)
        #expect(rig.model.menuActions.first?.title == "Убрать из избранного")
    }

    @Test func englishWordIsReadAloudWhenItAppears() async throws {
        let rig = try makeRig(autoSpeak: true)
        rig.model.cardDidChange()
        #expect(rig.speech.spoken.last?.text == rig.model.currentWord?.lemma)
        let before = rig.speech.spoken.count
        rig.model.flip()
        #expect(rig.speech.spoken.count == before, "the Russian side is not read aloud")
    }
}
