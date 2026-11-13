# pagma

A package manager for the prompt layer: agent skills, subagent definitions and shared
tools kept as **immutable versions in a cellar**, **elected** through one manifest, and
**rendered** into the directories each AI harness actually loads from. The engine
behind a private dotfiles repo, extracted so the same mechanism can run anywhere.

Named for the blacksmith in *Overgeared*. pagma needs one repository to be the hub that
every skill and agent is managed from: it holds each version you write and the manifest of
which is live, and from it a skill is global or aimed at a single repo. A repo set up as
that hub, new or existing, is a *descendant*: it carries the engine inside and takes its
updates from it. The scaffold that makes one is the *rare book*. Those two nouns are the
whole borrowed vocabulary; the verbs stay plain: `just forge render`.

**Built for agents, learned by hand.** Every change has two verbs over one engine: an
`-exact` form that takes arguments, which is what an agent runs, and an interactive twin
with fzf pickers, which is for you.

| By hand | What an agent runs | Does |
|---|---|---|
| `just forge view` | `just forge show <label>` | read one election: version, tier, edges, live state |
| `just forge elect` | `just forge elect-exact <label> <version>` | make a version live |
| `just forge move` | `just forge move-exact <label> <scope>` | move a skill between scopes |
| `just forge retire` | `just forge retire-exact <label>` | take a skill out of service, keep its versions |

Drive it by hand once before you delegate it. You will know what your agent can do
because you have done it yourself.

## The mechanism in one screen

```text
forge/skills/global/consult/v1.7.0/SKILL.md   ← cellar: every version ever authored, immutable once committed
            ↓  forge/elections.json: global/consult → v1.7.0
            ↓  just forge render
home/claude/skills/consult/SKILL.md           ← bin tree: disposable build output, gitignored
            ↑  ~/.claude/skills → home/claude/skills   (one symlink, made once)
```

Three ideas, each borrowed:

| Idea | Prior art | What it buys |
|---|---|---|
| Versions are directories, never edited in place | Homebrew Cellar (`Cellar/<formula>/<version>/`) | `git log` is the history of the text; a bad bump is one election away from undone |
| Which version is live is a manifest entry, not a symlink | Homebrew `opt/`, Nix generations | promote = edit one line + render; the drift gate can prove the live tree matches |
| Output is a build step from manifest + cellar | compiler: source → artifact | delete the bin trees, render, get them back byte-identical |

Two more that fall out of running it for a while:

- **Capability tiers, not model names.** A version declares `tier: sota`, never
  `model: opus`. The manifest's per-harness `tiers` table lowers the tier to a concrete
  model and effort at render. Swap the model fleet without touching a single skill body.
- **Agents as variants.** One agent definition, N rendered names, each with election-level
  overrides (`workhorse`, `workhorse-ro` with mutation tools removed). The `shim` agent in
  the example is the degenerate case: the whole contract is the tier.

The drift gate is the whole safety story: `just forge render --check` renders to a
shadow tree and byte-diffs it against the live bin trees, failing on any hand edit,
missing version or orphan. Run it in CI or as a pre-commit hook and the manifest is
provably what is live.

## Quickstart

**With a coding agent** (Claude Code, Codex, any harness that can read a URL and run a
shell). Open it in the directory that should hold your prompts, empty or not, and paste:

```
Install pagma here: read and follow https://github.com/hefboom/pagma/blob/main/INSTALL.md
```

Or clone this repo and type `/pagma-install` in Claude Code inside it; it asks where
your descendant should live, builds it there, and tells you when the clone can go. The
clone is a bootstrap, not a place to work: nothing runs from the engine's own checkout.

[`INSTALL.md`](./INSTALL.md) is written for the agent: it installs what is missing,
mounts the engine, scaffolds the descendant, links the harness and reports. Nothing in it
touches your `~/.claude` without asking when something is already there.

