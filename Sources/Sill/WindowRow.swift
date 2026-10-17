import AppKit
import SillCore

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
        number.stringValue = index <= 9 ? "\(index)" : ""; number.font = .monospacedDigitSystemFont(ofSize: 10, weight: .medium)
        number.textColor = .secondaryLabelColor
        number.alignment = .center; number.drawsBackground = true
        number.backgroundColor = .controlBackgroundColor
        number.wantsLayer = true; number.layer?.cornerRadius = 3; number.layer?.masksToBounds = true
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
        number.frame = CGRect(x: 19, y: 1, width: 11, height: 12)
        number.isHidden = !Preferences.shared.showNumbers || number.stringValue.isEmpty
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
    override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); updateBackground() }
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
