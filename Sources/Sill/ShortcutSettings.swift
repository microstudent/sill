import SwiftUI
import AppKit
import SillCore

struct ShortcutSettings: View {
    @ObservedObject var preferences: Preferences
    @ObservedObject var hotkeys: HotKeyManager
    let search: () -> Void
    @State private var recording = false
    @State private var failure: String?
    @State private var numberModifiers = ShortcutModifiers()
    var body: some View {
        Group {
            Section {
                Toggle(L("启用搜索快捷键", "Enable Search Shortcut"), isOn: Binding(get: { preferences.searchShortcut }, set: { failure = hotkeys.setEnabled(search: $0) }))
                LabeledContent(L("打开窗口搜索", "Open Window Search")) {
                    Button { failure = nil; recording = true } label: {
                        Text(preferences.shortcuts.search.display).font(.system(.body, design: .monospaced)).frame(minWidth: 96)
                    }.help(L("点击后按下新的组合键", "Click, then press a new shortcut"))
                    .accessibilityLabel(L("录制搜索快捷键", "Record Search Shortcut")).accessibilityValue(preferences.shortcuts.search.display)
                }
                Button(L("试用搜索", "Try Search"), action: search)
            } header: { Text(L("窗口搜索", "Window Search")) } footer: {
                Text(L("支持中文、英文、全拼和首字母。用空格组合关键词。", "Search in Chinese, English, full pinyin or initials. Combine keywords with spaces."))
            }
            Section {
                Toggle(L("启用数字切换", "Enable Number Switching"), isOn: Binding(get: { preferences.numberShortcut }, set: { failure = hotkeys.setEnabled(numbers: $0) }))
                LabeledContent(L("组合键", "Shortcut")) {
                    Text(numberModifiers.symbols + "1–9").font(.system(.body, design: .monospaced)).foregroundStyle(.secondary)
                }
                HStack(spacing: 10) {
                    ForEach([ShortcutModifiers.control, .option, .shift, .command], id: \.rawValue) { modifier in
                        Toggle(modifier.symbols, isOn: Binding(get: { numberModifiers.contains(modifier) }, set: {
                            if $0 { numberModifiers.insert(modifier) } else { numberModifiers.remove(modifier) }
                        })).toggleStyle(.button).help(modifierName(modifier))
                    }
                    Spacer()
                    Button(L("应用", "Apply")) {
                        var candidate = preferences.shortcuts; candidate.numberModifiers = numberModifiers
                        failure = hotkeys.apply(candidate)
                    }.disabled(numberModifiers == preferences.shortcuts.numberModifiers)
                }
                Toggle(L("显示窗口编号", "Show Window Numbers"), isOn: $preferences.showNumbers)
            } header: { Text(L("数字切换", "Number Switching")) } footer: {
                Text(L("切换鼠标所在显示器的前 9 个窗口。至少选择 ⌃、⌥ 或 ⌘ 中的一项。", "Switch to the first nine windows on the pointer’s display. Include ⌃, ⌥ or ⌘."))
            }
            if let message = failure ?? hotkeys.error {
                Section { Label(message, systemImage: "exclamationmark.circle").foregroundStyle(.orange).font(.callout) }
            }
            Section {
                LabeledContent(L("选择 / 切换", "Select / Switch"), value: "↑ ↓ / ↩")
                LabeledContent(L("关闭 / 最小化 / 隐藏应用", "Close / Minimize / Hide App"), value: "⌘W / ⌘M / ⌘H")
                Button(L("恢复默认快捷键", "Restore Default Shortcuts")) {
                    failure = hotkeys.apply(.defaults)
                    numberModifiers = preferences.shortcuts.numberModifiers
                }
            } header: { Text(L("搜索面板内", "Inside Search")) }
        }
        .onAppear { numberModifiers = preferences.shortcuts.numberModifiers }
        .sheet(isPresented: $recording, onDismiss: { hotkeys.endRecording() }) {
            VStack(spacing: 16) {
                Image(systemName: "keyboard").font(.system(size: 30)).foregroundStyle(.secondary)
                Text(L("按下新的快捷键", "Press a New Shortcut")).font(.headline)
                Text(L("包含 ⌃、⌥ 或 ⌘，按 Esc 取消。", "Include ⌃, ⌥ or ⌘. Press Esc to cancel.")).foregroundStyle(.secondary)
                ShortcutCapture { shortcut in
                    guard let shortcut else { failure = nil; recording = false; return }
                    var candidate = preferences.shortcuts; candidate.search = shortcut
                    failure = hotkeys.apply(candidate)
                    if failure == nil { recording = false }
                }.frame(width: 330, height: 52)
                if let failure { Text(failure).foregroundStyle(.orange).font(.caption).fixedSize(horizontal: false, vertical: true) }
                Button(L("取消", "Cancel")) { failure = nil; recording = false }.keyboardShortcut(.cancelAction)
            }.padding(28).frame(width: 390)
                .onAppear { hotkeys.beginRecording() }
        }
    }
    private func modifierName(_ modifier: ShortcutModifiers) -> String {
        switch modifier { case .control: return "Control"; case .option: return "Option"; case .shift: return "Shift"; default: return "Command" }
    }
}

private struct ShortcutCapture: NSViewRepresentable {
    let receive: (GlobalShortcut?) -> Void
    func makeNSView(context: Context) -> CaptureView { let view = CaptureView(); view.receive = receive; return view }
    func updateNSView(_ view: CaptureView, context: Context) { view.receive = receive }
    static func dismantleNSView(_ view: CaptureView, coordinator: ()) { view.stop() }
}

private final class CaptureView: NSView {
    var receive: ((GlobalShortcut?) -> Void)?
    private var monitor: Any?
    private var displayed = "…"
    override var acceptsFirstResponder: Bool { true }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow(); stop()
        guard let window else { return }
        window.makeFirstResponder(self)
        // Only observe this sheet while the user explicitly records a shortcut.
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self, event.window === self.window else { return event }
            let modifiers = ShortcutModifiers(event.modifierFlags)
            if event.type == .flagsChanged { self.displayed = modifiers.symbols; self.needsDisplay = true; return event }
            if event.keyCode == 53 { self.receive?(nil); return nil }
            let labels: [UInt16: String] = [49: "Space", 36: "↩", 76: "⌤", 48: "⇥", 51: "⌫", 117: "⌦", 123: "←", 124: "→", 125: "↓", 126: "↑", 115: "↖", 119: "↘", 116: "⇞", 121: "⇟", 122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12"]
            let label = labels[event.keyCode] ?? event.charactersIgnoringModifiers?.uppercased() ?? ""
            let shortcut = GlobalShortcut(keyCode: UInt32(event.keyCode), modifiers: modifiers, keyLabel: label)
            self.displayed = shortcut.display; self.needsDisplay = true
            self.receive?(shortcut)
            return nil
        }
    }
    func stop() { if let monitor { NSEvent.removeMonitor(monitor) }; monitor = nil }
    deinit { stop() }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.controlBackgroundColor.setFill(); NSBezierPath(roundedRect: bounds, xRadius: 10, yRadius: 10).fill()
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedSystemFont(ofSize: 21, weight: .medium), .foregroundColor: NSColor.labelColor]
        let string = displayed as NSString; let size = string.size(withAttributes: attributes)
        string.draw(at: CGPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2), withAttributes: attributes)
    }
}
