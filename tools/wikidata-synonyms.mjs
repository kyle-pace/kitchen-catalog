// Other names and "kind of" links for catalog items, from Wikidata (CC0). A build-time helper:
// nothing calls Wikidata at run time, and nothing lands in catalog.json without a person accepting it.
//
//   node tools/wikidata-synonyms.mjs                 look up every item, write tools/out/wikidata-candidates.json
//   node tools/wikidata-synonyms.mjs --only eggplant,taro   just these ids
//   node tools/wikidata-synonyms.mjs --apply         add the candidates marked "accept": true to catalog.json
//
// Answers are cached in tools/.cache/wikidata/ (git-ignored), so a rerun only asks for what's new.
// --offline uses the cache only (--cache <dir> to point it somewhere else), for testing without a network.
//
// Each candidate says why it might be wrong: "collides" (another item already uses those words), "short"
// (3 letters or fewer), "changes" (flyer lines in the answer key or Tests/flyer-lines/ that would match differently).
// Accept by setting "accept": true, then run --apply and `node js/score.mjs`.
import { readFileSync, writeFileSync, mkdirSync, existsSync, readdirSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { load, match, normalize, CATALOG_PATH } from "../js/catalog.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const OUT = join(here, "out", "wikidata-candidates.json");
const args = process.argv.slice(2);
const flag = (name) => args.includes(name);
const value = (name) => (args.includes(name) ? args[args.indexOf(name) + 1] : null);
const offline = flag("--offline");
const cacheDir = value("--cache") ?? join(here, ".cache", "wikidata");
const API = "https://www.wikidata.org/w/api.php";
// Wikidata asks for a descriptive User-Agent with a way to get in touch.
const UA = "KitchenCatalog-synonyms/1.0 (https://github.com/kyle-pace/kitchen-catalog)";
const LANGS = ["en", "en-gb", "en-ca", "en-au"];
// Descriptions that say an entity is something you'd buy to eat, not a person, place, film or company.
const FOODISH = /\b(vegetable|fruit|berry|cultivar|plant|species|herb|spice|food|ingredient|cut of|meat|beef|pork|poultry|chicken|fish|seafood|shellfish|mollusc|mollusk|crustacean|sauce|condiment|paste|cheese|dairy|milk|cream|yogurt|egg|noodle|pasta|rice|grain|cereal|bean|legume|pea|lentil|mushroom|fungus|nut|seed|oil|vinegar|sugar|syrup|flour|starch|bread|pastry|cake|dumpling|beverage|drink|juice|tea|coffee|snack|sweet|confection|seasoning|tofu|seaweed|kelp|algae|sausage|ham|bacon|squash|melon|citrus|tuber|root|leaf|leaves|greens)\b/i;
const NOT_FOOD = /\b(film|album|song|band|company|village|city|town|river|mountain|surname|given name|novel|episode|video game|character|television|magazine|journal|software|ship|painting)\b/i;

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
async function api(params) {
  const qs = new URLSearchParams({ format: "json", ...params });
  const file = join(cacheDir, qs.toString().replace(/[^a-z0-9]+/gi, "_").slice(0, 180) + ".json");
  if (existsSync(file)) return JSON.parse(readFileSync(file, "utf8"));
  if (offline) return null;
  for (let attempt = 0; attempt < 4; attempt++) {
    const res = await fetch(`${API}?${qs}`, { headers: { "User-Agent": UA } });
    if (res.status === 429 || res.status >= 500) { await sleep(2000 * (attempt + 1)); continue; }
    if (!res.ok) throw new Error(`Wikidata ${res.status} for ${qs}`);
    // Wikidata reports API errors (rate limits, bad parameters) as HTTP 200 with an "error" body, and an outage can
    // return an HTML page. Neither is an answer, so neither is cached: wait and try again.
    let json;
    try { json = await res.json(); } catch { await sleep(2000 * (attempt + 1)); continue; }
    if (json.error) {
      if (json.error.code === "maxlag" || json.error.code === "ratelimited") { await sleep(5000 * (attempt + 1)); continue; }
      throw new Error(`Wikidata error ${json.error.code}: ${json.error.info}`);
    }
    mkdirSync(cacheDir, { recursive: true });
    writeFileSync(file, JSON.stringify(json));
    await sleep(150); // be polite: well under Wikidata's limits
    return json;
  }
  throw new Error(`Wikidata kept failing for ${qs}`);
}

const englishNames = (entity) => {
  const names = [];
  for (const l of LANGS) {
    if (entity.labels?.[l]) names.push(entity.labels[l].value);
    for (const a of entity.aliases?.[l] ?? []) names.push(a.value);
  }
  return names;
};
const claimIds = (entity, prop) => (entity.claims?.[prop] ?? []).map((c) => c.mainsnak?.datavalue?.value?.id).filter(Boolean);
const claimStrings = (entity, prop) => (entity.claims?.[prop] ?? []).map((c) => c.mainsnak?.datavalue?.value).filter((v) => typeof v === "string");

/** The Wikidata entity for a catalog item: a search hit whose English name is the item's name or an alias, and whose
 * description reads like food. Returns null when nothing is clearly right (better no candidate than a wrong one). */
async function findEntity(item) {
  const wanted = new Set([item.name, ...item.aliases].map(normalize));
  for (const query of [item.name, ...item.aliases.slice(0, 2)]) {
    const found = await api({ action: "wbsearchentities", search: query.replace(/\([^)]*\)/g, "").trim(), language: "en", type: "item", limit: "7" });
    for (const hit of found?.search ?? []) {
      const desc = hit.description ?? "";
      const names = [hit.label, ...(hit.aliases ?? []), hit.match?.text].filter(Boolean).map(normalize);
      if (!names.some((n) => wanted.has(n)) || NOT_FOOD.test(desc) || !FOODISH.test(desc)) continue;
      const full = await api({ action: "wbgetentities", ids: hit.id, props: "labels|aliases|descriptions|claims", languages: LANGS.join("|") });
      const entity = full?.entities?.[hit.id];
      if (entity) return { id: hit.id, description: desc, entity };
    }
  }
  return null;
}

