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

    @Test func noDensityForThingsACupDoesntMeasure() {
        #expect(Density.gramsPerCup("eggs") == nil)
    }
}
