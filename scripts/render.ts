// Renders bin trees from the election manifest.
//
// Replaces the symlink farm: each election becomes a real directory copied out of
// the cellar, with its `SKILL.md` frontmatter lowered from the abstract `tier:` to
// this harness's engine dialect. The manifest is the source of truth for placement
// and dialect; the rendered tree is disposable output — delete it, re-run, get it
// back byte-identical.
//
// `--check` renders into a throwaway shadow tree and byte-diffs each election's shadow
// directory against the live bin-tree directory. An empty diff is the proof that the
// live tree is exactly what the manifest says it should be — no hand edits, no drift.
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";

// The descendant root: the repo whose forge/elections.json this render serves.
// $FORGE_ROOT names it outright; otherwise it is the nearest ancestor of this script
// that holds forge/elections.json. Anchored on the manifest, not on .git or a bin-tree
// name, so the engine can live anywhere (forge/scripts/ today, a subtree tomorrow) and
// the output roots can be renamed without breaking discovery. The engine owns no paths.
function repoRoot(): string {
  if (process.env.FORGE_ROOT) return path.resolve(process.env.FORGE_ROOT);
  let dir = path.dirname(new URL(import.meta.url).pathname);
  while (true) {
    if (fs.existsSync(path.join(dir, "forge", "elections.json"))) return dir;
    const parent = path.dirname(dir);
    if (parent === dir) throw new Error("Could not locate the descendant root (no ancestor holds forge/elections.json; set FORGE_ROOT)");
    dir = parent;
  }
}

// `--manifest <path>` substitutes the election manifest only — cellar sources and
// output roots still resolve against the repo root, so a candidate manifest can be
// shadow-rendered from scratch before it replaces the live one.
function manifestPath(): string {
  const i = process.argv.indexOf("--manifest");
  return i !== -1 ? path.resolve(process.argv[i + 1]) : path.join(repoRoot(), "forge", "elections.json");
}

const MANIFEST = manifestPath();
const SHADOW = path.join(repoRoot(), "forge", "scratch", "render-check");

// Cellar bookkeeping, not skill content — never rendered into a bin tree.
const CELLAR_ONLY = new Set([".yanked"]);

interface Entry {
  version: string;
  bundle?: string[];
  /** Per-placement override of the version's own `tier:` frontmatter. */
  tier?: string;
}

/** One eligible engine for a tier on this harness — the per-harness engine dialect.
    Each tier maps to a *list* of these; the first member is the tier's default, and an
    election-level qualifier (`sota[fable]`) selects another member by its `model`. */
interface TierBinding {
  model?: string;
  effort?: string;
}

interface ToolEntry {
  version: string;
}

/** A partial election: a versioned prose fragment, inlined into consumer bodies at
    render. No root and no dest — a partial renders nowhere on its own. */
interface PartialEntry {
  version: string;
}

/** One rendered agent variant: a named set of election-level overrides laid over the
    version's frontmatter. The key it sits under is the rendered agent's name. */
interface Variant {
  /** Same contract as a skill election's `tier` — bare or member-qualified. */
  tier?: string;
  /** Wins over the version's own `effort:` (an election-level override, unlike the
      tier's default effort). */
  effort?: string;
  /** Rendered verbatim as the `disallowedTools:` line — how a read-only variant is cut. */
  disallowedTools?: string;
}
const VARIANT_KEYS = new Set(["tier", "effort", "disallowedTools"]);

interface AgentEntry {
  version: string;
  /** Rendered name -> overrides. When present it is the *complete* rendered set — the
      entry's own name renders only if listed. Absent: one file named after the entry,
      no overrides. */
  variants?: Record<string, Variant>;
}

interface Harness {
  roots: Record<string, string>;
  /** A row is either a member list, or a string naming another tier (a deprecated
      alias — `"strong": "sota"` — dereferenced one hop at resolution). */
  tiers?: Record<string, TierBinding[] | string>;
  /** Tier applied when neither the election nor the frontmatter names one. */
  defaultTier?: string;
  elections: Record<string, Record<string, Entry>>;
  /** Stable versionless root the tool elections render to (the opt-path). */
  toolsRoot?: string;
  /** Consumer-visible form of the opt-path — what `{{tools:<name>}}` expands to.
      Distinct from toolsRoot: that is where render *writes* (repo-relative), this is
      the path rendered skills *reference* at runtime. */
  toolsOpt?: string;
  tools?: Record<string, ToolEntry>;
  /** The harness's partial elections — the allowlist `partials:` declarations resolve
      against. Fragments, not files: `{{partials:<name>}}` expands to the elected
      version's text in place. */
  partials?: Record<string, PartialEntry>;
  /** Root the agent elections render to — one `.md` file per rendered name. */
  agentsRoot?: string;
  agents?: Record<string, AgentEntry>;
  /** Per-scope entry names the prune pass leaves alone — hand-placed dirs render
      does not own. Everything else under a declared root is prunable. */
  unmanaged?: Record<string, string[]>;
  /** Multicast scopes: scope -> the suite whose receipt subscribes a repo. A multicast
      scope has elections but no `roots` entry — each election renders into every
      subscriber's rendered root instead. Hand-authored, like `roots`. */
  multicast?: Record<string, string>;
}

interface Manifest {
  /** The engine version this manifest was written against (`v0.0.1`), checked at
      every run against the engine's own VERSION file: a descendant pins pagma. */
  engine?: string;
  harnesses: Record<string, Harness>;
}

/** A repo that holds a multicast scope's suite receipt and a declared root. */
interface Subscriber {
  repo: string;
  /** The repo's rendered root, repo-relative (its `roots` entry). */
  root: string;
  /** Absolute path of the receipt file. */
  receipt: string;
  /** Read from the receipt; unset when the receipt is unreadable (see `error`). */
  version?: string;
  /** The suite's declared floors on forge skills (`{skill: ">=X.Y.Z"}`), as stamped. */
  peers?: Record<string, string>;
  /** Why the receipt is unusable — names the file. A per-placement error. */
  error?: string;
}

interface Target {
  /** Cellar version dir this election renders from. */
  src: string;
  /** Where the rendered copy lands. */
  dest: string;
  label: string;
  /** Elected version string, stamped into the rendered frontmatter. */
  version: string;
  /** Election-level tier override — wins over the frontmatter `tier:`. May carry a
      member qualifier (`sota[fable]`); qualifiers are manifest-only dialect. */
  electionTier?: string;
  tiers: Record<string, TierBinding[] | string>;
  defaultTier?: string;
  /** The harness's tool elections — the allowlist `tools:` declarations resolve against. */
  toolElections: Record<string, ToolEntry>;
  toolsOpt?: string;
  /** The harness's partial elections — the allowlist `partials:` declarations resolve against. */
  partialElections: Record<string, PartialEntry>;
  /** Set on a multicast placement: the suite and the repo this copy lands in. */
  multicast?: string;
  subscriber?: Subscriber;
  /** Set on a multicast placement whose dest a rooted election already renders: that
      election's label. One election per path — the placement is `error`. */
  claimed?: string;
  /** Set on an agent placement: the cellar entry, the rendered name, that variant's
      overrides, and whether the entry declares variants at all (stamped when it does). */
  agent?: { entry: string; name: string; overrides: Variant; variant: boolean };
}

function readManifest(): Manifest {
  if (!fs.existsSync(MANIFEST)) {
    console.error(`no manifest at ${MANIFEST} — hand-author it, see forge/README.md`);
    process.exit(1);
  }
  const manifest = JSON.parse(fs.readFileSync(MANIFEST, "utf8")) as Manifest;
  if (manifest.engine !== undefined) {
    const have = fs.readFileSync(path.join(path.dirname(new URL(import.meta.url).pathname), "..", "VERSION"), "utf8").trim();
    const want = manifest.engine.replace(/^v/, "");
    if (have !== want) {
      console.error(`manifest pins engine v${want} but this engine is v${have} — pull the engine subtree to v${want}, or re-pin`);
      process.exit(1);
    }
  }
  return manifest;
}

const RECEIPT_VERSION = /^v\d+\.\d+\.\d+$/;
const PEER_FLOOR = /^>=v?\d+(\.\d+)*$/;

/** Dotted numeric compare over the parts after an optional `v`; on an equal prefix the
    longer tuple wins (`v1.0.7.3` >= `v1.0.7`). Negative, zero or positive like a sort cmp. */
