import AppKit
import SillCore

struct WindowGroup {
    let title: String
    let items: [WindowItem]
}

enum WindowList {
    static func filtered(_ windows: [WindowItem], screen: NSScreen? = nil) -> [WindowItem] {
        let p = Preferences.shared
        let excluded = Set(p.excluded.split(whereSeparator: { $0.isWhitespace || $0 == "," }).map(String.init))
        let regex = p.titleFilter.isEmpty ? nil : try? NSRegularExpression(pattern: p.titleFilter, options: .caseInsensitive)
        return windows.filter { item in
            if excluded.contains(item.bundleID) { return false }
            if !p.showWindowless && item.element == nil { return false }
            if !p.showMinimized && item.minimized { return false }
            if let regex, regex.firstMatch(in: item.label, range: NSRange(item.label.startIndex..., in: item.label)) != nil { return false }
            guard let screen else { return true }
            if ["displayAll", "displayVisible"].contains(p.scope), item.element != nil {
                // Assign a spanning window to the display containing the largest part of it.
                let owner = NSScreen.screens.max { a, b in
                    let x = a.frame.intersection(item.frame); let y = b.frame.intersection(item.frame)
                    return (x.isNull ? 0 : x.width * x.height) < (y.isNull ? 0 : y.width * y.height)
                }
                if owner != screen { return false }
            }
            if ["visible", "displayVisible"].contains(p.scope) { return item.onScreen && !item.minimized && !item.hidden }
            if p.scope == "visibleFullscreen" { return item.onScreen || item.fullscreen }
            return true
        }.sorted { $0.id < $1.id }
    }
    static func groups(_ items: [WindowItem]) -> [WindowGroup] {
        // Input is in stable discovery order. Cluster before partitioning so sidebar
        // rendering and number shortcuts share the same app/window order.
        let items = WindowOrdering.adjacentByApplication(items) { item in
            item.bundleID.isEmpty ? "pid:\(item.pid)" : "bundle:\(item.bundleID)"
        }
        switch Preferences.shared.grouping {
        case "none": return [WindowGroup(title: "", items: items)]
        case "app":
            let names = Array(Set(items.map(\.appName))).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            return names.map { name in WindowGroup(title: name, items: items.filter { $0.appName == name }) }
        default:
            let categories: [(String, (WindowItem) -> Bool)] = [
                (L("全屏", "Full Screen"), { $0.fullscreen }),
                (L("当前桌面", "Current Desktop"), { !$0.fullscreen && $0.onScreen && !$0.minimized && !$0.hidden }),
                (L("其他空间与隐藏窗口", "Other Spaces & Hidden"), { !$0.fullscreen && !$0.minimized && (!$0.onScreen || $0.hidden) && $0.element != nil }),
                (L("已最小化", "Minimized"), { !$0.fullscreen && $0.minimized }),
                (L("无窗口的应用", "Apps Without Windows"), { $0.element == nil })
            ]
            return categories.compactMap { title, predicate in
                let group = items.filter(predicate)
                return group.isEmpty ? nil : WindowGroup(title: title, items: group)
            }
        }
    }
}

