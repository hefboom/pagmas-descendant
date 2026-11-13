# INSTALL.md — for the agent

You are a coding agent setting up **pagma** for the person you are working with. Work
through the steps in order, run the checks, and stop to ask only where this file says
to. Report at the end with the output of the two verification commands.

Vocabulary: the *engine* is this repository, mounted at `forge/engine/` inside a
*descendant*, the repo that holds the person's own skills, agents and manifest.

The person may not know these words, so say the thing before the term. pagma needs one
repository to be the hub that every skill and agent is managed from. The hub holds every
version the person writes, and the one manifest that says which version is live. From it a
skill is either global (every session on the machine sees it) or aimed at a single
repository (only sessions in that repo see it). A repo set up as that hub, a new one or
one they already have, is a *descendant* of pagma: it carries the engine inside it and
takes its updates from it. That noun is the only coined word; the act has none, it is
setting the repo up.

## What to read

This file is the whole install for a machine with nothing in the way. Each situation
below has its own file in `install/`, next to this one. Read a file when its row applies,
and only then:

| When | Read | At |
|---|---|---|
| `uname -s` starts with `MINGW` or `MSYS` (Git Bash on Windows) | `install/windows.md` | before the plan |
| one of `~/.claude/{skills,agents,tools}` is a real directory with content | `install/existing-folder.md` | before the plan, and again in step 4 |
| bun or just has to come from its project's installer script | `install/installers.md` | before the plan, and again in step 1 |
| the person picks "Explain first" | `install/explain.md` | then |
| the machine has pagma but no ledger (uninstall, update) | `install/no-ledger.md` | before removing or updating anything |

## The ledger

Everything this install puts on the machine is written down as it is created: one JSON
object per line in `~/.config/pagma/ledger.jsonl`. `UNINSTALL.md` walks that file, so it
removes exactly what pagma added and can say when nothing is left. Two rules:

- Record a thing only if **this run** created it. A tool that already resolved, a line
  already in an rc file, a link that already pointed here: no line. Uninstall never offers
  to remove what is not on the ledger.
- Record it right after creating it, with `jq -nc` so no quoting is done by hand. There are
  seven kinds, and an eighth on Windows (`install/windows.md`); each step below says when its line is written:

```bash
L="$HOME/.config/pagma/ledger.jsonl"; mkdir -p "$(dirname "$L")"
jq -nc --arg n bun --arg v installer --arg r 'rm -rf "$HOME/.bun"' '{kind:"dep",name:$n,via:$v,remove:$r}' >> "$L"
jq -nc --arg p "$HOME/.config/pagma/env" '{kind:"file",path:$p}' >> "$L"
jq -nc --arg f "$HOME/.profile" --arg t '[ -f "$HOME/.config/pagma/env" ] && . "$HOME/.config/pagma/env"' '{kind:"line",file:$f,text:$t}' >> "$L"
jq -nc --arg p "<clone path>" '{kind:"clone",path:$p}' >> "$L"
jq -nc --arg p "<descendant path>" --argjson i false '{kind:"descendant",path:$p,in_place:$i}' >> "$L"
jq -nc --arg p "$HOME/.claude/skills" --arg t "<descendant path>/home/claude/skills" '{kind:"symlink",path:$p,target:$t}' >> "$L"
jq -nc --arg p "$HOME/.claude/skills" --arg k "$HOME/.claude/skills.before-pagma" '{kind:"aside",path:$p,kept:$k}' >> "$L"
```

Paths are absolute. A `line` or `file` entry for something a tool's own installer left
behind also carries `by` with that tool's name (`--arg b bun`, `by:$b`) and is removed
together with the tool. A `dep` line carries the command that undoes it:

| Installed with | `via` | `remove` |
|---|---|---|
| Homebrew | `brew` | `brew uninstall <name>` |
| apt | `apt` | `sudo apt-get remove <name>` |
| dnf | `dnf` | `sudo dnf remove <name>` |
| the bun installer | `installer` | `rm -rf "$HOME/.bun"` |
| the just installer | `installer` | `rm "$HOME/.local/bin/just"` |
| winget (Windows) | `winget` | `winget uninstall --id <id> -e` |

## Before you change anything

Look first and change nothing: which of the six tools in step 1 are missing (your
before-list), which row of step 2 you are in, and whether `~/.claude/{skills,agents,tools}`
exist. If bun or just will come from an installer script, fetch and read it now (`install/installers.md`).