function cmpVersion(a: string, b: string): number {
  const parts = (v: string) => v.replace(/^v/, "").split(".").map(Number);
  const [x, y] = [parts(a), parts(b)];
  for (let i = 0; i < Math.min(x.length, y.length); i++) if (x[i] !== y[i]) return x[i] - y[i];
  return x.length - y.length;
}

function readReceipt(file: string, suite: string): Pick<Subscriber, "version" | "peers" | "error"> {
  let r: any;
  try {
    r = JSON.parse(fs.readFileSync(file, "utf8"));
  } catch (e) {
    return { error: `${file}: not readable JSON (${(e as Error).message})` };
  }
  if (r?.suite !== suite) return { error: `${file}: names suite ${JSON.stringify(r?.suite)}, not ${suite}` };
  if (typeof r.version !== "string" || !RECEIPT_VERSION.test(r.version)) {
    return { error: `${file}: carries no vX.Y.Z version` };
  }
  const peers = r.peers;
  if (peers !== undefined) {
    const ok = peers !== null && typeof peers === "object" && !Array.isArray(peers) &&
      Object.values(peers).every((f) => typeof f === "string" && PEER_FLOOR.test(f));
    if (!ok) return { error: `${file}: "peers" must map skill names to ">=X.Y.Z" floors` };
  }
  return { version: r.version, peers };
}

/** `$FORGE_DEV_ROOT` with the shell scripts' `~/dev` default. */
function devRoot(): string {
  return process.env.FORGE_DEV_ROOT ? path.resolve(process.env.FORGE_DEV_ROOT) : path.join(os.homedir(), "dev");
}

/** A multicast scope's group: every declared root (bar `global`) whose repo dir holds
    the suite's receipt. Repo dir resolution is link.sh's — `$FORGE_DEV_ROOT/<repo>`,
    `dotfiles` the forge's own repo. Symlinked repo dirs are skipped, so a compat link
    to a real dir never renders it twice. */
function subscribers(h: Harness, scope: string, suite: string): Subscriber[] {
  const out: Subscriber[] = [];
  for (const [repo, root] of Object.entries(h.roots)) {
    if (repo === "global" || repo === scope) continue;
    const dir = repo === "dotfiles" ? repoRoot() : path.join(devRoot(), repo);
    if (!fs.existsSync(dir) || fs.lstatSync(dir).isSymbolicLink()) continue;
    const receipt = path.join(dir, ".claude", "skills", `${suite}.receipt.json`);
    if (!fs.existsSync(receipt)) continue;
    out.push({ repo, root, receipt, ...readReceipt(receipt, suite) });
  }
  return out;
}

/** One entry per election: `t` is the election itself, `placements` its N copies when
    the scope is multicast (zero when nobody subscribes) and null otherwise. */
interface Election {
  t: Target;
  placements: Target[] | null;
}

function elections(manifest: Manifest, outPrefix: string | null): Election[] {
  const out: Election[] = [];
  const base = outPrefix ?? repoRoot();
  for (const [harness, h] of Object.entries(manifest.harnesses)) {
    for (const [scope, skills] of Object.entries(h.elections)) {
      const root = h.roots[scope];
      const suite = h.multicast?.[scope];
      if (!root && !suite) throw new Error(`${harness}: scope "${scope}" has elections but no root`);
      const subs = suite ? subscribers(h, scope, suite) : [];
      for (const [skill, entry] of Object.entries(skills)) {
        const t: Target = {
          src: path.join(repoRoot(), "forge", "skills", scope, skill, entry.version),
          dest: root ? path.join(base, root, skill) : "",
          label: `${harness}/${scope}/${skill}`,
          version: entry.version,
          electionTier: entry.tier,
          tiers: h.tiers ?? {},
          defaultTier: h.defaultTier,
          toolElections: h.tools ?? {},
          toolsOpt: h.toolsOpt,
          partialElections: h.partials ?? {},
        };
        out.push({
          t,
          placements: suite
            ? subs.map((s) => ({ ...t, dest: path.join(base, s.root, skill), multicast: suite, subscriber: s }))
            : null,
        });
      }
    }
  }
  const rooted = new Map(out.filter((e) => !e.placements).map((e) => [e.t.dest, e.t.label]));
  for (const e of out) for (const p of e.placements ?? []) p.claimed = rooted.get(p.dest);
  return out;
}

/** Every election as a src -> dest pair — a multicast election as one pair per
    subscriber. `outPrefix` reroots them into a shadow tree. */
function targets(manifest: Manifest, outPrefix: string | null): Target[] {
  return elections(manifest, outPrefix).flatMap((e) => e.placements ?? [e.t]);
}

/** The name a placement is reported under — errors and held lines key on it. A
    variant placement is `<label>#<rendered name>`; an agent without variants keys on
    its label like any election. */
function placementKey(t: Target): string {
  if (t.subscriber) return `${t.label} @ ${t.subscriber.repo}`;
  if (t.agent?.variant) return `${t.label}#${t.agent.name}`;
  return t.label;
}

type Verdict = { kind: "ok" } | { kind: "held" | "error"; message: string };

/** Floor checks for one multicast placement, both directions. A bad receipt or a keg
    floor above the elected version is `error` — the manifest's fault, loud. The skill's
    `engines:` floor above the receipt's version is `held` — the repo is behind and the
    fix is a stamp, which render never performs. An unreadable cellar version or
    malformed `engines:` is `ok` here: the render of that placement reports it. */
function floorVerdict(t: Target): Verdict {
  const s = t.subscriber;
  if (!s) return { kind: "ok" };
  const at = placementKey(t);
  if (s.error !== undefined || s.version === undefined) return { kind: "error", message: `${at}: ${s.error}` };
  if (t.claimed) {
    return { kind: "error", message: `${at}: ${s.root}/${path.basename(t.dest)} is already rendered by ${t.claimed} — one election per path` };
  }
  try {
    const content = fs.readFileSync(path.join(t.src, "SKILL.md"), "utf8");
    const close = content.indexOf("\n---", 4);
    const front = content.startsWith("---\n") && close !== -1 ? content.slice(4, close) : "";
    for (const e of resolveEngineDeps(front, t)) {
      if (e.suite === t.multicast && cmpVersion(s.version, e.spec.split(">=")[1]) < 0) {
        return { kind: "held", message: `${at}: ${e.suite} is ${s.version} there, needs ${e.spec} — re-stamp` };
      }
    }
  } catch {
    return { kind: "ok" };
  }
  const floor = s.peers?.[path.basename(t.dest)];
  if (floor !== undefined && cmpVersion(t.version, floor.slice(2)) < 0) {
    return {
      kind: "error",
      message: `${at}: keg ${s.version} needs ${path.basename(t.dest)} ${floor}, elected ${t.version} — elect a newer version`,
    };
  }
  return { kind: "ok" };
}

interface ToolTarget {
  src: string;
  dest: string;
  label: string;
  version: string;
}

/** Every tool election as a src -> dest pair. Tools are code, not prompts — no tier, no lowering. */
function toolTargets(manifest: Manifest, outPrefix: string | null): ToolTarget[] {
  const out: ToolTarget[] = [];
  const base = outPrefix ?? repoRoot();
  for (const [harness, h] of Object.entries(manifest.harnesses)) {
    if (!h.tools) continue;
    if (!h.toolsRoot) throw new Error(`${harness}: has tools but no toolsRoot`);
    for (const [tool, entry] of Object.entries(h.tools)) {
      out.push({
        src: path.join(repoRoot(), "forge", "tools", tool, entry.version),
        dest: path.join(base, h.toolsRoot, tool),
        label: `${harness}/tools/${tool}`,
        version: entry.version,
      });
    }
  }
  return out;
}

const AGENT_NAME = /^[A-Za-z0-9][A-Za-z0-9_-]*$/;

/** Every agent placement as a src -> dest pair: one per variant, or one named after
    the entry when it declares none. The dest is a file — `{agentsRoot}/{name}.md`. The
    rendered name is the identity Claude Code spawns by, so it is unique across the
    whole root: two entries naming the same variant is a manifest-structure error. */
interface PartialTarget {
  /** Cellar version dir. */
  src: string;
  label: string;
  version: string;
  harness: string;
  name: string;
}

/** Every partial election. No dest — a partial is inlined into its consumers, never
    placed — so the only state it has of its own is whether the cellar version and its
    entry file exist. */
function partialTargets(manifest: Manifest): PartialTarget[] {
  const out: PartialTarget[] = [];
  for (const [harness, h] of Object.entries(manifest.harnesses)) {
    for (const [name, entry] of Object.entries(h.partials ?? {})) {
      out.push({ src: path.join(repoRoot(), "forge", "partials", name, entry.version), label: `${harness}/partials/${name}`, version: entry.version, harness, name });
    }
  }
  return out;
}

