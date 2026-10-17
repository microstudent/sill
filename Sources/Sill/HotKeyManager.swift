import AppKit
import Carbon
import Combine
import SillCore

/// System-registered shortcuts do not intercept or log arbitrary keyboard input.
final class HotKeyManager: ObservableObject {
    private var refs: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?
    var onSearch: (() -> Void)?
    var onNumber: ((Int) -> Void)?
    @Published private(set) var error: String?
    private var recording = false
    init() {
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, data in
            guard let event, let data else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            let manager = Unmanaged<HotKeyManager>.fromOpaque(data).takeUnretainedValue()
            if id.id == 1 { manager.onSearch?() } else { manager.onNumber?(Int(id.id) - 10) }
            return noErr
        }, 1, &event, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }
    func configure() {
        guard !recording else { return }
        error = install(Preferences.shared.shortcuts)
    }
    func beginRecording() { recording = true; unregister() }
    func endRecording() { recording = false; configure() }
    /// Verify the whole enabled set before persisting. Restore the working set on failure.
    func apply(_ candidate: ShortcutConfiguration) -> String? {
        guard candidate.isValid else {
            return candidate.hasCollision
                ? L("搜索快捷键与数字切换重复，请换一个组合。", "Search conflicts with number switching. Choose another combination.")
                : L("请包含 Control、Option 或 Command 键。", "Include Control, Option or Command.")
        }
        let previous = Preferences.shared.shortcuts
        if let failure = install(candidate) {
            let restoreError = install(previous)
            error = restoreError
            if recording { unregister() }
            return failure
        }
        Preferences.shared.shortcuts = candidate
        error = nil
        if recording { unregister() }
        return nil
    }
    func setEnabled(search: Bool? = nil, numbers: Bool? = nil) -> String? {
        let p = Preferences.shared
        let previousSearch = p.searchShortcut, previousNumbers = p.numberShortcut
        if let search { p.searchShortcut = search }
        if let numbers { p.numberShortcut = numbers }
        if let failure = install(p.shortcuts) {
            p.searchShortcut = previousSearch; p.numberShortcut = previousNumbers
            error = install(p.shortcuts)
            return failure
        }
        error = nil
        return nil
    }
    private func unregister() { refs.forEach { UnregisterEventHotKey($0) }; refs.removeAll() }
    private func install(_ config: ShortcutConfiguration) -> String? {
        unregister()
        let p = Preferences.shared
        var bindings: [(UInt32, ShortcutModifiers, UInt32)] = []
        if p.searchShortcut { bindings.append((config.search.keyCode, config.search.modifiers, 1)) }
        if p.numberShortcut {
            bindings += ShortcutConfiguration.numberKeyCodes.enumerated().map { ($0.element, config.numberModifiers, UInt32($0.offset + 11)) }
        }
        for (code, modifiers, id) in bindings {
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(code, modifiers.carbonFlags, EventHotKeyID(signature: 0x53494C4C, id: id), GetApplicationEventTarget(), OptionBits(kEventHotKeyExclusive), &ref)
            guard status == noErr, let ref else {
                unregister()
                return L("无法注册此组合键，可能已被系统或其他应用占用。请换一个组合。", "This shortcut could not be registered. It may be in use by the system or another app. Choose another combination.")
            }
            refs.append(ref)
        }
        return nil
    }
    deinit { refs.forEach { UnregisterEventHotKey($0) }; if let handler { RemoveEventHandler(handler) } }
}

extension ShortcutModifiers {
    var carbonFlags: UInt32 {
        (contains(.control) ? UInt32(controlKey) : 0) | (contains(.option) ? UInt32(optionKey) : 0)
        | (contains(.shift) ? UInt32(shiftKey) : 0) | (contains(.command) ? UInt32(cmdKey) : 0)
    }
    init(_ flags: NSEvent.ModifierFlags) {
        self = []
        if flags.contains(.control) { insert(.control) }
        if flags.contains(.option) { insert(.option) }
        if flags.contains(.shift) { insert(.shift) }
        if flags.contains(.command) { insert(.command) }
    }
}
