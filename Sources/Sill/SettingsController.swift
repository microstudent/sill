import SwiftUI
import AppKit
import ServiceManagement

final class SettingsNavigation: ObservableObject { @Published var page = "welcome" }

final class SettingsController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let service: WindowService
    private let hotkeys: HotKeyManager
    private let navigation = SettingsNavigation()
    var restoreWindows: (() -> Void)?
    var showSearch: (() -> Void)?
    init(service: WindowService, hotkeys: HotKeyManager) { self.service = service; self.hotkeys = hotkeys; super.init() }
    func show(page: String? = nil) {
        if let page { navigation.page = page }
        if window == nil {
            let view = SettingsView(preferences: .shared, service: service, navigation: navigation, hotkeys: hotkeys, restore: { [weak self] in self?.restoreWindows?() }, search: { [weak self] in self?.showSearch?() })
            let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 860, height: 660), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
            window.contentView = NSHostingView(rootView: view)
            window.minSize = NSSize(width: 800, height: 620)
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.backgroundColor = .windowBackgroundColor
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
    @ObservedObject var navigation: SettingsNavigation
    @ObservedObject var hotkeys: HotKeyManager
    let restore: () -> Void
    let search: () -> Void
    private var page: String { navigation.page }
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
        HStack(spacing: 0) {
            SettingsNavigationPane(material: preferences.sidebarMaterial) {
                VStack(alignment: .leading, spacing: 0) {
                    List(selection: $navigation.page) {
                        ForEach(pages, id: \.0) { id, title, symbol in
                            HStack(spacing: 9) {
                                Image(systemName: symbol).font(.system(size: 15, weight: .regular))
                                    .symbolRenderingMode(.hierarchical).frame(width: 20, height: 20)
                                Text(id == "appearance" ? L("外观与语言", "Appearance") : title).font(.system(size: 13)).help(title)
                            }.tag(id).padding(.vertical, 4)
                        }
                    }.listStyle(.sidebar).scrollContentBackground(.hidden).padding(.top, 12)
                    if !service.trusted {
                        Label(L("需要辅助功能权限", "Accessibility required"), systemImage: "exclamationmark.circle")
                            .font(.caption).foregroundStyle(.orange).padding(14)
                    }
                }.background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
            }.frame(width: 208)
            Rectangle().fill(Color(nsColor: .separatorColor).opacity(0.35)).frame(width: 0.5)
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(pages.first { $0.0 == page }?.1 ?? "").font(.system(size: 22, weight: .semibold))
                    Text(pageDescription).font(.callout).foregroundStyle(.secondary)
                }.padding(.horizontal, 28).padding(.top, 36).padding(.bottom, 4)
                Form {
                    switch page {
                    case "sidebar": sidebar
                    case "appearance": appearance
                    case "rules": rules
                    case "keyboard": ShortcutSettings(preferences: preferences, hotkeys: hotkeys, search: search)
                    case "about": about
                    default: welcome
                    }
                }.formStyle(.grouped).scrollContentBackground(.hidden).id(page)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
        }.frame(minWidth: 800, minHeight: 580).background(Color(nsColor: .windowBackgroundColor))
            .ignoresSafeArea(.container, edges: .top)
    }
    private var pageDescription: String {
        switch page {
        case "sidebar": return L("让窗口出现在顺手的位置。", "Keep your windows within easy reach.")
        case "appearance": return L("选择适合你的外观与阅读体验。", "Make Sill feel at home on your Mac.")
        case "rules": return L("只留下你想看到的窗口。", "Choose the windows you want to see.")
        case "keyboard": return L("用熟悉的组合键，快速找到窗口。", "Reach any window with shortcuts that feel familiar.")
        case "about": return L("窗口在侧，随手可达。", "Your windows, within reach.")
        default: return L("从屏幕边缘，轻松切换每一个窗口。", "Switch between windows from the edge of your screen.")
        }
    }
    private var welcome: some View {
        Group {
            Section {
                Text(L("把窗口放在屏幕边缘，悬停展开，点击即达。", "Keep your windows at the edge. Hover to expand. Click to switch.")).font(.title3).padding(.vertical, 8)
                Text(L("更轻松地找到并切换每一个窗口。", "Find and switch between your windows with ease.")).foregroundStyle(.secondary)
            }
            if !service.trusted {
                Section(L("辅助功能权限", "Accessibility Permission")) {
                    Label(L("需要你在系统设置中开启权限", "Enable access in System Settings"), systemImage: "hand.raised")
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
                Toggle(L("根据标题自动调整展开宽度", "Fit Expanded Width to Titles"), isOn: $preferences.adaptiveWidth)
                if preferences.adaptiveWidth {
                    Text(L("展开时自动选择 300–420 点宽度，本次展开期间保持稳定。悬停在截断的标题上可查看完整内容。", "Automatically uses 300–420 pt and keeps the width steady until collapse. Hover over a truncated title to see it in full.")).font(.caption).foregroundStyle(.secondary)
                } else {
                    HStack { Text(L("展开宽度", "Expanded Width")); Slider(value: $preferences.width, in: 180...600, step: 10); Text("\(Int(preferences.width))").monospacedDigit().frame(width: 34) }
                }
                Text(L("鼠标移到侧边栏上自动展开；向屏幕边缘横向滚动可暂时隐藏，再次移到边缘即可展开。", "Hover to expand. Scroll horizontally toward the display edge to hide temporarily; return to the edge to reveal it.")).font(.caption).foregroundStyle(.secondary)
            }
            Section(L("窗口避让", "Window Clearance")) {
                Toggle(L("自动调整窗口宽度，避免被侧边栏遮挡", "Auto-adjust Window Widths to Avoid Overlap"), isOn: $preferences.autoAvoid)
                Text(L("仅为收起状态预留空间；不调整全屏或最小化窗口。", "Reserves the resting width only. Full-screen and minimized windows are excluded.")).font(.caption).foregroundStyle(.secondary)
                Toggle(L("手动调整窗口后，暂停避让 60 秒", "Pause Clearance for 60 Seconds After Manual Resizing"), isOn: $preferences.pauseAfterManualResize)
                    .disabled(!preferences.autoAvoid)
                Button(L("还原本次自动调整的窗口", "Restore Automatically Adjusted Windows"), action: restore)
            }
        }
    }
    private var appearance: some View {
        Group {
            Section {
                HStack(spacing: 16) {
                    ThemeChoice(value: "system", title: L("跟随系统", "Automatic"), selection: $preferences.theme)
                    ThemeChoice(value: "light", title: L("浅色", "Light"), selection: $preferences.theme)
                    ThemeChoice(value: "dark", title: L("深色", "Dark"), selection: $preferences.theme)
                }.frame(maxWidth: .infinity).padding(.vertical, 6)
            } header: { Text(L("主题", "Theme")) }
            Section {
                Picker(L("界面材质", "Surface Material"), selection: $preferences.sidebarMaterial) {
                    if #available(macOS 26.0, *) {
                        Text(L("液态玻璃", "Liquid Glass")).tag("glass")
                        Text(L("通透玻璃", "Clear Glass")).tag("clearGlass")
                    } else {
                        Text(L("液态玻璃（毛玻璃替代）", "Liquid Glass (Frosted)")).tag("glass")
                        Text(L("通透玻璃（毛玻璃替代）", "Clear Glass (Frosted)")).tag("clearGlass")
                    }
                    Text(L("经典毛玻璃", "Classic Frosted")).tag("frosted")
                }
            } header: { Text(L("材质", "Material")) } footer: {
                Text(L("应用于侧边栏、窗口搜索和设置导航。", "Applies to the sidebar, window search and settings navigation."))
            }
            Section {
                HStack(spacing: 16) {
                    Text(L("文字和图标大小", "Text & Icon Size"))
                    Spacer(minLength: 16)
                    Slider(value: $preferences.textSize, in: 11...20, step: 1).frame(maxWidth: 190)
                        .accessibilityLabel(L("文字和图标大小", "Text & Icon Size"))
                    Text("\(Int(preferences.textSize))").monospacedDigit().foregroundStyle(.secondary).frame(width: 22)
                }
                Picker(L("界面语言", "Language"), selection: $preferences.language) {
                    Text(L("跟随系统", "System Default")).tag("system")
                    Text("简体中文").tag("zh-Hans"); Text("English").tag("en")
                }
            } header: { Text(L("文字与语言", "Text & Language")) } footer: {
                Text(L("更改立即生效。", "Changes apply immediately."))
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
    private var about: some View {
        Section {
            VStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable().interpolation(.high).frame(width: 88, height: 88)
                Text("Sill").font(.system(size: 30, weight: .semibold))
                Text(L("版本 ", "Version ") + (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"))
                    .font(.callout).foregroundStyle(.secondary)
                Text(L("窗口在侧，随手可达。", "Your windows, within reach."))
                    .font(.body).foregroundStyle(.secondary).padding(.top, 8)
            }.frame(maxWidth: .infinity).padding(.vertical, 38)
        }
    }
}
import SillCore