/** A partial election's own refusal, or null when its cellar entry is sound. The
    consumers' lowering refuses the same way; this is the row for a partial nobody
    includes yet. */
function partialError(p: PartialTarget): string | null {
  const file = path.join(p.src, `${p.name}.md`);
  return fs.existsSync(file) ? null : `${p.label}: elects ${p.version} but ${file} does not exist`;
}

function agentTargets(manifest: Manifest, outPrefix: string | null): Target[] {
  const out: Target[] = [];
  const base = outPrefix ?? repoRoot();
  for (const [harness, h] of Object.entries(manifest.harnesses)) {
    if (!h.agents) continue;
    if (!h.agentsRoot) throw new Error(`${harness}: has agents but no agentsRoot`);
    const seen = new Map<string, string>();
    for (const [entry, e] of Object.entries(h.agents)) {
      const label = `${harness}/agents/${entry}`;
      const variants = e.variants ?? { [entry]: {} };
      if (Object.keys(variants).length === 0) {
        throw new Error(`${label}: "variants" is empty — list the rendered names, or drop the key to render "${entry}" alone`);
      }
      for (const [name, overrides] of Object.entries(variants)) {
        if (!AGENT_NAME.test(name)) throw new Error(`${label}: variant "${name}" is not a legal agent name`);
        const prior = seen.get(name);
        if (prior) throw new Error(`${label}: variant "${name}" is already rendered by ${prior} — one agent per name`);
        seen.set(name, label);
        out.push({
          src: path.join(repoRoot(), "forge", "agents", entry, e.version),
          dest: path.join(base, h.agentsRoot, `${name}.md`),
          label,
          version: e.version,
          electionTier: overrides.tier,
          tiers: h.tiers ?? {},
          defaultTier: h.defaultTier,
          toolElections: h.tools ?? {},
          toolsOpt: h.toolsOpt,
          partialElections: h.partials ?? {},
          agent: { entry, name, overrides, variant: e.variants !== undefined },
        });
      }
    }
  }
  return out;
}

/** Agent placements grouped per election, in manifest order — the unit `--status`
    and `--json` report on. */
function agentElections(manifest: Manifest, outPrefix: string | null): { label: string; placements: Target[] }[] {
  const groups = new Map<string, Target[]>();
  for (const t of agentTargets(manifest, outPrefix)) {
    let g = groups.get(t.label);
    if (!g) groups.set(t.label, (g = []));
    g.push(t);
  }
  return [...groups].map(([label, placements]) => ({ label, placements }));
}

/** The frontmatter file a placement lowers — a skill's SKILL.md, an agent's AGENT.md. */
function sourceFile(t: Target): string {
  return t.agent ? "AGENT.md" : "SKILL.md";
}

function copyDir(src: string, dest: string): void {
  fs.mkdirSync(dest, { recursive: true });
  for (const e of fs.readdirSync(src, { withFileTypes: true })) {
    if (CELLAR_ONLY.has(e.name)) continue;
    const from = path.join(src, e.name);
    const to = path.join(dest, e.name);
    if (e.isDirectory()) copyDir(from, to);
    else fs.copyFileSync(from, to);
  }
}

/** Relative paths of every file under `dir`, sorted — the unit of comparison. */
function fileList(dir: string): string[] {
  const out: string[] = [];
  const walk = (d: string, prefix: string) => {
    for (const e of fs.readdirSync(d, { withFileTypes: true })) {
      if (CELLAR_ONLY.has(e.name)) continue;
      const rel = prefix ? `${prefix}/${e.name}` : e.name;
      if (e.isDirectory()) walk(path.join(d, e.name), rel);
      else out.push(rel);
    }
  };
  walk(dir, "");
  return out.sort();
}

/** Diff two dirs by file list then by bytes. Returns human-readable differences. */
function diffDirs(expected: string, actual: string): string[] {
  const a = fileList(expected);
  const b = fileList(actual);
  const diffs: string[] = [];
  for (const f of a) if (!b.includes(f)) diffs.push(`missing: ${f}`);
  for (const f of b) if (!a.includes(f)) diffs.push(`extra:   ${f}`);
  for (const f of a) {
    if (!b.includes(f)) continue;
    const x = fs.readFileSync(path.join(expected, f));
    const y = fs.readFileSync(path.join(actual, f));
    if (!x.equals(y)) diffs.push(`differs: ${f}`);
  }
  return diffs;
}

/** Shadow-vs-live diff for one placement: a directory diff for a skill or tool, a
    byte compare for an agent (its dest is one file). */
function diffTarget(shadow: string, t: { dest: string; agent?: unknown }): string[] {
  if (!t.agent) return diffDirs(shadow, fs.realpathSync(t.dest));
  return fs.readFileSync(shadow).equals(fs.readFileSync(t.dest)) ? [] : ["differs: " + path.basename(t.dest)];
}

/** Live state of one non-multicast placement against the shadow render. */
function liveState(t: Target, errors: Map<string, string>): "ok" | "drift" | "missing" | "error" {
  if (errors.has(placementKey(t))) return "error";
  if (!fs.existsSync(t.dest)) return "missing";
  const shadow = path.join(SHADOW, path.relative(repoRoot(), t.dest));
  return diffTarget(shadow, t).length > 0 ? "drift" : "ok";
}

interface ResolvedTier {
  /** Display form: `sota`, or `sota[fable]` when a qualifier picked a member. */
  name: string;
  binding: TierBinding;
  source: "election" | "variant" | "frontmatter" | "default";
}

// Tier resolution: election override > frontmatter `tier:` > harness defaultTier.
// A tier names a *list* of eligible engines; the unqualified name resolves to the
// first member, an election-level qualifier (`sota[fable]`) picks the member whose
// `model` matches — anything outside the list refuses to render (the list is the
// allowlist keeping qualifiers inside the tier's capability class). A qualifier in
// frontmatter is an engine leak into the cellar and refuses, like `model:` does.
function resolveTier(t: Target, fmTier: string | undefined): ResolvedTier | undefined {
  if (fmTier?.includes("[")) {
    throw new Error(
      `${t.label}: frontmatter tier "${fmTier}" carries a member qualifier — member selection is manifest dialect; declare the bare tier and qualify the election entry instead`,
    );
  }
  const raw = t.electionTier ?? fmTier ?? t.defaultTier;
  if (raw === undefined) return undefined;
  const source = t.electionTier ? (t.agent ? "variant" : "election") : fmTier ? "frontmatter" : "default";
  const m = raw.match(/^([^[\]]+)(?:\[([^[\]]+)\])?$/);
  if (!m) throw new Error(`${t.label}: malformed tier "${raw}"`);
  const [, tier, qualifier] = m;
  let members = t.tiers[tier];
  if (typeof members === "string") {
    // Deprecated-alias row: a pointer to the canonical tier, one hop only.
    const target = t.tiers[members];
    if (typeof target === "string") throw new Error(`${t.label}: tier alias "${tier}" points at another alias ("${members}") — aliases must name a member list`);
    members = target;
  }
  if (!members || members.length === 0) throw new Error(`${t.label}: tier "${tier}" not in the harness's tiers table`);
  const binding = qualifier === undefined ? members[0] : members.find((b) => b.model === qualifier);
  if (!binding) {
    throw new Error(
      `${t.label}: tier "${raw}": no eligible member with model "${qualifier}" — eligible: ${members.map((b) => b.model).join(", ")}`,
    );
  }
  return { name: qualifier === undefined ? tier : `${tier}[${qualifier}]`, binding, source };
}

interface ResolvedToolDep {
  name: string;
  version: string;
  /** Entry-point filename inside the tool version dir — the one file matching `<name>.<ext>`. */
  entry: string;
}

