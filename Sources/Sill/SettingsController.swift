import SwiftUI
import AppKit
import ServiceManagement

final class SettingsController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let service: WindowService
    var restoreWindows: (() -> Void)?
    var showSearch: (() -> Void)?
    init(service: WindowService) { self.service = service; super.init() }
    func show() {
        if window == nil {
            let view = SettingsView(preferences: .shared, service: service, restore: { [weak self] in self?.restoreWindows?() }, search: { [weak self] in self?.showSearch?() })
            let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 850, height: 660), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.contentView = NSHostingView(rootView: view)
            window.minSize = NSSize(width: 780, height: 620)
            window.isReleasedWhenClosed = false; window.center()
            window.delegate = self
            window.setFrameAutosaveName("SillSettings")
            self.window = window
        }
        window?.title = L("Sill 设置", "Sill Settings")
        window?.appearance = Preferences.shared.appearance
        NSApp.setActivationPolicy(.regular)
        if window?.isMiniaturized == true { window?.deminiaturize(nil) }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
    func updateAppearance() { window?.appearance = Preferences.shared.appearance; window?.title = L("Sill 设置", "Sill Settings") }
}

struct SettingsView: View {
    @ObservedObject var preferences: Preferences
    @ObservedObject var service: WindowService
    let restore: () -> Void
    let search: () -> Void
    @State private var page = "welcome"
    @State private var loginEnabled = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?
    private var pages: [(String, String, String)] { [
        ("welcome", L("开始使用", "Welcome"), "house"),
        ("sidebar", L("侧边栏", "Sidebar"), "sidebar.left"),
        ("appearance", L("外观与语言", "Appearance & Language"), "paintpalette"),
        ("rules", L("窗口规则", "Window Rules"), "line.3.horizontal.decrease.circle"),
        ("keyboard", L("搜索与快捷键", "Search & Shortcuts"), "keyboard"),
        ("about", L("关于", "About"), "info.circle")
    ] }
    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 10) {
                    Image(systemName: "sidebar.left").font(.system(size: 26, weight: .medium)).foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 2) { Text("Sill").font(.headline); Text(L("窗口，触手可及", "Your windows, within reach")).font(.caption).foregroundStyle(.secondary) }
                }.padding(.horizontal, 16).padding(.top, 25)
                List(selection: $page) {
                    ForEach(pages, id: \.0) { id, title, symbol in Label(title, systemImage: symbol).tag(id).padding(.vertical, 6) }
                }.listStyle(.sidebar)
                Label(service.trusted ? L("辅助功能已授权", "Accessibility enabled") : L("等待辅助功能权限", "Accessibility required"), systemImage: service.trusted ? "checkmark.circle.fill" : "exclamationmark.circle")
                    .font(.caption).foregroundStyle(service.trusted ? Color.green : Color.orange).padding(16)
            }.frame(minWidth: 210, idealWidth: 220, maxWidth: 260)
            VStack(alignment: .leading, spacing: 0) {
                Text(pages.first { $0.0 == page }?.1 ?? "").font(.system(size: 24, weight: .semibold)).padding(.horizontal, 28).padding(.top, 26).padding(.bottom, 8)
                Form {
                    switch page {
                    case "sidebar": sidebar
                    case "appearance": appearance
                    case "rules": rules
                    case "keyboard": keyboard
                    case "about": about
                    default: welcome
                    }
                }.formStyle(.grouped)
            }.frame(minWidth: 540, maxWidth: .infinity, maxHeight: .infinity)
        }.frame(minWidth: 780, minHeight: 580)
    }
    private var welcome: some View {
        Group {
            Section {
                Text(L("把窗口放在屏幕边缘，悬停展开，点击即达。", "Keep your windows at the edge. Hover to expand. Click to switch.")).font(.title3).padding(.vertical, 8)
                Text(L("更轻松地找到并切换每一个窗口。", "Find and switch between your windows with ease.")).foregroundStyle(.secondary)
            }
            Section(L("辅助功能权限", "Accessibility Permission")) {
                Label(service.trusted ? L("已授权，可以读取和切换窗口", "Authorized to list and switch windows") : L("需要你在系统设置中开启权限", "Enable access in System Settings"), systemImage: service.trusted ? "checkmark.shield" : "hand.raised")
                Text(L("用于读取窗口标题、切换、最小化和调整窗口。无需屏幕录制权限；窗口信息仅在本机处理。", "Used to read titles, switch, minimize and resize windows. No Screen Recording permission is required. Window information stays on this Mac.")).font(.callout).foregroundStyle(.secondary)
                HStack {
                    Button(L("打开辅助功能设置", "Open Accessibility Settings")) {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                    }
                    Button(L("重新检查", "Check Again")) { service.refresh() }
                }
                Button(L("在 Finder 中显示应用", "Show App in Finder")) {
                    NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
                }
                if !service.trusted {
                    Text(L("在列表中添加并开启 Sill。授权后会自动加载窗口。", "Add and enable Sill in the list. Windows load automatically after access is granted.")).font(.caption).foregroundStyle(.secondary)
                }
            }
            Section {
                Toggle(L("登录时启动", "Launch at Login"), isOn: Binding(get: { loginEnabled }, set: { enabled in
                    do {
                        if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                        loginEnabled = SMAppService.mainApp.status == .enabled
                        loginError = SMAppService.mainApp.status == .requiresApproval ? L("请在系统设置的登录项中允许此应用。", "Allow this app in System Settings → Login Items.") : nil
                    } catch { loginError = error.localizedDescription; loginEnabled = SMAppService.mainApp.status == .enabled }
                }))
                if let loginError { Text(loginError).foregroundStyle(.orange).font(.caption) }
                Button(L("打开窗口搜索", "Open Window Search"), action: search)
            }
            if let error = service.actionError { Section { Text(error).foregroundStyle(.orange); Button(L("清除提示", "Dismiss")) { service.actionError = nil } } }
        }
    }
    private var sidebar: some View {
        Group {
            Section(L("窗口与显示器", "Windows & Displays")) {
                Picker(L("显示窗口范围", "Show Windows From"), selection: $preferences.scope) {
                    Text(L("所有空间", "All Spaces")).tag("all")
                    Text(L("可见窗口及全屏空间", "Visible & Full Screen")).tag("visibleFullscreen")
                    Text(L("可见窗口", "Visible Windows")).tag("visible")
                    Text(L("本显示器的所有空间", "All Spaces on This Display")).tag("displayAll")
                    Text(L("本显示器的可见窗口", "Visible Windows on This Display")).tag("displayVisible")
                }
                Picker(L("显示侧边栏", "Show Sidebar On"), selection: $preferences.displays) {
                    Text(L("所有显示器", "All Displays")).tag("all")
                    Text(L("主显示器", "Primary Display")).tag("primary")
                    Text(L("不显示", "No Display")).tag("none")
                }
            }
            Section(L("位置", "Position")) {
                Picker(L("水平位置", "Horizontal Position"), selection: $preferences.edge) {
                    Text(L("左侧", "Left")).tag(SillCore.SidebarEdge.left)
                    Text(L("右侧", "Right")).tag(SillCore.SidebarEdge.right)
                }.pickerStyle(.segmented)
                Picker(L("垂直位置", "Vertical Position"), selection: $preferences.vertical) {
                    Text(L("顶部", "Top")).tag("top"); Text(L("居中", "Center")).tag("center"); Text(L("底部", "Bottom")).tag("bottom")
                }.pickerStyle(.segmented)
            }
            Section(L("悬停与收起", "Hover & Collapse")) {
                Picker(L("鼠标离开时", "When Cursor Leaves"), selection: $preferences.resting) {
                    ForEach(SillCore.RestingMode.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                HStack { Text(L("展开宽度", "Expanded Width")); Slider(value: $preferences.width, in: 180...600, step: 10); Text("\(Int(preferences.width))").monospacedDigit().frame(width: 34) }
                Text(L("鼠标移到侧边栏上自动展开；向屏幕边缘横向滚动可暂时隐藏，再次移到边缘即可展开。", "Hover to expand. Scroll horizontally toward the display edge to hide temporarily; return to the edge to reveal it.")).font(.caption).foregroundStyle(.secondary)
            }
            Section(L("窗口避让", "Window Clearance")) {
                Toggle(L("自动调整窗口宽度，避免被侧边栏遮挡", "Auto-adjust Window Widths to Avoid Overlap"), isOn: $preferences.autoAvoid)
                Text(L("仅为收起状态预留空间；不调整全屏或最小化窗口。手动调整过的窗口暂停避让 60 秒。", "Reserves the resting width only. Full-screen and minimized windows are excluded. Manual resizing pauses adjustment for 60 seconds.")).font(.caption).foregroundStyle(.secondary)
                Button(L("还原本次自动调整的窗口", "Restore Automatically Adjusted Windows"), action: restore)
            }
        }
    }
    private var appearance: some View {
        Group {
            Section(L("语言", "Language")) {
                Picker(L("界面语言", "Interface Language"), selection: $preferences.language) {
                    Text(L("跟随系统", "Follow System")).tag("system")
                    Text("简体中文").tag("zh-Hans"); Text("English").tag("en")
                }
                Text(L("立即生效，无需重启。", "Applies immediately, without restarting.")).foregroundStyle(.secondary).font(.caption)
            }
            Section(L("外观", "Appearance")) {
                Picker(L("侧边栏材质", "Sidebar Material"), selection: $preferences.sidebarMaterial) {
                    if #available(macOS 26.0, *) {
                        Text(L("液态玻璃", "Liquid Glass")).tag("glass")
                        Text(L("通透玻璃", "Clear Glass")).tag("clearGlass")
                    } else {
                        Text(L("液态玻璃（使用毛玻璃）", "Liquid Glass (Frosted Fallback)")).tag("glass")
                        Text(L("通透玻璃（使用毛玻璃）", "Clear Glass (Frosted Fallback)")).tag("clearGlass")
                    }
                    Text(L("经典毛玻璃", "Classic Frosted")).tag("frosted")
                }
                if #available(macOS 26.0, *) {
                    Text(L("液态玻璃呈现柔和的折射与层次；通透玻璃更轻盈，经典毛玻璃更柔和。切换立即生效。", "Liquid Glass adds depth and refraction. Clear Glass is more transparent; Classic Frosted gives a softer blur. Changes apply immediately.")).font(.caption).foregroundStyle(.secondary)
                } else {
                    Text(L("液态玻璃需要 macOS 26 或更新版本，当前系统使用经典毛玻璃。", "Liquid Glass requires macOS 26 or later. This Mac uses Classic Frosted.")).font(.caption).foregroundStyle(.secondary)
                }
                Picker(L("主题", "Theme"), selection: $preferences.theme) {
                    Text(L("跟随系统", "Follow System")).tag("system")
                    Text(L("浅色", "Light")).tag("light"); Text(L("深色", "Dark")).tag("dark")
                }.pickerStyle(.segmented)
                HStack { Text(L("文字和图标大小", "Text & Icon Size")); Slider(value: $preferences.textSize, in: 11...20, step: 1); Text("\(Int(preferences.textSize))").monospacedDigit() }
                Text(L("采用系统字体与背景材质，遵循系统的减少动态效果设置。", "Uses system fonts and materials, and respects Reduce Motion.")).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    private var rules: some View {
        Group {
            Section {
                Picker(L("窗口分组", "Group Windows"), selection: $preferences.grouping) {
                    Text(L("按可见性", "By Visibility")).tag("visibility")
                    Text(L("按应用", "By App")).tag("app")
                    Text(L("不分组", "One Group")).tag("none")
                }
                Toggle(L("显示最小化的窗口", "Show Minimized Windows"), isOn: $preferences.showMinimized)
                Toggle(L("显示没有窗口的运行中应用", "Show Running Apps Without Windows"), isOn: $preferences.showWindowless)
            }
            Section(L("排除规则", "Exclusion Rules")) {
                Text(L("应用 Bundle ID，每行一个", "App bundle IDs, one per line")).font(.caption).foregroundStyle(.secondary)
                TextEditor(text: $preferences.excluded).font(.system(.body, design: .monospaced)).frame(height: 100)
                Text(L("也可以右键点击侧边栏中的窗口，排除该应用。", "You can also right-click a sidebar window to exclude its app.")).font(.caption).foregroundStyle(.secondary)
                TextField(L("窗口标题正则表达式", "Window Title Regular Expression"), text: $preferences.titleFilter)
                if !preferences.titleFilter.isEmpty && (try? NSRegularExpression(pattern: preferences.titleFilter)) == nil {
                    Text(L("正则表达式无效，暂不应用此规则。", "Invalid regular expression. This rule is not applied.")).font(.caption).foregroundStyle(.orange)
                }
            }
        }
    }
    private var keyboard: some View {
        Group {
            Section(L("窗口搜索", "Window Search")) {
                Toggle(L("Control + Option + 空格 打开搜索", "Control + Option + Space Opens Search"), isOn: $preferences.searchShortcut)
                Text(L("支持中文、英文、全拼和拼音首字母，例如微信可输入 weixin 或 wx。可用空格组合多个关键词。方向键或 Tab 选择，Enter 切换，Esc 取消。", "Search in Chinese, English, full pinyin or initials: use weixin or wx for 微信. Separate keywords with spaces. Select with arrows or Tab, switch with Enter, cancel with Esc.")).foregroundStyle(.secondary)
                Button(L("试用搜索", "Try Search"), action: search)
            }
            Section(L("数字切换", "Number Switching")) {
                Toggle(L("Control + Option + 1–9 切换窗口", "Control + Option + 1–9 Switches Windows"), isOn: $preferences.numberShortcut)
                Toggle(L("在侧边栏显示数字", "Show Numbers on Sidebar"), isOn: $preferences.showNumbers)
                Text(L("数字对应鼠标所在显示器侧边栏的前九个窗口。", "Numbers correspond to the first nine windows in the sidebar on the pointer’s display.")).font(.caption).foregroundStyle(.secondary)
            }
            Section(L("面板操作", "Panel Actions")) {
                LabeledContent(L("关闭窗口", "Close Window"), value: "⌘W")
                LabeledContent(L("最小化窗口", "Minimize Window"), value: "⌘M")
                LabeledContent(L("隐藏应用", "Hide App"), value: "⌘H")
            }
        }
    }
    private var about: some View {
        Section {
            VStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable().interpolation(.high).frame(width: 88, height: 88)
                Text("Sill").font(.system(size: 30, weight: .semibold))
                Text(L("版本 ", "Version ") + (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"))
                    .font(.callout).foregroundStyle(.secondary)
                Text(L("窗口在侧，随手可达。", "Your windows, within reach."))
                    .font(.body).foregroundStyle(.secondary).padding(.top, 8)
            }.frame(maxWidth: .infinity).padding(.vertical, 38)
        }
    }
}
import SillCore
