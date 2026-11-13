#!/usr/bin/env bun
// Section-grain reads of markdown docs. A README stays one file with one owner;
// this tool makes its headings addressable, so a skill loads the sections it
// cites instead of the whole file — a view over the table, never a copy of it.
//
//   doc-section --outline <file>…       → one TSV row per heading:
//                                         file  slug  depth  line  bytes  heading
//   doc-section <file>#<slug>…          → per address: `==> file#slug  N bytes <==`
//                                         then the section's exact source bytes
//   doc-section --self-test             → grades this file against fixtures/
//
// Addresses are GitHub heading slugs — the same fragment the docs' own links use
// (`../README.md#pattern`), so one checker covers links and selections. A section
// runs from its heading to the next heading of equal or shallower depth, subtree
// included. Every address resolves before anything prints; one miss refuses the
// whole call (exit 1, empty stdout, `CODE: msg` per error on stderr):
//   USAGE  NO_FILE  MISSING (stderr carries the outline)  DUPLICATE  OVERLAP  GRAMMAR
// Grammar is deliberately small: ATX headings only, outside a leading `---`
// frontmatter block, ``` / ~~~ fences (closer ≥ opener length) and indented code.
// A setext underline or an unclosed fence is GRAMMAR — refused, not guessed.
// Walks no directories: `git ls-files '*.md' | xargs doc-section --outline`.
import * as fs from "node:fs";
import * as path from "node:path";

type Heading = { slug: string; depth: number; line: number; start: number; end: number; text: string };
type Doc = { file: string; text: string; headings: Heading[] };

class Refusal extends Error {
  constructor(public code: string, message: string) { super(message); }
}

export function slugify(text: string): string {
  return text
    .replace(/`([^`]*)`/g, "$1")
    .replace(/\[([^\]]*)\]\([^)]*\)/g, "$1")
    .toLowerCase()
    .replace(/[^\p{L}\p{N} _-]/gu, "")
    .replace(/ /g, "-"); // each space → one hyphen, as GitHub does ("a / b" → "a--b")
}

export function parse(file: string, text: string): Doc {
  const lines = text.split("\n");
  const offsets: number[] = [];
  for (let o = 0, i = 0; i < lines.length; i++) { offsets.push(o); o += lines[i].length + 1; }
  const headings: Heading[] = [];
  let i = 0;
  // Frontmatter: a leading `---` block. Its `# comment` lines are not headings.
  if (/^---\s*$/.test(lines[0] ?? "")) {
    i = 1;
    while (i < lines.length && !/^(---|\.\.\.)\s*$/.test(lines[i])) i++;
    if (i >= lines.length) throw new Refusal("GRAMMAR", `${file}:1 frontmatter never closes`);
    i++;
  }
  let fence: { ch: string; len: number; line: number } | null = null;
  let prevText = false; // previous line is paragraph text — a `===`/`---` here is setext
  for (; i < lines.length; i++) {
    const ln = lines[i];
    const f = /^ {0,3}(`{3,}|~{3,})/.exec(ln);
    if (fence) {
      if (f && f[1][0] === fence.ch && f[1].length >= fence.len && /^\s*$/.test(ln.slice(f[0].length))) fence = null;
      continue;
    }
    if (f) { fence = { ch: f[1][0], len: f[1].length, line: i + 1 }; prevText = false; continue; }
    if (/^(\t| {4})/.test(ln)) { prevText = false; continue; } // indented code
    if (prevText && /^ {0,3}(=+|-+)\s*$/.test(ln)) throw new Refusal("GRAMMAR", `${file}:${i + 1} setext heading — use an ATX \`#\` heading`);
    const h = /^ {0,3}(#{1,6})[ \t]+(.*?)(?:[ \t]+#+)?[ \t]*$/.exec(ln);
    if (h) {
      headings.push({ slug: slugify(h[2]), depth: h[1].length, line: i + 1, start: offsets[i], end: text.length, text: h[2] });
      prevText = false;
      continue;
    }
    prevText = ln.trim() !== "";
  }
  if (fence) throw new Refusal("GRAMMAR", `${file}:${fence.line} fence never closes`);
  for (let k = 0; k < headings.length; k++) {
    const next = headings.slice(k + 1).find((n) => n.depth <= headings[k].depth);
    if (next) headings[k].end = next.start;
  }
  return { file, text, headings };
}

const bytes = (s: string) => Buffer.byteLength(s, "utf8");
const outlineRows = (d: Doc) =>
  d.headings.map((h) => [d.file, h.slug, h.depth, h.line, bytes(d.text.slice(h.start, h.end)), h.text].join("\t"));

function load(file: string): Doc {
  let text: string;
  try { text = fs.readFileSync(file, "utf8"); } catch { throw new Refusal("NO_FILE", file); }
  return parse(file, text);
}