async function labels(ids) {
  const out = {};
  for (let i = 0; i < ids.length; i += 50) {
    const got = await api({ action: "wbgetentities", ids: ids.slice(i, i + 50).join("|"), props: "labels", languages: "en" });
    for (const [id, e] of Object.entries(got?.entities ?? {})) out[id] = e.labels?.en?.value;
  }
  return out;
}

/** Flyer lines to check candidates against: the answer keys, plus any plain-text lists in Tests/flyer-lines/. */
function flyerLines() {
  const root = join(here, "..", "Tests");
  const lines = new Set();
  for (const f of existsSync(join(root, "answer-keys")) ? readdirSync(join(root, "answer-keys")) : []) {
    if (f.endsWith(".json")) for (const l of JSON.parse(readFileSync(join(root, "answer-keys", f), "utf8")).lines) lines.add(l.item);
  }
  for (const f of existsSync(join(root, "flyer-lines")) ? readdirSync(join(root, "flyer-lines")) : []) {
    for (const l of readFileSync(join(root, "flyer-lines", f), "utf8").split("\n")) if (l.trim()) lines.add(l.trim());
  }
  return [...lines];
}

async function lookUp() {
  const raw = JSON.parse(readFileSync(CATALOG_PATH, "utf8"));
  const catalog = load();
  const only = value("--only")?.split(",");
  const ids = Object.keys(raw.items).filter((id) => !only || only.includes(id));
  // Who already uses each normalized term, so a candidate that's someone else's name is flagged.
  const owner = new Map(catalog.terms.map((t) => [t.term, t.id]));
  const byName = new Map(Object.entries(raw.items).map(([id, it]) => [normalize(it.name), id]));
  const lines = flyerLines().map((text) => ({ text, words: new Set(normalize(text.replace(/\([^)]*\)/g, " ")).split(" ")) }));
  // Id and strength: weak to strong is the change that matters most, since strong matches are filled in without review.
  const show = (m) => (m ? `${m.id}${m.strength === "weak" ? " (weak)" : ""}` : "none");
  const before = new Map(lines.map((l) => [l.text, show(match(catalog, l.text))]));
  // Accept marks from an earlier run carry over, so a rerun (or --only) doesn't undo review work.
  const earlier = existsSync(OUT) ? JSON.parse(readFileSync(OUT, "utf8")).items : [];
  const marked = new Map(earlier.map((r) => [r.id, r]));
  const sortTerms = (terms) => terms.sort((a, b) => b.words - a.words || b.term.length - a.term.length || (b.isName ? 1 : 0) - (a.isName ? 1 : 0));
  const results = [];
  let done = 0;
  for (const id of ids) {
    const item = raw.items[id];
    const hit = await findEntity(item);
    done++;
    if (done % 50 === 0) console.error(`${done} of ${ids.length}`);
    if (!hit) { results.push({ id, name: item.name, wikidata: null }); continue; }
    const taxon = new Set(claimStrings(hit.entity, "P225").map(normalize)); // scientific names
    const have = new Set([item.name, ...item.aliases].map(normalize));
    const seen = new Set();
    const aliases = [];
    for (const name of englishNames(hit.entity)) {
      const n = normalize(name);
      if (!n || have.has(n) || taxon.has(n) || seen.has(n)) continue;
      seen.add(n);
      const flags = [];
      if (owner.has(n) && owner.get(n) !== id) flags.push(`collides with ${owner.get(n)}`);
      if (n.replace(/ /g, "").length <= 3) flags.push("short");
      if (/\d/.test(n)) flags.push("has a number");
      // Would it change how any known flyer line matches? Only lines with all of its words can change (in any order,
      // since the matcher also reads "Onion - Green" as "green onion").
      const trial = { ...catalog, terms: sortTerms([...catalog.terms, { id, term: n, words: n.split(" ").length, isName: false }]),
        single: n.includes(" ") ? catalog.single : new Set([...catalog.single, n]),
        ownWords: { ...catalog.ownWords, [id]: new Set([...(catalog.ownWords[id] ?? []), ...n.split(" ")]) } };
      const changes = lines.filter((l) => n.split(" ").every((w) => l.words.has(w)))
        .map((l) => [l.text, before.get(l.text), show(match(trial, l.text))]).filter(([, a, b]) => a !== b)
        .map(([text, a, b]) => `${text}: ${a} -> ${b}`);
      if (changes.length) flags.push("changes");
      const wasAccepted = marked.get(id)?.aliases?.some((x) => x.alias === name && x.accept) ?? false;
      aliases.push({ alias: name, accept: wasAccepted, flags, ...(changes.length ? { changes: changes.slice(0, 5) } : {}) });
    }
    // "Kind of": P279 (subclass of) and P31 (instance of), when the parent is also a catalog item.
    const up = [...claimIds(hit.entity, "P279"), ...claimIds(hit.entity, "P31")];
    const upNames = up.length ? await labels(up) : {};
    const parents = Object.entries(upNames)
      .map(([qid, label]) => ({ qid, label, catalog: label ? byName.get(normalize(label)) ?? owner.get(normalize(label)) ?? null : null }))
      .filter((p) => p.catalog && p.catalog !== id)
      .map((p) => ({ parent: p.catalog, via: `${p.qid} ${p.label}`, current: item.parent ?? null,
        accept: marked.get(id)?.parents?.some((x) => x.parent === p.catalog && x.accept) ?? false }));
    results.push({ id, name: item.name, wikidata: { id: hit.id, description: hit.description }, aliases, parents });
  }
  // Items not looked up this time (--only) keep their earlier candidates.
  const ran = new Set(results.map((r) => r.id));
  for (const r of earlier) if (!ran.has(r.id)) results.push(r);
  results.sort((a, b) => a.id.localeCompare(b.id));
  mkdirSync(dirname(OUT), { recursive: true });
  const about = "Candidates from Wikidata for review. Set accept: true on the ones to keep, then run with --apply. " +
    "flags: collides (another item uses the words), short, changes (known flyer lines would match differently; see changes).";
  writeFileSync(OUT, JSON.stringify({ about, made: new Date().toISOString().slice(0, 10), items: results }, null, 1) + "\n");
  const now = results.filter((r) => ran.has(r.id));
  const n = now.filter((r) => r.wikidata).length;
  const a = now.reduce((s, r) => s + (r.aliases?.length ?? 0), 0);
  const clean = now.reduce((s, r) => s + (r.aliases?.filter((x) => !x.flags.length).length ?? 0), 0);
  const p = now.reduce((s, r) => s + (r.parents?.length ?? 0), 0);
  console.log(`${n} of ${now.length} items found on Wikidata. ${a} alias candidates (${clean} with no flags), ${p} parent candidates. Wrote ${OUT}`);
}

