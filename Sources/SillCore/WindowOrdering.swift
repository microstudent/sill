/// Clusters windows by app while preserving each app's first position and its window order.
public enum WindowOrdering {
    public static func adjacentByApplication<Item, AppID: Hashable>(_ items: [Item], applicationID: (Item) -> AppID) -> [Item] {
        var order: [AppID] = []
        var buckets: [AppID: [Item]] = [:]
        for item in items {
            let key = applicationID(item)
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: []].append(item)
        }
        return order.flatMap { buckets[$0] ?? [] }
    }
}
