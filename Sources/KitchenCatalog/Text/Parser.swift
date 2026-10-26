import Foundation

// Swift only. Moved from PantryKit on 2026-10-25 so both apps can use it. Unlike `Catalog.match`,
// this has no JavaScript twin, so the Swift/JS parity rule in the README doesn't cover it.

/// One recipe ingredient line, split into the parts matching cares about.
public struct ParsedLine: Sendable {
    public var raw: String
    public var name: String          // "boneless chicken thigh with skin"
    public var alternates: [String]  // "potato starch or cornstarch" -> ["cornstarch"]
    public var prep: String          // text after the first comma
    public var optional: Bool

    public init(raw: String, name: String, alternates: [String] = [], prep: String = "", optional: Bool = false) {
        self.raw = raw
        self.name = name
        self.alternates = alternates
        self.prep = prep
        self.optional = optional
    }
}

public enum Parser {
    public static let unicodeFractions = "¼½¾⅓⅔⅛⅜⅝⅞"
    public static let units: Set<String> = Set("""
        tbsp tbsps tablespoon tablespoons tsp tsps teaspoon teaspoons cup cups oz ounce ounces lb lbs pound pounds \
        g gram grams kg ml l liter liters quart quarts pint pints pinch pinches dash dashes clove cloves bunch bunches head heads \
        sheet sheets piece pieces can cans jar jars package packages pkg stalk stalks sprig sprigs slice slices inch inches cm stick sticks \
        handful knob
        """.split(separator: " ").map(String.init))
    public static let sizes: Set<String> = ["small", "medium", "large", "extra-large", "big", "whole"]
    public static let fillers: Set<String> = ["to", "-", "or", "a", "an", "of"]
    public static let leadPhrases = ["juice of", "zest of", "pinch of", "dash of", "a pinch of", "a few"]

    public static func parse(_ line: String) -> ParsedLine {
        let optional = line.lowercased().contains("optional")

        // Drop parentheticals, including doubled ((...)) from some recipe sites.
        var s = line.replacingRegex(#"\([^()]*\)"#, with: " ")
        s = s.replacingRegex(#"\([^()]*\)"#, with: " ")
        s = s.replacingOccurrences(of: "\"", with: " inch ")

        let lowered = s.lowercased().trimmingCharacters(in: .whitespaces)
        for phrase in leadPhrases where lowered.hasPrefix(phrase + " ") {
            s = String(s.trimmingCharacters(in: .whitespaces).dropFirst(phrase.count))
            break
        }

        // Prep notes come after the first comma.
        var prep = ""
        if let comma = s.firstIndex(of: ",") {
            prep = String(s[s.index(after: comma)...]).trimmingCharacters(in: .whitespaces)
            s = String(s[..<comma])
        }
        s = s.replacingRegex(#"\b(for|to) (garnish|serving|serve|taste|frying|dusting)\b.*"#, with: "", caseInsensitive: true)

        // Strip leading quantities, units and size words.
        let tokens = s.replacingOccurrences(of: "-", with: " - ")
            .split(whereSeparator: { $0.isWhitespace }).map(String.init)
        var kept: [String] = []
        for token in tokens {
            let t = token.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
            if t.matchesRegex("^[\\d/.\(unicodeFractions)]+$") { continue }
            if kept.isEmpty && (fillers.contains(t) || units.contains(t) || sizes.contains(t)) { continue }
            kept.append(token)
        }
        var name = kept.joined(separator: " ")
            .replacingOccurrences(of: " - ", with: "-")
            .trimmingCharacters(in: .whitespaces)
        name = name.replacingRegex(#"\b(such as|like)\b.*"#, with: "", caseInsensitive: true)
            .trimmingCharacters(in: .whitespaces)

        var alternates: [String] = []
        if name.contains(" or ") {
            let parts = name.components(separatedBy: " or ").map { $0.trimmingCharacters(in: .whitespaces) }
            name = parts[0]; alternates = Array(parts.dropFirst())
        }
        if name.contains("/") {
            let parts = name.components(separatedBy: "/").map { $0.trimmingCharacters(in: .whitespaces) }
            name = parts[0]; alternates = Array(parts.dropFirst()) + alternates
        }
        return ParsedLine(raw: line, name: name, alternates: alternates, prep: prep, optional: optional)
    }
}

// MARK: - Normalizing names

public enum Names {
    /// Lowercase, plain ASCII-ish words, single spaces.
    public static func normalize(_ s: String) -> String {
        let lowered = s.lowercased().replacingOccurrences(of: "’", with: "'")
        return lowered.replacingRegex("[^a-z0-9' -]", with: " ")
            .replacingRegex("\\s+", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    public static func singular(_ w: String) -> String {
        if w.count > 3 && w.hasSuffix("ies") { return String(w.dropLast(3)) + "y" }
        if w.count > 3 && w.hasSuffix("oes") { return String(w.dropLast(2)) }
        if w.count > 3 && w.hasSuffix("s") && !w.hasSuffix("ss") { return String(w.dropLast()) }
        return w
    }

    /// The lookup key: normalized, each word singular.
    public static func key(_ s: String) -> String {
        normalize(s).split(separator: " ").map { singular(String($0)) }.joined(separator: " ")
    }
}

/// Compiled patterns, so each one is compiled once per launch instead of on every call.
/// (Compiling them over and over made matching a whole recipe collection slow enough for
/// iOS to kill the app.)
private enum RegexCache {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var compiled: [String: NSRegularExpression] = [:]

    static func regex(_ pattern: String, caseInsensitive: Bool) -> NSRegularExpression? {
        let key = (caseInsensitive ? "i:" : "s:") + pattern
        lock.lock()
        defer { lock.unlock() }
        if let re = compiled[key] { return re }
        guard let re = try? NSRegularExpression(pattern: pattern, options: caseInsensitive ? [.caseInsensitive] : []) else { return nil }
        compiled[key] = re
        return re
    }
}

extension String {
    public func replacingRegex(_ pattern: String, with template: String, caseInsensitive: Bool = false) -> String {
        guard let re = RegexCache.regex(pattern, caseInsensitive: caseInsensitive) else { return self }
        return re.stringByReplacingMatches(in: self, range: NSRange(startIndex..., in: self), withTemplate: template)
    }

    public func matchesRegex(_ pattern: String) -> Bool {
        guard let re = RegexCache.regex(pattern, caseInsensitive: false) else { return false }
        return re.firstMatch(in: self, range: NSRange(startIndex..., in: self)) != nil
    }
}