// Tool-dependency resolution: the version's `tools:` frontmatter list is the declared
// import surface, validated against the manifest's tool elections (a declared tool with
// no election refuses — the missing-symbol error). Entry point is by convention: exactly
// one file named `<name>.<ext>` in the elected version dir; zero or several refuses.
function resolveToolDeps(front: string, t: Target): ResolvedToolDep[] {
  const line = front.match(/^tools:[ \t]*(.*)$/m);
  if (!line) return [];
  const inline = line[1].match(/^\[([^\]]*)\][ \t]*$/);
  if (!inline) {
    throw new Error(`${t.label}: "tools:" frontmatter must be an inline list — tools: [name, name]`);
  }
  const names = inline[1].split(",").map((s) => s.trim()).filter((s) => s.length > 0);
  return names.map((name) => {
    const election = t.toolElections[name];
    if (!election) {
      throw new Error(`${t.label}: declares tool "${name}" but the manifest has no tool election for it`);
    }
    const dir = path.join(repoRoot(), "forge", "tools", name, election.version);
    if (!fs.existsSync(dir)) {
      throw new Error(`${t.label}: tool "${name}" elects ${election.version} but ${dir} does not exist`);
    }
    const entryRe = new RegExp(`^${name}\\.[A-Za-z0-9]+$`);
    const entries = fs.readdirSync(dir).filter((f) => entryRe.test(f));
    if (entries.length !== 1) {
      throw new Error(
        `${t.label}: tool "${name}" ${election.version} must have exactly one entry file named ${name}.<ext> — found ${entries.length ? entries.join(", ") : "none"}`,
      );
    }
    return { name, version: election.version, entry: entries[0] };
  });
}

interface ResolvedPartialDep {
  name: string;
  version: string;
  /** The fragment, trailing whitespace trimmed — what the body macro expands to. */
  text: string;
}

// Partial resolution: the version's `partials:` frontmatter list declares the fragments
// the body may include, validated against the manifest's partial elections the way
// `tools:` is (a declared partial with no election refuses). Entry by convention: the
// one `<name>.md` in the elected version dir. A partial is leaf text — it declares
// nothing and includes nothing, so a macro inside it refuses rather than rendering
// literally or pulling deps the consumer never declared.
function resolvePartialDeps(front: string, t: Target): ResolvedPartialDep[] {
  const line = front.match(/^partials:[ \t]*(.*)$/m);
  if (!line) return [];
  const inline = line[1].match(/^\[([^\]]*)\][ \t]*$/);
  if (!inline) {
    throw new Error(`${t.label}: "partials:" frontmatter must be an inline list — partials: [name, name]`);
  }
  const names = inline[1].split(",").map((s) => s.trim()).filter((s) => s.length > 0);
  return names.map((name) => {
    const election = t.partialElections[name];
    if (!election) {
      throw new Error(`${t.label}: declares partial "${name}" but the manifest has no partial election for it`);
    }
    const file = path.join(repoRoot(), "forge", "partials", name, election.version, `${name}.md`);
    if (!fs.existsSync(file)) {
      throw new Error(`${t.label}: partial "${name}" elects ${election.version} but ${file} does not exist`);
    }
    const text = fs.readFileSync(file, "utf8").trimEnd();
    if (/\{\{(tools|engines|partials|agent)[:}]/.test(text)) {
      throw new Error(`${t.label}: partial "${name}" ${election.version} contains a {{...}} macro — a partial is leaf text`);
    }
    return { name, version: election.version, text };
  });
}

interface ResolvedEngineDep {
  suite: string;
  /** The floor as the probe reads it — `<suite>@>=X.Y.Z`, any `v` prefix dropped. */
  spec: string;
}

// Engine resolution: the version's `engines:` frontmatter list declares the stamped
// suites the skill runs against. Nothing is elected here — the target repo's stamp
// chose its suite version and wrote the receipt — so nothing resolves to a path: the
// body macro {{engines:<suite>}} expands to the spec itself, the constraint a
// `just-probe --engine` call checks against that receipt at run time. Floors only
// (`>=`): a ceiling would be a claim about kegs not yet cut.
const ENGINE_SPEC = /^([A-Za-z0-9_.-]+)@>=v?(\d+)\.(\d+)\.(\d+)$/;
function resolveEngineDeps(front: string, t: Target): ResolvedEngineDep[] {
  const line = front.match(/^engines:[ \t]*(.*)$/m);
  if (!line) return [];
  const inline = line[1].match(/^\[([^\]]*)\][ \t]*$/);
  if (!inline) {
    throw new Error(`${t.label}: "engines:" frontmatter must be an inline list — engines: [suite@>=X.Y.Z]`);
  }
  const specs = inline[1].split(",").map((s) => s.trim()).filter((s) => s.length > 0);
  const seen = new Set<string>();
  return specs.map((raw) => {
    const m = raw.match(ENGINE_SPEC);
    if (!m) {
      throw new Error(`${t.label}: engine "${raw}" is not a floor — engines: [suite@>=X.Y.Z], floors only, never a ceiling`);
    }
    const [, suite, major, minor, patchV] = m;
    if (seen.has(suite)) throw new Error(`${t.label}: engine "${suite}" declared twice`);
    seen.add(suite);
    return { suite, spec: `${suite}@>=${major}.${minor}.${patchV}` };
  });
}

