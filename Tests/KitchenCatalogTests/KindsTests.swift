import Testing
@testable import KitchenCatalog

@Test func kinds() {
    #expect(Kinds.kind(of: "Aka Miso") == "miso")
    #expect(Kinds.kind(of: "Dashiiri Awase Miso") == "miso")
    #expect(Kinds.kind(of: "Miso Barbecue Sauce") == "sauce")
    #expect(Kinds.kind(of: "King Oyster Mushrooms") == "mushroom")
    #expect(Kinds.kind(of: "Enoki") == "mushroom")
    #expect(Kinds.kind(of: "Dried Shiitake") == "mushroom")
    #expect(Kinds.kind(of: "Heirloom Tomatoes") == "tomato")
    #expect(Kinds.kind(of: "Cumin, ground") == "cumin")
    #expect(Kinds.kind(of: "Peas frozen") == "pea")
    #expect(Kinds.kind(of: "Thai Chilies") == "chili")
    #expect(Kinds.kind(of: "Bay Leaves") == "leaf")
    #expect(Kinds.kind(of: "Hummus") == "hummus")
}

@Test func arrange() {
    let names = ["Aka Miso", "Avocados", "Enjuku Koji Miso", "Lemons", "Miso Barbecue Sauce", "White Miso", "Yoka Miso", "Zucchini"]
    let runs = Kinds.arrange(names, name: { $0 })
    #expect(runs.flatMap(\.items) == ["Avocados", "Lemons", "Aka Miso", "Enjuku Koji Miso", "White Miso", "Yoka Miso", "Miso Barbecue Sauce", "Zucchini"])
    #expect(runs.compactMap(\.kind) == ["miso"])
    #expect(Kinds.title("miso", count: 4) == "Miso")
    #expect(Kinds.title("mushroom", count: 3) == "Mushrooms")
}

@Test func plurals() {
    #expect(Kinds.kind(of: "Kalamata Olives") == "olive")
    #expect(Kinds.kind(of: "Butter Cookies") == "cookie")
    #expect(Kinds.kind(of: "Frozen Blueberries") == "blueberry")
}
