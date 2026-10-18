import AppKit
import VoiceNotesCore

enum DictationSound {
    private static let listeningSound = "Tink"
    private static let stoppedSound = "Pop"
    private static let errorSound = "Basso"

    static func play(for phase: DictationPhase) {
        switch phase {
        case .listening: NSSound(named: listeningSound)?.play()
        case .transcribing: NSSound(named: stoppedSound)?.play()
        case .idle, .paused: return
        }
    }

    static func playError() {
        NSSound(named: errorSound)?.play()
    }
}
