import Testing
@testable import KitchenCatalog

struct DensityTests {
    @Test func everyIDIsInTheCatalog() {
        #expect(!Density.ids.isEmpty)
        for id in Density.ids { #expect(Catalog.shared.item(id) != nil, "\(id) isn't in the catalog") }
    }

    @Test func aKnownIngredient() {
        #expect(Density.gramsPerCup("all-purpose-flour") == 120)
    }

    @Test func byTheNameInARecipe() {
        #expect(Density.gramsPerCup(named: " all-purpose flour") == 120)
        #expect(Density.gramsPerCup(named: "sugar") == 200)
        #expect(Density.gramsPerCup(named: "brown sugar") == 213)
        #expect(Density.gramsPerCup(named: "chicken stock") == nil)
    }

    @Test func noDensityForThingsACupDoesntMeasure() {
        #expect(Density.gramsPerCup("eggs") == nil)
    }
}
