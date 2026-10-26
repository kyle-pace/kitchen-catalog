import Foundation

// Swift only. Moved from PantryKit on 2026-10-25 so both apps can use it. Unlike `Catalog.match`,
// this has no JavaScript twin, so the Swift/JS parity rule in the README doesn't cover it.

/// What kind of thing an item is, so like things sit together in a list: "Aka Miso",
/// "White Miso" and "Yoka Miso" are all miso; "Enoki" and "King Oyster Mushrooms" are both
/// mushrooms. Mostly the last word of the name; a short list covers names that don't say it.
public enum Kinds {
    /// Words that name a kind without saying so.
    static let families: [String: String] = [
        "shiitake": "mushroom", "enoki": "mushroom", "maitake": "mushroom", "morel": "mushroom",
        "chanterelle": "mushroom", "cremini": "mushroom", "crimini": "mushroom", "portobello": "mushroom",
        "porcini": "mushroom", "shimeji": "mushroom", "wood ear": "mushroom",
        "chile": "chili", "chilli": "chili",
        "scallion": "onion", "shallot": "onion",
        "ramen": "noodle", "udon": "noodle", "soba": "noodle", "vermicelli": "noodle",
        "doenjang": "miso",
    ]

    /// Last words that describe a form rather than a thing ("Cumin, ground", "Peas frozen").
    static let qualifiers: Set<String> = ["dried", "fresh", "frozen", "whole", "ground", "raw", "organic", "large", "small"]

    /// The kind, lowercased and singular: "miso", "mushroom". Nil for an empty name.
    public static func kind(of name: String) -> String? {
        var text = name.lowercased()
        if let paren = text.firstIndex(of: "(") { text = String(text[..<paren]) }
        if let comma = text.firstIndex(of: ",") { text = String(text[..<comma]) }
        var words = text.split(whereSeparator: { !$0.isLetter && $0 != "'" }).map(String.init)
        while words.count > 1, let last = words.last, qualifiers.contains(last) { words.removeLast() }
        guard let last = words.last else { return nil }
        if words.count >= 2, let two = families[words.suffix(2).joined(separator: " ")] { return two }
        let word = singular(last)
        return families[word] ?? word
    }

    /// "mushrooms" -> "mushroom", "tomatoes" -> "tomato", "chilies" -> "chili", "leaves" -> "leaf".
    static func singular(_ w: String) -> String {
        guard w.count > 3 else { return w }
        if w == "chilies" || w == "chillies" { return "chili" }
        if ["cookies", "brownies", "smoothies", "veggies", "pierogies", "goodies"].contains(w) { return String(w.dropLast()) }
        if w.hasSuffix("ies") { return String(w.dropLast(3)) + "y" }
        if ["leaves": "leaf", "halves": "half", "loaves": "loaf"][w] != nil { return ["leaves": "leaf", "halves": "half", "loaves": "loaf"][w]! }
        if w.hasSuffix("oes") || w.hasSuffix("ches") || w.hasSuffix("shes") || w.hasSuffix("sses") || w.hasSuffix("xes") { return String(w.dropLast(2)) }
        if w.hasSuffix("ss") || w.hasSuffix("us") { return w }
        if w.hasSuffix("s") { return String(w.dropLast()) }
        return w
    }

    /// Names in A-to-Z order with like things together. A kind with two or more members sits
    /// where its own name falls ("Miso" under M); everything else sits where its name falls.
    /// Each run comes back with its kind when it has `minimum` or more members, for a subheading.
    public static func arrange<T>(_ items: [T], name: (T) -> String, minimum: Int = 3) -> [(kind: String?, items: [T])] {
        let kinds = items.map { kind(of: name($0)) }
        var counts: [String: Int] = [:]
        for k in kinds { if let k { counts[k, default: 0] += 1 } }
        let keyed = zip(items, kinds).map { item, k -> (key: String, kind: String?, item: T) in
            if let k, counts[k, default: 0] >= 2 { return (k, k, item) }
            return (name(item).lowercased(), nil, item)
        }
        let sorted = keyed.sorted { a, b in
            if a.key != b.key { return a.key.localizedCompare(b.key) == .orderedAscending }
            return name(a.item).localizedCompare(name(b.item)) == .orderedAscending
        }
        var runs: [(kind: String?, items: [T])] = []
        for entry in sorted {
            if let k = entry.kind, let last = runs.last, last.kind == k { runs[runs.count - 1].items.append(entry.item) }
            else { runs.append((entry.kind, [entry.item])) }
        }
        // Small runs read as plain items: no subheading.
        return runs.map { $0.items.count >= minimum ? $0 : (nil, $0.items) }
    }

    /// "miso" -> "Miso", "mushroom" -> "Mushrooms": the heading for a run of `count` items.
    public static func title(_ kind: String, count: Int) -> String {
        let uncountable: Set<String> = ["miso", "rice", "flour", "sugar", "salt", "oil", "vinegar", "tea", "coffee", "kimchi", "tofu", "cheese", "milk", "yogurt", "butter", "honey", "pasta", "seafood", "fish", "ginger", "kombu", "wine", "seaweed", "garlic", "spinach", "kale", "cilantro", "parsley", "basil", "mint", "lettuce", "broccoli", "bread", "chocolate", "corn", "meat", "beef", "pork", "chicken", "lamb", "sake", "mirin", "stock", "broth", "juice", "cream", "jam", "dashi"]
        let word = count > 1 && !uncountable.contains(kind) ? plural(kind) : kind
        return word.prefix(1).uppercased() + word.dropFirst()
    }

    static func plural(_ w: String) -> String {
        if w.hasSuffix("y"), let before = w.dropLast().last, !"aeiou".contains(before) { return String(w.dropLast()) + "ies" }
        if w.hasSuffix("o") || w.hasSuffix("ch") || w.hasSuffix("sh") || w.hasSuffix("s") || w.hasSuffix("x") { return w + "es" }
        return w + "s"
    }
}
