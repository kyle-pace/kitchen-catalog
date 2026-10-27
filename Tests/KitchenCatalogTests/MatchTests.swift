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
        // Found in the Oct 23 re-run: roasts, "for soup", more than one comma.
        ("Pork Loin Roast", "pork-loin", .strong),
        ("Cosmic Crisp Apples", "apples", .strong),
        ("Beef Short Rib For Soup", "beef-short-ribs", .strong),
        ("Pork For Stew", "pork-stew-meat", .strong),
        ("Pork shoulder (butt), boneless", "pork-shoulder", .strong),
        ("Natures Soy Tofu", "tofu", .strong),
        ("Cabbage Green", "green-cabbage", .strong),
        ("Boneless Beef Top Sirloin Steaks, Premium Beef, Value Pack", "beef-sirloin", .strong),
        ("White Shrimp H/O 20-30 - 4 lbs", "shrimp", .strong),
        // Other names (2026-10-27): regional and market names, and broad words for the search box.
        ("Coriander", "fresh-herbs", .strong),
        ("Pak Choi", "bok-choy", .strong),
        ("Rocket", "arugula", .strong),
        ("Capsicum", "bell-peppers", .strong),
        ("Gai Choy", "mustard-greens", .strong),
        ("Korean Chili Powder", "gochugaru", .strong),
        ("Chili Powder", "chili-powder", .strong),
        ("Bean Sprouts", "bean-sprouts", .strong),
        ("Lap Cheong", "sausage", .strong),
        ("Bangus", "milkfish", .strong),
        ("Pork", "pork", .strong),
        ("Whole Fish", "fish", .strong),
        ("Beef For Stew", "beef-stew", .strong),
        ("Passion Fruit Juice", "juice", .strong),
        ("Katsu Shredded Cabbage", "green-cabbage", .strong),
        // Ready-made products keep their cooking words: glazed donuts are donuts.
        ("Sweet P's Glazed Donuts", "donuts", .strong),
        ("Fried Leek Pie", "prepared-meals", .strong),
    ])
    func strong(_ text: String, _ id: String, _ strength: Catalog.Strength) {
        let m = c.match(text)
        #expect(m?.id == id)
        #expect(m?.strength == strength)
    }

    /// A dish or a mix, not the grocery: cooking words before an ingredient, and "X & Y" where Y is what it's made of.
    @Test(arguments: ["Oreo Savory Chicken Flavor/ Vintage Popcorn Flavor", "Braised Yellow Croaker with Rice Cake", "Stewed Pork Trotters",
                      "Metropolitan Market Spiced Butternut Squash", "MP Hotdogs Chicken & Pork Jumbo"])
    func notStrong(_ text: String) {
        #expect(c.match(text)?.strength != .strong)
    }

    /// Kind-of links: every parent exists, and a few broad words sit above the items they cover.
    @Test func kindsOf() {
        for (id, item) in c.items { if let p = item.parent { #expect(c.items[p] != nil, "\(id) has a missing parent \(p)") } }
        func up(_ id: String) -> [String] {
            var out: [String] = [], p = c.items[id]?.parent
            while let next = p, out.count < 10 { out.append(next); p = c.items[next]?.parent }
            return out
        }
        for (id, p) in [("pork-belly-sliced", "pork"), ("beef-sirloin", "beef"), ("salmon-sockeye", "seafood"), ("clams", "shellfish"),
                        ("kabocha-squash", "squash"), ("purple-napa-cabbage", "cabbage")] {
            #expect(up(id).contains(p), "\(id) should be a kind of \(p)")
        }
    }

    @Test func oldIDsStillResolve() {
        #expect(c.item("rice-jasmine")?.id == "jasmine-rice")
    }
}
