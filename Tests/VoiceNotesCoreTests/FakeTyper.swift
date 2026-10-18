@testable import VoiceNotesCore

@MainActor
final class FakeTyper: TextTyping {
    var failure: DictationError?
    private(set) var typed: [String] = []

    func type(_ text: String) throws {
        if let failure { throw failure }
        typed.append(text)
    }
}