**An existing folder.** If one of `~/.claude/{skills,agents,tools}` is a real directory
with content, settle it now, before the plan: read `install/existing-folder.md` and ask
its question. The answer goes into the plan's `Links` block.

Then show the person the plan in exactly this layout, filled in for this machine. It is
read in a terminal, often inside a question box that renders no tables, so: one fact per
line, a label with indented lines under it, columns lined up with spaces, nothing that
runs past its line, no paragraphs. Leave out a block that does not apply (no installer
block when the package manager has the tool):

```text
PLAN: nothing has been changed yet

Machine
  system     Ubuntu 24.04, apt, sudo works
  present    git, jq, python3
  missing    bun, just, fzf

Tools to install
  fzf        pickers, for you     apt package          I run it
  bun        runs the renderer    installer script     I run it; if refused, you run it
  just       runs the verbs       installer script     I run it; if refused, you run it

bun installer: read in full, matches the baseline
  downloads  one zip from github.com/oven-sh/bun
  writes     ~/.bun/bin/bun
  rc edits   3 lines appended to ~/.bashrc
  root       no
  also       runs the new bun once for completions

just installer: read in full, matches the baseline
  downloads  one archive from github.com/casey/just
  writes     ~/.local/bin/just
  rc edits   none
  root       no

Files pagma writes
  ~/.config/pagma/env             new: PATH for bun and just, FORGE_ROOT
  ~/.profile                      1 line added
  ~/.bashrc                       1 line added, at the top
  the line                        [ -f "$HOME/.config/pagma/env" ] && . "$HOME/.config/pagma/env"
  ~/.config/pagma/ledger.jsonl    new: the record of everything in this plan

Descendant: the hub repo all your skills and agents are managed from
  ~/pagmas-descendant             new git repo, engine <version> at forge/engine/
  holds                           every version you write, and the manifest of what is live
  serves                          global skills for every session, or skills for one repo

Links
  ~/.claude/skills                to ~/pagmas-descendant/home/claude/skills
  ~/.claude/agents                to ~/pagmas-descendant/home/claude/agents
  ~/.claude/tools                 to ~/pagmas-descendant/home/claude/tools

When you say go ahead
  step 1     I install fzf, bun, just
  step 2     I write the env file and the two rc lines
  step 3     I create ~/pagmas-descendant, mount the engine, build, render
  step 4     I link the three directories and run the two checks
  stops      only if a step is refused or needs your hand
  result     six tools, ~/pagmas-descendant, /hello in a new session
  undo       /pagma-uninstall removes every item on the ledger
```

The values are an example; the labels and their order are fixed. A script that does not
match the baseline says so on its header line, with each difference on its own line under
it. In the bootstrap row of step 2 the descendant line shows the suggested directory, and
"Change the plan" below is where the person moves it: do not ask about it again later.
An explanation has a fixed layout of its own, in `install/explain.md`.

Where each piece goes is fixed too, for every question in this file:

| Piece | Where it goes |
|---|---|
| the plan | ordinary message text, in one code block, the last thing you write before the question |
| an explanation | ordinary message text, in the layout of `install/explain.md` (one block per piece: its name on a line, dash lines under it), the last thing you write before the question |
| the question | your harness's question tool, if it has one: one line (`How do you want to proceed?`) and the choices, a few words each. Without such a tool, list the choices as text and wait |
| an option's preview pane | never. Leave that field out of every option: it shows only while that option is highlighted, so text there is missed, and the other options show an empty pane |

If your harness hides earlier text while a question is open, put the plan or the
explanation into the question's own text instead. Still never into a preview.

Under that, offer the same four choices on every machine, in this order and in these
words. The question comes back after the middle two, until the person picks the first or
the last:

| Choice | What you do |
|---|---|
| **Go ahead** (recommended) | start step 1 |
| **Explain first** | ask which piece they want explained: one tool, one row of the plan, or all of it. Answer from `install/explain.md`, in its layout: one block per piece, never a paragraph. Then ask the four choices again. Do not repeat the plan; it is still above |
| **Change the plan** | a different directory for the descendant, or leave the rc lines to them (below). Show the changed plan and the four choices again |
| **Stop** | change nothing, and say that nothing was changed |

