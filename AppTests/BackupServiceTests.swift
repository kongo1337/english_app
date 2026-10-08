import Foundation
import StudyCore
import Testing

@testable import EnglishCards

@MainActor
@Suite struct BackupServiceTests {
    private func makeRig() throws -> (backup: BackupService, study: StudyService, settings: SettingsStore) {
        let now = TestNow(testDate(2026, 10, 8, 12))
        let engine = try StudyEngine(
            catalog: makeTestCatalog(), repository: InMemoryProgressRepository(), settings: StudySettings(),
            clock: testClock(), now: { now.value })
        let study = StudyService(engine: engine)
        let settings = SettingsStore(defaults: makeTestDefaults())
        return (BackupService(study: study, settings: settings, now: { now.value }), study, settings)
    }

    @Test func exportedFileCanBeReadBack() throws {
        let rig = try makeRig()
        for _ in 0..<4 { rig.study.perform(.learned) }
        rig.settings.update { $0.autoSpeak = true }

        let url = try rig.backup.export()
        #expect(url.lastPathComponent == "english-cards-2026-10-08.json")
        let backup = try rig.backup.read(try Data(contentsOf: url))
        #expect(backup.settings.autoSpeak)
        #expect(backup.payload.progress.count == 4)
        #expect(backup.dictionaryVersion == 1)
    }

    @Test func importOnAFreshInstallRestoresProgressAndSettings() throws {
        let source = try makeRig()
        for _ in 0..<7 { source.study.perform(.learned) }
        source.study.perform(.stillLearning)
        source.settings.update { $0.speechAccent = .uk }
        let data = try Data(contentsOf: try source.backup.export())

        let target = try makeRig()
        let backup = try target.backup.read(data)
        try target.backup.apply(backup)
        #expect(target.study.progress == source.study.progress)
        #expect(target.study.plan == source.study.plan)
        #expect(target.settings.values.speechAccent == .uk)
        #expect(target.settings.values.hasSeenHelp, "the help does not pop up again after an import")
    }

    @Test func notABackupIsRejectedWithoutChangingAnything() throws {
        let rig = try makeRig()
        rig.study.perform(.learned)
        let before = rig.study.progress
        #expect(throws: BackupFailure.unreadable) { try rig.backup.read(Data("[]".utf8)) }
        #expect(rig.study.progress == before)
    }

    @Test func eraseAllLeavesAFreshStudy() throws {
        let rig = try makeRig()
        rig.study.perform(.learned)
        rig.study.eraseAll()
        #expect(rig.study.progress.isEmpty)
        #expect(rig.study.plan.learnedCount == 0)
        #expect(rig.study.canUndoLearn == false)
    }
}
