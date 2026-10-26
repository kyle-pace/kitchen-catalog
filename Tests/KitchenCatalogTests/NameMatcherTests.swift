import Testing
@testable import KitchenCatalog

/// NameMatcher works over any list of items, not just On Hand's pantry. PantryKit's ScoreTests
/// cover it in depth against the real pantry; these check the basics on a tiny list.
private struct Thing: MatchableItem {
    let id: String
    let name: String
    var aliases: [String] = []
}

private let things = [
    Thing(id: "thai-basil", name: "Thai Basil"),
    Thing(id: "pork-shoulder", name: "Pork Shoulder"),
    Thing(id: "butter", name: "Butter"),
    Thing(id: "aka-miso", name: "Aka Miso"),
    Thing(id: "white-miso", name: "White Miso"),
    Thing(id: "green-onion", name: "Green Onion", aliases: ["scallions"]),
]

@Test func parsesRecipeLines() {
    let p = Parser.parse("2 tablespoons potato starch or cornstarch, divided")
    #expect(p.name == "potato starch")
    #expect(p.alternates == ["cornstarch"])
    #expect(p.prep == "divided")
}

@Test func resolvesAgainstAnyItems() {
    let m = NameMatcher(items: things)
    #expect(m.resolve(line: "1 cup Thai basil leaves") == .item("thai-basil"))
    #expect(m.resolve(line: "2 lb boneless pork shoulder") == .item("pork-shoulder"))
    #expect(m.resolve(line: "3 scallions, sliced") == .item("green-onion"))
    #expect(m.resolve(line: "1 cup water") == .staple)
    #expect(m.resolve(line: "1 cup buttermilk").itemID == nil)
    if case .ask(let ids) = m.resolve(line: "2 tbsp miso") {
        #expect(Set(ids) == ["aka-miso", "white-miso"])
    } else {
        Issue.record("miso should ask which one")
    }
}
