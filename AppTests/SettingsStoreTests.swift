import Foundation
import StudyCore
import Testing

@testable import EnglishCards

@MainActor
@Suite struct SettingsStoreTests {
    @Test func startsWithTheDocumentedDefaults() {
        let store = SettingsStore(defaults: makeTestDefaults())
        let values = store.values
        #expect(values.study.newWordsPerDay == 60 && values.study.carryoverBuffer == 20)
        #expect(values.study.enabledLists == [.ox3000, .ox5000])
        #expect(values.study.levels == Set(CEFRLevel.allCases))
        #expect(values.study.order == .byLevel)
        #expect(values.study.reviewLimit == nil)
        #expect(values.study.dayStartHour == 4)
        #expect(values.direction == .enToRu)
        #expect(values.speechAccent == .us && values.speechSpeed == .normal && !values.autoSpeak)
        #expect(values.haptics && values.reminderEnabled)
        #expect(values.reminderHour == 19 && values.reminderMinute == 0)
        #expect(values.theme == .system)
        #expect(!values.hasSeenHelp)
    }

    @Test func changesSurviveRecreatingTheStore() {
        let defaults = makeTestDefaults()
        let store = SettingsStore(defaults: defaults)
        store.update {
            $0.study.newWordsPerDay = 35
            $0.study.reviewLimit = 100
            $0.study.enabledLists = [.ox5000]
            $0.direction = .ruToEn
            $0.theme = .dark
        }
        let reloaded = SettingsStore(defaults: defaults).values
        #expect(reloaded == store.values)
        #expect(reloaded.study.newWordsPerDay == 35 && reloaded.study.reviewLimit == 100)
        #expect(reloaded.study.enabledLists == [.ox5000])
        #expect(reloaded.direction == .ruToEn && reloaded.theme == .dark)
    }

    @Test func theStudySeedIsGeneratedOnceAndKept() {
        let defaults = makeTestDefaults()
        let first = SettingsStore(defaults: defaults).values.study.seed
        let second = SettingsStore(defaults: defaults).values.study.seed
        #expect(first == second)
        #expect(SettingsStore(defaults: makeTestDefaults()).values.study.seed != first)
    }

    @Test func missingKeysFallBackToDefaults() throws {
        let defaults = makeTestDefaults()
        defaults.set(Data(#"{"direction":"ruToEn","haptics":false}"#.utf8), forKey: "settings.v1")
        let values = SettingsStore(defaults: defaults).values
        #expect(values.direction == .ruToEn && !values.haptics)
        #expect(values.study.newWordsPerDay == 60)
        #expect(values.speechAccent == .us && values.theme == .system)
    }

    @Test func corruptDataIsReplacedByDefaults() {
        let defaults = makeTestDefaults()
        defaults.set(Data("not json".utf8), forKey: "settings.v1")
        #expect(SettingsStore(defaults: defaults).values.study.newWordsPerDay == 60)
    }

    @Test func notifiesOnlyWhenSomethingChanged() {
        let store = SettingsStore(defaults: makeTestDefaults())
        var notifications = 0
        store.didChange = { _ in notifications += 1 }
        store.update { $0.haptics = true }  // already true
        #expect(notifications == 0)
        store.update { $0.haptics = false }
        #expect(notifications == 1)
    }

    @Test func bindingReadsAndWrites() {
        let store = SettingsStore(defaults: makeTestDefaults())
        let binding = store.binding(\.autoSpeak)
        #expect(binding.wrappedValue == false)
        binding.wrappedValue = true
        #expect(store.values.autoSpeak)
    }

    @Test func speechOptionsMapToSystemValues() {
        #expect(SpeechAccent.us.languageCode == "en-US")
        #expect(SpeechAccent.uk.languageCode == "en-GB")
        #expect(SpeechSpeed.slow.rate < SpeechSpeed.normal.rate)
        #expect(ThemeChoice.system.colorScheme == nil)
    }
}

@Suite struct LaunchOptionsTests {
    @Test func parsesTestingArguments() {
        let options = LaunchOptions.parse(["App", "-uiTesting", "-fixedNow", "2026-10-08T12:00:00Z"])
        #expect(options.uiTesting)
        #expect(options.fixedNow == Date(timeIntervalSince1970: 1_791_460_800))
    }

    @Test func parsesTheSeededReviews() {
        #expect(LaunchOptions.parse(["App", "-uiTesting", "-seedReviews", "4"]).seedReviews == 4)
        #expect(LaunchOptions.parse(["App"]).seedReviews == nil)
    }

    @Test func parsesTheDailyPlanSize() {
        #expect(LaunchOptions.parse(["App", "-uiTesting", "-newWordsPerDay", "3"]).newWordsPerDay == 3)
        #expect(LaunchOptions.parse(["App", "-newWordsPerDay", "many"]).newWordsPerDay == nil)
    }

    @Test func defaultsToNormalLaunch() {
        #expect(LaunchOptions.parse(["App"]) == LaunchOptions())
        #expect(LaunchOptions.parse(["App", "-fixedNow"]).fixedNow == nil)
    }
}
