import Foundation

// Swift only. Moved from PantryKit on 2026-10-25 so both apps can use it. Unlike `Catalog.match`,
// this has no JavaScript twin, so the Swift/JS parity rule in the README doesn't cover it.

/// Something text can be matched to by name: a pantry item, a list item.
public protocol MatchableItem: Sendable {
    var id: String { get }
    var name: String { get }
    var aliases: [String] { get }
    /// Extra words used only by the shortlist ("Korean red pepper paste"). Nil unless an item has one.
    var matchDescription: String? { get }
}

extension MatchableItem {
    public var matchDescription: String? { nil }
}

/// The word lists `NameMatcher` uses. (A generic type can't hold static stored properties.)
public enum MatchWords {
    public static let staples: Set<String> = Set(["water", "ice", "ice water", "boiling water", "hot water", "cold water", "warm water"].map(Names.key))
    public static let descriptors: Set<String> = Set("""
        fresh freshly ground finely coarsely chopped minced sliced diced grated toasted roasted boneless skinless skin-on \
        unsalted salted low-sodium reduced-sodium cooked uncooked dried soft firm silken extra-firm thinly thick thin cold hot warm \
        peeled crushed whole large small medium plus about
        """.split(separator: " ").map(String.init))

    /// Generic words recipes tack on after the ingredient: "Thai basil leaves", "panko bread crumbs".
    public static let trailingGeneric: [[String]] = ["leaves", "leaf", "sprigs", "bread crumbs", "breadcrumbs", "crumbs"]
        .map { Names.key($0).split(separator: " ").map(String.init) }

    public static let formWords: Set<String> = Set(["dried", "ground", "powder", "canned", "tinned", "frozen", "pickled", "smoked", "instant", "flakes"].map(Names.key))
}

/// Matches a name or recipe line to one of a set of items: alias lookup, then a shortlist.
/// On Hand uses it over pantry items (`Matcher` in PantryKit); any list of `MatchableItem`s works.
public struct NameMatcher<Item: MatchableItem>: Sendable {
    public let items: [Item]
    public let byID: [String: Item]
    public private(set) var aliases: [String: String] = [:]   // key -> item id
    /// Each item's name, alias and description keys, worked out once: the shortlist compares
    /// every item for every unknown line, so keying names there was the slow part.
    private let itemKeys: [(id: String, keys: [(words: Set<String>, trigrams: Set<String>)])]

    public init(items source: [Item], learned: [String: String] = [:]) {
        items = source
        byID = Dictionary(uniqueKeysWithValues: source.map { ($0.id, $0) })
        itemKeys = source.map { item in
            let names = [item.name] + item.aliases + (item.matchDescription.map { [$0] } ?? [])
            return (item.id, names.map { n in
                let kn = Names.key(n)
                return (Set(kn.split(separator: " ").map(String.init)), Self.trigrams(kn))
            })
        }
        for item in source {
            for name in [item.name] + item.aliases {
                let k = Names.key(name)
                if aliases[k] == nil { aliases[k] = item.id }
            }
        }
        for (k, id) in learned where byID[id] != nil { aliases[Names.key(k)] = id }
    }

    public mutating func learn(_ name: String, id: String) { aliases[Names.key(name)] = id }

    public func isStaple(_ name: String) -> Bool { MatchWords.staples.contains(Names.key(name)) }

    /// Lookup in order:
    /// 1. exact name or alias
    /// 2. without a generic trailing word ("Thai basil leaves" -> "thai basil")
    /// 3. without leading descriptors ("boneless pork shoulder" -> "pork shoulder")
    /// 4. a trailing phrase of 2+ words ("Thai bird's eye chilies" -> "bird's eye chilies").
    ///    Single trailing words are too risky: "sansho pepper" must not become "pepper".
    public func lookup(_ name: String) -> String? {
        let k = Names.key(name)
        guard !k.isEmpty else { return nil }
        if let id = aliases[k] { return id }
        let all = k.split(separator: " ").map(String.init)

        for tail in MatchWords.trailingGeneric where all.count > tail.count && Array(all.suffix(tail.count)) == tail {
            if let id = aliases[all.dropLast(tail.count).joined(separator: " ")] { return id }
        }

        var words = all
        while words.count > 1, MatchWords.descriptors.contains(words[0]) {
            words.removeFirst()
            if let id = aliases[words.joined(separator: " ")] { return id }
        }

        if all.count > 2 {
            for start in 1...(all.count - 2) {
                if let id = aliases[all[start...].joined(separator: " ")] { return id }
            }
        }
        return nil
    }

    /// A word check on the model's pick, which it can't talk its way past:
    /// - the item's main (last) word, from its name or an alias, must appear in the recipe line
    ///   ("butter" is not a word in "buttermilk"; "quarters" is not in "chicken thigh")
    /// - a form word in the item's name ("dried shrimp") must appear in the line too.
    public func plausible(line: ParsedLine, item: Item) -> Bool {
        let lineWords = Set(Names.key(line.raw).split(separator: " ").map(String.init))
        let headMatches = ([item.name] + item.aliases).contains { name in
            guard let head = Names.key(name).split(separator: " ").last else { return false }
            return lineWords.contains(String(head))
        }
        guard headMatches else { return false }
        let itemWords = Set(Names.key(item.name).split(separator: " ").map(String.init))
        for form in MatchWords.formWords where itemWords.contains(form) && !lineWords.contains(form) {
            if form == "canned" && lineWords.contains("can") { continue }  // "1 (28-ounce) can ..."
            return false
        }
        return true
    }

    /// Several items of the same kind ("miso" with Aka Miso, White Miso, ...): the user should choose.
    public func sameKind(_ name: String, among candidates: [String]) -> [String] {
        let k = Names.key(name)
        guard !k.isEmpty else { return [] }
        return candidates.filter { id in
            guard let item = byID[id] else { return false }
            let n = Names.key(item.name)
            return n == k || n.hasSuffix(" " + k)
        }
    }

    /// The closest items by word overlap and character trigrams.
    public func shortlist(_ name: String, limit: Int = 8) -> [String] {
        let k = Names.key(name)
        let q = Set(k.split(separator: " ").map(String.init))
        let qt = Self.trigrams(k)
        var scored: [(Double, String)] = []
        for item in itemKeys {
            var best = 0.0
            for (words, tn) in item.keys {
                let w = Double(q.intersection(words).count) / Double(max(1, q.union(words).count))
                let t = Double(qt.intersection(tn).count) / Double(max(1, qt.union(tn).count))
                best = max(best, 0.6 * w + 0.4 * t)
            }
            scored.append((best, item.id))
        }
        scored.sort { $0.0 == $1.0 ? $0.1 > $1.1 : $0.0 > $1.0 }
        return scored.prefix(limit).filter { $0.0 > 0.05 }.map { $0.1 }
    }

    private static func trigrams(_ s: String) -> Set<String> {
        let c = Array(s)
        guard c.count >= 3 else { return [s] }
        return Set((0...(c.count - 3)).map { String(c[$0..<($0 + 3)]) })
    }
}
