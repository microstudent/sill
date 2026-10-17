/// A small, testable policy for search commands. Composition and ordinary text
/// editing remain owned by the macOS text input system.
public enum SearchKeyboard {
    public enum Modifier: Hashable { case command, control, option, shift }
    public enum Command: Equatable { case dismiss, activate, move(Int), close, minimize, hide }

    public static func command(keyCode: UInt16, characters: String?, modifiers: Set<Modifier>, hasMarkedText: Bool) -> Command? {
        guard !hasMarkedText else { return nil }
        if modifiers == [.command] {
            switch characters {
            case "w": return .close
            case "m": return .minimize
            case "h": return .hide
            default: return nil
            }
        }
        guard modifiers.isEmpty || (keyCode == 48 && modifiers == [.shift]) else { return nil }
        switch keyCode {
        case 53: return .dismiss
        case 36, 76: return .activate
        case 125: return .move(1)
        case 126: return .move(-1)
        case 48: return .move(modifiers.contains(.shift) ? -1 : 1)
        default: return nil
        }
    }
}
