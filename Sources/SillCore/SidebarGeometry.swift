import Foundation
import CoreGraphics

public enum SidebarEdge: String, CaseIterable, Codable, Sendable {
    case left, right
}

public enum RestingMode: String, CaseIterable, Codable, Sendable {
    case hidden, icons, titleStart, expanded

    public var width: CGFloat {
        switch self {
        case .hidden: return 3
        case .icons: return 34
        case .titleStart: return 110
        case .expanded: return 320
        }
    }
}

public enum SidebarGeometry {
    public static func frame(in visibleFrame: CGRect, edge: SidebarEdge, width: CGFloat, height: CGFloat, offset: CGFloat = 0) -> CGRect {
        let w = min(max(3, width), visibleFrame.width)
        let h = min(max(44, height), visibleFrame.height - 16)
        let y = min(max(visibleFrame.minY + 8, visibleFrame.midY - h / 2 + offset), visibleFrame.maxY - h - 8)
        return CGRect(x: edge == .left ? visibleFrame.minX : visibleFrame.maxX - w, y: y, width: w, height: h)
    }

    /// AX uses a top-left origin on the primary display; AppKit uses bottom-left.
    public static func accessibilityRect(_ rect: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    public static func avoidingStrip(window: CGRect, visibleFrame: CGRect, edge: SidebarEdge, width: CGFloat, minimumWidth: CGFloat = 320) -> CGRect? {
        guard window.intersects(visibleFrame), window.width >= minimumWidth else { return nil }
        var result = window
        if edge == .left {
            let boundary = visibleFrame.minX + width + 8
            guard window.minX < boundary, window.maxX > boundary else { return nil }
            result.origin.x = boundary
            result.size.width = window.maxX - boundary
        } else {
            let boundary = visibleFrame.maxX - width - 8
            guard window.maxX > boundary, window.minX < boundary else { return nil }
            result.size.width = boundary - window.minX
        }
        guard result.width >= minimumWidth, result != window else { return nil }
        return result
    }
}
