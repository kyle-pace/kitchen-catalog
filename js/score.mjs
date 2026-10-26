// How well the catalog matches a hand-labeled answer key. node js/score.mjs [answer key] [--list wrong|weak|none|close]
// Strong exact: the right item. Close: a parent or child of the right item. Wrong: a strong match to an unrelated item,
// the kind that breaks trust, since automated jobs fill strong matches in without review.
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { load, match } from "./catalog.mjs";
const here = dirname(fileURLToPath(import.meta.url));
const args = process.argv.slice(2);
const keyPath = args[0] && !args[0].startsWith("--") ? args[0] : join(here, "..", "Tests", "answer-keys", "deals-2026-10-23.json");
const which = args.includes("--list") ? args[args.indexOf("--list") + 1] : null;
const catalog = load();
const key = JSON.parse(readFileSync(keyPath, "utf8"));
const up = (id) => { const out = []; let p = catalog.items[id]?.parent; while (p) { out.push(p); p = catalog.items[p]?.parent; } return out; };
const related = (a, b) => up(a).includes(b) || up(b).includes(a);
const r = { exact: 0, close: 0, wrong: 0, weakRight: 0, weakWrong: 0, none: 0 };
const lists = { wrong: [], weak: [], none: [], close: [] };
for (const line of key.lines) {
  const m = match(catalog, line.item);
  const exp = line.expect;
  if (!m) { r.none++; lists.none.push(`${line.item}  [${exp}]`); continue; }
  const ok = m.id === exp || (line.accept || []).includes(m.id), near = !ok && related(m.id, exp);
  if (m.strength === "strong") {
    if (ok) r.exact++;
    else if (near) { r.close++; lists.close.push(`${line.item} -> ${m.id}  [${exp}]`); }
    else { r.wrong++; lists.wrong.push(`${line.item} -> ${m.id}  [${exp}]`); }
  } else {
    if (ok || near) r.weakRight++; else r.weakWrong++;
    lists.weak.push(`${line.item} -> ${m.id}${ok || near ? "" : "  (wrong)"}  [${exp}]`);
  }
}
const n = key.lines.length, pct = (x) => `${Math.round((x / n) * 100)}%`;
console.log(`${n} lines. Strong: ${r.exact} right (${pct(r.exact)}), ${r.close} close, ${r.wrong} wrong. ` +
  `Weak (sent to review): ${r.weakRight + r.weakWrong}, ${r.weakWrong} of them wrong. No match: ${r.none}.`);
if (which) console.log(lists[which].join("\n"));
