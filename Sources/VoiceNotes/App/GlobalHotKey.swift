import Carbon.HIToolbox
import Observation
import VoiceNotesCore

@MainActor
@Observable
final class GlobalHotKey {
    private static let signature: OSType = 0x564E_484B
    private static let hotKeyID = EventHotKeyID(signature: signature, id: 1)

    private(set) var isRegistered = false

    @ObservationIgnored private var hotKeyRef: EventHotKeyRef?
    @ObservationIgnored private var handlerRef: EventHandlerRef?
    @ObservationIgnored private var action: (() -> Void)?

    func register(_ hotKey: HotKey, action: @escaping () -> Void) {
        unregister()
        self.action = action
        installHandlerIfNeeded()
        let status = RegisterEventHotKey(
            hotKey.keyCode,
            hotKey.modifiers,
            Self.hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        isRegistered = status == noErr
        if isRegistered {
            AppLog.info("Dictation shortcut \(hotKey.displayString) is active.")
        } else {
            AppLog.error("Dictation shortcut \(hotKey.displayString) can't be registered (status \(status)). Another app may use it.")
        }
    }

    func unregister() {
        guard let hotKeyRef else { return }
        UnregisterEventHotKey(hotKeyRef)
        self.hotKeyRef = nil
        isRegistered = false
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var pressedEvent = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
                MainActor.assumeIsolated { hotKey.action?() }
                return noErr
            },
            1,
            &pressedEvent,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )
    }
}
