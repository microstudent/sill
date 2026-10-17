import Foundation
import CoreGraphics

public enum WindowTitle {
    /// Only remove an exact browser-app suffix; keep the original title for search and accessibility.
    public static func display(_ title: String, app: String, bundleID: String) -> String {
        let browsers: Set<String> = ["com.apple.Safari", "com.google.Chrome", "com.microsoft.edgemac", "org.mozilla.firefox", "company.thebrowser.Browser", "com.brave.Browser"]
        guard browsers.contains(bundleID), !app.isEmpty else { return title }
        for separator in [" — ", " – ", " - "] {
            let suffix = separator + app
            if title.hasSuffix(suffix), title.count > suffix.count {
                return String(title.dropLast(suffix.count))
            }
        }
        return title
    }

    public static func isFilename(_ title: String) -> Bool {
        let extensions: Set<String> = ["swift", "md", "txt", "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "png", "jpg", "jpeg", "heic", "gif", "svg", "zip", "json", "yaml", "yml", "csv", "html", "css", "js", "ts", "tsx", "py", "mov", "mp4"]
        return extensions.contains((title as NSString).pathExtension.lowercased())
    }

    public static func expandedWidth(titleWidth: CGFloat, availableWidth: CGFloat) -> CGFloat {
        min(max(0, availableWidth), max(300, min(420, ceil(titleWidth + 55))))
    }

    public static func previewFrame(row: CGRect, size: CGSize, visibleFrame: CGRect, edge: SidebarEdge) -> CGRect {
        let width = min(size.width, max(0, visibleFrame.width - 16))
        let height = min(size.height, max(0, visibleFrame.height - 16))
        let x = edge == .left ? row.maxX + 8 : row.minX - width - 8
        return CGRect(x: min(max(x, visibleFrame.minX + 8), visibleFrame.maxX - width - 8),
                      y: min(max(row.midY - height / 2, visibleFrame.minY + 8), visibleFrame.maxY - height - 8),
                      width: width, height: height)
    }
}
