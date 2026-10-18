import Foundation
import Testing
@testable import VoiceNotesCore

struct HotKeyTests {
    @Test func defaultDictationIsControlOptionSpace() {
        #expect(HotKey.defaultDictation.displayString == "⌃⌥Space")
    }

    @Test func displayOrdersModifiersLikeMacMenus() {
        let hotKey = HotKey(
            keyCode: 2,
            modifiers: HotKey.commandModifier | HotKey.shiftModifier | HotKey.controlModifier,
            keyLabel: "D"
        )
        #expect(hotKey.displayString == "⌃⇧⌘D")
    }

    @Test func displaysSingleKeyWithoutModifiers() {
        #expect(HotKey(keyCode: 96, modifiers: 0, keyLabel: "F5").displayString == "F5")
    }

    @Test func roundTripsThroughJSON() throws {
        let data = try JSONEncoder().encode(HotKey.defaultDictation)
        #expect(try JSONDecoder().decode(HotKey.self, from: data) == .defaultDictation)
    }
}
