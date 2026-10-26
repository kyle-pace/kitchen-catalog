import Testing
@testable import KitchenCatalog

/// The Swift and JavaScript matchers must agree; these cases are also in js/test.mjs.
struct MatchTests {
    let c = Catalog.shared

    @Test(arguments: [
        ("Chicken leg quarters, 10 lb", "chicken-leg-quarters", Catalog.Strength.strong),
        ("Onion - Green", "green-onion", .strong),
        ("Kikkoman Organic Soy Sauce", "soy-sauce", .strong),
        ("Nappa cabbage", "napa-cabbage", .strong),
        ("Atlantic salmon fillet", "salmon-atlantic", .strong),
        ("scallions", "green-onion", .strong),
        ("gochujang", "gochujang", .strong),
    ])
    func strong(_ text: String, _ id: String, _ strength: Catalog.Strength) {
        let m = c.match(text)
        #expect(m?.id == id)
        #expect(m?.strength == strength)
    }

    @Test(arguments: ["Calbee Shrimp Chips", "Tincarbell Egg Bread", "Fami Original Soy Milk"])
    func notStrong(_ text: String) {
        #expect(c.match(text)?.strength != .strong)
    }

    @Test func oldIDsStillResolve() {
        #expect(c.item("rice-jasmine")?.id == "jasmine-rice")
    }
}
