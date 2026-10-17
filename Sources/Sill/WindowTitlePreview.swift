import AppKit
import SillCore

/// A nonactivating, click-through help panel; it never takes focus from the selected app.
final class WindowTitlePreview {
    private var panel: SidebarPanel?

    func show(item: WindowItem, row: NSView) {
        guard let window = row.window, let screen = window.screen else { return }
        hide()
        let visible = screen.visibleFrame
        let contentWidth = min(420, visible.width - 48)
        let heading = NSTextField(labelWithString: item.appName)
        heading.font = .systemFont(ofSize: 11, weight: .medium)
        heading.textColor = .secondaryLabelColor
        let title = NSTextField(wrappingLabelWithString: item.label)
        title.font = .systemFont(ofSize: Preferences.shared.textSize)
        title.maximumNumberOfLines = 0
        title.cell?.wraps = true
        title.cell?.isScrollable = false
        let textHeight = title.cell?.cellSize(forBounds: CGRect(x: 0, y: 0, width: contentWidth, height: .greatestFiniteMagnitude)).height ?? 40
        let height = min(visible.height - 16, ceil(textHeight) + 46)
        let panel = SidebarPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = true
        panel.level = .popUpMenu; panel.hidesOnDeactivate = false; panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .canJoinAllApplications, .transient, .ignoresCycle]
        panel.appearance = window.appearance
        let background = NSVisualEffectView()
        background.material = .toolTip; background.state = .active; background.blendingMode = .behindWindow
        background.wantsLayer = true; background.layer?.cornerRadius = 9; background.layer?.masksToBounds = true
        heading.frame = CGRect(x: 12, y: height - 27, width: contentWidth, height: 15)
        title.frame = CGRect(x: 12, y: 12, width: contentWidth, height: height - 39)
        background.addSubview(heading); background.addSubview(title)
        panel.contentView = background
        let rowFrame = window.convertToScreen(row.convert(row.bounds, to: nil))
        panel.setFrame(WindowTitle.previewFrame(row: rowFrame, size: CGSize(width: contentWidth + 24, height: height), visibleFrame: visible, edge: Preferences.shared.edge), display: true)
        window.addChildWindow(panel, ordered: .above)
        panel.orderFrontRegardless()
        self.panel = panel
    }

    func hide() {
        if let panel { panel.parent?.removeChildWindow(panel); panel.orderOut(nil) }
        panel = nil
    }
    deinit { hide() }
}
