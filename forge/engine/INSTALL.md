# INSTALL.md — for the agent

You are a coding agent setting up **pagma** for the person you are working with. Work
through the steps in order, run the checks, and stop to ask only where this file says
to. Report at the end with the output of the two verification commands.

Vocabulary: the *engine* is this repository, mounted at `forge/engine/` inside a
*descendant*, the repo that holds the person's own skills, agents and manifest.

## 1. Prerequisites

The engine needs `git`, `bun`, `just`, `jq`, `fzf`, `python3`. Check each with
`command -v`. Install only what is missing, with the person's package manager:

| OS | Command |
|---|---|
| macOS (Homebrew) | `brew install bun just jq fzf python3` |
| Debian / Ubuntu | `sudo apt-get update && sudo apt-get install -y git jq fzf python3 just` then bun below |
| Fedora | `sudo dnf install -y git jq fzf python3 just` then bun below |
| Windows | stop — use WSL2 and run this file inside it; native Windows is not supported |

bun, when the package manager has no package for it:
`curl -fsSL https://bun.sh/install | bash`, then make sure `$HOME/.bun/bin` is on `PATH`
for this shell and in the person's shell rc. just, when apt has no package for it:
`curl -sSf https://just.systems/install.sh | bash -s -- --to ~/.local/bin`.

Check: every one of the six names resolves with `command -v`.

## 2. The descendant

Decide which case you are in by looking at the current directory:

| You see | Case | Do |
|---|---|---|
| `forge/elections.json` and `forge/engine/VERSION` | an existing descendant (a clone of a template, or a second machine) | nothing here, go to step 3 |
| `forge/engine/VERSION` but no `forge/elections.json` | engine mounted, not yet scaffolded | `bash forge/engine/scripts/init.sh`, go to step 4 |
| neither, inside a git repo | a repo that should become a descendant | mount the engine (below), then `init.sh` |
| neither, not a git repo | nothing yet | `git init && git commit --allow-empty -m init`, then mount the engine, then `init.sh` |

Mount the engine as a git subtree at a pinned tag, never a clone or a fork:

```bash
git subtree add --prefix forge/engine https://github.com/hefboom/pagma.git v0.1.1 --squash
```

Check: `cat forge/engine/VERSION` prints `0.1.1`.

## 3. Build

```bash
just forge install      # bun install inside forge/engine
just forge render       # writes the bin trees under home/
```

## 4. Link the harness to the bin trees

The engine renders into `home/claude/{skills,agents,tools}` inside the descendant and
never writes outside it. The harness reads `~/.claude/{skills,agents,tools}`. One
symlink per directory connects them. For each of `skills`, `agents`, and `tools` (tools
only if `home/claude/tools` exists):

- `~/.claude/<dir>` does not exist → `ln -s "$PWD/home/claude/<dir>" ~/.claude/<dir>`
- it is already a symlink → read its target, show the person, ask before repointing
- it is a real directory with content → **stop and ask**. The person has hand-placed
  skills there. Offer two paths: move them into the cellar (one `forge/skills/global/<name>/v1.0.0/` each, then elect), or leave the directory and link per skill. Do not delete or overwrite anything.

Check: `readlink ~/.claude/skills` prints a path ending in `home/claude/skills`.

## 5. Verify and report

```bash
just forge status
just forge render --check
```

Pass looks like: every row's LIVE column says `ok`, and the gate prints
`N/N elections render byte-identical to the live bin trees`. Report both outputs, the
OS and package manager you used, and anything you installed. Then tell the person:
a new session will have `/hello`, and the authoring loop is

```bash
cp -R forge/skills/global/hello/v1.0.0 forge/skills/global/<name>/v1.0.0
$EDITOR forge/skills/global/<name>/v1.0.0/SKILL.md
just forge elect-exact claude-code/global/<name> v1.0.0
```

If anything in this file did not match what you found, say so in the report — that is
a bug in this file.
