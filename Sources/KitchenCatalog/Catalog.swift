import Foundation

/// The shared list of grocery items. Apps store an item's `id` (it never changes) and show its
/// `name`; deals, statuses and notes are layers on top, keyed by the id.
public struct Catalog: Sendable {
    public struct Item: Sendable, Decodable {
        public let name: String
        public let section: String
        public let aliases: [String]
        /// A more general item this is a kind of ("onions-yellow" -> "onion").
        public let parent: String?
        /// Older ids for the same thing, so earlier data still links up.
        public let also: [String]?
        /// How many people buy it. Missing means common.
        public let popularity: Popularity?
        /// True for packaged and prepared types people buy ready-made (chips, soda, frozen pizza)
        /// rather than cook with. Missing means an ingredient. (Not the same as `Kinds`, which groups
        /// items by family: "White Miso" -> miso.)
        public let product: Bool?
    }

    /// Everyday: most households buy it most weeks (eggs, rice, chicken thighs, onions).
    /// Specialty: a smaller group buys it (beef tendon, geoduck). Grocery Deals ranks by it.
    public enum Popularity: String, Sendable, Decodable { case everyday, common, specialty }

    public struct Section: Sendable, Decodable, Identifiable {
        public let id: String
        public let name: String
    }

    public enum Strength: String, Sendable { case strong, weak }

    public struct Match: Sendable {
        public let id: String
        public let item: Item
        public let term: String
        /// Strong: it's what the product is. Weak: it's in there, maybe as a flavor ("shrimp chips").
        public let strength: Strength
    }

    public let version: Int
    public let sections: [Section]
    public let items: [String: Item]
    private let terms: [Term]

    private struct Term: Sendable {
        let id: String
        let term: String
        let words: Int
        let isName: Bool
    }

    private struct File: Decodable {
        let version: Int
        let sections: [Section]
        let items: [String: Item]
    }

