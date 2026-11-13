# Authoring in a descendant

How the forge works once it is installed, and how to write, version and release a skill
in it. Written to be read by section: the starter skill `prime-forge` loads the sections
it cites with the `doc-section` tool, so the headings here are addresses. Renaming one
is a change to announce in `CHANGELOG.md`.

Every command runs from the descendant's root. From anywhere else it is
`just -f "$FORGE_ROOT/justfile" forge <verb>`.

## Layout

| Path | What it holds |
|---|---|
| `forge/elections.json` | the manifest: which version of each skill, agent and tool is live, and where it renders |
| `forge/skills/{scope}/{name}/v{X.Y.Z}/SKILL.md` | the skills cellar: every version ever written |
| `forge/agents/{name}/v{X.Y.Z}/AGENT.md` | the agents cellar |
| `forge/tools/{name}/v{X.Y.Z}/` | the tools cellar: scripts that several skills call |
| `forge/partials/{name}/v{X.Y.Z}/{name}.md` | shared text that render splices into skill bodies (optional) |
| `forge/engine/` | pagma itself, a git subtree pinned to a tag. Never edited here |
| `home/claude/{skills,agents,tools}/` | the rendered output the harness reads. Gitignored, rebuilt by render |
| `home/claude/repos/{scope}/skills/` | the rendered output for one repo, or for the hub itself |
| `forge/scratch/` | throwaway trees the checks render into. Gitignored |

## Pattern

Three parts: a cellar, a manifest and a render step.

```text
forge/skills/global/review/v1.2.0/SKILL.md    cellar: committed, never edited again
        ↓  forge/elections.json: global/review → v1.2.0
        ↓  just forge render
home/claude/skills/review/SKILL.md            output: gitignored, rebuilt on every render
        ↑  ~/.claude/skills links here, made once at install
```

- **The cellar is storage.** A version is a directory. Once committed it is frozen: a
  change is a new directory beside it. Nothing loads a skill from the cellar.
- **The manifest is the only record of what is live.** `git log -- forge/elections.json`
  is the release history. Going back is electing the earlier version.
- **Render is a build step.** It copies each elected version into the output tree and
  rewrites its frontmatter (see Tiers and Tools). Delete the output, render, and it comes
  back byte for byte.
- **Render owns its output folders.** Anything in one that no election accounts for is
  deleted at the next render. A name listed under the manifest's `unmanaged` is left
  alone; that is how the Claude app's `synced/` folder survives.

What may change without touching a skill's text lives in the manifest: its version, its
scope, a tier override. What would be wrong to change without touching the text stays in
that version's frontmatter and travels with it.

## Tiers

A version names a capability tier, never a model: `tier: sota`, not `model: opus`. The
manifest's `tiers` table turns the tier into a model and an effort at render, so the
models can be swapped in one place without touching a skill.

| Tier | In the starter manifest |
|---|---|
| `lightweight` | Haiku, effort high |
| `workhorse` | Sonnet, effort high |
| `sota` | Opus, effort high |
| `session` | no model at all: the skill runs on whatever the session is using |

- No `tier:` line means the manifest's `defaultTier`.
- An `effort:` line in the version wins over the tier's effort.
- A `model:` line in a cellar version is refused at render.
- One election can be moved to another tier without a new version:
  `just forge tier-exact <label> <tier>`, and `-` in place of the tier clears it.

`just forge status` prints one row per election: version, tier, where the tier came
from, the model it became, and a LIVE column.

## Tools

A tool is a script that more than one skill calls. It has its own cellar entry and its
own election, and skills never name its version or its path:

```text
tools: [doc-section]                  frontmatter: the skill declares the tool
{{tools:doc-section}} --outline f.md  body: a path macro, flags written after it
```

Render expands the macro to the tool's stable path, `~/.claude/tools/<name>/<entry>`,
which always holds the elected version. A macro for a tool the skill did not declare, or
one with no election, is refused. The macro is a path: the interpreter comes from the
script's first line. To show the macro in a skill without it being expanded, put a
backslash before the opening braces.

## Agents

An agent definition renders once per **variant**: a name in the manifest with its own
overrides (`tier`, `effort`, `disallowedTools`). The starter `shim` agent is one
definition rendered six times, as `lightweight`, `workhorse` and `sota`, each with a
read-only `-ro` twin. In the body, `{{agent}}` becomes the rendered name.

```bash
just forge variant-exact claude-code/agents/shim workhorse-medium tier=workhorse effort=medium
just forge variant-exact claude-code/agents/shim workhorse-medium -     # drop it again
```

## Add a skill

