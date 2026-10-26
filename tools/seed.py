# One-time: merge Pantry's pantry.json and Grocery Deals' config/items.json into catalog.json.
# After this, catalog.json is the source of truth and is edited by hand (or by review tools).
import json, re, sys
pantry = json.load(open(sys.argv[1]))['items']
deals = json.load(open(sys.argv[2]))['items']
out = sys.argv[3]

SECTIONS = [
    ("produce", "Produce"), ("meat", "Meat"), ("seafood", "Seafood"), ("dairy-eggs", "Dairy & eggs"),
    ("bakery", "Bakery"), ("frozen", "Frozen"), ("pantry", "Pantry"), ("spices", "Spices"),
    ("international", "International"), ("snacks-drinks", "Snacks & drinks"), ("prepared", "Prepared foods"),
    ("household", "Household"), ("other", "Other"),
]
BY_CATEGORY = {
    "Spices": "spices", "Chile Heat": "spices",
    "Asian Sauces & Pastes": "international", "Dried Umami & Dry Goods": "international", "Preserved & Pickled Vegetables": "international",
    "Rice, Grains & Noodles": "pantry", "Flour, Baking & Thickeners": "pantry", "Canned & Boxed": "pantry", "Salt, Sugar & Sweeteners": "pantry",
    "Western Condiments": "pantry", "Nuts & Seeds": "pantry", "Vinegars": "pantry", "Oils & Fats": "pantry", "Dried Beans & Lentils": "pantry",
    "Cooking Wines & Spirits": "pantry", "Counter & Cool-Dark Produce": "produce", "Freezer": "frozen",
}
WORDS = [
    ("seafood", r"\b(fish|salmon|shrimp|prawn|crab|clam|mussel|squid|tuna|cod|anchov|scallop|oyster(?! sauce))"),
    ("meat", r"\b(chicken|pork|beef|lamb|turkey|bacon|sausage|ham|duck|ground)\b"),
    ("dairy-eggs", r"\b(milk|cream|cheese|butter|yogurt|egg|kefir|ghee)"),
    ("produce", r"\b(green|greens|spinach|kale|lettuce|onion|scallion|pepper|herb|cilantro|basil|ginger|garlic|cabbage|carrot|celery|tomato|bean sprout|mushroom|tofu|lemon|lime|apple|potato|squash|cucumber|zucchini|bok choy|choy|radish|daikon)"),
]

def section_for(item):
    cat = item.get("category") or ""
    if cat in BY_CATEGORY: return BY_CATEGORY[cat]
    name = item["name"].lower()
    for section, pattern in WORDS:
        if re.search(pattern, name): return section
    return "dairy-eggs" if cat == "Fridge Staples" else "other"

def words(t):
    t = re.sub(r"[^a-z0-9 ]+", " ", t.lower())
    return frozenset(w[:-1] if len(w) > 3 and w.endswith("s") and not w.endswith("ss") else w for w in t.split())

items = {}
for p in pantry:
    names = [p["name"].lower()] + [a.lower() for a in p.get("aliases") or []]
    items[p["id"]] = {"name": p["name"], "section": section_for(p),
                      "aliases": sorted(set(n for n in names if n != p["name"].lower()))}

pantry_ids = set(items)
def terms_of(entry): return [entry["name"].lower()] + entry["aliases"]

for key, d in deals.items():
    label = d["label"]
    deal_terms = [label.lower()] + [m.lower() for m in d.get("match") or []]
    extra = {k: d[k] for k in ("staple", "benchmark") if k in d}
    if key in items:
        target = key
    else:
        # The same thing under another id ("rice-jasmine" = "jasmine-rice"): merge, keeping Deals' key.
        target = next((pid for pid in pantry_ids if words(items[pid]["name"]) == words(label)), None)
    if target:
        e = items[target]
        e["aliases"] = sorted(set(e["aliases"]) | (set(deal_terms) - {e["name"].lower()}))
        if extra: e["deals"] = extra
        if target != key: e.setdefault("also", []).append(key)
        if e["section"] == "other": e["section"] = d.get("category", "other")
        continue
    # A more specific kind of something Pantry has ("yellow onion" under "onion"): its own item,
    # with the general one as parent, and the shared words move to the specific one.
    entry = {"name": label, "section": d.get("category", "other"), "aliases": sorted(set(deal_terms) - {label.lower()})}
    shared = [pid for pid in pantry_ids if set(terms_of(items[pid])) & set(deal_terms)]
    general = [pid for pid in shared if words(items[pid]["name"]) < words(label) or len(words(items[pid]["name"])) <= len(words(label))]
    if general:
        parent = min(general, key=lambda pid: len(items[pid]["name"]))
        entry["parent"] = parent
        for pid in shared:
            items[pid]["aliases"] = [a for a in items[pid]["aliases"] if a not in deal_terms]
    if extra: entry["deals"] = extra
    items[key] = entry

# Single words that name a whole class of things only lead to wrong matches.
GENERIC = {"pepper", "oil", "sauce", "salt", "sugar", "rice", "noodle", "noodles", "curry", "jack", "goat", "paste", "powder", "seasoning", "vinegar", "wine", "chili", "chile", "bean", "beans", "greens", "meat", "fish"}
for e in items.values():
    e["aliases"] = sorted(a for a in set(e["aliases"]) if a not in GENERIC and a != e["name"].lower())

catalog = {
    "about": "The shared list of grocery items for Pantry and Grocery Deals. Each item has a fixed id that never changes; apps store the id and show the name. aliases are other ways people and flyers write it.",
    "version": 1,
    "sections": [{"id": i, "name": n} for i, n in SECTIONS],
    "items": dict(sorted(items.items())),
}
json.dump(catalog, open(out, "w"), indent=1, ensure_ascii=False)
print(len(items), "items")