Shell startup files and `~/.claude` are the person's. A harness may refuse to touch them
without the person's say-so, and it is right to: their "go ahead" on this plan is that
say-so. If they leave the rc lines to themselves, skip those and give them the line to add when they choose;
everything else still installs, but new shells will not find bun and just until it is there.

Then work in small commands: one change and its ledger line per command, never a whole
step at once, so a refusal stops one thing and you know which. If the harness still
refuses a change after the person's yes, do not work around it. Hand them the exact lines
to run, and continue once that step's check passes.

## 1. Prerequisites

The engine needs `git`, `bun`, `just` **1.31 or newer**, `jq`, `fzf`, `python3`. Check
each with `command -v`, and `just --version` against the floor: the engine's justfile uses
`[group]` and `mod`, and distro packages are often older (Ubuntu 24.04 ships 1.21). Write
down which names are missing, or for just too old, **before** you install anything: that
list is what the ledger records. Install only what is missing, with the person's package
manager:

| OS | Command |
|---|---|
| macOS (Homebrew) | `brew install bun just jq fzf python3` |
| Debian / Ubuntu | `sudo apt-get update && sudo apt-get install -y git jq fzf python3` then bun and just from their installer scripts |
| Fedora | `sudo dnf install -y git jq fzf python3 just` then bun from its installer script; check the just version |
| Windows (Git Bash) | `winget`, one tool per command: `install/windows.md`. Inside WSL2, use the Linux row |

bun (when the package manager has no package for it) and just (when the package manager's
is missing or below 1.31) come from their projects' installer scripts. Never pipe one into
a shell unread: `install/installers.md` says how each is fetched, read and run.

Both land outside the default `PATH`. pagma owns one shell file for that and for the
descendant's location, sourced by one guarded line per rc file — the rustup pattern
(`~/.cargo/env`). Write `~/.config/pagma/env` (create the directory) with exactly:

```bash
# pagma — sourced by the shell rc files; remove with UNINSTALL.md
export PATH="$HOME/.bun/bin:$HOME/.local/bin:$PATH"
```

