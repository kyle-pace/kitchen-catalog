import Foundation

/// Grams in a cup of an ingredient, for converting between volume and weight. Keyed by catalog id;
/// the table is densities.json.
public enum Density {
    private struct File: Decodable { let gramsPerCup: [String: Double] }

    private static let table: [String: Double] = {
        guard let url = Bundle.module.url(forResource: "densities", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data) else { return [:] }
        return file.gramsPerCup
    }()

    public static var ids: [String] { Array(table.keys) }

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