// Resolve every address; return the slices or every refusal met along the way.
export function resolve(addrs: string[], loader = load): { slices: { addr: string; body: string }[]; errors: Refusal[] } {
  const docs = new Map<string, Doc>();
  const errors: Refusal[] = [];
  const picked: { addr: string; doc: Doc; h: Heading }[] = [];
  for (const addr of addrs) {
    const at = addr.indexOf("#");
    if (at <= 0 || at === addr.length - 1) { errors.push(new Refusal("USAGE", `${JSON.stringify(addr)} is not <file>#<slug>`)); continue; }
    const file = addr.slice(0, at), slug = addr.slice(at + 1);
    let doc = docs.get(file);
    if (!doc) {
      try { doc = loader(file); docs.set(file, doc); } catch (e) { if (e instanceof Refusal) { errors.push(e); continue; } throw e; }
    }
    const hits = doc.headings.filter((h) => h.slug === slug);
    if (hits.length === 0) {
      errors.push(new Refusal("MISSING", `${addr} — headings in ${file}:\n${outlineRows(doc).map((r) => "  " + r).join("\n")}`));
    } else if (hits.length > 1) {
      errors.push(new Refusal("DUPLICATE", `${addr} at lines ${hits.map((h) => h.line).join(", ")} — rename one heading at the source`));
    } else picked.push({ addr, doc, h: hits[0] });
  }
  for (let a = 0; a < picked.length; a++) for (let b = a + 1; b < picked.length; b++) {
    const p = picked[a], q = picked[b];
    if (p.doc !== q.doc) continue;
    const inside = (x: Heading, y: Heading) => x.start >= y.start && x.end <= y.end;
    if (inside(p.h, q.h) || inside(q.h, p.h)) errors.push(new Refusal("OVERLAP", `${p.addr} and ${q.addr} — one contains the other`));
  }
  return { slices: picked.map((p) => ({ addr: p.addr, body: p.doc.text.slice(p.h.start, p.h.end) })), errors };
}

function fail(errors: Refusal[]): never {
  for (const e of errors) process.stderr.write(`${e.code}: ${e.message}\n`);
  process.exit(1);
}

function selfTest(): never {
  const dir = path.join(import.meta.dir, "fixtures");
  let failures = 0;
  for (const name of fs.readdirSync(dir).filter((n) => n.endsWith(".md")).sort()) {
    const expect = fs.readFileSync(path.join(dir, name.replace(/\.md$/, ".expect")), "utf8").trimEnd();
    const text = fs.readFileSync(path.join(dir, name), "utf8");
    let got: string;
    try {
      const doc = parse(name, text);
      const rows = outlineRows(doc);
      // Slices are source bytes: top-level sections plus the preamble tile the file exactly.
      const top = doc.headings.filter((h) => h.depth === Math.min(...doc.headings.map((x) => x.depth)));
      const tiled = (top.length ? text.slice(0, top[0].start) : text) + top.map((h) => text.slice(h.start, h.end)).join("");
      if (tiled !== text) rows.push("TILE MISMATCH");
      const extra: string[] = [];
      for (const line of expect.split("\n").filter((l) => l.startsWith("EXTRACT "))) {
        const [, slug] = line.split(" ");
        const r = resolve([`${name}#${slug}`], () => doc);
        extra.push(r.errors.length ? `EXTRACT ${slug} ERROR ${r.errors[0].code}` : `EXTRACT ${slug} OK`);
      }
      got = ["OUTLINE", ...rows, "END", ...extra].join("\n");
    } catch (e) {
      if (!(e instanceof Refusal)) throw e;
      got = `ERROR ${e.code}`;
    }
    if (got !== expect) { failures++; process.stderr.write(`FAIL ${name}\n--- expected\n${expect}\n--- got\n${got}\n`); }
    else process.stdout.write(`ok ${name}\n`);
  }
  process.exit(failures ? 1 : 0);
}

if (import.meta.main) {
  const argv = process.argv.slice(2);
  if (argv[0] === "--self-test") selfTest();
  if (argv.length === 0) fail([new Refusal("USAGE", "doc-section --outline <file>… | doc-section <file>#<slug>…")]);
  if (argv[0] === "--outline") {
    const files = argv.slice(1);
    if (files.length === 0 || files.some((f) => f.startsWith("--") || f.includes("#"))) fail([new Refusal("USAGE", "doc-section --outline <file>… (paths only, no #slug)")]);
    const docs: Doc[] = [], errors: Refusal[] = [];
    for (const f of files) { try { docs.push(load(f)); } catch (e) { if (e instanceof Refusal) errors.push(e); else throw e; } }
    if (errors.length) fail(errors);
    for (const d of docs) for (const r of outlineRows(d)) process.stdout.write(r + "\n");
    process.exit(0);
  }
  if (argv.some((a) => a.startsWith("--"))) fail([new Refusal("USAGE", "doc-section --outline <file>… | doc-section <file>#<slug>…")]);
  const { slices, errors } = resolve(argv);
  if (errors.length) fail(errors);
  let out = "";
  for (const s of slices) {
    if (out && !out.endsWith("\n")) out += "\n";
    out += `==> ${s.addr}  ${bytes(s.body)} bytes <==\n${s.body}`;
  }
  process.stdout.write(out);
}
