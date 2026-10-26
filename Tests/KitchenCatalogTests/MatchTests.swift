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
        // What a product is, not what's in it: shrimp chips are chips, egg bread is bread.
        ("Calbee Shrimp Chips", "chips", .strong),
        ("Tincarbell Egg Bread", "bread", .strong),
        ("Fami Original Soy Milk", "soy-milk", .strong),
        ("Chaokoh Coco Milk", "coconut-milk", .strong),
        // A name that runs into cut words; sizes and "Selected Varieties" after the name.
        ("Beef Shank Boneless", "beef-shank", .strong),
        ("General Mills Cereal, Selected Varieties, 8.9 to 12 oz", "cereal", .strong),
        // The part before the comma, or before "with", is the product.
        ("Act II Popcorn, Butter Lovers or Movie Theater Butter", "popcorn", .strong),
        ("Goat Meat w/Skin on", "goat", .strong),
        // Specific beats general.
        ("Cherry Blossom Pork Back Rib (Fresh)", "pork-baby-back-ribs", .strong),
        ("Black Cod Fillet", "sablefish", .strong),
        ("Kokusai Calrose Rice", "rice-medium-grain", .strong),
    ])
    func strong(_ text: String, _ id: String, _ strength: Catalog.Strength) {
        let m = c.match(text)
        #expect(m?.id == id)
        #expect(m?.strength == strength)
    }

    @Test(arguments: ["Oreo Savory Chicken Flavor/ Vintage Popcorn Flavor"])
    func notStrong(_ text: String) {
        #expect(c.match(text)?.strength != .strong)
    }

    @Test func oldIDsStillResolve() {
        #expect(c.item("rice-jasmine")?.id == "jasmine-rice")
    }
}