    /// The catalog that ships with this package.
    public static let shared: Catalog = {
        guard let url = Bundle.module.url(forResource: "catalog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let catalog = try? Catalog(json: data) else { return Catalog(version: 0, sections: [], items: [:]) }
        return catalog
    }()

    public init(json: Data) throws {
        let file = try JSONDecoder().decode(File.self, from: json)
        self.init(version: file.version, sections: file.sections, items: file.items)
    }

    init(version: Int, sections: [Section], items: [String: Item]) {
        self.version = version
        self.sections = sections
        self.items = items
        var terms: [Term] = []
        for (id, item) in items {
            for name in [item.name] + item.aliases {
                let n = Self.normalize(name)
                if !n.isEmpty { terms.append(Term(id: id, term: n, words: n.split(separator: " ").count, isName: name == item.name)) }
            }
        }
        // Longest first; on a tie, an item's own name beats someone else's alias.
        self.terms = terms.sorted { ($0.words, $0.term.count, $0.isName ? 1 : 0, $1.id) > ($1.words, $1.term.count, $1.isName ? 1 : 0, $0.id) }
    }

    public func section(_ id: String) -> Section? { sections.first { $0.id == id } }

    /// The item for an id, including older ids listed in `also`.
    public func item(_ id: String) -> (id: String, item: Item)? {
        if let item = items[id] { return (id, item) }
        return items.first { $0.value.also?.contains(id) == true }.map { ($0.key, $0.value) }
    }

    // MARK: matching (the same rules as js/catalog.mjs)

    /// "Chicken Leg-Quarters, 10 lb!" -> "chicken leg quarter 10 lb"
    public static func normalize(_ text: String) -> String {
        var t = text.lowercased().replacingOccurrences(of: "&", with: " and ").replacingOccurrences(of: "’", with: "").replacingOccurrences(of: "'", with: "")
        t = t.replacingOccurrences(of: #"[^a-z0-9À-ɏ぀-ヿ一-鿿]+"#, with: " ", options: .regularExpression)
        return t.split(separator: " ").map { singular(String($0)) }.joined(separator: " ")
    }

    private static func singular(_ w: String) -> String {
        if w.count <= 3 || w.hasSuffix("ss") || w.hasSuffix("us") || w.hasSuffix("is") { return w }
        if w.hasSuffix("ies") { return String(w.dropLast(3)) + "y" }
        if ["oes", "ches", "shes", "xes"].contains(where: w.hasSuffix) { return String(w.dropLast(2)) }
        return w.hasSuffix("s") ? String(w.dropLast()) : w
    }

    private static let qualifier = try! NSRegularExpression(pattern: #"^(?:organic|fresh|frozen|large|small|medium|jumbo|extra|select|premium|natural|local|whole|boneless|skinless|bone|skin|in|on|sliced|diced|chopped|bag|pack|package|tray|bunch|ea|each|ct|count|pc|pcs|lb|lbs|oz|fl|kg|g|ml|l|gal|dozen|doz|value|family|club|bulk|assorted|headless|cut|fillet|filet|steak|portion|piece|chunk|point|flat|roll|wing|midjoint|tip|loin|chop|shank|half|jarred|canned|bottle|jar|can|selected|variety|variant|series|size|pk|multi|single|qt|inch|of|to|the|shell|square|fz|live|box|case|regular|light|original|mini|\d+(?:\.\d+)?(?:g|kg|ml|oz|lb|ct|pk)?)$"#)
    private static let changesIt: Set<String> = ["soy", "oat", "almond", "coconut", "rice", "plant", "based", "cashew", "chocolate", "strawberry", "banana", "condensed", "evaporated", "powdered", "flavored", "shrimp", "fish"]

    private static func isQualifier(_ w: String) -> Bool {
        qualifier.firstMatch(in: w, range: NSRange(w.startIndex..., in: w)) != nil
    }

    /// The catalog item a piece of text names, or nil. Only fill things in automatically from
    /// strong matches; weak ones are worth asking about.
    public func match(_ text: String) -> Match? {
        // "Braised croaker with rice cake", "Goat meat w/skin on": the product is what comes before "with".
        let main = text.range(of: #"\s+(?:with\b|w/)\s*"#, options: [.regularExpression, .caseInsensitive])
            .map { String(text[..<$0.lowerBound]) }
            .flatMap { $0.isEmpty ? nil : $0 } ?? text
        let a = read(main)
        let b = Self.reorder(main).flatMap(read)
        // "Popcorn, Butter Lovers or Movie Theater Butter": when the part before the comma names the
        // product outright, it wins over a flavor or variant after the comma.
        let pick: (Match, Int)? = switch (a, b) {
        case let (a?, b?): (b.0.strength == .strong && a.0.strength == .strong) || b.1 >= a.1 ? b : a
        case let (a?, nil): a
        case let (nil, b?): b
        default: nil
        }
        return pick?.0
    }

    /// "Onion - Green" -> "green onion"; "Onion, yellow boiler" -> "yellow boiler onion"
    private static func reorder(_ text: String) -> String? {
        let t = text.replacingOccurrences(of: #"\([^)]*\)"#, with: " ", options: .regularExpression)
        guard let r = t.range(of: #"^([^,\-–]+)\s*[,\-–]\s*([^,]+)$"#, options: .regularExpression) else { return nil }
        let parts = t[r].split(whereSeparator: { ",-–".contains($0) }).map { $0.trimmingCharacters(in: .whitespaces) }
        return parts.count == 2 ? "\(parts[1]) \(parts[0])" : nil
    }

    private func read(_ candidate: String) -> (Match, Int)? {
        let words = Self.normalize(candidate.replacingOccurrences(of: #"\([^)]*\)"#, with: " ", options: .regularExpression)).split(separator: " ").map(String.init)
        guard !words.isEmpty else { return nil }
        var end = words.count
        while end > 1, Self.isQualifier(words[end - 1]) { end -= 1 }
        let all = " " + words.joined(separator: " ") + " "
        var best: (Match, Int)?
        for t in terms {
            guard let at = all.range(of: " \(t.term) ") else { continue }
            // At the head: the term ends where the product name ends, give or take trailing qualifiers.
            // A term may run into the qualifiers ("beef shank boneless": "shank" is also a cut word),
            // as long as it starts inside the product name ("salmon steak" is still salmon, not steak).
            let startWord = all[..<at.lowerBound].split(separator: " ").count
            let atHead = (startWord < end && startWord + t.words >= end) || all.hasSuffix(" \(t.term) ")
            let before = all[..<at.lowerBound].split(separator: " ").last.map(String.init) ?? ""
            let changed = t.words == 1 && Self.changesIt.contains(before)
            let termWords = Set(t.term.split(separator: " ").map(String.init))
            let rest = Set(words).subtracting(termWords)
            let nameWords = Self.normalize(items[t.id]?.name ?? "").split(separator: " ").map(String.init).filter { !termWords.contains($0) }
            let overlap = nameWords.filter(rest.contains).count
            let strong = atHead && !changed && (t.words >= 2 || t.isName || end <= 3)
            let score = t.words * 10 + overlap * 3 + (atHead ? 2 : 0) + (t.isName ? 1 : 0) + (strong ? 5 : 0)
            if best == nil || score > best!.1, let item = items[t.id] {
                best = (Match(id: t.id, item: item, term: t.term, strength: strong ? .strong : .weak), score)
            }
        }
        return best
    }
}