function apply() {
  const raw = JSON.parse(readFileSync(CATALOG_PATH, "utf8"));
  const cands = JSON.parse(readFileSync(OUT, "utf8"));
  let added = 0, linked = 0;
  for (const r of cands.items) {
    const item = raw.items[r.id];
    if (!item) continue;
    const more = (r.aliases ?? []).filter((a) => a.accept && !item.aliases.includes(a.alias)).map((a) => a.alias);
    if (more.length) { item.aliases.push(...more); item.aliases.sort((x, y) => x.toLowerCase().localeCompare(y.toLowerCase())); added += more.length; }
    const p = (r.parents ?? []).find((x) => x.accept);
    if (p && raw.items[p.parent]) {
      // Never make a loop: the new parent mustn't already be below this item.
      let up = p.parent, loop = false;
      for (let n = 0; up && n < 20; up = raw.items[up]?.parent, n++) if (up === r.id) loop = true;
      if (loop) console.error(`Skipped ${r.id} -> ${p.parent}: it would make a loop.`);
      else { item.parent = p.parent; linked++; }
    }
  }
  writeFileSync(CATALOG_PATH, JSON.stringify(raw, null, 1) + "\n");
  console.log(`Added ${added} aliases and ${linked} parent links. Now run: node js/test.mjs && node js/score.mjs`);
}

if (flag("--apply")) apply(); else await lookUp();
