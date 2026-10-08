import Foundation
import StudyCore
import Testing

@testable import EnglishCards

@MainActor
final class SpyCenter: ReminderCenter {
    var granted = true
    private(set) var authorizationRequests = 0
    private(set) var scheduled: [PlannedReminder] = []
    private(set) var removeAllCalls = 0

    func requestAuthorization() async -> Bool {
        authorizationRequests += 1
        return granted
    }

    func replaceAll(_ reminders: [PlannedReminder], calendar: Calendar) async { scheduled = reminders }
    func removeAll() {
        removeAllCalls += 1
        scheduled = []
    }
}

@MainActor
@Suite struct ReminderServiceTests {
    private struct Rig {
        let service: ReminderService
        let center: SpyCenter
        let settings: SettingsStore
        let study: StudyService
    }

    private func makeRig() throws -> Rig {
        let now = TestNow(testDate(2026, 10, 8, 9))
        let engine = try StudyEngine(
            catalog: makeTestCatalog(), repository: InMemoryProgressRepository(), settings: StudySettings(),
            clock: testClock(), now: { now.value })
        let study = StudyService(engine: engine)
        let settings = SettingsStore(defaults: makeTestDefaults())
        let center = SpyCenter()
        let service = ReminderService(study: study, settings: settings, center: center, now: { now.value })
        return Rig(service: service, center: center, settings: settings, study: study)
    }

    @Test func nothingIsAskedOrScheduledBeforeTheFirstFinishedSession() async throws {
        let rig = try makeRig()
        await rig.service.refresh()
        #expect(rig.center.authorizationRequests == 0)
        #expect(rig.center.scheduled.isEmpty)
    }

    @Test func afterTheFirstSessionTheNextSevenDaysAreScheduled() async throws {
        let rig = try makeRig()
        rig.service.noteSessionFinished()
        #expect(rig.settings.values.hasFinishedFirstSession)
        await rig.service.refresh()
        #expect(rig.center.authorizationRequests == 1)
        #expect(rig.center.scheduled.count == 7)
        #expect(rig.center.scheduled.first?.body == "Сегодня ещё 60 новых слов.")
    }

    @Test func finishingThePlanDropsTodaysReminder() async throws {
        let rig = try makeRig()
        rig.service.noteSessionFinished()
        let before = rig.service.signature
        while case .card = rig.study.phase { rig.study.perform(.learned) }
        #expect(rig.service.signature != before, "progress must trigger a re-plan")
        await rig.service.refresh()
        #expect(rig.center.scheduled.count == 6)
    }

    @Test func switchingRemindersOffCancelsThem() async throws {
        let rig = try makeRig()
        rig.service.noteSessionFinished()
        await rig.service.refresh()
        rig.settings.update { $0.reminderEnabled = false }
        await rig.service.refresh()
        #expect(rig.center.scheduled.isEmpty)
        #expect(rig.center.removeAllCalls == 1)
    }

    @Test func deniedPermissionSchedulesNothing() async throws {
        let rig = try makeRig()
        rig.center.granted = false
        rig.service.noteSessionFinished()
        await rig.service.refresh()
        #expect(rig.center.scheduled.isEmpty)
    }

    @Test func changingTheTimeChangesTheSignature() throws {
        let rig = try makeRig()
        let before = rig.service.signature
        rig.settings.update { $0.reminderHour = 8 }
        #expect(rig.service.signature != before)
    }
}
