import AppKit
import SillCore

final class SidebarPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class SidebarController {
    let panel: SidebarPanel
    let screen: NSScreen
    private let service: WindowService
    private let surface = SidebarSurface()
    private let scroll = SidebarScrollView()
    private let stack = SidebarStackView()
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
        let scrollOrigin = scroll.contentView.bounds.origin
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
        let maximumY = max(0, stack.frame.height - scroll.contentSize.height)
        scroll.contentView.scroll(to: CGPoint(x: 0, y: min(max(0, scrollOrigin.y), maximumY)))
        scroll.reflectScrolledClipView(scroll.contentView)
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
