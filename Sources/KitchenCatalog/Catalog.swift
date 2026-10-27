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
    /// One-word names and aliases (for "Chicken & Pork"), and every word in each item's names (for cooking words).
    private let single: Set<String>
    private let ownWords: [String: Set<String>]

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
        self.single = Set(terms.filter { $0.words == 1 }.map(\.term))
        var direct: [String: Set<String>] = [:]
        for t in terms { direct[t.id, default: []].formUnion(t.term.split(separator: " ").map(String.init)) }
        // An item's own words include its parents' ("dried" for wood ear, a kind of dried mushroom).
        var own: [String: Set<String>] = [:]
        for (id, item) in items {
            var set = direct[id] ?? []
            var p = item.parent, n = 0
            while let next = p, n < 10 { set.formUnion(direct[next] ?? []); p = items[next]?.parent; n += 1 }
            own[id] = set
        }
        self.ownWords = own
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

    private static let qualifier = try! NSRegularExpression(pattern: #"^(?:organic|fresh|frozen|large|small|medium|jumbo|extra|select|premium|natural|local|whole|boneless|skinless|bone|skin|in|on|sliced|diced|chopped|bag|pack|package|tray|bunch|ea|each|ct|count|pc|pcs|lb|lbs|oz|fl|kg|g|ml|l|gal|dozen|doz|value|family|club|bulk|assorted|headless|cut|fillet|filet|steak|portion|piece|chunk|point|flat|roll|wing|midjoint|tip|loin|chop|shank|half|jarred|canned|bottle|jar|can|selected|variety|variant|series|size|pk|multi|single|qt|inch|of|to|the|shell|square|fz|live|box|case|regular|light|original|mini|roast|firm|soft|up|and|s|h|o|p|d|head|tail|off|peeled|deveined|raw|cooked|\d+(?:\.\d+)?(?:g|kg|ml|oz|lb|ct|pk)?)$"#)
    private static let changesIt: Set<String> = ["soy", "oat", "almond", "coconut", "rice", "plant", "based", "cashew", "chocolate", "strawberry", "banana", "condensed", "evaporated", "powdered", "flavored", "shrimp", "fish"]
    // A cooking word before an ingredient makes the line a dish, not the grocery: "Braised Yellow Croaker with Rice Cake",
    // "Stewed Pork Trotters", "Spiced Butternut Squash". Such matches are weak (sent to review). Ready-made products
    // ("Glazed Donuts", "Fried Leek Pie") and items with the word in one of their names ("fried dace") are unaffected.
    private static let dish: Set<String> = ["braised", "stewed", "spiced", "marinated", "steamed", "grilled", "sauteed", "glazed", "fried", "roasted", "rotisserie",
                                            "bbq", "barbecue", "pulled", "salted", "dried", "preserved", "pickled", "sour", "candied"]

    private static func isQualifier(_ w: String) -> Bool {
        qualifier.firstMatch(in: w, range: NSRange(w.startIndex..., in: w)) != nil
    }

    /// The catalog item a piece of text names, or nil. Only fill things in automatically from
    /// strong matches; weak ones are worth asking about.
    public func match(_ text: String) -> Match? {
        // "Braised croaker with rice cake", "Goat meat w/skin on": the product is what comes before "with".
        // (Reading the whole name when that part names nothing was tried: it turned "Braised Yellow Croaker
        // with Rice Cake" into rice cakes.) "Beef short rib for soup": likewise before "for", but only when
        // that part names something ("Pork for stew" is stew meat, not pork).
        let beforeWith = text.range(of: #"\s+(?:with\b|w/)\s*"#, options: [.regularExpression, .caseInsensitive])
            .map { String(text[..<$0.lowerBound]) }
            .flatMap { $0.isEmpty ? nil : $0 } ?? text
        let beforeFor = beforeWith.range(of: #"\s+for\b\s*"#, options: [.regularExpression, .caseInsensitive])
            .map { String(beforeWith[..<$0.lowerBound]) }
            .flatMap { $0.isEmpty ? nil : $0 }
        // ...unless a name or alias that itself says "for" is what the whole line is ("pork for stew", "beef for stew").
        let saysFor = read(beforeWith).map { $0.0.strength == .strong && $0.0.term.split(separator: " ").contains("for") } ?? false
        let main = saysFor ? beforeWith : (beforeFor.flatMap { read($0) != nil ? $0 : nil } ?? beforeWith)
        let a = read(main)
        let b = Self.reorder(main).flatMap(read)
        // "Popcorn, Butter Lovers or Movie Theater Butter": when the part before the comma names the
        // product outright, it wins over a flavor or variant after the comma.
        var pick: (Match, Int)? = switch (a, b) {
        case let (a?, b?): (b.0.strength == .strong && a.0.strength == .strong) || b.1 >= a.1 ? b : a
        case let (a?, nil): a
        case let (nil, b?): b
        default: nil
        }
        // "Boneless Beef Top Sirloin Steaks, Premium Beef, Value Pack": with more than one comma and no
        // strong reading yet, the part before the first comma is the product.
        if pick?.0.strength != .strong, main.filter({ $0 == "," }).count >= 2,
           let first = main.split(separator: ",", maxSplits: 1).first, let c = read(String(first)), c.0.strength == .strong {
            pick = c
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
        var bestStart = 0
        var strongIds: Set<String> = []
        var seen: [(term: Term, start: Int)] = []
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
            if strong { strongIds.insert(t.id) }
            seen.append((term: t, start: startWord))
            if best == nil || score > best!.1, let item = items[t.id] {
                best = (Match(id: t.id, item: item, term: t.term, strength: strong ? .strong : .weak), score)
                bestStart = startWord
            }
        }
        // A longer alias found mid-name ("cosmic crisp" in "Cosmic Crisp Apples") is still a strong match
        // when another name for the same item is at the head.
        if let found = best, found.0.strength == .weak, strongIds.contains(found.0.id) {
            let m = found.0
            best = (Match(id: m.id, item: m.item, term: m.term, strength: .strong), found.1)
        }
        if let found = best, found.0.strength == .strong {
            let m = found.0
            let own = ownWords[m.id] ?? []
            let cooked = m.item.product != true && words[..<bestStart].contains { Self.dish.contains($0) && !own.contains($0) }
            // "Hotdogs Chicken & Pork": a grocery, "and", then the item names what the product is made of. Weak.
            let madeOf = bestStart >= 2 && words[bestStart - 1] == "and" && single.contains(words[bestStart - 2])
            if cooked || madeOf { best = (Match(id: m.id, item: m.item, term: m.term, strength: .weak), found.1) }
        }
        // "Pepsi Wild Cherry", "Hi-Chew Mango": a ready-made product named earlier in the line, then a flavor. The line is
        // that product, sent to review (the longest such name wins, then the first). Words that are also the matched item's
        // own ("bun" in "Burger Buns", "soup" in "Soup Mix") don't count.
        if let current = best, current.0.strength == .strong, current.0.item.product != true {
            let own = ownWords[current.0.id] ?? []
            let prior = seen
                .filter { f in
                    items[f.term.id]?.product == true && f.start + f.term.words <= bestStart
                        && !f.term.term.split(separator: " ").allSatisfy { word in own.contains(String(word)) }
                }
                .min { a, b in (a.term.words, -a.start) > (b.term.words, -b.start) }
            if let prior, let item = items[prior.term.id] {
                best = (Match(id: prior.term.id, item: item, term: prior.term.term, strength: .weak), current.1)
            }
        }
        return best
    }
}
