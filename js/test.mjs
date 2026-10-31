// Same cases as Tests/KitchenCatalogTests/MatchTests.swift. node js/test.mjs
import { load, match } from "./catalog.mjs";
const c = load();
let failed = 0;
const strong = [["Chicken leg quarters, 10 lb", "chicken-leg-quarters"], ["Onion - Green", "green-onion"], ["Kikkoman Organic Soy Sauce", "soy-sauce"],
  ["Nappa cabbage", "napa-cabbage"], ["Atlantic salmon fillet", "salmon-atlantic"], ["scallions", "green-onion"], ["gochujang", "gochujang"],
  // What a product is, not what's in it: shrimp chips are chips, egg bread is bread.
  ["Calbee Shrimp Chips", "chips"], ["Tincarbell Egg Bread", "bread"], ["Fami Original Soy Milk", "soy-milk"], ["Chaokoh Coco Milk", "coconut-milk"],
  // A name that runs into cut words; sizes and "Selected Varieties" after the name.
  ["Beef Shank Boneless", "beef-shank"], ["General Mills Cereal, Selected Varieties, 8.9 to 12 oz", "cereal"],
  // The part before the comma, or before "with", is the product.
  ["Act II Popcorn, Butter Lovers or Movie Theater Butter", "popcorn"], ["Goat Meat w/Skin on", "goat"],
  // Specific beats general.
  ["Cherry Blossom Pork Back Rib (Fresh)", "pork-baby-back-ribs"], ["Black Cod Fillet", "sablefish"], ["Kokusai Calrose Rice", "rice-medium-grain"],
  // Found in the Oct 23 re-run: roasts, "for soup", more than one comma.
  ["Pork Loin Roast", "pork-loin"], ["Cosmic Crisp Apples", "apples"], ["Beef Short Rib For Soup", "beef-short-ribs"], ["Pork For Stew", "pork-stew-meat"], ["Pork shoulder (butt), boneless", "pork-shoulder"], ["Natures Soy Tofu", "tofu"], ["Cabbage Green", "green-cabbage"], ["Boneless Beef Top Sirloin Steaks, Premium Beef, Value Pack", "beef-sirloin"], ["White Shrimp H/O 20-30 - 4 lbs", "shrimp"],
  // Other names (2026-10-27): regional and market names, and broad words for the search box.
  ["Coriander Leaves", "fresh-herbs"], ["Pak Choi", "bok-choy"], ["Rocket", "arugula"], ["Capsicum", "bell-peppers"], ["Gai Choy", "mustard-greens"],
  ["Korean Chili Powder", "gochugaru"], ["Chili Powder", "chili-powder"], ["Bean Sprouts", "bean-sprouts"], ["Lap Cheong", "sausage"],
  ["Bangus", "milkfish"], ["Pork", "pork"], ["Whole Fish", "fish"], ["Beef For Stew", "beef-stew"], ["Passion Fruit Juice", "juice"],
  ["Katsu Shredded Cabbage", "green-cabbage"]];
