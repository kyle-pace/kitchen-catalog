import Foundation

/// Grams in a cup of an ingredient, for converting between volume and weight. Keyed by catalog id;
/// the table is densities.json.
public enum Density {
    private struct File: Decodable {
        let gramsPerCup: [String: Double]
        /// What a recipe means by a word the catalog keeps broad: "sugar" is white sugar here.
        let plainWords: [String: String]
    }

    private static let file: File = {
        guard let url = Bundle.module.url(forResource: "densities", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data) else { return File(gramsPerCup: [:], plainWords: [:]) }
        return file
    }()

    private static var table: [String: Double] { file.gramsPerCup }

    public static var ids: [String] { Array(table.keys) + file.plainWords.values }

    /// The density of an ingredient as a recipe names it: "all-purpose flour, sifted", "sugar".
    public static func gramsPerCup(named name: String, in catalog: Catalog = .shared) -> Double? {
        let words = Catalog.normalize(name)
        if let id = file.plainWords[words] { return gramsPerCup(id, in: catalog) }
        guard let match = catalog.match(name), match.strength == .strong else { return nil }
        return gramsPerCup(match.id, in: catalog)
    }

    /// The item's own value or its nearest parent's, nil if neither has one.
    public static func gramsPerCup(_ id: String, in catalog: Catalog = .shared) -> Double? {
        var next: String? = id
        var seen = Set<String>()
        while let current = next, seen.insert(current).inserted {
            if let value = table[current] { return value }
            next = catalog.item(current)?.item.parent
        }
        return nil
    }
}
