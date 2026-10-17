import Foundation

public enum WindowSearch {
    /// Build once per app/title change; scoring itself never transliterates text.
    public struct Document: Sendable {
        fileprivate let name: Field
        fileprivate let title: Field
        public init(title: String, app: String) {
            name = Field(app)
            self.title = Field(title)
        }
    }

    fileprivate struct Field: Sendable {
        let literal: String
        let pinyin: String
        let initials: String

        init(_ value: String) {
            literal = normalize(value)
            // Do not broaden plain English titles into unrelated acronym matches.
            let hasHan = value.unicodeScalars.contains {
                (0x3400...0x9FFF).contains($0.value) || (0x20000...0x323AF).contains($0.value) || (0xF900...0xFAFF).contains($0.value)
            }
            guard hasHan else { pinyin = ""; initials = ""; return }
            let latin = normalize(value.applyingTransform(.toLatin, reverse: false) ?? value)
            let syllables = latin.split { !$0.isLetter && !$0.isNumber }
            pinyin = syllables.joined()
            initials = String(syllables.compactMap(\.first))
        }
    }

    private static func normalize(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }

    public static func score(query: String, title: String, app: String) -> Int? {
        score(query: query, document: Document(title: title, app: app))
    }

    public static func score(query: String, document: Document) -> Int? {
        let tokens = normalize(query).split(whereSeparator: \.isWhitespace)
        guard !tokens.isEmpty else { return 0 }
        var total = 0
        for token in tokens {
            let term = String(token)
            var matches: [Int] = []
            for (field, appBonus) in [(document.name, 20), (document.title, 0)] {
                if field.literal == term { matches.append(140 + appBonus) }
                else if field.literal.hasPrefix(term) { matches.append(120 + appBonus) }
                else if field.literal.contains(term) { matches.append(100 + appBonus) }

                // Apostrophes / hyphens may delimit syllables; v also represents ü in input methods.
                let roman = term.replacingOccurrences(of: "'", with: "").replacingOccurrences(of: "’", with: "").replacingOccurrences(of: "-", with: "")
                guard !roman.isEmpty, roman.unicodeScalars.allSatisfy({ (97...122).contains($0.value) || (48...57).contains($0.value) }) else { continue }
                let full = roman.replacingOccurrences(of: "v", with: "u")
                if !field.pinyin.isEmpty {
                    if field.pinyin == full { matches.append(80 + appBonus) }
                    else if field.pinyin.hasPrefix(full) { matches.append(70 + appBonus) }
                    else if field.pinyin.contains(full) { matches.append(60 + appBonus) }
                }
                if !field.initials.isEmpty {
                    if field.initials == roman { matches.append(50 + appBonus) }
                    else if field.initials.hasPrefix(roman) { matches.append(40 + appBonus) }
                    else if field.initials.contains(roman) { matches.append(30 + appBonus) }
                }
            }
            guard let best = matches.max() else { return nil }
            total += best
        }
        return total
    }
}
