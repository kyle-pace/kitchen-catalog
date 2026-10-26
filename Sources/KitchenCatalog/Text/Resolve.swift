import Foundation

// Swift only. Moved from PantryKit on 2026-10-25 so both apps can use it. Unlike `Catalog.match`,
// this has no JavaScript twin, so the Swift/JS parity rule in the README doesn't cover it.

/// What a name or recipe line turned into.
public enum Resolution: Equatable, Sendable {
    /// Water and the like: not tracked.
    case staple
    /// A confident match to one item.
    case item(String)
    /// Unclear: show these choices (two or three buttons, plus "Something else").
    case ask([String])
    /// Not in the list: offer to add it.
    case new

    public var itemID: String? { if case .item(let id) = self { return id } else { return nil } }
}

extension NameMatcher {
    /// The deterministic pipeline: staples, then name and alias lookup (including "or"
    /// alternates), then a shortlist that must pass the word check. In testing, an on-device
    /// model added no correct answers once these guards were in place, so there is none here.
    public func resolve(_ parsed: ParsedLine) -> Resolution {
        if isStaple(parsed.name) { return .staple }
        for name in [parsed.name] + parsed.alternates {
            if let id = lookup(name) { return .item(id) }
        }
        let candidates = shortlist(parsed.name)
        let sameKind = sameKind(parsed.name, among: candidates)
        if sameKind.count >= 2 { return .ask(sameKind) }
        // Only offer choices that pass the word check ("butter" is not a word in "buttermilk").
        let plausible = candidates.filter { id in byID[id].map { self.plausible(line: parsed, item: $0) } ?? false }
        if plausible.isEmpty { return .new }
        return .ask(Array(plausible.prefix(3)))
    }

    public func resolve(line: String) -> Resolution { resolve(Parser.parse(line)) }
}
