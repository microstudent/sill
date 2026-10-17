import AppKit
import Combine
import SillCore

final class Preferences: ObservableObject {
    static func migrateLegacyDefaultsIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: "didMigrateFromPrototype") else { return }
        let current = defaults.persistentDomain(forName: "local.sill.app") ?? [:]
        if let legacy = defaults.persistentDomain(forName: "local.contextsfork.app") {
            for (key, value) in legacy where current[key] == nil {
                defaults.set(value, forKey: key)
            }
        }
        defaults.set(true, forKey: "didMigrateFromPrototype")
    }
    static let shared = Preferences()
    private let defaults = UserDefaults.standard
    @Published var language: String { didSet { save(language, "language") } }
    @Published var edge: SidebarEdge { didSet { save(edge.rawValue, "edge") } }
    @Published var resting: RestingMode { didSet { save(resting.rawValue, "resting") } }
    @Published var width: Double { didSet { save(width, "width") } }
    @Published var textSize: Double { didSet { save(textSize, "textSize") } }
    @Published var vertical: String { didSet { save(vertical, "vertical") } }
    @Published var displays: String { didSet { save(displays, "displays") } }
    @Published var scope: String { didSet { save(scope, "scope") } }
    @Published var grouping: String { didSet { save(grouping, "grouping") } }
    @Published var theme: String { didSet { save(theme, "theme") } }
    @Published var sidebarMaterial: String { didSet { save(sidebarMaterial, "sidebarMaterial") } }
    @Published var showMinimized: Bool { didSet { save(showMinimized, "showMinimized") } }
    @Published var showWindowless: Bool { didSet { save(showWindowless, "showWindowless") } }
    @Published var autoAvoid: Bool { didSet { save(autoAvoid, "autoAvoid") } }
    @Published var excluded: String { didSet { save(excluded, "excluded") } }
    @Published var titleFilter: String { didSet { save(titleFilter, "titleFilter") } }
    @Published var searchShortcut: Bool { didSet { save(searchShortcut, "searchShortcut") } }
    @Published var numberShortcut: Bool { didSet { save(numberShortcut, "numberShortcut") } }
    @Published var showNumbers: Bool { didSet { save(showNumbers, "showNumbers") } }
    var onChange: (() -> Void)?

    init() {
        defaults.register(defaults: ["language":"system", "edge":"left", "resting":"icons", "width":210.0,
            "textSize":14.0, "vertical":"center", "displays":"all", "scope":"displayAll", "grouping":"visibility",
            "theme":"system", "sidebarMaterial":"glass", "showMinimized":true, "showWindowless":false, "autoAvoid":false,
            "excluded":"", "titleFilter":"", "searchShortcut":true, "numberShortcut":false, "showNumbers":false])
        language = defaults.string(forKey: "language")!
        edge = SidebarEdge(rawValue: defaults.string(forKey: "edge")!) ?? .left
        resting = RestingMode(rawValue: defaults.string(forKey: "resting")!) ?? .icons
        width = min(600, max(180, defaults.double(forKey: "width")))
        textSize = min(20, max(11, defaults.double(forKey: "textSize")))
        vertical = defaults.string(forKey: "vertical")!
        displays = defaults.string(forKey: "displays")!
        scope = defaults.string(forKey: "scope")!
        grouping = defaults.string(forKey: "grouping")!
        theme = defaults.string(forKey: "theme")!
        sidebarMaterial = defaults.string(forKey: "sidebarMaterial")!
        showMinimized = defaults.bool(forKey: "showMinimized")
        showWindowless = defaults.bool(forKey: "showWindowless")
        autoAvoid = defaults.bool(forKey: "autoAvoid")
        excluded = defaults.string(forKey: "excluded")!
        titleFilter = defaults.string(forKey: "titleFilter")!
        searchShortcut = defaults.bool(forKey: "searchShortcut")
        numberShortcut = defaults.bool(forKey: "numberShortcut")
        showNumbers = defaults.bool(forKey: "showNumbers")
    }
    private func save(_ value: Any, _ key: String) { defaults.set(value, forKey: key); onChange?() }
    var isChinese: Bool { language == "zh-Hans" || (language == "system" && (Locale.preferredLanguages.first?.hasPrefix("zh") ?? false)) }
    var rowHeight: CGFloat { CGFloat(textSize + 12) }
    var restingWidth: CGFloat { resting == .expanded ? width : resting.width }
    var appearance: NSAppearance? {
        theme == "light" ? NSAppearance(named: .aqua) : theme == "dark" ? NSAppearance(named: .darkAqua) : nil
    }
}

func L(_ chinese: String, _ english: String) -> String { Preferences.shared.isChinese ? chinese : english }

extension RestingMode {
    var label: String {
        switch self {
        case .hidden: return L("隐藏", "Hide")
        case .icons: return L("仅显示图标", "Show Icons")
        case .titleStart: return L("图标和标题开头", "Icons & Title Start")
        case .expanded: return L("保持展开", "Keep Expanded")
        }
    }
}
