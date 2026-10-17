import AppKit
import Carbon
import SillCore

final class SearchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class SearchController: NSObject, NSSearchFieldDelegate, NSTableViewDataSource, NSTableViewDelegate, NSWindowDelegate {
    private let service: WindowService
    private let panel: SearchPanel
    private let field = NSSearchField()
    private let table = NSTableView()
    private let footer = NSTextField(labelWithString: "")
    private var results: [WindowItem] = []
    private var searchIndex: [UInt64: (title: String, app: String, document: WindowSearch.Document)] = [:]
    private var eventMonitor: Any?
    init(service: WindowService) {
        self.service = service
        panel = SearchPanel(contentRect: CGRect(x: 0, y: 0, width: 620, height: 490), styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel], backing: .buffered, defer: false)
        super.init()
        panel.titleVisibility = .hidden; panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true; panel.level = .floating; panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .canJoinAllApplications, .ignoresCycle]
        panel.isReleasedWhenClosed = false; panel.delegate = self
        let effect = NSVisualEffectView(frame: panel.contentView!.bounds)
        effect.autoresizingMask = [.width, .height]; effect.material = .hudWindow; effect.state = .active
        panel.contentView = effect
        field.frame = CGRect(x: 20, y: 419, width: 580, height: 38)
        field.font = .systemFont(ofSize: 20); field.focusRingType = .none
        field.delegate = self; field.sendsSearchStringImmediately = true
        effect.addSubview(field)
        let scroll = NSScrollView(frame: CGRect(x: 12, y: 42, width: 596, height: 365))
        scroll.drawsBackground = false; scroll.hasVerticalScroller = true; scroll.autohidesScrollers = true
        table.headerView = nil; table.backgroundColor = .clear; table.rowHeight = 42
        table.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("window")))
        table.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        table.dataSource = self; table.delegate = self; table.target = self; table.action = #selector(chosen)
        scroll.documentView = table; effect.addSubview(scroll)
        footer.frame = CGRect(x: 22, y: 13, width: 575, height: 20)
        footer.font = .systemFont(ofSize: 11); footer.textColor = .secondaryLabelColor; effect.addSubview(footer)
    }
    func show() {
        if panel.isVisible { dismiss(); return }
        panel.appearance = Preferences.shared.appearance
        panel.title = L("搜索窗口", "Search Windows")
        field.placeholderString = L("应用、窗口标题、拼音或首字母", "App, window title, pinyin or initials")
        field.stringValue = ""
        footer.stringValue = L("↑ ↓ 选择   ↵ 切换   esc 取消   ⌘W 关闭   ⌘M 最小化", "↑ ↓ Select   ↵ Switch   esc Cancel   ⌘W Close   ⌘M Minimize")
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        if let screen { panel.setFrameOrigin(CGPoint(x: screen.visibleFrame.midX - panel.frame.width / 2, y: screen.visibleFrame.midY - panel.frame.height / 2)) }
        updateResults(preserveSelection: false)
        panel.makeKeyAndOrderFront(nil); panel.makeFirstResponder(field)
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel.isVisible, event.window == self.panel else { return event }
            if self.handle(event) { return nil }; return event
        }
    }
    func dismiss() {
        panel.orderOut(nil)
        if let eventMonitor { NSEvent.removeMonitor(eventMonitor); self.eventMonitor = nil }
    }
    func windowDidResignKey(_ notification: Notification) { dismiss() }
    func controlTextDidChange(_ obj: Notification) { updateResults(preserveSelection: false) }
    func refresh() { if panel.isVisible { updateResults() } }
    private func updateResults(preserveSelection: Bool = true) {
        let selected = preserveSelection && results.indices.contains(table.selectedRow) ? results[table.selectedRow].id : nil
        let candidates = WindowList.filtered(service.windows)
        let liveIDs = Set(candidates.map(\.id))
        searchIndex = searchIndex.filter { liveIDs.contains($0.key) }
        results = candidates.compactMap { item -> (WindowItem, Int)? in
            if searchIndex[item.id]?.title != item.label || searchIndex[item.id]?.app != item.appName {
                searchIndex[item.id] = (item.label, item.appName, WindowSearch.Document(title: item.label, app: item.appName))
            }
            guard let document = searchIndex[item.id]?.document,
                  let score = WindowSearch.score(query: field.stringValue, document: document) else { return nil }
            return (item, score)
        }.sorted { a, b in a.1 != b.1 ? a.1 > b.1 : a.0.lastUsed != b.0.lastUsed ? a.0.lastUsed > b.0.lastUsed : a.0.id < b.0.id }.map(\.0)
        table.reloadData()
        if !results.isEmpty { table.selectRowIndexes(IndexSet(integer: results.firstIndex { $0.id == selected } ?? 0), byExtendingSelection: false) }
        if results.isEmpty { footer.stringValue = service.trusted ? L("没有匹配的窗口", "No matching windows") : L("请先在设置中授予辅助功能权限", "Enable Accessibility in Settings first") }
        else { footer.stringValue = L("↑ ↓ 选择   ↵ 切换   esc 取消   ⌘W 关闭   ⌘M 最小化", "↑ ↓ Select   ↵ Switch   esc Cancel   ⌘W Close   ⌘M Minimize") }
    }
    private func handle(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 53: dismiss(); return true
        case 36: chosen(); return true
        case 125, 126, 48:
            guard !results.isEmpty else { return true }
            let delta = event.keyCode == 126 || (event.keyCode == 48 && event.modifierFlags.contains(.shift)) ? -1 : 1
            let row = (max(0, table.selectedRow) + delta + results.count) % results.count
            table.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false); table.scrollRowToVisible(row)
            return true
        default:
            guard event.modifierFlags.contains(.command), results.indices.contains(table.selectedRow) else { return false }
            let item = results[table.selectedRow]
            if event.charactersIgnoringModifiers == "w" { service.close(item); return true }
            if event.charactersIgnoringModifiers == "m" { service.minimize(item); return true }
            if event.charactersIgnoringModifiers == "h" { NSRunningApplication(processIdentifier: item.pid)?.hide(); return true }
            return false
        }
    }
    @objc private func chosen() {
        guard results.indices.contains(table.selectedRow) else { return }
        let item = results[table.selectedRow]; dismiss(); service.activate(item)
    }
    func numberOfRows(in tableView: NSTableView) -> Int { results.count }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = results[row]
        let view = NSTableCellView()
        let icon = NSImageView(frame: CGRect(x: 10, y: 7, width: 28, height: 28)); icon.image = service.icon(for: item)
        view.addSubview(icon)
        let label = NSTextField(labelWithString: item.label)
        label.frame = CGRect(x: 50, y: 19, width: 510, height: 20); label.font = .systemFont(ofSize: 14); label.lineBreakMode = .byTruncatingTail
        view.addSubview(label)
        let app = NSTextField(labelWithString: item.appName + (item.minimized ? L(" · 已最小化", " · Minimized") : ""))
        app.frame = CGRect(x: 50, y: 2, width: 510, height: 17); app.font = .systemFont(ofSize: 11); app.textColor = .secondaryLabelColor
        view.addSubview(app)
        view.setAccessibilityLabel(item.appName + " — " + item.label)
        return view
    }
}

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
