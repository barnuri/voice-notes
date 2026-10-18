import Foundation

public struct HotKey: Codable, Equatable, Sendable {
    public static let commandModifier: UInt32 = 0x0100
    public static let shiftModifier: UInt32 = 0x0200
    public static let optionModifier: UInt32 = 0x0800
    public static let controlModifier: UInt32 = 0x1000
    private static let spaceKeyCode: UInt32 = 49
    private static let modifierSymbols: [(modifier: UInt32, symbol: String)] = [
        (controlModifier, "⌃"),
        (optionModifier, "⌥"),
        (shiftModifier, "⇧"),
        (commandModifier, "⌘"),
    ]

    public static let defaultDictation = HotKey(
        keyCode: spaceKeyCode,
        modifiers: controlModifier | optionModifier,
        keyLabel: "Space"
    )

    public let keyCode: UInt32
    public let modifiers: UInt32
    public let keyLabel: String

    public init(keyCode: UInt32, modifiers: UInt32, keyLabel: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.keyLabel = keyLabel
    }

    public var displayString: String {
        let symbols = Self.modifierSymbols.filter { modifiers & $0.modifier != 0 }.map(\.symbol)
        return symbols.joined() + keyLabel
    }
}