// Lowering pass: resolve the abstract capability tier to this harness's engine
// dialect and rewrite the rendered SKILL.md's frontmatter with it, plus an
// `x-forge-version:` stamp so the rendered copy names its cellar version.
//
// Resolution + qualifier semantics live in resolveTier above.
// The tier's `effort` is a default — an explicit `effort:` in the version wins.
// A concrete `model:` in the cellar is a dialect leak and refuses to render.
function lower(content: string, t: Target): string {
  if (!content.startsWith("---\n")) throw new Error(`${t.label}: ${sourceFile(t)} has no frontmatter to lower into`);
  let close = content.indexOf("\n---", 4);
  if (close === -1) throw new Error(`${t.label}: unterminated frontmatter`);
  let front = content.slice(4, close);
  if (/^model:/m.test(front)) {
    throw new Error(`${t.label}: cellar frontmatter declares "model:" — a concrete engine is harness dialect; declare "tier:" instead`);
  }
  /** Replace one `key:` line of the frontmatter in place (the empty string drops it). */
  const rewriteLine = (key: string, replacement: string): boolean => {
    const m = front.match(new RegExp(`^${key}:[ \\t]*.*$`, "m"));
    if (!m) return false;
    const start = 4 + front.indexOf(m[0]);
    content = content.slice(0, start) + replacement + content.slice(start + m[0].length + 1);
    close = content.indexOf("\n---", 4);
    front = content.slice(4, close);
    return true;
  };

  // Agent pass, frontmatter half: the rendered name is the variant's — `name:` is
  // rewritten to it (Claude Code spawns by that field, not the filename) — and the
  // variant's own `effort:` / `disallowedTools:` lines are dropped here so the
  // override can be injected below as the only copy. The overrides object is the
  // allowlist: a key render doesn't lower refuses.
  const over = t.agent?.overrides ?? {};
  if (t.agent) {
    const at = placementKey(t);
    for (const k of Object.keys(over)) {
      if (!VARIANT_KEYS.has(k)) throw new Error(`${at}: variant overrides unknown key "${k}" — tier, effort, disallowedTools`);
    }
    if (!rewriteLine("name", `name: ${t.agent.name}\n`)) throw new Error(`${at}: AGENT.md frontmatter has no "name:" line to render the variant name into`);
    if (over.effort !== undefined) rewriteLine("effort", "");
    if (over.disallowedTools !== undefined) rewriteLine("disallowedTools", "");
  }

  // Tool pass, frontmatter half: `tools:` is forge dialect, lowered away — replaced
  // in place by an `x-forge-tools:` stamp naming each dep's elected version.
  const deps = resolveToolDeps(front, t);
  const toolsLine = front.match(/^tools:[ \t]*.*$/m);
  if (toolsLine) {
    const stamp =
      deps.length > 0 ? `x-forge-tools: ${deps.map((d) => `${d.name}@${d.version}`).join(", ")}\n` : "";
    const start = 4 + front.indexOf(toolsLine[0]);
    content = content.slice(0, start) + stamp + content.slice(start + toolsLine[0].length + 1);
    close = content.indexOf("\n---", 4);
    front = content.slice(4, close);
  }

  // Partial pass, frontmatter half: `partials:` is forge dialect, lowered away —
  // replaced in place by an `x-forge-partials:` stamp naming each fragment's version.
  const partials = resolvePartialDeps(front, t);
  rewriteLine(
    "partials",
    partials.length > 0 ? `x-forge-partials: ${partials.map((d) => `${d.name}@${d.version}`).join(", ")}\n` : "",
  );

  // Engine pass, frontmatter half: `engines:` is validated and kept verbatim — no
  // x- stamp, since nothing was elected or resolved (see resolveEngineDeps).
  const engines = resolveEngineDeps(front, t);

  const fmTier = front.match(/^tier:[ \t]*(\S+)[ \t]*$/m);
  const resolved = resolveTier(t, fmTier?.[1]);

  const lines: string[] = [];
  if (resolved) {
    if (resolved.binding.model !== undefined) lines.push(`model: ${resolved.binding.model}\n`);
    if (resolved.binding.effort !== undefined && over.effort === undefined && !/^effort:/m.test(front)) lines.push(`effort: ${resolved.binding.effort}\n`);
  }
  if (over.effort !== undefined) lines.push(`effort: ${over.effort}\n`);
  if (over.disallowedTools !== undefined) lines.push(`disallowedTools: ${over.disallowedTools}\n`);
  lines.push(`x-forge-version: ${t.version}\n`);
  if (t.agent?.variant) lines.push(`x-forge-variant: ${t.agent.name}\n`);
  const injected = lines.join("");

  let out: string;
  if (fmTier) {
    // Replace the tier: line in place with the dialect fields.
    const start = 4 + front.indexOf(fmTier[0]);
    out = content.slice(0, start) + injected + content.slice(start + fmTier[0].length + 1);
  } else {
    // No tier: line to replace (election override or defaultTier on an untiered version) — inject before the closing fence.
    out = content.slice(0, close + 1) + injected + content.slice(close + 1);
  }

  // Tool pass, body half: expand each {{tools:<name>}} path macro to the opt-path of
  // the dep's entry file. Undeclared names refuse — the declaration is the allowlist.
  // \{{tools:...}} is the escape: renders as the literal macro text minus the backslash,
  // so a skill can document the syntax without invoking it.
  const ESC = "\u0000forge-tools-esc\u0000";
  out = out.replaceAll("\\{{tools:", ESC);
  const byName = new Map(deps.map((d) => [d.name, d]));
  out = out.replace(/\{\{tools:([^{}]*)\}\}/g, (_, name: string) => {
    const dep = byName.get(name);
    if (!dep) {
      throw new Error(`${t.label}: {{tools:${name}}} references a tool not declared in the version's "tools:" frontmatter`);
    }
    if (!t.toolsOpt) {
      throw new Error(`${t.label}: {{tools:${name}}} used but the harness declares no toolsOpt`);
    }
    return `${t.toolsOpt}/${dep.name}/${dep.entry}`;
  });
  if (out.includes("{{tools:")) {
    throw new Error(`${t.label}: malformed {{tools:...}} token survived expansion`);
  }
  out = out.replaceAll(ESC, "{{tools:");

  // Engine pass, body half: expand each {{engines:<suite>}} to the declared floor
  // spec. Undeclared suites refuse — the declaration is the allowlist, as for tools —
  // and \{{engines:...}} is the escape, same rule.
  const ENG_ESC = "\u0000forge-engines-esc\u0000";
  out = out.replaceAll("\\{{engines:", ENG_ESC);
  const bySuite = new Map(engines.map((e) => [e.suite, e]));
  out = out.replace(/\{\{engines:([^{}]*)\}\}/g, (_, suite: string) => {
    const eng = bySuite.get(suite);
    if (!eng) {
      throw new Error(`${t.label}: {{engines:${suite}}} references a suite not declared in the version's "engines:" frontmatter`);
    }
    return eng.spec;
  });
  if (out.includes("{{engines:")) {
    throw new Error(`${t.label}: malformed {{engines:...}} token survived expansion`);
  }
  out = out.replaceAll(ENG_ESC, "{{engines:");

  // Partial pass, body half: expand each {{partials:<name>}} to the elected fragment's
  // text, spliced where the macro stands. Undeclared names refuse — the declaration is
  // the allowlist — and \{{partials:...}} is the escape, same rule as the others.
  const PART_ESC = "\u0000forge-partials-esc\u0000";
  out = out.replaceAll("\\{{partials:", PART_ESC);
  const byPartial = new Map(partials.map((p) => [p.name, p]));
  out = out.replace(/\{\{partials:([^{}]*)\}\}/g, (_, name: string) => {
    const p = byPartial.get(name);
    if (!p) {
      throw new Error(`${t.label}: {{partials:${name}}} references a partial not declared in the version's "partials:" frontmatter`);
    }
    return p.text;
  });
  if (out.includes("{{partials:")) {
    throw new Error(`${t.label}: malformed {{partials:...}} token survived expansion`);
  }
  out = out.replaceAll(PART_ESC, "{{partials:");

  // Agent pass, body half: {{agent}} expands to the rendered name — how one body
  // attests its own variant (`tier: sota-ro`). Skills have no rendered name, so the
  // macro is agent-only; \{{agent}} is the escape, same rule as the others.
  if (t.agent) {
    const AG_ESC = "\u0000forge-agent-esc\u0000";
    out = out.replaceAll("\\{{agent}}", AG_ESC).replaceAll("{{agent}}", t.agent.name).replaceAll(AG_ESC, "{{agent}}");
  }
  return out;
}

/** root (repo-relative) → entry names render owns there: elected skills/tools plus
    any `unmanaged` names the manifest exempts. Prune deletes everything else — a
    declared root is fully render-owned. */
function ownedNames(manifest: Manifest): Map<string, Set<string>> {
  const own = new Map<string, Set<string>>();
  const names = (root: string): Set<string> => {
    let s = own.get(root);
    if (!s) own.set(root, (s = new Set()));
    return s;
  };
  for (const h of Object.values(manifest.harnesses)) {
    for (const [scope, root] of Object.entries(h.roots)) {
      const s = names(root);
      for (const n of Object.keys(h.elections[scope] ?? {})) s.add(n);
      for (const n of h.unmanaged?.[scope] ?? []) s.add(n);
    }
    if (h.toolsRoot) {
      const s = names(h.toolsRoot);
      for (const n of Object.keys(h.tools ?? {})) s.add(n);
    }
    if (h.agentsRoot) {
      const s = names(h.agentsRoot);
      for (const [entry, e] of Object.entries(h.agents ?? {})) {
        for (const n of Object.keys(e.variants ?? { [entry]: {} })) s.add(`${n}.md`);
      }
    }
  }
  // A multicast placement owns its skill name at its subscriber's root — unless held,
  // which is not rendered there, so a stale copy of it is prunable.
  for (const t of targets(manifest, null)) {
    if (t.subscriber && floorVerdict(t).kind !== "held") names(t.subscriber.root).add(path.basename(t.dest));
  }
  return own;
}

/** Repo-relative paths of entries under owned roots that no election accounts for —
    what prune deletes and what --check/--status report as orphans. */
function orphanEntries(manifest: Manifest, base: string): string[] {
  const out: string[] = [];
  for (const [root, keep] of ownedNames(manifest)) {
    const dir = path.join(base, root);
    if (!fs.existsSync(dir)) continue;
    for (const e of fs.readdirSync(dir)) if (!keep.has(e)) out.push(path.join(root, e));
  }
  return out.sort();
}

interface RenderResult {
  skills: Target[];
  tools: ToolTarget[];
  agents: Target[];
  pruned: string[];
  /** label -> refusal message. Only populated when `collect` is set — the live
      render stays fail-fast, the diagnostic modes report every broken election. */
  errors: Map<string, string>;
  /** placement key -> held message. A held placement is not rendered and is no error. */
  held: Map<string, string>;
}

/** `collect` turns per-election refusals into rows instead of an abort: one broken
    election degrades to one error row rather than bricking every read surface.
    Manifest-*structure* errors (a scope with elections but no root, unreadable JSON)
    still throw in every mode — there is no election row to attach them to. */
