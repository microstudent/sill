import AppKit
import SillCore

struct WindowGroup {
    let title: String
    let items: [WindowItem]
}

enum WindowList {
    static func filtered(_ windows: [WindowItem], screen: NSScreen? = nil) -> [WindowItem] {
        let p = Preferences.shared
        let excluded = Set(p.excluded.split(whereSeparator: { $0.isWhitespace || $0 == "," }).map(String.init))
        let regex = p.titleFilter.isEmpty ? nil : try? NSRegularExpression(pattern: p.titleFilter, options: .caseInsensitive)
        return windows.filter { item in
            if excluded.contains(item.bundleID) { return false }
            if !p.showWindowless && item.element == nil { return false }
            if !p.showMinimized && item.minimized { return false }
            if let regex, regex.firstMatch(in: item.label, range: NSRange(item.label.startIndex..., in: item.label)) != nil { return false }
            guard let screen else { return true }
            if ["displayAll", "displayVisible"].contains(p.scope), item.element != nil {
                // Assign a spanning window to the display containing the largest part of it.
                let owner = NSScreen.screens.max { a, b in
                    let x = a.frame.intersection(item.frame); let y = b.frame.intersection(item.frame)
                    return (x.isNull ? 0 : x.width * x.height) < (y.isNull ? 0 : y.width * y.height)
                }
                if owner != screen { return false }
            }
            if ["visible", "displayVisible"].contains(p.scope) { return item.onScreen && !item.minimized && !item.hidden }
            if p.scope == "visibleFullscreen" { return item.onScreen || item.fullscreen }
            return true
        }.sorted { $0.id < $1.id }
    }
    static func groups(_ items: [WindowItem]) -> [WindowGroup] {
        // Input is in stable discovery order. Cluster before partitioning so sidebar
        // rendering and number shortcuts share the same app/window order.
        let items = WindowOrdering.adjacentByApplication(items) { item in
            item.bundleID.isEmpty ? "pid:\(item.pid)" : "bundle:\(item.bundleID)"
        }
        switch Preferences.shared.grouping {
        case "none": return [WindowGroup(title: "", items: items)]
        case "app":
            let names = Array(Set(items.map(\.appName))).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            return names.map { name in WindowGroup(title: name, items: items.filter { $0.appName == name }) }
        default:
            let categories: [(String, (WindowItem) -> Bool)] = [
                (L("全屏", "Full Screen"), { $0.fullscreen }),
                (L("当前桌面", "Current Desktop"), { !$0.fullscreen && $0.onScreen && !$0.minimized && !$0.hidden }),
                (L("其他空间与隐藏窗口", "Other Spaces & Hidden"), { !$0.fullscreen && !$0.minimized && (!$0.onScreen || $0.hidden) && $0.element != nil }),
                (L("已最小化", "Minimized"), { !$0.fullscreen && $0.minimized }),
                (L("无窗口的应用", "Apps Without Windows"), { $0.element == nil })
            ]
            return categories.compactMap { title, predicate in
                let group = items.filter(predicate)
                return group.isEmpty ? nil : WindowGroup(title: title, items: group)
            }
        }
    }
}
