import AVFoundation
import Foundation

@MainActor
protocol Speaking: AnyObject {
    func speak(_ text: String, accent: SpeechAccent, speed: SpeechSpeed)
    func stop()
}

/// Reads English text aloud with the system voices (offline). The audio session uses the
/// `.playback` category, so speech is audible even with the silent switch on.
@MainActor
final class SpeechService: NSObject, Speaking, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, accent: SpeechAccent, speed: SpeechSpeed) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        stop()
        activateSession()

        let utterance = AVSpeechUtterance(string: trimmed)
        // Without an English voice the system would read English with a Russian one.
        utterance.voice = AVSpeechSynthesisVoice(language: accent.languageCode)
            ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = speed.rate
        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    private func activateSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)
    }

    private func deactivateIfIdle() {
        guard !synthesizer.isSpeaking else { return }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.deactivateIfIdle() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.deactivateIfIdle() }
    }
}
