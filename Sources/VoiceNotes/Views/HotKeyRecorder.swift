import AppKit
import Carbon.HIToolbox
import SwiftUI
import VoiceNotesCore

struct HotKeyRecorder: View {
    private static let namedKeys: [UInt16: String] = [
        UInt16(kVK_Space): "Space", UInt16(kVK_Return): "Return", UInt16(kVK_Tab): "Tab",
        UInt16(kVK_Delete): "Delete", UInt16(kVK_F1): "F1", UInt16(kVK_F2): "F2",
        UInt16(kVK_F3): "F3", UInt16(kVK_F4): "F4", UInt16(kVK_F5): "F5", UInt16(kVK_F6): "F6",
        UInt16(kVK_F7): "F7", UInt16(kVK_F8): "F8", UInt16(kVK_F9): "F9", UInt16(kVK_F10): "F10",
        UInt16(kVK_F11): "F11", UInt16(kVK_F12): "F12",
    ]
    private static let modifierMap: [(flag: NSEvent.ModifierFlags, modifier: UInt32)] = [
        (.command, HotKey.commandModifier),
        (.shift, HotKey.shiftModifier),
        (.option, HotKey.optionModifier),
        (.control, HotKey.controlModifier),
    ]

    @Binding var hotKey: HotKey
    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        Button(isRecording ? "Press a shortcut…" : hotKey.displayString) {
            isRecording ? stopRecording() : startRecording()
        }
        .onDisappear(perform: stopRecording)
    }

    private func startRecording() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            capture(event)
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }

    private func capture(_ event: NSEvent) {
        defer { stopRecording() }
        guard event.keyCode != UInt16(kVK_Escape) else { return }
        hotKey = HotKey(
            keyCode: UInt32(event.keyCode),
            modifiers: Self.carbonModifiers(from: event.modifierFlags),
            keyLabel: Self.label(for: event)
        )
    }

    private static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        modifierMap.filter { flags.contains($0.flag) }.reduce(0) { $0 | $1.modifier }
    }

    private static func label(for event: NSEvent) -> String {
        if let name = namedKeys[event.keyCode] { return name }
        return (event.charactersIgnoringModifiers ?? "?").uppercased()
    }
}
