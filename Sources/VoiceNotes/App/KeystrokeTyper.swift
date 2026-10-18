import ApplicationServices
import VoiceNotesCore

@MainActor
final class KeystrokeTyper: TextTyping {
    private static let trustPromptOption = "AXTrustedCheckOptionPrompt"

    static func isTrusted(prompt: Bool) -> Bool {
        AXIsProcessTrustedWithOptions([trustPromptOption: prompt] as CFDictionary)
    }

    func type(_ text: String) throws {
        guard Self.isTrusted(prompt: true) else {
            Clipboard.copy(text)
            throw DictationError.accessibilityDenied
        }
        let source = CGEventSource(stateID: .hidSystemState)
        for character in text {
            let units = Array(String(character).utf16)
            post(units, keyDown: true, source: source)
            post(units, keyDown: false, source: source)
        }
    }

    private func post(_ units: [UniChar], keyDown: Bool, source: CGEventSource?) {
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: keyDown) else { return }
        event.flags = []
        event.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
        event.post(tap: .cghidEventTap)
    }
}
