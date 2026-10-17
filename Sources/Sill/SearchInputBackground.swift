import AppKit

final class SearchInputBackground: NSView {
    var placeholder = "" { didSet { needsDisplay = true } }
    var showsPlaceholder = true { didSet { if oldValue != showsPlaceholder { needsDisplay = true } } }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 12, yRadius: 12)
        NSColor.labelColor.withAlphaComponent(0.035).setFill()
        path.fill()
        NSColor.labelColor.withAlphaComponent(0.08).setStroke()
        path.lineWidth = 1
        path.stroke()
        if showsPlaceholder {
            let color = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
                ? NSColor.secondaryLabelColor : NSColor.labelColor.withAlphaComponent(0.30)
            (placeholder as NSString).draw(in: CGRect(x: 42, y: 13, width: bounds.width - 58, height: 20), withAttributes: [
                .font: NSFont.systemFont(ofSize: 15), .foregroundColor: color
            ])
        }
    }
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}

final class SearchResultRow: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {
        guard selectionHighlightStyle != .none else { return }
        NSColor.controlAccentColor.withAlphaComponent(0.10).setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 4, dy: 1), xRadius: 8, yRadius: 8).fill()
    }
}
