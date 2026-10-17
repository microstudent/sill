import AppKit

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
