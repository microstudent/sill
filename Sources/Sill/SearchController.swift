import AppKit
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
    private let emptyState = SearchEmptyState()
    var showSettings: (() -> Void)?
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
        emptyState.frame = scroll.frame
        emptyState.openSettings = { [weak self] in self?.dismiss(); self?.showSettings?() }
        effect.addSubview(emptyState)
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
    func refresh() {
        guard panel.isVisible else { return }
        panel.appearance = Preferences.shared.appearance
        panel.title = L("搜索窗口", "Search Windows")
        field.placeholderString = L("应用、窗口标题、拼音或首字母", "App, window title, pinyin or initials")
        updateResults()
    }
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
        if !results.isEmpty {
            let row = results.firstIndex { $0.id == selected } ?? 0
            table.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            if !preserveSelection { table.scrollRowToVisible(row) }
        } else { table.deselectAll(nil) }
        emptyState.isHidden = !results.isEmpty
        emptyState.update(trusted: service.trusted, hasQuery: !field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        if results.isEmpty { footer.stringValue = L("esc 关闭搜索", "esc Close Search") }
        else { footer.stringValue = L("↑ ↓ 选择   ↵ 切换   esc 取消   ⌘W 关闭   ⌘M 最小化", "↑ ↓ Select   ↵ Switch   esc Cancel   ⌘W Close   ⌘M Minimize") }
    }
    private func handle(_ event: NSEvent) -> Bool {
        let editor = field.currentEditor() as? NSTextView
        let flags: [(NSEvent.ModifierFlags, SearchKeyboard.Modifier)] = [(.command, .command), (.control, .control), (.option, .option), (.shift, .shift)]
        let modifiers = Set(flags.compactMap { event.modifierFlags.contains($0.0) ? $0.1 : nil })
        guard let command = SearchKeyboard.command(keyCode: event.keyCode, characters: event.charactersIgnoringModifiers,
                                                   modifiers: modifiers, hasMarkedText: editor?.hasMarkedText() ?? false) else { return false }
        switch command {
        case .dismiss: dismiss()
        case .activate:
            guard !(panel.firstResponder is NSButton) else { return false }
            chosen()
        case .move(let delta):
            // When there are no results, Tab must still reach the Settings button.
            guard !results.isEmpty else { return event.keyCode != 48 }
            let row = (max(0, table.selectedRow) + delta + results.count) % results.count
            table.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            table.scrollRowToVisible(row)
        case .close, .minimize, .hide:
            guard results.indices.contains(table.selectedRow) else { return false }
            let item = results[table.selectedRow]
            if command == .close { service.close(item) }
            else if command == .minimize { service.minimize(item) }
            else { NSRunningApplication(processIdentifier: item.pid)?.hide() }
        }
        return true
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
        view.toolTip = item.appName + " — " + item.label
        view.setAccessibilityLabel(view.toolTip)
        return view
    }
}