**Without one**, start from the template: [github.com/hefboom/pagmas-descendant](https://github.com/hefboom/pagmas-descendant)
→ *Use this template* → clone it. It is a descendant with the engine already mounted
and `/pagma-install` committed in `.claude/skills/`, so in Claude Code the install is
that one command; other agents find the same pointer in `AGENTS.md`.

<details>
<summary>The steps by hand</summary>

Prerequisites: `bun`, `just`, `jq`, `fzf`, `python3`, `git` (per-OS commands in `INSTALL.md`).

```bash
mkdir pagmas-descendant && cd pagmas-descendant && git init && git commit --allow-empty -m init
git subtree add --prefix forge/engine https://github.com/hefboom/pagma.git v0.1.20 --squash
bash forge/engine/scripts/init.sh          # the rare book: manifest, cellar, justfile, first render
just forge status                          # one row per election, LIVE column says ok
```

`init` writes `forge/elections.json` with one harness and one elected skill, copies the
`hello` skill and the `shim` agent into your cellar, and renders them into `home/claude/`.
Point the harness at the bin trees once — `ln -s $PWD/home/claude/skills ~/.claude/skills`,
same for `agents/` — and `/hello` exists in your next session. It never touches `~` itself.

</details>

From there the loop is:

```bash
cp -R forge/skills/global/hello/v1.0.0 forge/skills/global/hello/v1.0.1   # new version = new directory
$EDITOR forge/skills/global/hello/v1.0.1/SKILL.md
just forge elect-exact claude-code/global/hello v1.0.1                      # validates, writes the manifest, renders
just forge render --check                                                   # drift gate
```

Try it without a repo: `FORGE_ROOT=$PWD/examples/descendant just render --check` from
this checkout renders the example in place.

Supported: macOS and Linux. Windows natively through Git Bash is new in v0.1.19 and still
being proven (`INSTALL.md` § On Windows); inside WSL2 it is the Linux install.

## Layout of a descendant

```text
forge/
  engine/            pagma — this repo, as a git subtree pinned to a tag
  elections.json     the manifest: harnesses → roots, tiers, elections, agents, tools
  skills/            cellar: {scope}/{name}/v{X.Y.Z}/SKILL.md
  agents/            cellar: {name}/v{X.Y.Z}/AGENT.md
  tools/ partials/   cellars: shared executables and prose fragments (optional)
  scratch/           the --check shadow tree (gitignored)
home/<harness>/      bin trees (gitignored)
justfile             mod forge 'forge/engine/justfile'
```

**The engine owns no paths.** It finds the descendant through `$FORGE_ROOT`, or by
walking up from its own location to the nearest `forge/elections.json`. Every path in the
manifest is relative to that root. The manifest also pins the engine (`"engine": "v0.1.0"`);
render refuses to run against a different `VERSION`, so pulling the subtree and re-pinning
is one deliberate step.

Scopes route output: `global` renders to the harness's user-level directory; a repo
basename renders to `home/<harness>/repos/<repo>/` and `just forge link <repo>` plants
the one symlink that repo needs; `keg-only` keeps a version in the cellar and renders it
nowhere. Pick the verb lexicon up from `just forge` (grouped) or `just forge all`.

## Upgrading the engine

With an agent, in the descendant: `/pagma-update` in Claude Code, or paste
`Upgrade pagma here: read and follow https://github.com/hefboom/pagma/blob/main/UPDATE.md`.
It shows the changelog between your pin and the newest tag, asks, then pulls, re-pins,
applies each version's `manifest:` step and runs the gate. By hand:

```bash
git subtree pull --prefix forge/engine https://github.com/hefboom/pagma.git v0.2.0 --squash
jq '.engine = "v0.2.0"' forge/elections.json > t && mv t forge/elections.json    # plus any manifest: lines in CHANGELOG.md
just forge render --check
```

Tags are the versions. There is no package to install; the subtree commit is the receipt.
Leaving is `/pagma-uninstall`, or [`UNINSTALL.md`](./UNINSTALL.md) for any agent. Install
keeps a ledger of everything it creates on the machine (`~/.config/pagma/ledger.jsonl`:
the links, the shell lines, the tools it had to add). Uninstall walks that ledger, asks
per item, and reports entry by entry until nothing is left. Nothing of yours goes without
asking.

## Posture

Dogfooded upstream: the author's own dotfiles consume this exact engine as a subtree,
pinned by tag, and every verb here is exercised daily there. No support promise, no
stability promise before v1 — the manifest shape and the `-exact` verbs are the parts
least likely to move. Issues and patches welcome; expect the answer to be "that is the
descendant's job" more often than not. The harvest/stamp/keg scripts in `scripts/` are a
suite-publishing pipeline coupled to the author's suite and are not yet general.

## Docs

- [`INSTALL.md`](./INSTALL.md), [`UPDATE.md`](./UPDATE.md), [`UNINSTALL.md`](./UNINSTALL.md)
  — the three agent-facing procedures; [`CHANGELOG.md`](./CHANGELOG.md) — one entry per tag.
- [`scripts/README.md`](./scripts/README.md) — every script, the manifest contract,
  multicast scopes, link modes.
- [`examples/descendant/`](./examples/descendant/) — the rare book, readable in two minutes.

MIT — see [LICENSE](./LICENSE).
