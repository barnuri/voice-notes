import Testing
@testable import VoiceNotesCore

struct MicrophoneSelectionTests {
    private let available = ["built-in", "usb-headset"]

    @Test func storedDeviceThatIsAvailableIsUsed() {
        #expect(MicrophoneSelection.resolve(storedID: "usb-headset", available: available, defaultID: "built-in") == "usb-headset")
    }

    @Test func missingStoredDeviceFallsBackToDefault() {
        #expect(MicrophoneSelection.resolve(storedID: "unplugged", available: available, defaultID: "built-in") == "built-in")
    }

    @Test func systemDefaultChoiceUsesDefault() {
        let resolved = MicrophoneSelection.resolve(
            storedID: AppSettings.systemDefaultMicrophoneID,
            available: available,
            defaultID: "built-in"
        )
        #expect(resolved == "built-in")
    }

    @Test func noDefaultAndMissingStoredResolvesToNil() {
        #expect(MicrophoneSelection.resolve(storedID: "unplugged", available: [], defaultID: nil) == nil)
    }
}