`FORGE_ROOT` is added to it in step 2, once the descendant's path is known. Then add this
line, alone with no blank line around it and only if it is not already there (grep first), to `~/.profile` and to the **top** of
`~/.bashrc` (Ubuntu's `.bashrc` returns early for non-interactive shells, so a line below
that guard never reaches a tool's shell), or to `~/.zprofile` and `~/.zshrc` on macOS:

```bash
[ -f "$HOME/.config/pagma/env" ] && . "$HOME/.config/pagma/env"
```

Source the file in your current shell too. If your harness starts every command in a fresh
shell, its picture of the startup files was taken before this file existed: begin each
later command with `. "$HOME/.config/pagma/env";` until the session is restarted.

Check, in a fresh shell rather than the current one. Both print two paths:
`bash -lc 'command -v bun just'`, a login shell, and
`bash -c '. "$HOME/.bashrc"; command -v bun just'`, what a tool does when it loads the rc
file without a terminal. A bare `bash -c` reads no startup file at all and proves nothing.

Check: every one of the six names resolves with `command -v`, and `just --version` is 1.31 or newer.

Ledger: one `dep` line for each name on your before-list that now resolves, whoever typed
the command (a line you handed to the person counts). Tools that were already there get
none. Then a `file` line for `~/.config/pagma/env` if you created it, and a `line` line for
each rc file you added the source line to. From the two listings after the installers: each
non-blank line one of them added to a startup file is a `line` entry with `by`, and a file
that is plainly its own outside its directory (a completions file) is a `file` entry with
`by`. Skip what the ledger already covers.

## 2. The descendant

Decide which case you are in by looking at the current directory:

| You see | Case | Do |
|---|---|---|
| `VERSION` and `scripts/render.ts` in the directory itself, origin `hefboom/pagma` | a clone of the engine repo: the bootstrap case | never mount the engine into itself. **Ask where the descendant should live.** Suggest `~/pagmas-descendant`; offer an existing repo the person already keeps their shell or editor config in, which becomes the descendant in place. Create the directory if needed, then continue with the row that matches it, running every later command in that directory (`cd` or absolute paths; your session stays rooted in the clone). Record a `clone` line for the directory you are standing in. In step 5, add the cleanup line. |
| `forge/elections.json` and `forge/engine/VERSION` | an existing descendant (a clone of a template, or a second machine) | nothing here, go to step 3 |
| `forge/engine/VERSION` but no `forge/elections.json` | engine mounted, not yet scaffolded | `bash forge/engine/scripts/init.sh`, go to step 4 |
| neither, inside a git repo | a repo that should become a descendant | mount the engine (below), then `init.sh` |
| neither, not a git repo | nothing yet | `git init && git commit --allow-empty -m init`, then mount the engine, then `init.sh` |

Mount the engine as a git subtree at a pinned tag, never a clone or a fork:

```bash
git subtree add --prefix forge/engine https://github.com/hefboom/pagma.git v0.1.30 --squash
```

Check: `cat forge/engine/VERSION` prints `0.1.30`.

Now record the descendant's location: append `export FORGE_ROOT="<absolute path of the
descendant>"` to `~/.config/pagma/env` (replace an existing `FORGE_ROOT` line), and export
it in the current shell. The engine finds the descendant by walking up from its own
location, but skills that run from any cwd (the bundled `prime-forge`) need the variable.

Ledger: one `descendant` line, always, whichever row you came through: it is where pagma
lives on this machine. `in_place` is `true` when the directory is the person's own repo
holding things other than pagma (their config repo), `false` when it exists only to be the
descendant (created now, empty before, or a clone of the template). Uninstall never removes
an in-place directory, only pagma's paths inside it.

## 3. Build

```bash
just forge install      # bun install inside forge/engine
just forge render       # writes the bin trees under home/
```

## 4. Link the harness to the bin trees

The engine renders into `home/claude/{skills,agents,tools}` inside the descendant and
never writes outside it. The harness reads `~/.claude/{skills,agents,tools}`. One
symlink per directory connects them, three in all: `skills`, `agents`, `tools` (render
creates all three roots, empty or not). For each:

- `~/.claude/<dir>` does not exist → `ln -s "$PWD/home/claude/<dir>" ~/.claude/<dir>`
- it is a real directory and empty → `rmdir ~/.claude/<dir>`, which refuses a directory with content, then link as above
- it is already a symlink → read its target, show the person, ask before repointing
- it is a real directory with content → the person answered this before the plan ("An existing folder"). Act on that answer as `install/existing-folder.md` says. Never delete or overwrite what is there.

Check: `readlink ~/.claude/skills` prints a path ending in `home/claude/skills`.

Ledger: a `symlink` line for each link you created. If you repointed an existing link, add
its old target as `replaced` (`--arg w "<old target>"`, `replaced:$w`), so uninstall can
offer to point it back.

## 5. Verify and report

```bash
just forge status
just forge render --check
```

Pass looks like: every row's LIVE column says `ok`, and the gate prints
`N/N elections render byte-identical to the live bin trees`. Report both outputs, the
OS and package manager you used, and anything you installed. Close the ledger (drop
repeated lines from a re-run) and include it in the report, so the person sees everything
that was put on the machine:

```bash
L="$HOME/.config/pagma/ledger.jsonl"; awk '!seen[$0]++' "$L" > "$L.tmp" && mv "$L.tmp" "$L"; cat "$L"
```

The scaffold is
uncommitted; offer to commit it (`git add -A && git commit -m "pagma: descendant"`). If you
started in a clone of the engine (the bootstrap row), say that the clone is now redundant,
since the descendant carries its own copy of the engine, and give the person the line to
run after they open a session in the descendant: `rm -rf <path of the clone>`. Do not run
it yourself; it is the directory your session is in. Then tell the person:
a new session will have the starter set (`/hello`, `/prime-forge`, `/systems-architect`
and the six tier agents; `README.md` § Starter set says what each is for). `/prime-forge`
is the one to run first: it teaches their agent the forge. The authoring loop is

```bash
cp -R forge/skills/global/hello/v1.0.0 forge/skills/global/<name>/v1.0.0
$EDITOR forge/skills/global/<name>/v1.0.0/SKILL.md
just forge elect-exact claude-code/global/<name> v1.0.0
```

End with the one recommendation, in the same one-fact-per-line shape: before handing it
all to an agent, drive it by hand once, in a terminal inside the descendant.

```text
By hand, once
  just forge view      browse what is elected, with a detail pane
  just forge elect     change an election with pickers
  why                  each is the twin of a verb your agent runs (show, elect-exact)
  so                   you see what the agent can do by doing it yourself
```

If anything in this file did not match what you found, say so in the report — that is
a bug in this file.
