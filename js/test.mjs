// Same cases as Tests/KitchenCatalogTests/MatchTests.swift. node js/test.mjs
import { load, match } from "./catalog.mjs";
const c = load();
let failed = 0;
const strong = [["Chicken leg quarters, 10 lb", "chicken-leg-quarters"], ["Onion - Green", "green-onion"], ["Kikkoman Organic Soy Sauce", "soy-sauce"],
  ["Nappa cabbage", "napa-cabbage"], ["Atlantic salmon fillet", "salmon-atlantic"], ["scallions", "green-onion"], ["gochujang", "gochujang"]];
for (const [text, id] of strong) {
  const m = match(c, text);
  if (m?.id !== id || m?.strength !== "strong") { failed++; console.log("FAIL", text, "->", m?.id, m?.strength, "expected", id); }
}
for (const text of ["Calbee Shrimp Chips", "Tincarbell Egg Bread", "Fami Original Soy Milk"]) {
  const m = match(c, text);
  if (m?.strength === "strong") { failed++; console.log("FAIL", text, "should not be strong ->", m.id); }
}
console.log(failed ? `${failed} failed` : "all passed");
process.exit(failed ? 1 : 0);
