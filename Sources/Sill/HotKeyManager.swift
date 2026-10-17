import AppKit
import Carbon

/// System-registered shortcuts do not intercept or log arbitrary keyboard input.
final class HotKeyManager {
    private var refs: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?
    var onSearch: (() -> Void)?
    var onNumber: ((Int) -> Void)?
    var error: String?
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
        refs.forEach { UnregisterEventHotKey($0) }; refs.removeAll(); error = nil
        if Preferences.shared.searchShortcut { register(code: UInt32(kVK_Space), modifiers: UInt32(controlKey | optionKey), id: 1) }
        if Preferences.shared.numberShortcut {
            let keys = [kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5, kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9]
            for (i, key) in keys.enumerated() { register(code: UInt32(key), modifiers: UInt32(controlKey | optionKey), id: UInt32(i + 11)) }
        }
    }
    private func register(code: UInt32, modifiers: UInt32, id: UInt32) {
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(code, modifiers, EventHotKeyID(signature: 0x53494C4C, id: id), GetApplicationEventTarget(), 0, &ref)
        if status == noErr, let ref { refs.append(ref) }
        else { error = L("快捷键被其他应用占用，请从菜单栏打开搜索。", "A shortcut is in use by another app. Open Search from the menu bar.") }
    }
    deinit { refs.forEach { UnregisterEventHotKey($0) }; if let handler { RemoveEventHandler(handler) } }
}
