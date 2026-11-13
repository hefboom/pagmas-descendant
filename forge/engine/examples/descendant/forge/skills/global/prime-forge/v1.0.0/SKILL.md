---
name: prime-forge
description: Prime a fresh agent for work in the forge — loads how the cellar, the manifest and render fit together, the verbs, and what is live right now. Run it before writing, versioning or electing a skill, or before asking how the forge works.
allowed-tools: Read, Bash
tier: lightweight
tools: [doc-section]
---

# prime-forge

Load the forge's working model into a fresh agent: the cellar (every version, frozen), the manifest (`forge/elections.json`, what is live) and render (`just forge render`, which builds the folders the harness reads). Run it at the start of a session that will write or release a skill, or when the person wants the forge explained.

It loads how the forge works and one line per election. It does not load any skill's history: `just forge show <label>` gives that when it is needed.

This skill copies nothing it can read fresh. The verbs come from the justfile's own comments, and the model comes from the engine's `AUTHORING.md`, by section. What is written here is only what those cannot say: the rules for an agent.

## Instructions

- **The forge is the descendant at `$FORGE_ROOT`, and this skill runs from any directory.** Every command is `just -f "$FORGE_ROOT/justfile" forge <verb>` and every path starts at `$FORGE_ROOT/`. Do not `cd`. If `FORGE_ROOT` is empty, stop and say so: `~/.config/pagma/env` sets it, and a guessed path primes the wrong forge.
- **Copy labels, never build them.** Every `show` and `elect-exact` argument is a full label taken as-is from column 1 of `status`. The one exception is a brand-new skill's first election, which is not in `status` yet: `#add-a-skill` gives its form.
- **Asked about a skill, run `show <label>` first**, then read the elected version's directory in the cellar. What is live is what the manifest says, not what sorts first in a listing.
- **Changing a skill means a new version.** Copy the elected version to the next patch number and edit the copy. Never edit a committed version. Move the minor or major number only when the person says so.
- **The `-exact` verbs are the only way to write.** Never edit `forge/elections.json` by hand, except to add a new agent or tool, which has no verb yet. The pickers (`view`, `elect`, `move`, `retire`, `discover`) need a terminal and are for the person: never call them.
- **Judge health by the LIVE column, not by the exit code.** `status` and `show` exit 0 with a broken election in the table.
- **Read a copied version before editing it.** The read confirms the copy landed.

## Workflow

Three steps, in order:

1. The core of the authoring doc, by section, in one command. The shell expands the braces into one address per section:

   ```bash
   {{tools:doc-section}} "$FORGE_ROOT"/forge/engine/AUTHORING.md#{layout,pattern,tiers,add-a-new-version,promote-a-version,drift-gate,naming,frontmatter}
   ```

2. `just -f "$FORGE_ROOT/justfile" --list forge`: the verbs, read from the justfile's comments.
3. `just -f "$FORGE_ROOT/justfile" forge status`: one row per election.

That is the core only. Load the rest with the same tool when the work reaches it: `#add-a-skill` for a new skill, `#tools` and `#agents` for those cellars, `#retire-and-yank`, `#skill-skeleton` before writing a skill body. `{{tools:doc-section}} --outline <file>` lists every section of a file with its size.

Read `$FORGE_ROOT/forge/engine/scripts/README.md` only when the work is on the engine's own scripts.

## Output

One line: `Forge primed: cellar, manifest and render loaded.`

Nothing else when the run is clean. The verbs and the status table are already in context; printing them again repeats what the terminal just showed. Answer from them.

Then report anything that went wrong, before any authoring:

- `MISSING: <file>#<slug>` from step 1: a heading was renamed in the engine. The outline printed with the error shows the new address. Make a new version of this skill that cites it.
- `drift` or `missing` in the LIVE column: `just forge render` fixes both.
- `error` in the LIVE column: that election does not render. Elect a version that does with `elect-exact`; do not edit the manifest by hand.
