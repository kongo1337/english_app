import Foundation
import Observation
import StudyCore
import SwiftData

/// Everything the screens need, created once the dictionary has been loaded.
@MainActor
@Observable
final class AppEnvironment {
    let catalog: WordCatalog
    let study: StudyService
    let settings: SettingsStore
    let speech: any Speaking
    let haptics: HapticsService

    init(catalog: WordCatalog, study: StudyService, settings: SettingsStore, speech: any Speaking, haptics: HapticsService) {
        self.catalog = catalog
        self.study = study
        self.settings = settings
        self.speech = speech
        self.haptics = haptics
    }
}

/// Loads the dictionary and the storage in the background, then hands out the environment.
@MainActor
@Observable
final class AppModel {
    enum State {
        case loading
        case ready(AppEnvironment)
        case failed(String)
    }

    private(set) var state: State = .loading

    @ObservationIgnored private let options: LaunchOptions
    @ObservationIgnored private var container: ModelContainer?
    @ObservationIgnored private var started = false

    init(options: LaunchOptions = .current) {
        self.options = options
    }

    func start() async {
        guard !started else { return }
        started = true
        do {
            // Decoding ~1.6 MB of JSON stays off the main thread; the splash is shown meanwhile.
            let catalog = try await Task.detached(priority: .userInitiated) {
                try AppResources.loadCatalog()
            }.value
            state = .ready(try makeEnvironment(catalog: catalog))
        } catch {
            state = .failed(String(describing: error))
        }
    }

    private func makeEnvironment(catalog: WordCatalog) throws -> AppEnvironment {
        let defaults: UserDefaults
        if options.uiTesting {
            // A throw-away settings domain: every UI test run starts from scratch.
            let suite = "uitesting"
            UserDefaults.standard.removePersistentDomain(forName: suite)
            defaults = UserDefaults(suiteName: suite) ?? .standard
        } else {
            defaults = .standard
        }
        let settings = SettingsStore(defaults: defaults)
        if options.uiTesting {
            // The help sheet would cover the screen in every UI test.
            settings.update {
                $0.hasSeenHelp = true
                if let count = options.newWordsPerDay { $0.study.newWordsPerDay = count }
            }
        }

        let container = try Persistence.makeContainer(inMemory: options.uiTesting)
        self.container = container
        let repository = SwiftDataProgressRepository(container: container)

        let fixedNow = options.fixedNow
        let clock = DayClock()
        if options.uiTesting, let count = options.seedReviews, count > 0 {
            let today = clock.dayKey(for: fixedNow ?? Date())
            let seeded = catalog.words.prefix(count).map {
                WordProgress(wordId: $0.id, status: .review, box: 1, dueDayKey: today, timesSeen: 1)
            }
            try repository.commit(StateChange(progress: Array(seeded)))
        }
        let engine = try StudyEngine(
            catalog: catalog, repository: repository, settings: settings.values.study,
            clock: clock, now: { fixedNow ?? Date() })
        let study = StudyService(engine: engine)

        let haptics = HapticsService()
        haptics.isEnabled = settings.values.haptics
        settings.didChange = { [weak study, haptics] values in
            study?.apply(values.study)
            haptics.isEnabled = values.haptics
        }

        return AppEnvironment(
            catalog: catalog, study: study, settings: settings, speech: SpeechService(), haptics: haptics)
    }
}
