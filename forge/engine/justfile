# forge — versioned skill cellar + renderer
# Recipes execute with this file's directory (forge/) as cwd.
# A doc comment is one line — what the verb does and its signature. Depth lives with the
# body: scripts/README.md#<engine>sh for a delegated recipe (addressable via doc-section).

# Compact, grouped verb list for human eyes — the short render of the doc comments this list prints in full.
default:
    @bash scripts/verbs.sh

# The `just forge` list plus the -exact engines that scripts and agents call.
all:
    @bash scripts/verbs.sh --all

# Install bun dependencies
[group('build')]
install:
    bun install

# Scaffold a descendant around this engine (the rare book): copy examples/descendant/ into $FORGE_ROOT (else the engine's grandparent), pin the manifest to this VERSION, bun install, first render. Refuses an existing forge/elections.json. Runs directly too: bash forge/engine/scripts/init.sh
[group('build')]
init:
    @bash scripts/init.sh

# Render bin trees from forge/elections.json. Flags: --check (drift gate, no writes), --out <dir>, --manifest <path> (read the manifest from <path> instead; cellar + roots still resolve against the repo root), --status (resolution table, no writes), --json (machine-readable status + available versions, no writes)
[group('build')]
render *args:
    bun run scripts/render.ts {{args}}

# Print the tier-resolution table (election, version, tier, source, lowered model). Alias for render --status.
[group('inspect')]
status:
    bun run scripts/render.ts --status

# Interactive viewer over the election model: fzf list + per-selection detail pane (versions, tier lowering, tool and partial edges, live state). Read-only; prints the selected label.
[group('inspect')]
view:
    @bash scripts/view.sh

# Print one election's detail non-interactively: show <label> (elected version, tier lowering, tool and partial edges — or a partial's consumers — live state, full cellar version list). The read surface for scripts and agents; refuses unknown labels.
[group('inspect')]
show label:
    @bash scripts/view.sh --show {{label}}

# Derived edge ledger: every `just` call in each elected skill's body, resolved to its target justfile (an explicit -f path, the scope's repo under $FORGE_DEV_ROOT, or dotfiles) and checked against that justfile's `just --dump`. Read-only, derived from the bodies — never declared, so the ledger cannot drift from the text. CHECK: ok / missing / unchecked (no justfile reachable) / - (listing only). Exit 0 always.
[group('inspect')]
edges:
    @bash scripts/edges.sh

# Change an election: fzf pick a skill/tool/partial + an eligible version (yanked excluded), write elections.json, re-render. Args seed the pickers: elect [election] [version]. Needs a terminal — see elect-exact for scripts and agents.
[group('elect')]
elect *args:
    @bash scripts/elect.sh {{args}}

# Change an election non-interactively: elect-exact <label> <version> (exact strings, no pickers). The engine under elect; refuses unknown/ambiguous/yanked with the candidates listed.
[group('elect')]
elect-exact label version:
    @bash scripts/elect-core.sh {{label}} {{version}}

# Set an election's tier override non-interactively: tier-exact <label> <tier> — a bare tier (sota) or a member-qualified one (sota[fable]), or - to clear it. Validated by shadow-render; refuses tool and partial labels. Same engine as elect-exact (--tier).
[group('elect')]
tier-exact label tier:
    @bash scripts/elect-core.sh --tier {{label}} '{{tier}}'

# Set or drop an agent variant non-interactively: variant-exact <label> <name> [key=value ...] — the rendered name plus its overrides (tier=sota[fable] effort=xhigh disallowedTools='Edit, Write'), or a lone - to drop it. Validated by shadow-render; refuses skill, tool and partial labels. Same engine as elect-exact (--variant).
[group('elect')]
variant-exact label name *overrides:
    @bash scripts/elect-core.sh --variant {{label}} {{name}} {{overrides}}

# Move a skill between cellar scopes: fzf pick a skill + a destination scope, git-mv the cellar entry, rewrite elections.json (election transplants where the dest has a root or is multicast, drops otherwise), re-render. Needs a terminal — see move-exact.
[group('elect')]
move *args:
    @bash scripts/move.sh {{args}}

# Move a skill non-interactively: move-exact <label> <scope> (exact strings, no pickers). The engine under move and retire; refuses tool labels, labels elected elsewhere, unknown scopes, and name collisions.
[group('elect')]
move-exact label scope:
    @bash scripts/move-core.sh {{label}} {{scope}}