function render(outPrefix: string | null, collect = false): RenderResult {
  const manifest = readManifest();
  const base = outPrefix ?? repoRoot();
  // A declared root is render-owned even before its first election — materialize
  // empty ones so link.sh can bootstrap a freshly declared scope.
  for (const h of Object.values(manifest.harnesses)) {
    for (const root of Object.values(h.roots)) fs.mkdirSync(path.join(base, root), { recursive: true });
    if (h.agentsRoot) fs.mkdirSync(path.join(base, h.agentsRoot), { recursive: true });
  }
  const errors = new Map<string, string>();
  const attempt = (label: string, fn: () => void): void => {
    try {
      fn();
    } catch (e) {
      if (!collect) throw e;
      errors.set(label, (e as Error).message);
    }
  };
  const held = new Map<string, string>();
  const list = targets(manifest, outPrefix);
  for (const t of list) {
    attempt(placementKey(t), () => {
      if (!fs.existsSync(t.src)) {
        throw new Error(`${t.label}: elects ${t.version} but the cellar version dir ${t.src} does not exist`);
      }
      const verdict = floorVerdict(t);
      if (verdict.kind === "error") throw new Error(verdict.message);
      if (verdict.kind === "held") {
        held.set(placementKey(t), verdict.message);
        console.error(verdict.message);
        return;
      }
      fs.rmSync(t.dest, { recursive: true, force: true });
      copyDir(t.src, t.dest);
      const skillMd = path.join(t.dest, "SKILL.md");
      if (!fs.existsSync(skillMd)) throw new Error(`${t.label}: version has no SKILL.md`);
      fs.writeFileSync(skillMd, lower(fs.readFileSync(skillMd, "utf8"), t));
    });
  }
  // Tool pass: byte-identical copy plus a `.forge-version` sidecar naming the elected
  // version. No SKILL.md requirement, no lowering — tools are code, not prompts.
  const tools = toolTargets(manifest, outPrefix);
  for (const t of tools) {
    attempt(t.label, () => {
      if (!fs.existsSync(t.src)) {
        throw new Error(`${t.label}: elects ${t.version} but the cellar version dir ${t.src} does not exist`);
      }
      fs.rmSync(t.dest, { recursive: true, force: true });
      copyDir(t.src, t.dest);
      fs.writeFileSync(path.join(t.dest, ".forge-version"), t.version);
    });
  }
  // Agent pass: one lowered file per placement — the version's AGENT.md, written as
  // `{agentsRoot}/{rendered name}.md`. Same lowering as a skill plus the variant's
  // overrides; nothing else in the version dir is copied (an agent is one file).
  const agents = agentTargets(manifest, outPrefix);
  for (const t of agents) {
    attempt(placementKey(t), () => {
      if (!fs.existsSync(t.src)) {
        throw new Error(`${t.label}: elects ${t.version} but the cellar version dir ${t.src} does not exist`);
      }
      const src = path.join(t.src, "AGENT.md");
      if (!fs.existsSync(src)) throw new Error(`${t.label}: version has no AGENT.md`);
      fs.rmSync(t.dest, { recursive: true, force: true });
      fs.writeFileSync(t.dest, lower(fs.readFileSync(src, "utf8"), t));
    });
  }
  // Prune pass: a declared root is fully render-owned — anything left there that no
  // election accounts for (a retired election, a hand-placed dir) is deleted, so the
  // bin trees never outlive the manifest. `unmanaged` in the manifest is the opt-out.
  const pruned: string[] = [];
  for (const o of orphanEntries(manifest, base)) {
    fs.rmSync(path.join(base, o), { recursive: true, force: true });
    pruned.push(o);
  }
  return { skills: list, tools, agents, pruned, errors, held };
}

function check(): void {
  const manifest = readManifest();
  fs.rmSync(SHADOW, { recursive: true, force: true });
  const { errors, held } = render(SHADOW, true);

  let failures = 0;
  for (const t of targets(manifest, null)) {
    const key = placementKey(t);
    const broken = errors.get(key);
    if (broken) {
      console.error(broken);
      failures++;
      continue;
    }
    // Held is a repo-side state (the fix is a stamp, not a manifest edit) — not a failure.
    if (held.has(key)) continue;
    const shadow = path.join(SHADOW, path.relative(repoRoot(), t.dest));
    if (!fs.existsSync(t.dest)) {
      console.error(`${key}: no live entry to compare against`);
      failures++;
      continue;
    }
    // Directory-vs-directory byte diff: the freshly rendered shadow dir is the
    // expected side, the live bin-tree dir Claude Code loads is the actual one.
    const diffs = diffDirs(shadow, fs.realpathSync(t.dest));
    if (diffs.length > 0) {
      console.error(`${key}:`);
      for (const d of diffs) console.error(`  ${d}`);
      failures++;
    }
  }

  for (const t of toolTargets(manifest, null)) {
    const broken = errors.get(t.label);
    if (broken) {
      console.error(broken);
      failures++;
      continue;
    }
    const shadow = path.join(SHADOW, path.relative(repoRoot(), t.dest));
    if (!fs.existsSync(t.dest)) {
      console.error(`${t.label}: no live entry to compare against`);
      failures++;
      continue;
    }
    const diffs = diffDirs(shadow, fs.realpathSync(t.dest));
    if (diffs.length > 0) {
      console.error(`${t.label}:`);
      for (const d of diffs) console.error(`  ${d}`);
      failures++;
    }
  }

  // Agent placements: one file each, byte-compared.
  for (const t of agentTargets(manifest, null)) {
    const key = placementKey(t);
    const broken = errors.get(key);
    if (broken) {
      console.error(broken);
      failures++;
      continue;
    }
    if (!fs.existsSync(t.dest)) {
      console.error(`${key}: no live entry to compare against`);
      failures++;
      continue;
    }
    const diffs = diffTarget(path.join(SHADOW, path.relative(repoRoot(), t.dest)), t);
    if (diffs.length > 0) {
      console.error(`${key}:`);
      for (const d of diffs) console.error(`  ${d}`);
      failures++;
    }
  }

  // Orphans are drift too: the live tree holds entries the manifest no longer
  // accounts for. Render deletes them; until then the trees don't match the manifest.
  const orphaned = orphanEntries(manifest, repoRoot());
  for (const o of orphaned) console.error(`orphan: ${o} — nothing elects here; next render deletes it`);

  for (const p of partialTargets(manifest)) {
    const broken = partialError(p);
    if (broken) {
      console.error(broken);
      failures++;
    }
  }

  const total =
    targets(manifest, null).length +
    Object.values(manifest.harnesses).reduce((n, h) => n + Object.keys(h.tools ?? {}).length, 0) +
    partialTargets(manifest).length +
    agentTargets(manifest, null).length;

  if (failures > 0 || orphaned.length > 0) {
    const parts: string[] = [];
    if (failures > 0) parts.push(`${failures} of ${total} elections differ`);
    if (orphaned.length > 0) parts.push(`${orphaned.length} orphan entr${orphaned.length === 1 ? "y" : "ies"}`);
    console.error(`\n${parts.join(", ")} — render does not reproduce the live tree`);
    process.exit(1);
  }
  console.log(`${total}/${total} elections render byte-identical to the live bin trees`);
  console.log(`shadow tree: ${path.relative(repoRoot(), SHADOW)}`);
}

/** Live state of one multicast placement. `error` and `held` come from the render;
    the rest from diffing the shadow against the live tree, as for any election. */
function placementLive(t: Target, errors: Map<string, string>, held: Map<string, string>): string {
  const key = placementKey(t);
  if (errors.has(key)) return "error";
  if (held.has(key)) return "held";
  if (!fs.existsSync(t.dest)) return "missing";
  const shadow = path.join(SHADOW, path.relative(repoRoot(), t.dest));
  return diffDirs(shadow, fs.realpathSync(t.dest)).length > 0 ? "drift" : "ok";
}

/** A multicast election's LIVE is its worst placement; no placement at all is `nosub`. */
function aggregateLive(states: string[]): string {
  if (states.length === 0) return "nosub";
  return ["error", "drift", "missing", "held", "ok"].find((s) => states.includes(s))!;
}

/** Repos holding a multicast suite's receipt that have no declared root — not
    subscribers, so no row; narration only. Same listing discover.sh reads: git repos one
    level under the dev root, symlinks skipped. */
