import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let service = WindowService()
    private lazy var settings = SettingsController(service: service, hotkeys: hotkeys)
    private lazy var search = SearchController(service: service)
    private lazy var avoidance = WindowAvoidance(service: service)
    private let hotkeys = HotKeyManager()
    private var sidebars: [SidebarController] = []
    private var status: NSStatusItem?
    private var pointerTimer: Timer?
    private var screenToken: NSObjectProtocol?
    private var preferencesWork: DispatchWorkItem?
    private var lastTopology = ""
    private var lastAvoidanceConfig = ""

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let p = Preferences.shared
        settings.restoreWindows = { [weak self] in self?.avoidance.restore() }
        search.showSettings = { [weak self] in self?.settings.show() }
        settings.showSearch = { [weak self] in self?.search.show() }
        hotkeys.onSearch = { [weak self] in self?.search.show() }
        hotkeys.onNumber = { [weak self] number in self?.switchNumber(number) }
        p.onChange = { [weak self] in self?.schedulePreferencesChanged() }
        service.onUpdate = { [weak self] in
            guard let self else { return }
            self.sidebars.forEach { $0.rebuild() }
            self.search.refresh()
            self.updateAvoidance()
        }
        screenToken = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            self?.avoidance.restore(pauseFor: 1.5); self?.rebuildSidebars(); self?.service.scheduleRefresh()
        }
        createStatusItem()
        preferencesChanged()
        service.start()
        pointerTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            let mouse = NSEvent.mouseLocation; let now = Date.timeIntervalSinceReferenceDate
            self?.sidebars.forEach { $0.tick(mouse: mouse, now: now) }
        }
        pointerTimer?.tolerance = 0.025
        if !service.trusted || !UserDefaults.standard.bool(forKey: "hasLaunched") || CommandLine.arguments.contains("--settings") {
            settings.show(); UserDefaults.standard.set(true, forKey: "hasLaunched")
        }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { settings.show(); return true }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification: Notification) {
        service.stop(); pointerTimer?.invalidate()
        if let screenToken { NotificationCenter.default.removeObserver(screenToken) }
    }
    private var sidebarScreens: [NSScreen] {
        switch Preferences.shared.displays {
        case "none": return []
        case "primary": return Array(NSScreen.screens.prefix(1))
        default: return NSScreen.screens
        }
    }
    private func rebuildSidebars() {
        sidebars.forEach { $0.panel.orderOut(nil) }; sidebars.removeAll()
        for screen in sidebarScreens {
            let sidebar = SidebarController(screen: screen, service: service)
            sidebar.showShortcuts = { [weak self] in self?.settings.show(page: "keyboard") }
            sidebar.showSettings = { [weak self] in self?.settings.show() }
            sidebar.showSearch = { [weak self] in self?.search.show() }
            sidebars.append(sidebar)
        }
    }
    private func schedulePreferencesChanged() {
        preferencesWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.preferencesChanged() }
        preferencesWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: work)
    }
    private func preferencesChanged() {
        let p = Preferences.shared
        let config = "\(p.edge):\(p.resting):\(p.displays):\(p.autoAvoid):\(p.width):\(p.adaptiveWidth)"
        if !lastAvoidanceConfig.isEmpty && lastAvoidanceConfig != config { avoidance.restore(pauseFor: 1.5) }
        lastAvoidanceConfig = config
        NSApp.appearance = p.appearance
        settings.updateAppearance()
        let topology = p.displays + p.edge.rawValue
        if topology != lastTopology { lastTopology = topology; rebuildSidebars() }
        else { sidebars.forEach { $0.rebuild(force: true) } }
        hotkeys.configure()
        updateMenus()
        search.refresh()
        updateAvoidance()
    }
    private func updateAvoidance() {
        avoidance.update(screens: sidebarScreens) { screen in
            self.sidebars.first { $0.screen == screen }?.reservedWidth ?? Preferences.shared.restingWidth
        }
    }
    private func switchNumber(_ number: Int) {
        let screen = sidebarScreens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? sidebarScreens.first
        let groups = WindowList.groups(WindowList.filtered(service.windows, screen: screen))
        let items = groups.flatMap(\.items)
        guard items.indices.contains(number - 1) else { return }
        service.activate(items[number - 1])
    }
    private func createStatusItem() {
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status?.button?.image = NSImage(systemSymbolName: "sidebar.left", accessibilityDescription: "Sill")
        status?.button?.toolTip = "Sill"
    }
    private func updateMenus() {
        let menu = NSMenu()
        menu.addAction(L("搜索窗口…", "Search Windows…")) { [weak self] in self?.search.show() }
        menu.addAction(L("设置…", "Settings…")) { [weak self] in self?.settings.show() }
        menu.addAction(L("快捷键…", "Shortcuts…")) { [weak self] in self?.settings.show(page: "keyboard") }
        menu.addAction(L("刷新窗口列表", "Refresh Windows")) { [weak self] in self?.service.refresh() }
        menu.addItem(.separator())
        menu.addAction(L("暂时隐藏侧边栏", "Hide Sidebars For Now")) { [weak self] in self?.sidebars.forEach { $0.hideTemporarily() } }
        menu.addAction(L("还原自动调整的窗口", "Restore Adjusted Windows")) { [weak self] in self?.avoidance.restore() }
        menu.addItem(.separator())
        menu.addAction(L("退出 Sill", "Quit Sill")) { NSApp.terminate(nil) }
        status?.menu = menu
        let mainMenu = NSMenu()
        let appItem = NSMenuItem(); let appMenu = NSMenu()
        let settingsItem = appMenu.addAction(L("设置…", "Settings…")) { [weak self] in self?.settings.show() }
        settingsItem.keyEquivalent = ","
        appMenu.addAction(L("快捷键…", "Shortcuts…")) { [weak self] in self?.settings.show(page: "keyboard") }
        appMenu.addItem(.separator())
        let quit = appMenu.addAction(L("退出 Sill", "Quit Sill")) { NSApp.terminate(nil) }
        quit.keyEquivalent = "q"
        appItem.submenu = appMenu; mainMenu.addItem(appItem)
        let editItem = NSMenuItem(title: L("编辑", "Edit"), action: nil, keyEquivalent: "")
        let edit = NSMenu(title: editItem.title)
        for (title, action, key) in [(L("撤销", "Undo"), "undo:", "z"), (L("剪切", "Cut"), "cut:", "x"), (L("复制", "Copy"), "copy:", "c"), (L("粘贴", "Paste"), "paste:", "v"), (L("全选", "Select All"), "selectAll:", "a")] {
            edit.addItem(withTitle: title, action: NSSelectorFromString(action), keyEquivalent: key)
        }
        editItem.submenu = edit; mainMenu.addItem(editItem); NSApp.mainMenu = mainMenu
    }
}