```bash
mkdir -p forge/skills/global/<name>/v1.0.0        # write SKILL.md there
just forge elect-exact claude-code/global/<name> v1.0.0
```

The election validates the version, writes the manifest and renders. This is the one time
a label is written by hand, as `<harness>/<scope>/<name>`: a skill with no election yet
is not in `status`. A skill brought in
from elsewhere needs its `model:` line replaced by a `tier:` line, or removed.

A new agent or tool has no such verb yet: add `"<name>": {"version": "v1.0.0"}` under
the manifest's `agents` or `tools`, then `just forge render`.

## Add a new version

Never edit a committed version. Copy the live one to the next number and edit the copy:

```bash
cp -R forge/skills/global/<name>/v1.0.0 forge/skills/global/<name>/v1.0.1
$EDITOR forge/skills/global/<name>/v1.0.1/SKILL.md
```

The default bump is the last number. The middle or the first number moves only when the
person asks for it. Commit the new version, then promote it.

## Promote a version

```bash
just forge elect-exact <label> <version>
```

A label names one election: `claude-code/global/review` for a skill (harness, scope,
name), `claude-code/agents/<name>` and `claude-code/tools/<name>` for the other two
cellars. Take it from column 1 of `just forge status` rather than building it. The verb
checks the label and the version, refuses a yanked version, renders the changed manifest
into a throwaway tree first, and only then replaces the live manifest and renders. A
change that would not render leaves `forge/elections.json` as it was. The next session
picks the new version up.

## Retire and yank

| Verb | What it does |
|---|---|
| `just forge retire-exact <label>` | takes a skill out of service: its election goes, its versions move to the `keg-only` scope, its output is removed |
| `just forge yank-exact <label> <version>` | marks one version do-not-elect while the skill stays live. Refuses the live version. `unyank-exact` reverses it |
| `just forge move-exact <label> <scope>` | moves a skill, with its history, to another scope |

## Drift gate

```bash
just forge render --check
```

Renders into a throwaway tree and compares it, byte for byte, with the live output. It
fails on an output file edited by hand, an election naming a version that is gone, or
an entry no election accounts for. `just forge render` fixes the first and the last.

Read health from the LIVE column of `just forge status`, not from an exit code: the
table prints, and exits 0, with a broken election in it.

## Naming

- A name carries no version: `review`, never `review-v2`.
- A version is `v{major}.{minor}.{patch}`, a directory under the name.
- A scope says where a skill renders:

| Scope | Renders to |
|---|---|
| `global` | every session: `home/claude/skills/` |
| `hub` | sessions opened in the descendant itself: `home/claude/repos/hub/skills/`, which the descendant's own `.claude/skills` links to. `/pagma-update` and `/pagma-uninstall` live here |
| a repo's folder name | that repo only. `just forge discover-exact <repo>` sets it up in one step for a repo under `$FORGE_DEV_ROOT` (default `~/dev`): it declares the root in the manifest, renders, and makes the one link the repo needs |
| `keg-only` | nowhere. The versions are kept and nothing is rendered |

- The output tree is real directories. A link inside it was put there by hand.

## Frontmatter

These lines belong to one version's text and stay in its `SKILL.md`:

| Line | Meaning |
|---|---|
| `name`, `description` | what the harness shows and matches on |
| `tier` | the capability tier (Tiers) |
| `effort` | overrides the tier's effort |
| `tools` | the shared tools the body calls, as an inline list (Tools) |
| `partials` | the shared text the body includes, as an inline list |
| `allowed-tools`, `argument-hint`, `disable-model-invocation` | passed through to the harness unchanged |

Render adds `x-forge-version` to the output, so a rendered file names the cellar version
it came from.

## Skill skeleton

Not enforced by render. It is the shape the starter skills use, and one shape across a
cellar lets a person or an agent find the same part in the same place:

**Name → Variables → Instructions → Workflow → Output**

| Section | Holds |
|---|---|
| `# <name>` | one paragraph: what the skill is for |
| `## Variables` | the arguments it takes. Omit when there are none |
| `## Instructions` | rules that apply across every step. Omit when there are none |
| `## Workflow` | the numbered steps |
| `## Output` | what the skill reports, and in what shape |

A skill that fronts a set of commands does not copy their list into its body: a copy is
out of date the moment the commands change. It reads the list when it runs
(`just --list forge`, `<tool> --help`) and keeps only what the commands cannot say about
themselves: the rules for using them.

## Further reading

`scripts/README.md` documents every script, the full manifest contract, scopes that
render into several repos at once, and the two ways a repo can be linked.
