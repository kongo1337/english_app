import Foundation
import StudyCore
import UserNotifications

/// The system side of reminders, behind a protocol so tests and UI tests never touch it.
@MainActor
protocol ReminderCenter: AnyObject {
    /// Asks for permission (the system shows its dialog only once) and tells whether it is granted.
    func requestAuthorization() async -> Bool
    /// Cancels every pending reminder and schedules these.
    func replaceAll(_ reminders: [PlannedReminder], calendar: Calendar) async
    func removeAll()
}

@MainActor
final class SystemReminderCenter: ReminderCenter {
    private let center = UNUserNotificationCenter.current()

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func replaceAll(_ reminders: [PlannedReminder], calendar: Calendar) async {
        center.removeAllPendingNotificationRequests()
        for (index, reminder) in reminders.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = ReminderTexts.title
            content.body = reminder.body
            content.sound = .default
            let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            let request = UNNotificationRequest(identifier: "reminder.\(index)", content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    func removeAll() {
        center.removeAllPendingNotificationRequests()
    }
}

/// Used when the app runs under UI tests: nothing is asked and nothing is scheduled.
@MainActor
final class NullReminderCenter: ReminderCenter {
    func requestAuthorization() async -> Bool { false }
    func replaceAll(_ reminders: [PlannedReminder], calendar: Calendar) async {}
    func removeAll() {}
}

/// Keeps the scheduled reminders in line with the progress and the settings: after every
/// change the next days are planned again (see spec §1.8).
@MainActor
final class ReminderService {
    private let study: StudyService
    private let settings: SettingsStore
    private let center: any ReminderCenter
    private let now: @MainActor () -> Date

    init(study: StudyService, settings: SettingsStore, center: any ReminderCenter, now: @escaping @MainActor () -> Date) {
        self.study = study
        self.settings = settings
        self.center = center
        self.now = now
    }

    /// Changes whenever the reminders would have to be planned again.
    var signature: [Int] {
        let values = settings.values
        let remaining = study.plan.totalCount - study.plan.learnedCount
        return [
            values.reminderEnabled ? 1 : 0, values.reminderHour, values.reminderMinute,
            values.hasFinishedFirstSession ? 1 : 0, remaining, study.reviewDueCount, study.today.daysSinceEpoch,
        ]
    }

    /// The permission dialog appears after the first finished session, not at launch.
    func noteSessionFinished() {
        guard !settings.values.hasFinishedFirstSession else { return }
        settings.update { $0.hasFinishedFirstSession = true }
    }

    func refresh() async {
        let values = settings.values
        guard values.reminderEnabled else {
            center.removeAll()
            return
        }
        guard values.hasFinishedFirstSession else { return }
        guard await center.requestAuthorization() else {
            center.removeAll()
            return
        }
        let forecast = StatsCalculator.reviewForecast(progress: study.progress, today: study.today)
        let reminders = ReminderPlanner.plan(
            now: now(), hour: values.reminderHour, minute: values.reminderMinute,
            clock: study.engine.clock, today: study.today,
            newRemaining: study.plan.totalCount - study.plan.learnedCount, reviewForecast: forecast)
        await center.replaceAll(reminders, calendar: study.engine.clock.calendar)
    }
}
