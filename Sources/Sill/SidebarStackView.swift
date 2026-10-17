import AppKit

/// Paint behind consecutive windows without changing row positions or hit testing.
final class SidebarStackView: NSStackView {
    private static let palette: [NSColor] = [
        .systemBlue, .systemTeal, .systemPurple, .systemOrange,
        .systemPink, .systemGreen, .systemIndigo, .systemYellow
    ].shuffled()
    private static var applicationColors: [String: NSColor] = [:]

    override func layout() {
        super.layout()
        needsDisplay = true
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        var rows: [WindowRow] = []
        var application = ""

        func paintBlock() {
            guard rows.count > 1 else { return }
            let rect = rows.reduce(NSRect.null) { $0.union($1.frame) }.insetBy(dx: 1, dy: 0)
            guard rect.intersects(dirtyRect) else { return }
            if Self.applicationColors[application] == nil {
                Self.applicationColors[application] = Self.palette[Self.applicationColors.count % Self.palette.count]
            }
            Self.applicationColors[application]?.withAlphaComponent(dark ? 0.16 : 0.10).setFill()
            NSBezierPath(roundedRect: rect, xRadius: 7, yRadius: 7).fill()
        }

        for view in arrangedSubviews {
            guard let row = view as? WindowRow else {
                paintBlock(); rows.removeAll(); application = ""
                continue
            }
            let key = row.item.bundleID.isEmpty ? "pid:\(row.item.pid)" : "bundle:\(row.item.bundleID)"
            if key != application {
                paintBlock(); rows.removeAll(); application = key
            }
            rows.append(row)
        }
        paintBlock()
    }
}
