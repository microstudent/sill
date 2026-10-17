import AppKit

final class SearchEmptyState: NSView {
    private let icon = NSImageView()
    private let title = NSTextField(labelWithString: "")
    private let detail = NSTextField(wrappingLabelWithString: "")
    private let settings = ActionButton(handler: {})
    var openSettings: (() -> Void)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        icon.contentTintColor = .secondaryLabelColor
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 30, weight: .regular)
        title.font = .systemFont(ofSize: 16, weight: .medium)
        title.alignment = .center
        detail.font = .systemFont(ofSize: 13)
        detail.textColor = .secondaryLabelColor; detail.alignment = .center
        settings.isBordered = true; settings.bezelStyle = .rounded
        settings.handler = { [weak self] in self?.openSettings?() }
        [icon, title, detail, settings].forEach(addSubview)
    }
    convenience init() { self.init(frame: .zero) }
    required init?(coder: NSCoder) { fatalError() }

    func update(trusted: Bool, hasQuery: Bool) {
        icon.image = NSImage(systemSymbolName: trusted ? "magnifyingglass" : "lock.shield", accessibilityDescription: nil)
        title.stringValue = !trusted ? L("需要辅助功能权限", "Accessibility Access Required") : hasQuery ? L("未找到匹配窗口", "No Matching Windows") : L("暂无可用窗口", "No Windows Available")
        detail.stringValue = !trusted ? L("在设置中允许访问，即可搜索和切换窗口。", "Allow access in Settings to search and switch windows.") : hasQuery ? L("试试应用名、窗口标题、拼音或更短的关键词。", "Try an app name, window title, pinyin, or a shorter keyword.") : L("打开一个窗口，或在设置中检查排除规则。", "Open a window or check your exclusion rules in Settings.")
        settings.title = L("打开设置", "Open Settings")
        settings.isHidden = trusted && hasQuery
        needsLayout = true
    }
    override func layout() {
        super.layout()
        let center = bounds.midY
        icon.frame = CGRect(x: bounds.midX - 18, y: center + 35, width: 36, height: 36)
        title.frame = CGRect(x: 24, y: center, width: bounds.width - 48, height: 24)
        detail.frame = CGRect(x: 40, y: center - 45, width: bounds.width - 80, height: 40)
        settings.frame = CGRect(x: bounds.midX - 70, y: center - 85, width: 140, height: 28)
    }
}
