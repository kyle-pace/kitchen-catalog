# KitchenCatalog

The shared list of grocery items for **Pantry** and **Grocery Deals**, so "Leg quarters, 10 lb"
on a Lam's flyer, "chicken leg quarters" in the pantry and the reminder on your list are all the
same thing: `chicken-leg-quarters`.

- `Sources/KitchenCatalog/Resources/catalog.json`: the catalog. **The source of truth.** Edit it by hand.
  - `items`: id -> `name`, `section` (store section), `aliases` (other ways people and flyers write it),
    optional `parent` (a more general item: `onions-yellow` -> `onion`), `also` (older ids for the
    same thing, so earlier data still links up), `deals` (Grocery Deals' `staple`/`benchmark`), and `popularity`
    (`everyday` or `specialty`; missing means common), which Grocery Deals uses to rank deals people buy most first.
  - `sections`: store sections, in shopping order.
- Swift (`import KitchenCatalog`): `Catalog.shared.match("Onion - Green")` -> `green-onion`, strong.
- JavaScript (`js/catalog.mjs`): `match(load(), text)`, the same rules, for the Friday run and the site.
- Swift only (`Sources/KitchenCatalog/Text/`): `Parser` (recipe lines to name, alternates and prep), `Names`,
  `NameMatcher` (alias lookup, then a shortlist, over any list of `MatchableItem`s), `Resolution` and `Kinds`
  (what kind of thing an item is, so like things sit together). Moved here from On Hand's PantryKit on
  2026-10-25 so Grocery Deals can use them too. They have no JavaScript twin, so the parity rule below
  doesn't cover them.
- `tools/seed.py`: made the first version from Pantry's `pantry.json` and Deals' `config/items.json`.

## Rules

- **Ids never change.** Rename with `name`; merge by moving the old id into the survivor's `also`.
- Apps **store the id** and show the name. Status, amounts, notes and **deals are layers on top**,
  keyed by id. The Reminders list holds the item's name, never prices.
- Matching: the longest name or alias found wins, scored so specific beats general. A match is
  **strong** when the item is what the product is (its last noun, give or take sizes, cuts and words
  like "organic"), and **weak** when it's only mentioned ("Shrimp Chips"). Automated jobs fill in
  strong matches only and send weak ones for review.
- The Swift and JS matchers must agree: `swift test` and `node js/test.mjs` run the same cases.
- `node js/coverage.mjs <weeks dir>` reports how much of a set of deal rows the catalog recognizes.

## Using it in the Grocery Deals Friday run

The Friday run happens in the cloud with only the Deals repo, so Deals keeps a copy in
`vendor/kitchen-catalog/`. After editing the catalog, run `npm run sync-catalog` in the Deals repo.

1. In `draft-week.mjs`, after reading each flyer line: `const m = match(catalog, item)`. If `m.strength === "strong"`,
   set `item_key = m.id` (or keep the existing key when `m.item.also` includes it). Put weak and missing
   matches in the draft report's `review` list.
2. Show `catalog.items[item_key].name` on the site and in the app, so names read the same everywhere.
3. Group and compare prices by `item_key`; use `parent` to roll specific items up ("all onions").
4. When a deal is added to the list, pass the id (and only the id) to Pantry.

First run, the last three weeks (1,016 deal rows): 332 strong matches (Deals' own keys covered 300),
and the catalog agreed with 274 of those 300.
