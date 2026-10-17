import Foundation

public struct ShortcutModifiers: OptionSet, Codable, Equatable, Sendable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }
    public static let control = Self(rawValue: 1)
    public static let option = Self(rawValue: 2)
    public static let shift = Self(rawValue: 4)
    public static let command = Self(rawValue: 8)
    public var isValid: Bool { rawValue & ~15 == 0 && !intersection([.control, .option, .command]).isEmpty }
    public var symbols: String {
        (contains(.control) ? "⌃" : "") + (contains(.option) ? "⌥" : "") + (contains(.shift) ? "⇧" : "") + (contains(.command) ? "⌘" : "")
    }
}

public struct GlobalShortcut: Codable, Equatable, Sendable {
    public var keyCode: UInt32
    public var modifiers: ShortcutModifiers
    public var keyLabel: String
    public init(keyCode: UInt32, modifiers: ShortcutModifiers, keyLabel: String) {
        self.keyCode = keyCode; self.modifiers = modifiers; self.keyLabel = keyLabel
    }
    public var display: String { modifiers.symbols + keyLabel }
    public var isValid: Bool {
        modifiers.isValid && keyCode <= 126 && ![53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63].contains(keyCode) && !keyLabel.isEmpty
    }
}

public struct ShortcutConfiguration: Codable, Equatable, Sendable {
    public var search: GlobalShortcut
    public var numberModifiers: ShortcutModifiers
    public static let numberKeyCodes: [UInt32] = [18, 19, 20, 21, 23, 22, 26, 28, 25]
    public static let defaults = Self(search: GlobalShortcut(keyCode: 49, modifiers: [.control, .option], keyLabel: "Space"), numberModifiers: [.control, .option])
    public init(search: GlobalShortcut, numberModifiers: ShortcutModifiers) { self.search = search; self.numberModifiers = numberModifiers }
    public var hasCollision: Bool { search.modifiers == numberModifiers && Self.numberKeyCodes.contains(search.keyCode) }
    public var isValid: Bool { search.isValid && numberModifiers.isValid && !hasCollision }
    public static func restored(from data: Data?) -> Self {
        guard let data, let value = try? JSONDecoder().decode(Self.self, from: data), value.isValid else { return .defaults }
        return value
    }
}
