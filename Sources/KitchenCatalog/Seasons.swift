import Foundation

/// What's in season in the Seattle area (Resources/seasons.json), shared by Grocery Deals and
/// Maitake. Same rules as js/seasons.mjs; both run Tests/season-cases.json.
public struct Season: Sendable, Decodable, Identifiable, Hashable {
    /// The kind to look for, if there is one: Fuyu among persimmons.
    public struct Star: Sendable, Decodable, Hashable {
        public let label: String
        public let words: [String]
    }

    /// Never changes; Grocery Deals' feed and Maitake's settings key on it.
    public let id: String
    /// "Persimmons"
    public let label: String
    /// Catalog ids; a kind of one of these (its `parent` chain) counts too.
    public let items: [String]
    /// Extra words that mark a name as this item ("fuyu", "hachiya").
    public let words: [String]
    /// Month and day, "09-15". Both days count; a season can wrap the new year.
    public let from: String
    public let to: String
    /// A KitchenUI `Buddy.Kind` name, or nil for items without a character yet.
    public let buddy: String?
    public let star: Star?
    /// One friendly line about why now.
    public let tagline: String?
    /// Facts, with **bold** for a lead word.
    public let facts: [String]

    public init(id: String, label: String, items: [String], words: [String], from: String, to: String,
                buddy: String? = nil, star: Star? = nil, tagline: String? = nil, facts: [String] = []) {
        self.id = id
        self.label = label
        self.items = items
        self.words = words
        self.from = from
        self.to = to
        self.buddy = buddy
        self.star = star
        self.tagline = tagline
        self.facts = facts
    }

    enum CodingKeys: String, CodingKey { case id, label, items, words, from, to, buddy, star, tagline, facts }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        label = try c.decode(String.self, forKey: .label)
        items = try c.decodeIfPresent([String].self, forKey: .items) ?? []
        words = try c.decodeIfPresent([String].self, forKey: .words) ?? []
        from = try c.decode(String.self, forKey: .from)
        to = try c.decode(String.self, forKey: .to)
        buddy = try c.decodeIfPresent(String.self, forKey: .buddy)
        star = try c.decodeIfPresent(Star.self, forKey: .star)
        tagline = try c.decodeIfPresent(String.self, forKey: .tagline)
        facts = try c.decodeIfPresent([String].self, forKey: .facts) ?? []
    }

    // MARK: dates

    /// "2026-10-30" or "10-30": is that day inside the season?
    public func contains(day: String) -> Bool {
        let md = day.count > 5 ? String(day.dropFirst(5).prefix(5)) : day
        return from <= to ? (md >= from && md <= to) : (md >= from || md <= to)
    }

    /// Is a date (in the given calendar's time zone) inside the season?
    public func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        contains(day: Self.monthDay(date, calendar: calendar))
    }

    /// The last day of the season that includes `day`, or of the next one to end: "2027-01-15".
    public func endDay(after day: String) -> String {
        let year = Int(day.prefix(4)) ?? 0
        let md = String(day.dropFirst(5).prefix(5))
        return "\(String(format: "%04d", md > to ? year + 1 : year))-\(to)"
    }

    /// The same as a date: the last day of the season, at the start of that day.
    public func endDate(after date: Date, calendar: Calendar = .current) -> Date? {
        let iso = endDay(after: Self.isoDay(date, calendar: calendar))
        let parts = iso.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    // MARK: matching

    /// Does a catalog id belong to the season, directly or as a kind of one of its items?
    public func covers(itemID: String, in catalog: Catalog = .shared) -> Bool {
        var p: String? = itemID
        var n = 0
        while let id = p, n < 10 {
            if items.contains(id) { return true }
            p = catalog.items[id]?.parent
            n += 1
        }
        return false
    }

    /// Does a name ("Fuyu Persimmons, jumbo") mention the item? Whole words, made singular.
    public func mentions(_ text: String) -> Bool {
        let norm = Catalog.normalize(text)
        let found = Set(norm.split(separator: " ").map(String.init))
        return (words + [label]).contains { w in
            let n = Catalog.normalize(w)
            return n.contains(" ") ? " \(norm) ".contains(" \(n) ") : found.contains(n)
        }
    }

    /// Is a name the star kind ("Fuyu")? False when there's no star.
    public func isStar(_ text: String) -> Bool {
        guard let star else { return false }
        let words = Set(Catalog.normalize(text).split(separator: " ").map(String.init))
        return star.words.contains { words.contains(Catalog.normalize($0)) }
    }

    /// Does a deal or pantry line belong to the season? Its catalog id decides when it has one (a
    /// known `itemID`, or else what the name matches in the catalog, strong or weak): "Pastry Mitten
    /// Pie Slices, fuji apple" is pastries, not apples. Only a name the catalog doesn't know
    /// ("Hoshigaki") falls back to the season's words.
    public func matches(itemID: String?, name: String, in catalog: Catalog = .shared) -> Bool {
        let known = itemID.flatMap { catalog.items[$0] != nil ? $0 : catalog.item($0)?.id }
        if let id = known ?? catalog.match(name)?.id { return covers(itemID: id, in: catalog) }
        return mentions(name)
    }

    static func monthDay(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.month, .day], from: date)
        return String(format: "%02d-%02d", c.month ?? 0, c.day ?? 0)
    }

    static func isoDay(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

/// The season calendar that ships with this package.
public enum Seasons {
    private struct File: Decodable { let version: Int; let seasons: [Season] }

    /// Every season, in the file's order.
    public static let all: [Season] = {
        guard let url = Bundle.module.url(forResource: "seasons", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [] }
        return (try? decode(data)) ?? []
    }()

    public static func decode(_ data: Data) throws -> [Season] {
        try JSONDecoder().decode(File.self, from: data).seasons
    }

    /// The seasons that include a date, in the file's order.
    public static func on(_ date: Date = .now, calendar: Calendar = .current) -> [Season] {
        all.filter { $0.contains(date, calendar: calendar) }
    }

    public static func season(_ id: String) -> Season? { all.first { $0.id == id } }
}
