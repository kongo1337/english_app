import Foundation
import Observation
import StudyCore
import SwiftUI

/// The observable, persisted `UserSettings`. Views read `values` and change it through
/// `update(_:)` or a `binding(_:)`; every change is written to `UserDefaults` immediately.
@MainActor
@Observable
final class SettingsStore {
    private(set) var values: UserSettings

    /// Called after every change, with the new values (the app uses it to push study
    /// settings into the engine).
    @ObservationIgnored var didChange: (@MainActor (UserSettings) -> Void)?

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let key = "settings.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let stored = try? JSONDecoder().decode(UserSettings.self, from: data) {
            values = stored
        } else {
            // First launch: the study order gets its own stable random seed.
            var fresh = UserSettings()
            fresh.study.seed = UInt64.random(in: .min ... .max)
            values = fresh
            persist()
        }
    }

    func update(_ change: (inout UserSettings) -> Void) {
        var next = values
        change(&next)
        guard next != values else { return }
        values = next
        persist()
        didChange?(next)
    }

    /// A SwiftUI binding to one setting.
    func binding<Value>(_ keyPath: WritableKeyPath<UserSettings, Value>) -> Binding<Value> {
        Binding(
            get: { self.values[keyPath: keyPath] },
            set: { newValue in self.update { $0[keyPath: keyPath] = newValue } })
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(values) {
            defaults.set(data, forKey: key)
        }
    }
}