final class SidebarPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class ActionButton: NSButton {
    var handler: (() -> Void)?
    init(title: String = "", image: NSImage? = nil, handler: @escaping () -> Void) {
        super.init(frame: .zero)
        self.title = title; self.image = image; self.handler = handler
        target = self; action = #selector(invoke)
        isBordered = false
    }
    required init?(coder: NSCoder) { fatalError() }
    @objc private func invoke() { handler?() }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

final class WindowRow: NSView {
    let item: WindowItem
    let service: WindowService
    let icon = NSImageView()
    let label = NSTextField(labelWithString: "")
    let number = NSTextField(labelWithString: "")
    var activate: (() -> Void)?
    private var hovered = false
    private var previewWork: DispatchWorkItem?
    private let preview = WindowTitlePreview()
    init(item: WindowItem, service: WindowService, index: Int) {
        self.item = item; self.service = service
        super.init(frame: .zero)
        wantsLayer = true; layer?.cornerRadius = 6
        icon.image = service.icon(for: item); icon.imageScaling = .scaleProportionallyUpOrDown
        label.stringValue = WindowTitle.display(item.label, app: item.appName, bundleID: item.bundleID) + (item.minimized ? "  −" : "")
        label.font = .systemFont(ofSize: Preferences.shared.textSize)
        label.lineBreakMode = WindowTitle.isFilename(item.label) ? .byTruncatingMiddle : .byTruncatingTail
        label.textColor = item.minimized || item.hidden ? .secondaryLabelColor : .labelColor
        number.stringValue = "\(index)"; number.font = .monospacedDigitSystemFont(ofSize: 10, weight: .medium)
        number.textColor = .secondaryLabelColor
        addSubview(icon); addSubview(label); addSubview(number)
        setAccessibilityElement(true); setAccessibilityRole(.button)
        setAccessibilityLabel("\(item.appName) — \(item.label)")
        updateBackground()
    }
    required init?(coder: NSCoder) { fatalError() }
    override func layout() {
        super.layout()
        let size = min(25, Preferences.shared.textSize + 5)
        icon.frame = CGRect(x: (30 - size) / 2, y: (bounds.height - size) / 2, width: size, height: size)
        let labelHeight = ceil(label.intrinsicContentSize.height)
        label.frame = CGRect(x: 33, y: (bounds.height - labelHeight) / 2, width: max(0, bounds.width - 39), height: labelHeight)
        label.isHidden = bounds.width < 70
        number.frame = CGRect(x: 23, y: 0, width: 16, height: 12)
        number.isHidden = !Preferences.shared.showNumbers
    }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }
    override func mouseEntered(with event: NSEvent) {
        hovered = true; updateBackground(); dismissPreview()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.hovered, self.window?.isVisible == true,
                  !self.visibleRect.isEmpty,
                  self.label.isHidden || self.label.intrinsicContentSize.width > self.label.bounds.width else { return }
            self.preview.show(item: self.item, row: self)
        }
        previewWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: work)
    }
    override func mouseExited(with event: NSEvent) { hovered = false; updateBackground(); dismissPreview() }
    func dismissPreview() { previewWork?.cancel(); previewWork = nil; preview.hide() }
    override func viewWillMove(toWindow newWindow: NSWindow?) {
        dismissPreview(); super.viewWillMove(toWindow: newWindow)
    }
    override func scrollWheel(with event: NSEvent) { dismissPreview(); super.scrollWheel(with: event) }
    private func updateBackground() { layer?.backgroundColor = (hovered ? NSColor.labelColor.withAlphaComponent(0.08) : item.focused ? NSColor.controlAccentColor.withAlphaComponent(0.10) : .clear).cgColor }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) { dismissPreview(); activate?() }
    override func accessibilityPerformPress() -> Bool { dismissPreview(); activate?(); return true }
    override func menu(for event: NSEvent) -> NSMenu? {
        dismissPreview()
        let menu = NSMenu()
        menu.addAction(L("切换到窗口", "Switch to Window")) { [weak self] in self?.activate?() }
        if item.element != nil {
            menu.addAction(L("最小化", "Minimize")) { [weak self] in guard let self else { return }; self.service.minimize(self.item) }
            menu.addAction(L("关闭窗口", "Close Window")) { [weak self] in guard let self else { return }; self.service.close(self.item) }
        }
        menu.addItem(.separator())
        menu.addAction(L("隐藏应用", "Hide App")) { [weak self] in guard let self else { return }; NSRunningApplication(processIdentifier: self.item.pid)?.hide() }
        menu.addAction(L("从列表排除此应用", "Exclude This App")) { [weak self] in
            guard let self, !self.item.bundleID.isEmpty else { return }
            Preferences.shared.excluded += "\n" + self.item.bundleID
        }
        return menu
    }
}

final class ClosureMenuItem: NSMenuItem {
    let handler: () -> Void
    init(_ title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(invoke), keyEquivalent: "")
        target = self
    }
    required init(coder: NSCoder) { fatalError() }
    @objc func invoke() { handler() }
}
extension NSMenu {
    @discardableResult func addAction(_ title: String, checked: Bool = false, handler: @escaping () -> Void) -> NSMenuItem {
        let item = ClosureMenuItem(title, handler: handler)
        item.state = checked ? .on : .off
        addItem(item); return item
    }
}

final class SidebarSurface: NSView {
    let content = NSView()
    var hideGesture: (() -> Void)?
    private var gesture = SidebarGesture()
    private var background: NSView?
    private var currentMaterial = ""