# Retire a skill: fzf pick + confirm, then move to keg-only — drop its election, git-mv the cellar entry, re-render (prune removes the bin dir). The keg-only special case of move. Needs a terminal — see retire-exact.
[group('elect')]
retire *args:
    @bash scripts/retire.sh {{args}}

# Retire a skill non-interactively: retire-exact <label>. Alias for move-exact <label> keg-only.
[group('elect')]
retire-exact label:
    @bash scripts/move-core.sh {{label}} keg-only

# Yank a version non-interactively: yank-exact <label> <version> — write the .yanked do-not-elect sentinel beside the cellar version (staged, not committed). Refuses a version any election of that cellar entry still elects, in any harness; version-level sibling of retire.
[group('elect')]
yank-exact label version:
    @bash scripts/yank-core.sh {{label}} {{version}}

# Undo a yank non-interactively: unyank-exact <label> <version> — remove the .yanked sentinel so the version is electable again.
[group('elect')]
unyank-exact label version:
    @bash scripts/yank-core.sh {{label}} {{version}} --undo

# Onboard a repo-targeted scope: scan $FORGE_DEV_ROOT (default ~/dev) for git repos, annotated new / declared-but-unlinked / mislinked / linked, fzf pick one, then declare root + render + link. Arg seeds the query. Needs a terminal — see discover-exact.
[group('scope')]
discover *args:
    @bash scripts/discover.sh {{args}}

# Onboard a repo non-interactively: discover-exact <repo> — declare the root in elections.json if missing, render, link. The engine under discover; idempotent, refuses reserved scope names, multicast scope names and non-repos.
[group('scope')]
discover-exact repo:
    @bash scripts/discover-core.sh {{repo}}

# Link a repo-targeted scope: tree mode (default) symlinks $FORGE_DEV_ROOT/<repo>/.claude/skills (default ~/dev) at the rendered home/claude/repos/<repo>/skills tree, once; per-skill mode (elections.json linkModes) keeps that directory repo-owned and maintains one symlink per elected skill — re-run after election changes. Refuses rather than overwrite anything it doesn't own.
[group('scope')]
link repo:
    @bash scripts/link.sh {{repo}}

# Stamp the sssf-suite into a repo under $FORGE_DEV_ROOT, fzf-picked: stamp [repo] [version]. Needs a terminal — see stamp-exact.
[group('release')]
stamp *args:
    @bash scripts/stamp.sh {{args}}

# Stamp non-interactively and write the receipt: stamp-exact <repo> [version] (default the latest non-yanked keg).
[group('release')]
stamp-exact repo version='':
    @bash scripts/stamp-core.sh {{repo}} {{version}}

# Tour a keg by hand in the one persistent consumer at $FORGE_DEV_ROOT/sssf-playground: playground [version] (default the latest non-yanked keg).
[group('release')]
playground version='':
    @bash scripts/playground.sh {{version}}

# Print this forge's sssf-suite lab — the one repo harvest-plan and harvest-apply accept as a source.
[group('release')]
lab:
    #!/usr/bin/env bash
    set -euo pipefail
    source scripts/env.sh # cd to the descendant's forge/
    lab_file=kegs/sssf-suite/.lab
    lab=
    [[ -f "$lab_file" ]] && lab=$(tr -d '[:space:]' <"$lab_file")
    if [[ -z "$lab" ]]; then
      echo "no lab is set ($lab_file is missing or empty) — write the lab repo's basename to $lab_file, then stamp the new lab" >&2
      exit 1
    fi
    echo "$lab"

# Print the path of one sssf-suite keg: keg [version] (default the latest non-yanked keg). Read twin of lab: lab names the source, keg names the release.
[group('release')]
keg version='':
    @bash scripts/keg-core.sh {{version}}

# Plan the next sssf-suite keg from the lab's committed HEAD: harvest-plan <repo> [major|minor|patch] (default patch). Writes only the plan.
[group('release')]
harvest-plan repo bump='patch':
    @bash scripts/harvest-plan.sh {{repo}} {{bump}}

# Cut the next sssf-suite keg from an approved plan and stage it: harvest-apply <plan>. The dotfiles commit is the release act.
[group('release')]
harvest-apply plan:
    @bash scripts/harvest-apply.sh {{plan}}

# The retired symlink-election machinery (elect, move, fork, archive, ab, run,
# lockfile TUIs) lives on the archive/forge-legacy branch — see README.md § History.