function undeclaredReceipts(manifest: Manifest): string[] {
  const out: string[] = [];
  const dev = devRoot();
  if (!fs.existsSync(dev)) return out;
  for (const h of Object.values(manifest.harnesses)) {
    for (const suite of new Set(Object.values(h.multicast ?? {}))) {
      for (const e of fs.readdirSync(dev, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
        if (!e.isDirectory() || h.roots[e.name] !== undefined) continue;
        const dir = path.join(dev, e.name);
        if (!fs.existsSync(path.join(dir, ".git")) || !fs.existsSync(path.join(dir, ".claude", "skills", `${suite}.receipt.json`))) continue;
        out.push(`${e.name} carries a ${suite} receipt but no root — just forge discover-exact ${e.name} to subscribe`);
      }
    }
  }
  return out;
}

/** One agent placement's resolved dialect — what `--status` and `--json` project.
    Throws like `resolveTier` does; callers collect. */
function agentResolution(t: Target) {
  const content = fs.readFileSync(path.join(t.src, "AGENT.md"), "utf8");
  const close = content.indexOf("\n---", 4);
  const front = content.startsWith("---\n") && close !== -1 ? content.slice(4, close) : "";
  const fmTier = front.match(/^tier:[ \t]*(\S+)[ \t]*$/m)?.[1];
  const fmEffort = front.match(/^effort:[ \t]*(\S+)[ \t]*$/m)?.[1];
  const fmTools = front.match(/^disallowedTools:[ \t]*(.*)$/m)?.[1];
  const over = t.agent!.overrides;
  const resolved = resolveTier(t, fmTier);
  const effort = over.effort ?? fmEffort ?? resolved?.binding.effort ?? null;
  return {
    name: t.agent!.name,
    tier: resolved?.name ?? null,
    tierSource: resolved?.source ?? null,
    model: resolved?.binding.model ?? null,
    effort,
    effortSource: over.effort !== undefined ? "variant" : fmEffort !== undefined ? "frontmatter" : effort !== null ? "tier" : null,
    disallowedTools: over.disallowedTools ?? fmTools ?? null,
    tools: resolveToolDeps(front, t),
    partials: resolvePartialDeps(front, t).map(({ name, version }) => ({ name, version })),
  };
}

// Newest non-yanked cellar version ahead of the elected one, or null when the
// election is already at the cellar's electable frontier. Derivable without a
// lowering, so broken elections report it too — the recovery path needs a
// good version to name.
function newerVersion(cellar: string, elected: string): string | null {
  if (!fs.existsSync(cellar)) return null;
  const cmp = (a: string, b: string) => a.localeCompare(b, undefined, { numeric: true });
  const newest = fs
    .readdirSync(cellar, { withFileTypes: true })
    .filter((e) => e.isDirectory() && !fs.existsSync(path.join(cellar, e.name, ".yanked")))
    .map((e) => e.name)
    .sort(cmp)
    .at(-1);
  return newest !== undefined && cmp(newest, elected) > 0 ? newest : null;
}

// Projection of the manifest joined with each elected version's frontmatter:
// what tier every election resolves to, where that tier came from
// (election / frontmatter / default), and what it lowers to. The LIVE column
// diffs a shadow render against the live bin tree (ok / drift / missing), so a
// manifest edit shows as drift until the next render. The NEWER column names
// the newest non-yanked cellar version when it is ahead of the elected one.
// Writes only to scratch.
function status(): void {
  fs.rmSync(SHADOW, { recursive: true, force: true });
  const { errors, held } = render(SHADOW, true);
  const manifest = readManifest();
  const rows: string[][] = [["ELECTION", "VERSION", "NEWER", "TIER", "SOURCE", "MODEL", "EFFORT", "LIVE"]];
  for (const { t, placements } of elections(manifest, null)) {
    const newer = newerVersion(path.dirname(t.src), t.version) ?? "-";
    const broken = errors.get(t.label);
    if (broken) {
      rows.push([t.label, t.version, newer, "-", "-", "-", "-", "error"]);
      continue;
    }
    // The projection resolves the tier itself, so it can refuse independently of the
    // render above — collected the same way rather than aborting the table.
    let resolved: ResolvedTier | undefined;
    let fmEffort: string | undefined;
    try {
      const content = fs.readFileSync(path.join(t.src, "SKILL.md"), "utf8");
      const close = content.indexOf("\n---", 4);
      const front = content.startsWith("---\n") && close !== -1 ? content.slice(4, close) : "";
      const fmTier = front.match(/^tier:[ \t]*(\S+)[ \t]*$/m)?.[1];
      fmEffort = front.match(/^effort:[ \t]*(\S+)[ \t]*$/m)?.[1];
      resolved = resolveTier(t, fmTier);
    } catch (e) {
      errors.set(t.label, (e as Error).message);
      rows.push([t.label, t.version, newer, "-", "-", "-", "-", "error"]);
      continue;
    }
    // A multicast election's row is its worst placement, with one indented row under
    // it per subscriber; its own dest is empty, so it is never diffed.
    const states = placements?.map((p) => placementLive(p, errors, held));
    const shadow = path.join(SHADOW, path.relative(repoRoot(), t.dest));
    const live = states
      ? aggregateLive(states)
      : !fs.existsSync(t.dest)
        ? "missing"
        : diffDirs(shadow, fs.realpathSync(t.dest)).length > 0
          ? "drift"
          : "ok";
    rows.push([
      t.label,
      t.version,
      newer,
      resolved?.name ?? "-",
      resolved?.source ?? "-",
      resolved?.binding.model ?? "-",
      fmEffort !== undefined ? `${fmEffort} (frontmatter)` : resolved?.binding.effort ?? "-",
      live,
    ]);
    placements?.forEach((p, i) => rows.push([`  @${p.subscriber!.repo}`, p.subscriber!.version ?? "-", "-", "-", "-", "-", "-", states![i]]));
  }
  // Tool elections: no tier/lowering, so the dialect columns are structurally empty.
  for (const t of toolTargets(manifest, null)) {
    const newer = newerVersion(path.dirname(t.src), t.version) ?? "-";
    if (errors.has(t.label)) {
      rows.push([t.label, t.version, newer, "-", "-", "-", "-", "error"]);
      continue;
    }
    const shadow = path.join(SHADOW, path.relative(repoRoot(), t.dest));
    const live = !fs.existsSync(t.dest)
      ? "missing"
      : diffDirs(shadow, fs.realpathSync(t.dest)).length > 0
        ? "drift"
        : "ok";
    rows.push([t.label, t.version, newer, "-", "-", "-", "-", live]);
  }
  // Partial elections: inlined, never placed — there is no bin tree to diff, so LIVE
  // is the cellar entry's soundness (`ok` / `error`); a broken partial also surfaces as
  // `error` on every consumer that declares it. Dialect columns are structurally empty.
  for (const p of partialTargets(manifest)) {
    const newer = newerVersion(path.dirname(p.src), p.version) ?? "-";
    const broken = partialError(p);
    if (broken) errors.set(p.label, broken);
    rows.push([p.label, p.version, newer, "-", "-", "-", "-", broken ? "error" : "ok"]);
  }
  // Agent elections: an entry without variants is one row like a skill's; an entry
  // with variants is a parent row (version, aggregate LIVE) and one indented
  // `  #<rendered name>` row per variant carrying that variant's lowering.
  for (const { label, placements } of agentElections(manifest, null)) {
    const t0 = placements[0];
    const newer = newerVersion(path.dirname(t0.src), t0.version) ?? "-";
    const variant = t0.agent!.variant;
    const resolvedRows = placements.map((p) => {
      const key = placementKey(p);
      if (errors.has(key)) return { cols: ["-", "-", "-", "-"], live: "error" };
      try {
        const r = agentResolution(p);
        return { cols: [r.tier ?? "-", r.tierSource ?? "-", r.model ?? "-", r.effort !== null ? `${r.effort} (${r.effortSource})` : "-"], live: liveState(p, errors) };
      } catch (e) {
        errors.set(key, (e as Error).message);
        return { cols: ["-", "-", "-", "-"], live: "error" };
      }
    });
    if (!variant) {
      rows.push([label, t0.version, newer, ...resolvedRows[0].cols, resolvedRows[0].live]);
      continue;
    }
    rows.push([label, t0.version, newer, "-", "-", "-", "-", aggregateLive(resolvedRows.map((r) => r.live))]);
    placements.forEach((p, i) => rows.push([`  #${p.agent!.name}`, "-", "-", ...resolvedRows[i].cols, resolvedRows[i].live]));
  }
  // Orphans: live entries no election accounts for. Labeled by repo-relative path —
  // they are a filesystem fact, not an election, so there is no label to copy.
  for (const o of orphanEntries(manifest, repoRoot())) {
    rows.push([o, "-", "-", "-", "-", "-", "-", "orphan"]);
  }
  const widths = rows[0].map((_, i) => Math.max(...rows.map((r) => r[i].length)));
  for (const r of rows) console.log(r.map((c, i) => c.padEnd(widths[i])).join("  ").trimEnd());
  // Errors travel in-band: the table is the read surface, and its consumers run under
  // `set -euo pipefail`, so a broken election must not take the exit code with it.
  for (const message of errors.values()) console.error(message);
  for (const line of undeclaredReceipts(manifest)) console.error(line);
}

// JSON projection of the same model status() prints — one object per election with
// the resolved tier flattened into columns — plus what status doesn't compute: the
// cellar's available versions per election (yanked ones listed separately, from the
// `.yanked` sentinel) and the resolved tool edges. The machine-readable surface for
// external viewers and pickers; like --status, writes only to scratch.
function jsonDump(): void {
  fs.rmSync(SHADOW, { recursive: true, force: true });
  const { errors, held } = render(SHADOW, true);
  const manifest = readManifest();
  const live = (dest: string): "ok" | "drift" | "missing" => {
    if (!fs.existsSync(dest)) return "missing";
    const shadow = path.join(SHADOW, path.relative(repoRoot(), dest));
    return diffDirs(shadow, fs.realpathSync(dest)).length > 0 ? "drift" : "ok";
  };
  // Derivable without a successful lowering, so a broken election still reports its
  // available versions — the recovery path needs them to name a good one.
  const cellarVersions = (dir: string): string[] =>
    !fs.existsSync(dir)
      ? []
      : fs
          .readdirSync(dir, { withFileTypes: true })
          .filter((e) => e.isDirectory())
          .map((e) => e.name)
          .sort((a, b) => a.localeCompare(b, undefined, { numeric: true }));
  const skills = elections(manifest, null).map(({ t, placements }) => {
    const [harness, scope, name] = t.label.split("/");
    const cellar = path.dirname(t.src);
    const versions = cellarVersions(cellar);
    // Identity fields resolve without a lowering; the dialect fields are null when
    // the election refuses, and `error` carries the refusal. This is what keeps
    // elect-core/yank-core/move-core usable with a broken election in the manifest.
    const base = {
      harness,
      scope,
      name,
      label: t.label,
      version: t.version,
      versions,
      yanked: versions.filter((v) => fs.existsSync(path.join(cellar, v, ".yanked"))),
    };
    const nulled = { tier: null, tierSource: null, model: null, effort: null, effortSource: null, tools: [], partials: [], engines: [] };
    // A multicast election gains its suite and one entry per subscriber; its own `live`
    // is the aggregate. Non-multicast objects carry none of it.
    const states = placements?.map((p) => placementLive(p, errors, held));
    const multicast = placements
      ? {
          multicast: placements[0]?.multicast ?? manifest.harnesses[harness].multicast![scope],
          subscribers: placements.map((p, i) => ({
            repo: p.subscriber!.repo,
            root: p.subscriber!.root,
            receipt: p.subscriber!.receipt,
            live: states![i],
            error: errors.get(placementKey(p)) ?? null,
          })),
        }
      : {};
    const broken = errors.get(t.label);
    if (broken) return { ...base, ...nulled, live: "error", error: broken, ...multicast };
    try {
      const content = fs.readFileSync(path.join(t.src, "SKILL.md"), "utf8");
      const close = content.indexOf("\n---", 4);
      const front = content.startsWith("---\n") && close !== -1 ? content.slice(4, close) : "";
      const fmTier = front.match(/^tier:[ \t]*(\S+)[ \t]*$/m)?.[1];
      const fmEffort = front.match(/^effort:[ \t]*(\S+)[ \t]*$/m)?.[1];
      const resolved = resolveTier(t, fmTier);
      return {
        ...base,
        tier: resolved?.name ?? null,
        tierSource: resolved?.source ?? null,
        model: resolved?.binding.model ?? null,
        effort: fmEffort ?? resolved?.binding.effort ?? null,
        effortSource: fmEffort !== undefined ? "frontmatter" : resolved?.binding.effort !== undefined ? "tier" : null,
        tools: resolveToolDeps(front, t),
        partials: resolvePartialDeps(front, t).map(({ name, version }) => ({ name, version })),
        engines: resolveEngineDeps(front, t),
        live: states ? aggregateLive(states) : live(t.dest),
        error: null,
        ...multicast,
      };
    } catch (e) {
      const message = (e as Error).message;
      errors.set(t.label, message);
      return { ...base, ...nulled, live: "error", error: message, ...multicast };
    }
  });
  const tools = toolTargets(manifest, null).map((t) => {
    const [harness, , name] = t.label.split("/");
    const cellar = path.dirname(t.src);
    const versions = cellarVersions(cellar);
    return {
      harness,
      name,
      label: t.label,
      version: t.version,
      versions,
      yanked: versions.filter((v) => fs.existsSync(path.join(cellar, v, ".yanked"))),
      live: errors.has(t.label) ? "error" : live(t.dest),
      error: errors.get(t.label) ?? null,
    };
  });
  // Agent elections: identity fields plus one `variants` object per rendered name —
  // an entry without variants has exactly one, named after the entry. `live` and
  // `error` at the election level aggregate the variants'.
  const agents = agentElections(manifest, null).map(({ label, placements }) => {
    const t0 = placements[0];
    const [harness, , name] = label.split("/");
    const cellar = path.dirname(t0.src);
    const versions = cellarVersions(cellar);
    const variants = placements.map((p) => {
      const key = placementKey(p);
      const nulled = { name: p.agent!.name, tier: null, tierSource: null, model: null, effort: null, effortSource: null, disallowedTools: null, tools: [], partials: [] };
      if (errors.has(key)) return { ...nulled, live: "error", error: errors.get(key) };
      try {
        return { ...agentResolution(p), live: liveState(p, errors), error: null };
      } catch (e) {
        errors.set(key, (e as Error).message);
        return { ...nulled, live: "error", error: (e as Error).message };
      }
    });
    return {
      harness,
      name,
      label,
      version: t0.version,
      versions,
      yanked: versions.filter((v) => fs.existsSync(path.join(cellar, v, ".yanked"))),
      variant: t0.agent!.variant,
      live: aggregateLive(variants.map((v) => v.live)),
      error: variants.find((v) => v.error)?.error ?? null,
      variants,
    };
  });
  // Partial elections: identity fields plus `consumers` — the labels of every skill and
  // agent election whose version declares the partial — since a fragment's live state
  // is its consumers'. The reverse index `show` prints; the forward edge is each
  // consumer's `partials` list.
  const partials = partialTargets(manifest).map((p) => {
    const cellar = path.dirname(p.src);
    const versions = cellarVersions(cellar);
    const broken = partialError(p);
    const consumers = [
      ...skills.filter((s) => s.partials.some((x) => x.name === p.name)).map((s) => s.label),
      ...agents.filter((a) => a.variants.some((v) => v.partials.some((x) => x.name === p.name))).map((a) => a.label),
    ];
    return {
      harness: p.harness,
      name: p.name,
      label: p.label,
      version: p.version,
      versions,
      yanked: versions.filter((v) => fs.existsSync(path.join(cellar, v, ".yanked"))),
      live: broken ? "error" : "ok",
      error: broken,
      consumers,
    };
  });
  // Scope axis, per harness: every legal move destination as {name, root} — rooted
  // scopes from the roots map (root = where elections there render), cellar scope
  // dirs and keg-only with root null. Serves move-core.sh/move.sh their candidate
  // lists, so scopes resolve from the dump like labels and versions do. A multicast
  // scope has root null and names its suite — a legal destination, rendered per subscriber.
  const cellarScopes = fs
    .readdirSync(path.join(repoRoot(), "forge", "skills"), { withFileTypes: true })
    .filter((e) => e.isDirectory())
    .map((e) => e.name);
  const scopes: Record<string, { name: string; root: string | null; multicast?: string }[]> = {};
  for (const [harness, h] of Object.entries(manifest.harnesses)) {
    const names = new Set(["keg-only", ...Object.keys(h.roots), ...Object.keys(h.multicast ?? {}), ...cellarScopes]);
    scopes[harness] = [...names].sort().map((name) =>
      h.multicast?.[name] ? { name, root: null, multicast: h.multicast[name] } : { name, root: h.roots[name] ?? null },
    );
  }
  console.log(JSON.stringify({ skills, tools, partials, agents, scopes }, null, 2));
}

function main() {
  if (process.argv.includes("--json")) {
    jsonDump();
    return;
  }
  if (process.argv.includes("--status")) {
    status();
    return;
  }
  if (process.argv.includes("--check")) {
    check();
    return;
  }
  const outIdx = process.argv.indexOf("--out");
  const outPrefix = outIdx !== -1 ? path.resolve(process.argv[outIdx + 1]) : null;
  const { skills: placed, tools, agents, pruned, held } = render(outPrefix);
  const skills = placed.filter((t) => !held.has(placementKey(t)));
  for (const t of [...skills, ...tools, ...agents]) console.log(path.relative(outPrefix ?? repoRoot(), t.dest));
  for (const o of pruned) console.log(`pruned: ${o}`);
  console.log(
    `${skills.length} elections + ${tools.length} tools + ${agents.length} agents rendered${pruned.length ? `, ${pruned.length} pruned` : ""}${outPrefix ? ` into ${outPrefix}` : ""}`,
  );
}

main();