    func updateMaterial(_ requested: String) {
        let material: String
        if #available(macOS 26.0, *), requested == "glass" || requested == "clearGlass" {
            material = requested
        } else {
            material = "frosted"
        }
        guard currentMaterial != material else { return }
        currentMaterial = material
        content.removeFromSuperview()
        background?.removeFromSuperview()

        let effect: NSView
        if #available(macOS 26.0, *), material != "frosted" {
            let glass = NSGlassEffectView()
            glass.style = material == "clearGlass" ? .clear : .regular
            glass.cornerRadius = 11
            // Only contentView is guaranteed to render above the native glass.
            glass.contentView = content
            effect = glass
        } else {
            let frosted = NSVisualEffectView()
            frosted.material = .popover
            frosted.blendingMode = .behindWindow
            frosted.state = .active
            frosted.wantsLayer = true
            frosted.layer?.cornerRadius = 11
            frosted.layer?.masksToBounds = true
            frosted.addSubview(content)
            effect = frosted
        }
        effect.frame = bounds
        effect.autoresizingMask = [.width, .height]
        content.frame = bounds
        content.autoresizingMask = [.width, .height]
        addSubview(effect)
        background = effect
    }
    override func scrollWheel(with event: NSEvent) {
        if gesture.consume(event) { hideGesture?() }
        else { super.scrollWheel(with: event) }
    }
}

/// A scroll view normally consumes horizontal events before its parent sees them.
final class SidebarScrollView: NSScrollView {
    var willScroll: (() -> Void)?
    var hideGesture: (() -> Void)?
    private var gesture = SidebarGesture()
    override func scrollWheel(with event: NSEvent) {
        willScroll?()
        if gesture.consume(event) { hideGesture?() }
        else { super.scrollWheel(with: event) }
    }
}

private struct SidebarGesture {
    private var horizontal: CGFloat = 0
    private var lastTime: TimeInterval = 0
    mutating func consume(_ event: NSEvent) -> Bool {
        guard event.momentumPhase.isEmpty, abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) else { return false }
        if event.phase == .began || event.timestamp - lastTime > 0.3 { horizontal = 0 }
        lastTime = event.timestamp
        // A dismissal follows the physical gesture, independently of Natural Scrolling.
        horizontal += event.scrollingDeltaX * (event.isDirectionInvertedFromDevice ? -1 : 1)
        let sign: CGFloat = Preferences.shared.edge == .left ? 1 : -1
        if horizontal * sign > 30 { horizontal = 0; return true }
        return false
    }
}

final class SidebarController {
    let panel: SidebarPanel
    let screen: NSScreen
    private let service: WindowService
    private let surface = SidebarSurface()
    private let scroll = SidebarScrollView()
    private let stack = NSStackView()
    private let toolbar = NSView()
    private var expanded = false
    private var expansionWidth: CGFloat?
    private var measuredTitleWidth: CGFloat = 0
    var reservedWidth: CGFloat { Preferences.shared.resting == .expanded ? resolvedExpandedWidth : Preferences.shared.restingWidth }
    private var resolvedExpandedWidth: CGFloat {
        let p = Preferences.shared
        return p.adaptiveWidth ? (expansionWidth ?? WindowTitle.expandedWidth(titleWidth: measuredTitleWidth, availableWidth: screen.visibleFrame.width)) : p.width
    }
    private var temporarilyHidden = false
    private var leftSinceHide = false
    private var hoverStarted: TimeInterval?
    private var exitStarted: TimeInterval?
    private var menuOpen = false
    private var totalHeight: CGFloat = 200
    private var itemCount = 0
    private var groupHeights: [NSLayoutConstraint] = []
    private var emptyHeight: NSLayoutConstraint?
    private var lastSignature = ""
    var showSettings: (() -> Void)?
    var showSearch: (() -> Void)?

