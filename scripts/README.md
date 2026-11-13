# forge/scripts/

The live renderer plus its front ends. `render.ts` reads the election manifest
(`../elections.json` — declares which cellar version each harness/scope gets, where
it renders, and the harness's dialect bindings) and writes the bin trees out of the
cellar; `view.sh` is a
read-only fzf viewer over its `--json` output, and `elect-core.sh` is the write twin —
it edits the manifest (nothing else) and re-renders. `elect.sh` wraps that engine in
fzf pickers. `move-core.sh` is the scope-move engine — the one write path that *does*
touch the cellar, a `git mv` between scope dirs — with `move.sh` its fzf front end and
`retire.sh` the same front end pinned to the keg-only destination.
`verbs.sh` is the lexicon's human render — the short twin of `just --list forge`.
`link.sh` is the one-time bootstrap for repo-targeted scopes, and
`discover-core.sh` the onboarding engine that composes root declaration + render +
link (with `discover.sh` its fzf front end scanning `$FORGE_DEV_ROOT`).
Everything the legacy symlink machinery used to do is on the `archive/forge-legacy`
branch — [../README.md § History](../README.md#history).

Interactivity is layered, not branched: the engine is always non-interactive and the
picker is a thin resolution step in front of it, so scripted and interactive elections
share one write path. Anything that must run unattended calls `elect-core.sh`.

For the cellar/render model this implements, see [`../README.md`](../README.md).

## `init.sh`

The rare book. Scaffolds a descendant around this engine, once, before `just forge`
exists in the new repo — so it is run directly: `bash forge/engine/scripts/init.sh`
(the `init` recipe is the same script for an engine already mounted). Target is
`$FORGE_ROOT`, else the engine's grandparent (the engine must sit at
`<descendant>/forge/engine/`). Checks the prerequisites (bun, just, jq, fzf, python3),
refuses an existing `forge/elections.json`, copies `../examples/descendant/` in without
overwriting anything that exists (a kept file is reported with the template to merge
from), rewrites the copied manifest's `engine` pin from `../VERSION`, runs `bun install`
in the engine and a first render. Writes nothing outside the descendant — linking
`~/.claude/*` at the bin trees is the operator's step, printed as the next action.

## `render.ts`

Manifest → bin tree. For every skill election it resolves
`forge/skills/{scope}/{skill}/{version}` as source and `{root}/{skill}` as destination
(the root comes from the harness's `roots` map), removes the destination, and copies the
version directory in. Output is disposable — delete a bin tree, re-run, get it back
byte-identical.

| Mode | Behavior |
|---|---|
| `just forge render` | Renders every election into the live bin trees and prints one path per election. Also materializes every declared root, so a freshly declared zero-election scope gets its (empty) root dir. |
| `just forge render --check` | Drift gate. Renders into a throwaway shadow tree (`forge/scratch/render-check/`), then byte-diffs each election's live directory against its shadow. Reports `missing:` / `extra:` / `differs:` per file and exits non-zero on any mismatch — catches a hand-edited bin tree or a manifest pointing at a version that no longer exists. |
| `just forge render --out <dir>` | Renders into an alternate prefix instead of the live bin trees — every election's output root is rerooted under `<dir>`. This is the mechanism `--check` uses internally. |
| `just forge render --manifest <path>` | Reads the election manifest from `<path>` instead of `forge/elections.json`. Cellar sources and output roots still resolve against the repo root — only the manifest is substituted. Composes with `--out` to shadow-render a candidate manifest, which is how `elect-core.sh` validates before it commits. |
| `just forge status` (= `render --status`) | Resolution table, one row per election: version, a NEWER column naming the newest non-yanked cellar version when it is ahead of the elected one (`-` otherwise), resolved tier, tier source (`election` / `frontmatter` / `default`), lowered model/effort, and a LIVE column (`ok` / `drift` / `missing`) diffing a shadow render against the live bin tree — so a manifest edit reads as `drift` until the next render. Touches only the scratch shadow tree, never the bin trees. A multicast election adds `held` / `nosub` states and one row per subscriber — [§ Multicast](#multicast). |
| `just forge render --json` | The `--status` model as JSON, plus per-election data the table doesn't carry: every version available in the cellar (`versions`, with `yanked` listed separately from the `.yanked` sentinel) and the resolved tool edges (`tools`, from the version's `tools:` frontmatter), partial edges (`partials`, each `{name, version}`) and declared engine floors (`engines`, from its `engines:` frontmatter, each `{suite, spec}`). One object per skill election, per tool election, per partial election (identity, versions, `live` as the cellar entry's soundness, and `consumers` — the labels of every skill and agent election that declares it) and per agent election (the agent object carries `variant: bool` and a `variants` array — one `{name, tier, tierSource, model, effort, effortSource, disallowedTools, tools, live, error}` per rendered name; its own `live`/`error` aggregate them), plus a per-harness `scopes` array — every legal move destination as `{name, root}` (root `null` for keg-only and rootless scopes; a multicast scope's shape is in [§ Multicast](#multicast)) — so labels, versions, and scopes all resolve from the one dump. The machine-readable surface for external viewers/pickers; like `--status`, writes only to scratch. |

The live render (`render`, `--out`) is fail-fast: the first refusing election aborts the
pass. The diagnostic modes (`--status`, `--json`, `--check`) fail-*collect* instead —
a broken election degrades to one `error` row (`error` in the LIVE column, an `error`
string in the JSON object) while every other election still reports, so one bad version
string cannot brick the read surfaces the recovery engines depend on. `--status` and
`--json` exit 0 with errors present (their consumers run under `set -euo pipefail`, so
errors travel in-band); `--check` counts each broken election as a failure and exits
non-zero. Manifest-*structure* errors — a scope with elections but neither a root nor a
`multicast` entry, unreadable JSON — stay fail-fast in every mode, since there is no election row to attach them to.

### Lowering

After copying, `render.ts` rewrites the destination `SKILL.md` frontmatter: it resolves
the tier (election override → frontmatter `tier:` → harness `defaultTier`), lowers it to
the harness's `model`/`effort` dialect from the manifest's `tiers` table — each tier row
is a list of eligible engines, first member the default, an election-level qualifier
(`sota[fable]`) selecting another member by model name; a row may instead be a string
naming another tier (a deprecated alias, dereferenced one hop) — replacing the
version's `tier:` line in place when it has one, injecting the fields before the closing
fence when it doesn't (election override or `defaultTier` on an untiered version) —
keeps an explicit `effort:` in the version, and throws on a cellar `model:`, a qualifier
outside the tier's list, a qualifier in frontmatter (manifest-only dialect), or a version
with no `SKILL.md`. It also stamps `x-forge-version: <version>` into the rendered
frontmatter — the rendered copy names its cellar version, since the bin-tree path
(unlike a Homebrew keg path) doesn't carry it.

### Tool pass

After the skill elections, `render.ts` renders each entry of the manifest's per-harness
`tools` section: `forge/tools/{name}/{version}` copies to `{toolsRoot}/{name}` (the
stable versionless path consumers reference), plus a `.forge-version` sidecar file
containing the elected version string. Tools are code, not prompts — no SKILL.md
requirement, no lowering, no frontmatter stamping; the copied files stay byte-identical
to the cellar, and the sidecar alone names the version. `--check` and `--status` cover
tool elections the same way as skill elections (`--status` shows `-` in the
tier/source/model/effort columns).

### Agent pass

After the tool pass, `render.ts` renders each entry of the manifest's per-harness
`agents` section: `forge/agents/{name}/{version}/AGENT.md` lowers to
`{agentsRoot}/{rendered name}.md` — one file per **variant**, or one named after the
entry when it declares none. A variant is a named override set laid over the
frontmatter (`tier`, `effort`, `disallowedTools`; any other key refuses): the tier
resolves variant → frontmatter → `defaultTier` like a skill's election override and
lowers through the same `tiers` table; a variant `effort` replaces the version's own;
`disallowedTools` is injected verbatim. `name:` is rewritten to the rendered name
(Claude Code spawns by that field — refuses when the version has none), `{{agent}}` in
the body expands to it (`\{{agent}}` escapes), and an `x-forge-variant: <name>` stamp
joins `x-forge-version` when the entry declares variants. `variants`, when present,
is the complete rendered set — the entry's own name renders only if listed; rendered
names are unique across the root (manifest-structure error otherwise). The placement
key for errors is `<label>#<name>`; `--status` prints a variant entry as a parent row
(version, aggregate LIVE) plus one `  #<name>` row per variant, a plain entry as one
row; `--check` byte-compares each file; prune owns `<name>.md` per rendered name.

### Engine pass

The lowering pass's third rewrite, and the one that resolves to nothing. A version's
`engines:` frontmatter (`engines: [sssf-suite@>=1.25.0]`, an inline list of floors)
names the stamped suites it runs against; each `{{engines:<suite>}}` in the body expands
to the declared spec (`sssf-suite@>=1.25.0`), the constraint a `{{tools:just-probe}}
--engine` call checks against the target repo's receipt at run time. The frontmatter
line renders verbatim — no `x-` stamp, since nothing was elected or resolved: the
target's stamp chose the suite version. Refuses a non-inline list, a spec that is not
`<suite>@>=X.Y.Z` (a ceiling, a bare version), a suite declared twice, or an undeclared
macro; a declared engine with no macro is allowed, like a tool. `\{{engines:…}}` is the
escape, as for tools. `--json` carries the floors as `engines`, where `edges.sh` reads
them.

### Partial pass

The lowering pass's fourth rewrite, and the one that resolves to text. A version's
`partials:` frontmatter (`partials: [house-style]`, an inline list) names the shared
fragments its body includes; each `{{partials:<name>}}` expands to the elected
version's `forge/partials/<name>/<version>/<name>.md`, trailing whitespace trimmed,
spliced where the macro stands. The frontmatter line lowers to an
`x-forge-partials: <name>@<version>` stamp, as `tools:` does. Refuses a non-inline
list, a declared partial with no election in the harness's `partials` map, a missing
version dir or entry file, an undeclared macro — and a `{{…}}` macro inside the
fragment itself, since a partial is leaf text and may not pull deps its consumer never
declared. `\{{partials:…}}` is the escape. Nothing is placed: a partial has no root, no
dest and no prune entry; `--status` prints its row with LIVE `ok`/`error` from the
cellar entry alone, `--check` counts a broken one as a failure, and `--json` carries
the forward edge on each consumer (`partials`) and the reverse index on the partial
(`consumers`). Runs after the engine pass and before the agent body pass, so a
fragment's text is never scanned for the other macros — it refused earlier if it had
any.

### Multicast

A scope named in the harness's `multicast` map (`"multicast": {"sssf": "sssf-suite"}` —
scope → the suite whose receipt subscribes a repo) has elections but no `roots` entry:
each election renders into every subscriber's rendered root instead. One election, one
version, N placements — the version always comes from the election, never from a
receipt; a receipt only admits or holds a placement. The label stays one per election
(`claude-code/sssf/<skill>`), so `elect-exact`, `show`, `yank-exact` and `move-exact`
address it unchanged. A multicast scope with elections and no `roots` entry is exempt
from the manifest-structure error above.

**Subscribers.** A subscriber is every key of `roots` except `global` and the scope's own
name whose repo dir holds `.claude/skills/<suite>.receipt.json`. The repo dir is
`$FORGE_DEV_ROOT/<repo>` (default `~/dev`, as in the shell scripts), except `dotfiles`,
which is the forge's own repo root; a symlinked repo dir is skipped, so a compat link
never renders a repo twice. A receipt that is not JSON, names another suite, carries no
`vX.Y.Z` version, or carries a `peers` value that is not a map of skill name to
`">=X.Y.Z"` is a per-placement `error` naming the file; every other placement is
unaffected in `--status`, `--json` and `--check`. The live `render` is fail-fast, so there
a bad receipt aborts the pass — and `elect-exact`'s shadow render refuses — until that
repo is re-stamped. A receipt-bearing repo under `$FORGE_DEV_ROOT` with no declared root is not a
subscriber: `--status` prints one stderr line per such repo
(`<repo> carries a sssf-suite receipt but no root — just forge discover-exact <repo> to
subscribe`) and no row.

**Two floor checks per placement**, checked before the copy:

| Floor | Compared | Below the floor | Owner of the fix | `--check` |
|---|---|---|---|---|
| Skill side | each `engines:` floor of the version naming the scope's suite, against the receipt's version | `held` — not rendered, not owned at that root (a stale copy there is pruned); stderr `<label> @ <repo>: <suite> is <version> there, needs <spec> — re-stamp` | the repo — a stamp, not a manifest edit | skipped, not a failure |
| Keg side | the receipt's `peers` entry for the skill, against the elected version | `error` — `<label> @ <repo>: keg <version> needs <skill> >=X.Y.Z, elected <version> — elect a newer version` | the manifest — elect a newer version | counted as a failure |

Both use one dotted numeric compare over the parts after an optional `v`, a longer tuple
winning on an equal prefix (`v1.0.7.3` ≥ `v1.0.7`). If both apply, the skill-side `held`
wins over the keg-side `error`; a bad receipt is `error` before either. A placement whose
path a rooted election already renders (`<subscriber root>/<skill>` is that election's
dest) is `error` naming both labels — one election per path, and the fix is a manifest
edit. Floors naming a
suite other than the scope's are not checked here — they stay the run-time probe of
[§ Engine pass](#engine-pass). A receipt with no `peers` key declares no floors;
[`stamp-core.sh`](#stamp-coresh) writes it.

**Surfaces.**

| Surface | Multicast shape |
|---|---|
| `--status` | The election's row as usual, its LIVE the worst placement in the order `error` > `drift` > `missing` > `held` > `ok`; then one indented row per subscriber — label `  @<repo>`, VERSION the receipt's version, LIVE that placement's state, the other columns `-`. A scope with no subscribers renders nowhere and shows `nosub`. A held placement's reason is on stderr, not in a row. |
| `--json` | The election object gains `multicast: "<suite>"` and `subscribers: [{repo, root, receipt, live, error}]` (`receipt` the absolute path); its `live` is the aggregate. `error` is `null` for a `held` placement — held is not a fault. The `scopes` entry is `{name, root: null, multicast: "<suite>"}`. Non-multicast objects carry none of it. |
| `--check` | Per subscriber: the shadow against the live copy under the subscriber's root; the total counts placements, held ones included, not elections. |
| `render` | A held placement is not listed on stdout; its stderr line prints once per render. Prune follows the rendered root: a rendered placement's skill name is owned at its subscriber's root, a held one's is not. |

## `verbs.sh`

`just forge` (= `default`) and `just forge all`. The compact render of the verb
lexicon, for human eyes; `just --list forge` stays the full one, for agents and for
looking up a verb's contract. Read-only, writes nothing.

Both surfaces read the same source — the doc comments in `../justfile`. just allows
exactly one doc slot per recipe (`[doc('...')]` *replaces* the `#` comment rather than
supplementing it, in `--list`, `--show` and `--dump` alike), so a short text and a long
text cannot both be stored there. This script is the way out: keep the long text as the
single source and *derive* the short one, the same posture `render.ts` takes to the
cellar.

Two things it derives rather than declares, so the short render cannot drift from the
verb set it describes:

| Derived | From | Why not declared |
|---|---|---|
| group order | `[group(...)]` lines scanned from `../justfile` in source order | just's `--list` sorts groups alphabetically; authoring order is the meaningful one, and a list in here would be a second copy |
| which verbs are agent-only | an `-exact` verb is folded away exactly when its interactive twin exists | a twinless engine (`yank-exact`, `unyank-exact`) is the only way to reach that operation, so it must stay listed; a new pair classifies itself |

Each verb's line is its doc comment cut at the first sentence, em-dash, or colon —
whichever comes first — then truncated to fit. `just forge all` shows the folded
`-exact` engines too, dimmed and marked `(agent)`. Reads just's own model through
`just --dump --dump-format json`, never by parsing the justfile for recipes.

## `view.sh`

Read-only: writes only the scratch dump (`../scratch/view.json`). Three modes.

`just forge view` dumps `render.ts --json` once, pipes every election label into `fzf`,
and renders a per-selection detail pane by calling back into itself with
`--preview <label>`. The selected label prints to stdout on exit — the composition hook
`elect.sh` builds on. Interactive; needs a terminal.

`just forge show <label>` (= `--show`) prints that same detail non-interactively:
elected version marked `*` in the full cellar list, yanked flagged, tier lowering, tool
edges, live state — for an agent election with variants, one lowering block per
rendered name under a `variants` header. No fzf and no terminal — this is the per-election read surface for
scripts and agents, the detail counterpart to `--status`'s one-row-per-election table.
An unknown label exits non-zero with near-matches listed (same posture as
`elect-core.sh`); a missing label exits 2.

`--preview <label>` is fzf's callback for the preview pane, not a user entry point. It
shares the renderer with `--show` and differs only in freshness policy: `--show`
refreshes the dump first so it never prints stale state, while `--preview` reads the
existing dump without refreshing, so cursor movement never re-renders. Called with no
dump present it exits non-zero pointing at `just forge show`.

## `edges.sh`

`just forge edges`. The derived edge ledger: one row per `just` call found in an
elected skill's cellar body, as SKILL · TARGET · RECIPE · CLASS · CHECK. Derived, not
declared — the same posture as `verbs.sh`: the ledger *is* the text, so it cannot drift
from it, and it covers every immutable version without a bump. Bridge-layer script
(reads `$FORGE_DEV_ROOT`, default `~/dev`); render.ts stays hermetic.

Resolution: a backtick span containing `just`, optionally `-f <path>`, then bare words.
TARGET is the `-f` path when given, else the scope's repo (`$FORGE_DEV_ROOT/<scope>`,
or dotfiles for the `dotfiles` scope), else `cwd` for a global skill with no anchor.
RECIPE is `module::recipe` when the first word names a module in that justfile's dump.
CLASS is `same-repo` when target and cellar share the dotfiles history, `cross-repo`
otherwise, `unanchored` when the target is cwd. CHECK runs `just -f <justfile> --dump`
once per target: `ok`, `missing`, `unchecked` (no justfile reachable), `-` (a `--list`
call, lexicon only). Misses a verb written bare after a prefix stated once in prose;
placeholders like `<verb>` are excluded by construction. Exit 0 always — a read surface.

An `engines:` floor is one more row, read from the `--json` dump rather than the body:
CLASS `engine`, TARGET the scope's repo as above, RECIPE the spec, CHECK from that
repo's `.claude/skills/<suite>.receipt.json` — `ok`, `skew` (stamped below the floor),
`no-receipt`, or `unchecked` when the target is cwd. Engine rows sort first, the order
the probe checks them in.

## `elect-core.sh`

`just forge elect-exact <label> <version>`. The election engine, and the write twin of
`view.sh`. Takes one exact label and one exact version, validates both against
`render.ts --json`, then a `jq` path-assignment builds the candidate manifest in
scratch (skill, tool, partial and agent labels address their respective manifest sections,
routed by the dump's own `harness`/`scope`/`name` fields rather than by splitting the
label).

It compiles before it commits: the candidate is shadow-rendered from scratch
(`render.ts --manifest <candidate> --out <scratch dir>`) and only replaces
`../elections.json` once that render succeeds — a candidate that refuses exits
non-zero with the render error and leaves the manifest byte-identical. A full live
render follows, so the bin trees never lag the manifest. The manifest is the only file
it writes.

No pickers, no prompts, no terminal required — this is the surface for scripts and
agents. It refuses with a non-zero exit and the candidates listed on an unknown label
(near-matches printed), a label ambiguous across skills, tools, partials and agents, an unknown
version (eligible versions printed), or a yanked version — the `.yanked` sentinel means
do-not-elect, so only the viewer shows those. Re-electing the current version is a
no-op success.

`just forge tier-exact <label> <tier>` (= `--tier`) is the same engine on the
election's other writable field: it writes the election-level `tier` override — a
bare tier (`sota`) or a member-qualified one (`sota[fable]`) — or deletes it on `-`.
The engine checks only what the dump can't: tool, partial and agent labels are refused
(tools and partials carry no tier; an agent's tier lives on its variants). Whether the tier exists and the
qualifier names a member of its list is render's contract ([§ Lowering](#lowering)),
so an unknown tier or an off-list engine refuses at the shadow render, manifest
unchanged. Setting the override already in place is a no-op success. Version and tier
stay separate verbs because they are separate axes — the edition of the text vs. the
engine that runs it.

`just forge variant-exact <label> <name> [key=value ...]` (= `--variant`) is the same
engine on an agent election's variants map: `<name>` is the rendered agent name, the
rest are its overrides in helm `--set` shape (`tier=sota[fable] effort=xhigh
disallowedTools='Edit, Write, NotebookEdit'`; no overrides is `{}`), and a lone `-`
drops the variant — dropping the last one drops the `variants` key, so the entry
renders under its own name again. Skill and tool labels are refused; which keys lower
and whether the tier resolves is render's contract ([§ Agent pass](#agent-pass)), so an
unknown key refuses at the shadow render, manifest unchanged. Setting a variant to the
overrides it already has is a no-op success. Mind the contract: `variants` is the
complete rendered set, so adding the first variant to a plain entry stops the entry's
own name rendering until it is listed too (`variant-exact <label> <entry name>`).

## `elect.sh`

`just forge elect [election] [version]`. The fzf front end over `elect-core.sh`: the
same list `view.sh` shows (same preview pane) picks an election, a second fzf picks the
new version from the eligible list (`versions` minus `yanked`), and both exact strings
are handed to the engine. It resolves intent and writes nothing itself.

Both arguments seed the fzf queries and auto-select on a *unique* match, so
`just forge elect check-code v1.4.0` runs the flow without drawing a picker — but a
query matching several labels (`check-docs` matches both `check-docs` and
`check-docs-orchestrator`) opens the picker as normal, and so does a query matching
none.

Because that fallback is a blocking prompt, this script requires a terminal: it tests
`/dev/tty` up front and exits 2 with a pointer to `elect-core.sh` when there isn't one,
rather than hanging on input nobody is there to give.

## `yank-core.sh`

`just forge yank-exact <label> <version>` / `just forge unyank-exact <label> <version>`
(= `--undo`). The yank engine: one exact label and one exact version, validated against
`render.ts --json` (skill, tool, partial and agent labels all address their cellar dirs, routed
by the dump's own fields), then the `.yanked` do-not-elect sentinel is touched — or removed on
undo — beside that version's files and left staged, not committed. The sentinel is
cellar bookkeeping render never copies, and every elected version is refused, so no
re-render follows — the bin trees cannot have changed.

The guard that justifies the engine over a bare `touch`: yanking a version that *any*
election of the same cellar entry still elects is refused, with the electing labels
listed (elect another version on each first). The sentinel is a property of the cellar
entry, not of the label that addressed it — so the guard matches on `scope`+`name` for
skills and `name` for tools, partials and agents, across every harness in the dump, not
only the label given.
elect-core refuses to elect a yanked version, but nothing else would stop a live one
from being marked while render keeps serving it. Other refusals match elect-core's
posture: unknown label (near-matches
listed), a label ambiguous across skills and tools, an unknown version (cellar list
printed). Yanking an already-yanked version, or unyanking a non-yanked one, is a no-op
success. No pickers, no terminal — the surface for scripts and agents.

## `move-core.sh`

`just forge move-exact <label> <scope>` / `just forge retire-exact <label>` (= a move
to `keg-only`). The scope-move engine: one exact skill label and a destination scope,
validated against `render.ts --json`, then four effects in an order where every
intermediate state still renders — the source election is dropped from the manifest
first (the entry is then unelected but still in place, which prunes cleanly), the
cellar entry `git mv`s across scope dirs second (history and `.yanked` flags travel;
the move is left staged, not committed), the whole entry is re-added under the
destination scope third — never
before the cellar entry is there to render from — and a full render follows. A
destination with neither a root nor a multicast entry (`keg-only` included) skips the third step, so the move is a
two-step drop.

Election handling is one rule: **the election survives only where it can render.** A
destination with a root in the label's harness, or a multicast scope, gets the whole entry transplanted
(version, tier override, bundle); `keg-only` or a rootless scope drops it. Retire is
thus not its own engine — it is the keg-only special case of move; *yank* (`.yanked`)
is the version-level sibling.

No pickers, no terminal — the surface for scripts and agents. It refuses with a
non-zero exit on an unknown label (near-matches listed), a tool or partial label (rendered
skills may still declare it; neither cellar has scopes), a destination equal to the current scope, an
unknown destination scope (creating a scope is manifest authoring, done by hand; the
legal set is listed), a cellar entry some other election still renders (the move
would break it), or a destination name collision.

Labels come from the election dump, so an *unelected* cellar entry (keg-only, or a
rootless scope) is out of the engine's reach — reviving one is the manual inverse:
`git mv` out, add the election by hand, render.

## `move.sh`

`just forge move [election-query] [scope-query]`. The fzf front end over
`move-core.sh`: the same list `view.sh` shows (same preview pane) picks a skill
election, a second fzf picks the destination scope from the legal set (this
harness's roots + multicast scopes + `keg-only` + existing cellar scope dirs, minus the current scope),
and both exact strings go to the engine; it resolves intent and writes nothing itself.
Arguments seed the queries and auto-select on a unique match. Requires a terminal (`/dev/tty`), same posture as `elect.sh`.

## `retire.sh`

`just forge retire [query]`. `move.sh` with the destination pinned to `keg-only` and
a `y/N` confirm in place of the scope picker: pick a skill election, confirm, and
`move-core.sh <label> keg-only` runs; this script writes nothing itself. The argument seeds the query and auto-selects
on a unique match — safe because the confirm still gates the write. Requires a
terminal, refusing up front without one.

## `discover-core.sh`

`just forge discover-exact <repo>`. The repo-onboarding engine: takes one exact repo
basename, looks it up under `$FORGE_DEV_ROOT/<repo>` (default `~/dev` — the dev root
is a machine-level fact, so it lives in an env var, never the committed manifest),
declares its root in `elections.json` when the manifest lacks one
(`home/claude/repos/<repo>/skills`), re-renders (render materializes the empty root),
and delegates to `link.sh` for the symlink. The manifest write is skipped when the root is already declared — the
cross-machine case, where roots travel with the committed manifest but symlinks
don't — so the engine is idempotent end to end: an already-declared, already-linked
repo is a no-op success. Like every manifest/cellar write, the edit is left
uncommitted.

No pickers, no terminal — the surface for scripts and agents. It refuses (non-zero)
on a reserved scope name (`global` / `dotfiles` / `keg-only` / `tools` — the last
because its skill labels would collide with the tool-election label namespace), a
multicast scope name (a `multicast` key in the manifest — it renders into every
subscriber, it is not a repo target), a
missing repo dir, a directory with no `.git`, or anything `link.sh` refuses.

## `discover.sh`

`just forge discover [query]`. The fzf front end over `discover-core.sh`: scans
`$FORGE_DEV_ROOT` for git repos and annotates each with its manifest/link state —
`(new)` (no root declared), `(declared, unlinked)` (root in the manifest, no local
symlink), `(mislinked)` (an existing `.claude/skills` that is not the expected
symlink; the engine surfaces `link.sh`'s refusal), or `(linked)` (fully served,
kept visible as an overview; picking one is a no-op success) — and hands the pick's
exact basename to the engine; it resolves intent and writes nothing itself. With no git repos under the dev root it says so and
exits clean. The argument seeds the query and auto-selects on a unique match.
Requires a terminal (`/dev/tty`), same posture as `elect.sh`. Errors if the dev root
(`$FORGE_DEV_ROOT`, default `~/dev`) doesn't exist.

## `link.sh`

`just forge link <repo>`. Bootstrap for a repo-targeted scope, reading the root path
from the manifest's `roots` map and the link mode from its `linkModes` map
(claude-code only until a second harness declares repo roots). Render itself never
writes outside dotfiles — the symlinks are the only thing that lives in the target
repo, and this is the only script that touches one. Two modes:

**`tree`** (the default, `linkModes` entry absent) — one-time: symlinks
`$FORGE_DEV_ROOT/<repo>/.claude/skills` (default `~/dev`) at the rendered
`home/claude/repos/<repo>/skills` tree. Forge owns the whole directory. Idempotent: an
already-correct symlink is a no-op success. Refuses (non-zero, never deletes) on an
existing `.claude/skills` that is anything other than the expected symlink. Prints a
reminder if the target repo's `.gitignore` doesn't cover `.claude/skills`.

**`per-skill`** (`"linkModes": {"<repo>": "per-skill"}`) — for a repo that owns its
own committed `.claude/skills/`: the directory stays real and repo-owned, and each
elected skill gets its own symlink inside it, beside the repo's skill dirs (Homebrew
linking formulae into a shared bin dir, vs. tree mode's brew-owned prefix). Re-run
after any render that changes this scope's election set — unlike tree mode, the link
set tracks the elections. Ownership is the inode type: a symlink resolving into the
rendered root is forge's — created, retargeted, and pruned here when its election
goes away — anything else is repo-owned and never touched. Forge-owned names are
maintained as a managed block in the target's `.git/info/exclude` (machine-local
links, machine-local ignores — the target repo commits nothing), rewritten whole each
run and removed when the election set is empty. Refuses before writing anything on a
tree-mode symlink at the directory itself, or on a rendered name whose slot holds an
entry forge does not own (a real dir/file, or a symlink pointing elsewhere).

Both modes refuse on a repo with no root in the manifest (declared repo roots
listed), a missing repo dir, or an unrendered root.

## `keg-core.sh`

`just forge keg [version]`. The read primitive of the keg-only pattern: prints the
absolute path of the latest non-yanked sssf-suite keg, or of the named version (bare
`X.Y.Z` normalized to `vX.Y.Z`). Path only, so it composes —
`cat "$(just forge keg)/sssf/references/jig.md"`, `basename` for the version. Refuses
(non-zero, stderr) an unknown or yanked version, or a cellar with no electable keg.
Read twin of `lab`: `lab` names the source repo, `keg` names the release. Owns
latest-keg resolution: `stamp-core.sh`, `playground.sh` and `harvest-plan.sh` resolve
their keg through it.

## `stamp-core.sh`

`just forge stamp-exact <repo> [version]`. The deployment engine of the keg-only
pattern: copies every member subdir of the chosen sssf-suite keg
(`forge/kegs/sssf-suite/v<X.Y.Z>/`) into
`$FORGE_DEV_ROOT/<repo>/.claude/skills/<member>/` as real files — no symlinks, no
election, because sandbox transport is `git clone` and a forge symlink dies in any
clone. The charter `SKILL.md` at the keg root is provenance, not payload — it never
travels. Version defaults to the latest non-yanked keg; a bare `X.Y.Z` is normalized
to `vX.Y.Z`. Members sync with `rsync --delete`. The upgrade path is: no overlay,
`render.py capture` each customized rendered file BEFORE this stamp (capturing
after pins the old template); then stamp; then `render.py` from the consumer's
root — a stamp alone never touches a rendered file.
Every stamp also writes a receipt, `.claude/skills/sssf-suite.receipt.json`,
beside the members and outside them — version, the dotfiles commit that added the keg
(`null` while the keg is only staged), members, timestamp. Homebrew's
`INSTALL_RECEIPT.json`: the one place a consumer names which keg it is at, so "which
version is this repo on" is a committed file and drift has a base to be measured from.
Stamp is the receipt's only writer; after a harvest, stamp the source repo at the version
just cut — the rsync changes nothing tracked there (though `--delete` still removes
untracked build output under member dirs, e.g. `node_modules/`), and the receipt is the
effect. When the keg's `sssf/conformance.toml` carries a `[peers]` table (skill name → `">=X.Y.Z"`, the suite's declared floors on the forge skills it works with), the receipt gains a `peers` key with it — the keg owns the floors, the receipt renders them, and render reads only the receipt ([§ Multicast](#multicast)); no table, or a keg from before the file existed, writes no `peers` key, and a malformed table fails the stamp. The copy is not the release act — the commit in the target repo is; the
script prints the reminder and leaves everything uncommitted, same posture as yank.

A `.claude/skills` that is forge's own tree-mode symlink (pointing at the scope's
declared rendered root) is converted in place rather than refused: stamping declares
that the repo owns committed skills — exactly what per-skill linkMode encodes — so
`linkModes` gains the repo (manifest written, uncommitted), the symlink becomes a
real directory, and `link.sh` re-establishes one symlink per elected skill before
the members land beside them.

No pickers, no terminal — the surface for scripts and agents. Refuses (non-zero) on
a missing/non-git repo, an unknown or yanked version, a `.claude/skills` symlink
that is not forge's tree link, or a member destination that is a symlink
(forge-linked per-skill, not stamp-owned).

## `stamp.sh`

`just forge stamp [repo-query] [version-query]`. The fzf front end over
`stamp-core.sh`: pick a git repo under `$FORGE_DEV_ROOT` (default `~/dev`),
annotated with its stamp-relevant `.claude/skills` state — `(no .claude/skills
yet)`, `(has .claude/skills)`, `(tree-linked — stamp converts to per-skill)`, or
`(foreign symlink — the engine will refuse)` — then pick a keg version, newest
first, yanked excluded. Both exact strings go to the engine; this script resolves
intent and writes nothing itself. Arguments seed the queries and auto-select on a
unique match. Requires a terminal (`/dev/tty`), same posture as `elect.sh`.

## `playground.sh`

`just forge playground [version]` (default the latest non-yanked keg; bare `X.Y.Z`
normalized). One persistent consumer, `$FORGE_DEV_ROOT/sssf-playground`, with nothing
of its own: stamped from a keg, installed from it, toured by hand. The clean-room check
stamps the same fixture on every gate run and throws it away; this is the long-lived
twin, where the operator touches a keg — a run, its trace, the engine, and after Rung
95 an overlay. It does not experience a real consumer's upgrade (capture, stamp,
render): `install.py --force` overwrites every rendered file from the new templates
outright, and `render.py --force` puts the overlay's entries back — no capture step,
because nothing here is user-owned.

Idempotent, eight steps, one line each: creates the repo when missing (git init, a
first commit) or targets it when present; refuses a dirty tree, listing the
paths, so an uncommitted experiment never rides into a stamp commit; past that guard,
rewrites the role README every run — what the playground is for, how a refresh works,
that nothing flows back, never what it holds — so a stale copy never survives; left
unstaged, it lands in the install commit near the end (the stamp commit, when one
runs, stages only `.claude/skills`); stamps through
`stamp-core.sh` and commits `Stamp sssf-suite vX.Y.Z` unless the receipt already names
the version; runs `install.py --force` — safe here and nowhere else, because nothing in
the playground is user-owned, so every rendered file is refreshed from the keg's
templates (install.py never deletes, so a file an older keg stamped and a newer one
dropped lingers until a reset); when the playground holds an `sssf-overlay/` (Rung 95),
runs `render.py --force` so its declared entries come back over the fresh install while
an undeclared edit does not, and stops with render's own lines when an entry no longer
applies; keeps `.env`, which is never stamped, copying the sample
and naming the key when it is absent; stages and commits `install sssf-suite vX.Y.Z`,
the stamped `.gitignore` keeping `.env`, the trace db and the sessions out, with no
empty commit; prints the tour. A second run prints `already at` and `nothing to commit`.

Nothing flows back from the playground: a bug found here is fixed in the lab and
arrives with the next keg. Reset is a git operation, not a delete: check out the first
commit, `git clean -fdx -e .env`, run the verb again.

## `harvest-plan.sh`

`just forge harvest-plan <repo> [major|minor|patch]` (default `patch`). The plan half
of the harvest — the structural inverse of `stamp-core.sh`, split in two so the human
stands *between* passes rather than being asked mid-pass. This script derives; a
separate apply step will act on the approved plan. It writes one file,
`scratch/harvest/<repo>-<vNext>.plan.md` (its extraction under `scratch/harvest/src/`
is removed on every exit); never the cellar, the manifest, or the repo.

The payload oracle is the git index: the source is `git archive HEAD` of the repo's
`.claude/skills`, so untracked content (`node_modules/`, `.venv/`, run
records, the trace db) cannot enter and no exclude list has to be kept in step with
`.gitignore`. One table, the Members axis:

| Axis | Compares | Semantics | Row disposition |
|---|---|---|---|
| Members | repo `.claude/skills/<member>` vs latest non-yanked keg `<member>` | must converge — every difference is payload | `harvest` (changed) / `ride-along` (unchanged, copied from vPrev) |

The members are the core's `suite` — `.claude/skills/sssf/conformance.toml` at HEAD,
the list `conformance.py --suite` fans out over — read through `suite-members.sh`, so
the forge keeps no member list of its own (every cargo command reads a workspace's
`members` from its root `Cargo.toml` the same way). A member new to the keg has every
file `added` and is proposed `harvest`. The helper refuses a core with no contract (a
source from before v1.10.0) and a `suite` that is not distinct `[a-z0-9-]` names with
`sssf` among them: each name becomes a path under the keg.

The header's `render:` line is the gate's own check, delegated: the extracted sssf's
engine runs `render-oracle` against the repo at HEAD, the check harvest-apply runs on
the keg. The line is the engine's `ok` line, or a FAIL count after which the cut will
refuse, or `none` when the source's sssf ships no `render-oracle` (`cannot run` with
the engine's last line if it exits otherwise). It informs; it never refuses.

Re-running keeps the plan's `note:` line; everything else is derived again from HEAD.

The repo's stamp receipt (written by `stamp-core.sh`) is read from HEAD and reported
in the plan header. The base stays the latest non-yanked keg — apply refuses any other,
or ride-along members would regress to an older keg — so a receipt naming an older
version is a warning, not an override: the member diff then mixes the repo's own edits
with everything the suite gained since that stamp, and re-stamping first separates the
two.

Refuses (non-zero) on a missing/non-git repo, a repo that is not this forge's lab
(`kegs/sssf-suite/.lab` — missing, empty, or naming another repo: at most
one lab writes the keg), a core with no `suite` or a malformed
one, a member of the base keg the `suite` does not name (the forge cannot remove a
member yet), a member absent from HEAD or tracked as a symlink (the suite is not live
in that repo), no electable keg, or an unknown bump level. A dirty working tree is a
warning in the plan header, not a refusal — the plan reads HEAD either way. No
pickers, no terminal — safe for scripts and agents.

## `harvest-apply.sh`

`just forge harvest-apply <plan>`. The apply half: consumes a plan
`harvest-plan.sh` wrote and never re-derives anything from the world — source
commit, base keg, version, and which members ride in whole all come from the plan,
so the thing that was approved is the thing that runs (`terraform apply tfplan`,
not `terraform apply`). The inverse of `stamp-core.sh`, with `yank-core.sh`'s
posture: the new version dir is `git add`ed and left staged; the dotfiles commit
is the release act.

The member set comes from the plan's commit: the core's `suite` there, read through
`suite-members.sh`, each member taking its disposition from the plan's Members table.
A member the suite names with no row is a refusal, never a silent carry-over from
vPrev.

Refuses, writing nothing, unless the plan's repo (the header's source) is this
forge's lab (`kegs/sssf-suite/.lab` — missing, empty, or naming another
repo refuses), the plan says `status: approved` and its `note:`
line is filled (it becomes the charter's history entry), the
plan's source commit resolves in the repo, the base keg is still the latest
non-yanked one, and vNext does not exist. Kegs are immutable: an existing vNext is
never touched.

Then: `cp -R vPrev vNext`, each `harvest` member replaced by `git archive <commit>`
of the repo's `.claude/skills/<member>` (committed state only — nothing untracked
can enter, and no exclude list exists to drift), `ride-along` members kept from
vPrev, one provenance paragraph appended to the charter. Validation runs on the
result: no symlinks anywhere; each harvested member's file set equals the repo's
tracked set at that commit and its content matches the archive byte for byte; every
member and the charter present; and sssf's engine, `conformance.py --suite`, passing
on the keg — every member the core's `suite` names, each on its own
`conformance.toml`, sssf's check including a clean-room install and start of every
ADW — judged against the source at the plan's commit. An engine that is absent or
lacks clean-room is refused. Any exit before the `git add` removes vNext whole; the
extraction under `scratch/harvest/apply/` goes on every exit. On success the plan
is marked `status: applied` so it cannot be applied twice.

## `suite-members.sh`

`bash scripts/suite-members.sh <repo-dir> <commit>`. Prints the sssf-suite's members,
one per line in suite order: the core's `suite` in
`.claude/skills/sssf/conformance.toml` at that commit of the source repo — the list
`conformance.py --suite` fans out over, as Cargo reads a workspace's `members` from its
root manifest. `harvest-plan.sh` and `harvest-apply.sh` both read it here, so the forge
keeps no member list of its own and names only the core, the suite's entry point. No
`just` verb: a helper, not a surface.

Refuses (non-zero) when the core has no contract at that commit (a source from before
v1.10.0, the keg that added it), and when `suite` is not a list of distinct skill names
with the core among them. Each name becomes a path under the keg, so a name is
`[a-z0-9-]` only: `..` or a slash is refused before any script uses it.

## Cellar-only files

`.yanked` — the do-not-elect sentinel written beside a version's `SKILL.md` (by
`yank-core.sh`) — is cellar bookkeeping, not skill content. `render.ts` skips it both when copying and when building
the file lists `--check` diffs, so a yanked version never renders and its marker never
counts as drift.

`.lab` — `kegs/sssf-suite/.lab`, one line holding the lab repo's basename, read
by `harvest-plan.sh` and `harvest-apply.sh` (and the `lab` verb). Never rendered.
