import Foundation
import StudyCore
import SwiftUI

enum CardDirection: String, Codable, CaseIterable, Sendable {
    /// English on the front, Russian on the back.
    case enToRu
    /// Russian on the front, English on the back.
    case ruToEn
}

enum SpeechAccent: String, Codable, CaseIterable, Sendable {
    case us, uk

    var languageCode: String { self == .us ? "en-US" : "en-GB" }
}

enum SpeechSpeed: String, Codable, CaseIterable, Sendable {
    case slow, normal

    /// `AVSpeechUtterance` rates run from 0 to 1, the default being 0.5.
    var rate: Float { self == .slow ? 0.38 : 0.5 }
}

enum ThemeChoice: String, Codable, CaseIterable, Sendable {
    case system, light, dark

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// Everything the user can change in Settings. Stored as one JSON value; keys that are
/// missing (an older version wrote the file) fall back to the defaults.
struct UserSettings: Codable, Equatable, Sendable {
    var study = StudySettings()
    var direction: CardDirection = .enToRu
    var speechAccent: SpeechAccent = .us
    var speechSpeed: SpeechSpeed = .normal
    var autoSpeak = false
    var haptics = true
    var reminderEnabled = true
    var reminderHour = 19
    var reminderMinute = 0
    var theme: ThemeChoice = .system
    /// The "?" help opens by itself once; the red dot disappears after it was opened.
    var hasSeenHelp = false
    /// Notification permission is requested after the first finished session, not at launch.
    var hasFinishedFirstSession = false

    init() {}

    private enum CodingKeys: String, CodingKey {
        case study, direction, speechAccent, speechSpeed, autoSpeak, haptics
        case reminderEnabled, reminderHour, reminderMinute, theme, hasSeenHelp, hasFinishedFirstSession
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = UserSettings()
        study = try c.decodeIfPresent(StudySettings.self, forKey: .study) ?? defaults.study
        direction = try c.decodeIfPresent(CardDirection.self, forKey: .direction) ?? defaults.direction
        speechAccent = try c.decodeIfPresent(SpeechAccent.self, forKey: .speechAccent) ?? defaults.speechAccent
        speechSpeed = try c.decodeIfPresent(SpeechSpeed.self, forKey: .speechSpeed) ?? defaults.speechSpeed
        autoSpeak = try c.decodeIfPresent(Bool.self, forKey: .autoSpeak) ?? defaults.autoSpeak
        haptics = try c.decodeIfPresent(Bool.self, forKey: .haptics) ?? defaults.haptics
        reminderEnabled = try c.decodeIfPresent(Bool.self, forKey: .reminderEnabled) ?? defaults.reminderEnabled
        reminderHour = try c.decodeIfPresent(Int.self, forKey: .reminderHour) ?? defaults.reminderHour
        reminderMinute = try c.decodeIfPresent(Int.self, forKey: .reminderMinute) ?? defaults.reminderMinute
        theme = try c.decodeIfPresent(ThemeChoice.self, forKey: .theme) ?? defaults.theme
        hasSeenHelp = try c.decodeIfPresent(Bool.self, forKey: .hasSeenHelp) ?? defaults.hasSeenHelp
        hasFinishedFirstSession =
            try c.decodeIfPresent(Bool.self, forKey: .hasFinishedFirstSession) ?? defaults.hasFinishedFirstSession
    }
}