    init(screen: NSScreen, service: WindowService) {
        self.screen = screen; self.service = service
        panel = SidebarPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "Sill — " + L("侧边栏", "Sidebar")
        panel.isFloatingPanel = true; panel.hidesOnDeactivate = false
        panel.level = .floating; panel.isOpaque = false; panel.backgroundColor = .clear
        panel.hasShadow = true; panel.isMovable = false
        panel.collectionBehavior = [.canJoinAllSpaces, .canJoinAllApplications, .stationary, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        surface.updateMaterial(Preferences.shared.sidebarMaterial)
        surface.hideGesture = { [weak self] in self?.hideTemporarily() }
        scroll.willScroll = { [weak self] in self?.dismissPreviews() }
        scroll.hideGesture = { [weak self] in self?.hideTemporarily() }
        panel.contentView = surface
        toolbar.frame = CGRect(x: 0, y: 0, width: 320, height: 28)
        surface.content.addSubview(toolbar)
        scroll.drawsBackground = false; scroll.hasVerticalScroller = true; scroll.autohidesScrollers = true
        scroll.scrollerStyle = .overlay; scroll.horizontalScrollElasticity = .none
        surface.content.addSubview(scroll)
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 1
        stack.edgeInsets = NSEdgeInsets(top: 3, left: 2, bottom: 5, right: 2)
        scroll.documentView = stack
        rebuild(force: true)
        panel.orderFrontRegardless()
    }
    func rebuild(force: Bool = false) {
        let p = Preferences.shared
        let groups = WindowList.groups(WindowList.filtered(service.windows, screen: screen))
        let signature = "\(service.trusted)|" + groups.map { group in group.title + group.items.map { "\($0.id):\($0.label):\($0.focused):\($0.minimized):\($0.hidden)" }.joined() }.joined()
        if !force && signature == lastSignature { return }
        lastSignature = signature
        measuredTitleWidth = groups.flatMap(\.items).map { item in
            let text = WindowTitle.display(item.label, app: item.appName, bundleID: item.bundleID) + (item.minimized ? "  −" : "")
            return (text as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: p.textSize)]).width
        }.max() ?? 0
        if force { expansionWidth = nil }
        if (expanded || p.resting == .expanded) && expansionWidth == nil && !groups.isEmpty {
            expansionWidth = WindowTitle.expandedWidth(titleWidth: measuredTitleWidth, availableWidth: screen.visibleFrame.width)
        }
        panel.title = "Sill — " + L("侧边栏", "Sidebar")
        panel.appearance = p.appearance
        surface.updateMaterial(p.sidebarMaterial)
        stack.arrangedSubviews.forEach { stack.removeArrangedSubview($0); $0.removeFromSuperview() }
        groupHeights.removeAll(); emptyHeight = nil
        totalHeight = 38
        var index = 0
        for group in groups {
            if !group.title.isEmpty {
                let header = SidebarGroupHeader(title: group.title)
                groupHeights.append(append(header, height: 24))
            }
            for item in group.items {
                index += 1
                let row = WindowRow(item: item, service: service, index: index)
                row.activate = { [weak self] in self?.service.activate(item) }
                append(row, height: p.rowHeight)
            }
        }
        if index == 0 {
            let empty = SidebarEmptyState(trusted: service.trusted) { [weak self] in self?.showSettings?() }
            emptyHeight = append(empty, height: 110)
        }
        itemCount = index
        buildToolbar()
        layout(animated: false)
    }
    @discardableResult private func append(_ view: NSView, height: CGFloat) -> NSLayoutConstraint {
        view.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(view)
        let heightConstraint = view.heightAnchor.constraint(equalToConstant: height)
        NSLayoutConstraint.activate([heightConstraint, view.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -4)])
        return heightConstraint
    }
    private func buildToolbar() {
        toolbar.subviews.forEach { $0.removeFromSuperview() }
        let menu = ActionButton(image: NSImage(systemSymbolName: "ellipsis", accessibilityDescription: L("侧边栏选项", "Sidebar Options"))) { [weak self] in self?.openMenu() }
        menu.frame = CGRect(x: 3, y: 2, width: 28, height: 24); toolbar.addSubview(menu)
        let search = ActionButton(image: NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: L("搜索窗口", "Search Windows"))) { [weak self] in self?.showSearch?() }
        search.frame = CGRect(x: 46, y: 2, width: 24, height: 24); toolbar.addSubview(search)
        let settings = ActionButton(image: NSImage(systemSymbolName: "gearshape", accessibilityDescription: L("设置", "Settings"))) { [weak self] in self?.showSettings?() }
        settings.frame = CGRect(x: 78, y: 2, width: 24, height: 24); toolbar.addSubview(settings)
    }
    func tick(mouse: CGPoint, now: TimeInterval) {
        guard !menuOpen else { return }
        let over = panel.frame.contains(mouse)
        if temporarilyHidden {
            if !over { leftSinceHide = true }
            if !leftSinceHide { return }
        }
        if over {
            exitStarted = nil
            if hoverStarted == nil { hoverStarted = now }
            if now - (hoverStarted ?? now) > 0.12 && (!expanded || temporarilyHidden) {
                temporarilyHidden = false
                if shouldCaptureExpansionWidth { expansionWidth = WindowTitle.expandedWidth(titleWidth: measuredTitleWidth, availableWidth: screen.visibleFrame.width) }
                expanded = true; layout(animated: true)
            }
        } else {
            hoverStarted = nil
            if exitStarted == nil { exitStarted = now }
            if expanded && now - (exitStarted ?? now) > 0.28 {
                expanded = false
                if Preferences.shared.resting != .expanded { expansionWidth = nil }
                dismissPreviews(); layout(animated: true)
            }
        }
    }
    private var shouldCaptureExpansionWidth: Bool { Preferences.shared.resting != .expanded || expansionWidth == nil }
    private func dismissPreviews() { stack.arrangedSubviews.compactMap { $0 as? WindowRow }.forEach { $0.dismissPreview() } }
    func hideTemporarily() {
        dismissPreviews(); expansionWidth = nil
        temporarilyHidden = true; leftSinceHide = false; expanded = false
        hoverStarted = nil; layout(animated: true)
    }
    private func layout(animated: Bool) {
        let p = Preferences.shared
        let requestedWidth = temporarilyHidden ? 3 : (expanded || p.resting == .expanded) ? resolvedExpandedWidth : p.restingWidth
        let width = min(requestedWidth, screen.visibleFrame.width)
        // Keep every window at the same vertical position across hover transitions.
        let groupHeight: CGFloat = 24
        groupHeights.forEach { $0.constant = groupHeight }
        if let emptyHeight {
            emptyHeight.constant = width < 180 ? 38 : 110
            totalHeight = 38 + emptyHeight.constant
        } else {
            totalHeight = 38 + CGFloat(itemCount) * (p.rowHeight + 1) + CGFloat(groupHeights.count) * (groupHeight + 1)
        }
        let visible = screen.visibleFrame
        let offset: CGFloat = p.vertical == "top" ? visible.height : p.vertical == "bottom" ? -visible.height : 0
        let frame = SidebarGeometry.frame(in: visible, edge: p.edge, width: width, height: totalHeight, offset: offset)
        let duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 0.14
        if animated && duration > 0 {
            NSAnimationContext.runAnimationGroup { context in context.duration = duration; panel.animator().setFrame(frame, display: true) }
        } else { panel.setFrame(frame, display: true) }
        // Keep document width aligned with the target frame even while the panel animates.
        toolbar.frame = CGRect(x: 0, y: frame.height - 28, width: width, height: 28)
        toolbar.subviews.dropFirst().forEach { $0.isHidden = width < 110 }
        scroll.frame = CGRect(x: 0, y: 0, width: width, height: frame.height - 28)
        stack.setFrameSize(CGSize(width: width, height: max(totalHeight - 28, scroll.contentSize.height)))
        stack.layoutSubtreeIfNeeded()
    }
    private func openMenu() {
        menuOpen = true
        let p = Preferences.shared
        let menu = NSMenu()
        menu.addAction(L("暂时隐藏", "Hide For Now")) { [weak self] in self?.hideTemporarily() }
        menu.addItem(.separator())
        let heading = NSMenuItem(title: L("鼠标离开时", "When Cursor Not Over"), action: nil, keyEquivalent: "")
        menu.addItem(heading)
        for mode in RestingMode.allCases { menu.addAction(mode.label, checked: p.resting == mode) { p.resting = mode } }
        menu.addItem(.separator())
        menu.addAction(L("自动调整窗口宽度", "Auto-adjust Window Widths"), checked: p.autoAvoid) { p.autoAvoid.toggle() }
        menu.addAction(L("设置…", "Settings…")) { [weak self] in self?.showSettings?() }
        menu.popUp(positioning: nil, at: CGPoint(x: 10, y: 0), in: toolbar)
        menuOpen = false
    }
}