for (const [text, id] of strong) {
  const m = match(c, text);
  if (m?.id !== id || m?.strength !== "strong") { failed++; console.log("FAIL", text, "->", m?.id, m?.strength, "expected", id); }
}
// A dish or a mix, not the grocery: cooking words before an ingredient, and "X & Y" where Y is what it's made of.
for (const text of ["Oreo Savory Chicken Flavor/ Vintage Popcorn Flavor", "Braised Yellow Croaker with Rice Cake", "Stewed Pork Trotters",
  "Metropolitan Market Spiced Butternut Squash", "MP Hotdogs Chicken & Pork Jumbo", "BBQ Pork", "Pickled Cabbage",
  // A flavor after a ready-made product: the product, sent to review.
  "Pepsi Wild Cherry", "Hi-Chew Mango"]) {
  const m = match(c, text);
  if (m?.strength === "strong") { failed++; console.log("FAIL", text, "should not be strong ->", m.id); }
}
// Ready-made products keep their cooking words: glazed donuts are donuts.
for (const [text, id] of [["Sweet P's Glazed Donuts", "donuts"], ["Fried Leek Pie", "prepared-meals"]]) {
  const m = match(c, text);
  if (m?.id !== id || m?.strength !== "strong") { failed++; console.log("FAIL", text, "->", m?.id, m?.strength, "expected", id); }
}
// Kind-of links: every parent exists, and a few broad words sit above the items they cover.
for (const [id, item] of Object.entries(c.items)) if (item.parent && !c.items[item.parent]) { failed++; console.log("FAIL", id, "has a missing parent", item.parent); }
const up = (id) => { const o = []; let p = c.items[id]?.parent; while (p && o.length < 10) { o.push(p); p = c.items[p]?.parent; } return o; };
for (const [id, p] of [["pork-belly-sliced", "pork"], ["beef-sirloin", "beef"], ["salmon-sockeye", "seafood"], ["clams", "shellfish"], ["kabocha-squash", "squash"], ["purple-napa-cabbage", "cabbage"]]) {
  if (!up(id).includes(p)) { failed++; console.log("FAIL", id, "should be a kind of", p, "->", up(id).join(" > ")); }
}

// Seasons: the same cases as SeasonTests.swift (Tests/season-cases.json).
{
  const { inSeason, seasonsOn, seasonEnd, mentions, isStar, coversItem, matches, loadSeasons } = await import("./seasons.mjs");
  const { readFileSync } = await import("node:fs");
  const cases = JSON.parse(readFileSync(new URL("../Tests/season-cases.json", import.meta.url), "utf8"));
  const byId = Object.fromEntries(cases.fixture.map((s) => [s.id, s]));
  for (const [day, ids] of cases.on) {
    const got = seasonsOn(cases.fixture, day).map((s) => s.id);
    if (got.join() !== ids.join()) { failed++; console.log("FAIL season on", day, "->", got, "expected", ids); }
  }
  for (const [id, day, end] of cases.ends) {
    const got = seasonEnd(byId[id], day);
    if (got !== end) { failed++; console.log("FAIL season end", id, day, "->", got, "expected", end); }
  }
  for (const [id, text, want] of cases.mentions) if (mentions(byId[id], text) !== want) { failed++; console.log("FAIL season mentions", id, text, "expected", want); }
  for (const [id, text, want] of cases.star) if (isStar(byId[id], text) !== want) { failed++; console.log("FAIL season star", id, text, "expected", want); }
  for (const [id, key, name, want] of cases.matches) if (matches(byId[id], c, { key, name }) !== want) { failed++; console.log("FAIL season matches", id, key, name, "expected", want); }
  for (const [id, item, want] of cases.covers) if (coversItem(byId[id], c, item) !== want) { failed++; console.log("FAIL season covers", id, item, "expected", want); }
  // The real calendar: ids are unique, every item exists, dates are real month-days, inSeason agrees with seasonsOn.
  const real = loadSeasons();
  const seen = new Set();
  for (const s of real) {
    if (seen.has(s.id)) { failed++; console.log("FAIL season id used twice", s.id); }
    seen.add(s.id);
    for (const item of s.items) if (!c.items[item]) { failed++; console.log("FAIL season", s.id, "lists a missing item", item); }
    for (const d of [s.from, s.to]) if (!/^(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])$/.test(d)) { failed++; console.log("FAIL season", s.id, "has a bad date", d); }
    if (!s.label || !Array.isArray(s.facts)) { failed++; console.log("FAIL season", s.id, "needs a label and facts"); }
    if (!inSeason(s, s.from) || !inSeason(s, s.to)) { failed++; console.log("FAIL season", s.id, "doesn't include its own ends"); }
  }
}
console.log(failed ? `${failed} failed` : "all passed");
process.exit(failed ? 1 : 0);
