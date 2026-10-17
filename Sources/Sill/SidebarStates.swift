import AppKit

/// Compact rails show a separator, never a clipped or vertically wrapped heading.
final class SidebarGroupHeader: NSView {
    private let label = NSTextField(labelWithString: "")
    private let separator = NSBox()
    init(title: String) {
        super.init(frame: .zero)
        label.stringValue = title
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = .secondaryLabelColor; label.lineBreakMode = .byTruncatingTail
        separator.boxType = .separator
        addSubview(label); addSubview(separator)
        toolTip = title
    }
    required init?(coder: NSCoder) { fatalError() }
    override func layout() {
        super.layout()
        let compact = bounds.width < 100
        label.isHidden = compact; separator.isHidden = !compact
        label.frame = CGRect(x: 8, y: 3, width: max(0, bounds.width - 16), height: 16)
        separator.frame = CGRect(x: 8, y: bounds.midY, width: max(0, bounds.width - 16), height: 1)
    }
}

/// A small icon in the rail becomes a readable, actionable card on expansion.
final class SidebarEmptyState: NSView {
    private let icon = NSImageView()
    private let title = NSTextField(labelWithString: "")
    private let detail = NSTextField(wrappingLabelWithString: "")
    private let button: ActionButton
    private let action: () -> Void
    init(trusted: Bool, action: @escaping () -> Void) {
        self.action = action
        button = ActionButton(title: L("前往设置", "Open Settings"), handler: action)
        super.init(frame: .zero)
        icon.image = NSImage(systemSymbolName: trusted ? "rectangle.stack" : "lock.shield", accessibilityDescription: nil)
        icon.contentTintColor = .secondaryLabelColor
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 20, weight: .regular)
        title.stringValue = trusted ? L("暂无窗口", "No Windows") : L("允许访问窗口", "Allow Window Access")
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        title.alignment = .center; title.lineBreakMode = .byTruncatingTail
        detail.stringValue = trusted ? L("可以在设置中调整显示范围", "Adjust the window scope in Settings") : L("开启辅助功能，窗口即刻呈现", "Enable Accessibility to see your windows")
        detail.font = .systemFont(ofSize: 11); detail.textColor = .secondaryLabelColor
        detail.alignment = .center; detail.maximumNumberOfLines = 2
        button.isBordered = true; button.bezelStyle = .rounded; button.controlSize = .small
        [icon, title, detail, button].forEach(addSubview)
        toolTip = title.stringValue + " · " + detail.stringValue
        setAccessibilityElement(true); setAccessibilityRole(.button); setAccessibilityLabel(toolTip)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func layout() {
        super.layout()
        let compact = bounds.width < 176
        title.isHidden = compact; detail.isHidden = compact; button.isHidden = compact
        icon.frame = CGRect(x: bounds.midX - 10, y: compact ? bounds.midY - 11 : bounds.height - 27, width: 20, height: 22)
        title.frame = CGRect(x: 8, y: bounds.height - 51, width: max(0, bounds.width - 16), height: 19)
        detail.frame = CGRect(x: 12, y: 31, width: max(0, bounds.width - 24), height: 29)
        button.frame = CGRect(x: max(4, bounds.midX - 54), y: 4, width: min(108, bounds.width - 8), height: 24)
    }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) { action() }
    override func accessibilityPerformPress() -> Bool { action(); return true }
}
