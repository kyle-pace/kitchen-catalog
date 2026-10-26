// swift-tools-version: 6.2
import PackageDescription

// The shared list of grocery items for Pantry and Grocery Deals: fixed ids, names, other names
// and store sections. The same catalog.json is read by the Swift apps and by Grocery Deals'
// Friday run (js/catalog.mjs), and both match text to items by the same rules.
let package = Package(
    name: "KitchenCatalog",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [.library(name: "KitchenCatalog", targets: ["KitchenCatalog"])],
    targets: [
        .target(name: "KitchenCatalog", resources: [.copy("Resources/catalog.json")]),
        .testTarget(name: "KitchenCatalogTests", dependencies: ["KitchenCatalog"]),
    ]
)
