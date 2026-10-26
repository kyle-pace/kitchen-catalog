// How much of a set of deal rows the catalog recognizes. node js/coverage.mjs <weeks dir>
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { load, match } from "./catalog.mjs";
const dir = process.argv[2];
const catalog = load();
const rows = readdirSync(dir).filter((f) => f.endsWith(".json")).flatMap((f) => JSON.parse(readFileSync(join(dir, f), "utf8")).items);
const strength = { strong: 0, weak: 0 };
let matched = 0, agreed = 0, keyed = 0, disagree = [];
const missed = {};
for (const r of rows) {
  const m = match(catalog, r.item);
  if (m) strength[m.strength]++;
  if (r.item_key) keyed++;
  if (m) { matched++; if (r.item_key && (m.id === r.item_key || (m.item.also || []).includes(r.item_key))) agreed++; else if (r.item_key) disagree.push(`${r.item} -> catalog ${m.id}, deals ${r.item_key}`); }
  else missed[r.category] = (missed[r.category] || 0) + 1;
}
console.log(`${rows.length} deal rows. Catalog recognizes ${matched} (${Math.round((matched / rows.length) * 100)}%). Deals' own keys: ${keyed}; catalog agrees on ${agreed}.`);
console.log("By strength:", strength);
console.log("Not recognized, by category:", missed);
console.log("Weak (sample):\n  " + rows.map((r) => [r.item, match(catalog, r.item)]).filter(([, m]) => m?.strength === "weak").slice(0, 15).map(([i, m]) => `${i}  ->  ${m.id}`).join("\n  "));
console.log("Disagreements:", disagree.slice(0, 15));
const sample = rows.filter((r) => match(catalog, r.item)?.strength === "strong" && !r.item_key).slice(0, 25).map((r) => `${r.item}  ->  ${match(catalog, r.item).id}`);
console.log("Newly recognized (sample):\n  " + sample.join("\n  "));
