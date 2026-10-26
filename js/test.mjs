// Same cases as Tests/KitchenCatalogTests/MatchTests.swift. node js/test.mjs
import { load, match } from "./catalog.mjs";
const c = load();
let failed = 0;
const strong = [["Chicken leg quarters, 10 lb", "chicken-leg-quarters"], ["Onion - Green", "green-onion"], ["Kikkoman Organic Soy Sauce", "soy-sauce"],
  ["Nappa cabbage", "napa-cabbage"], ["Atlantic salmon fillet", "salmon-atlantic"], ["scallions", "green-onion"], ["gochujang", "gochujang"],
  // What a product is, not what's in it: shrimp chips are chips, egg bread is bread.
  ["Calbee Shrimp Chips", "chips"], ["Tincarbell Egg Bread", "bread"], ["Fami Original Soy Milk", "soy-milk"], ["Chaokoh Coco Milk", "coconut-milk"],
  // Specific beats general.
  ["Cherry Blossom Pork Back Rib (Fresh)", "pork-baby-back-ribs"], ["Black Cod Fillet", "sablefish"], ["Kokusai Calrose Rice", "rice-medium-grain"]];
for (const [text, id] of strong) {
  const m = match(c, text);
  if (m?.id !== id || m?.strength !== "strong") { failed++; console.log("FAIL", text, "->", m?.id, m?.strength, "expected", id); }
}
for (const text of ["Oreo Savory Chicken Flavor/ Vintage Popcorn Flavor"]) {
  const m = match(c, text);
  if (m?.strength === "strong") { failed++; console.log("FAIL", text, "should not be strong ->", m.id); }
}
console.log(failed ? `${failed} failed` : "all passed");
process.exit(failed ? 1 : 0);
