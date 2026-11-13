# INSTALL.md — for the agent

You are a coding agent setting up **pagma** for the person you are working with. Work
through the steps in order, run the checks, and stop to ask only where this file says
to. Report at the end with the output of the two verification commands.

Vocabulary: the *engine* is this repository, mounted at `forge/engine/` inside a
*descendant*, the repo that holds the person's own skills, agents and manifest.

## The ledger

Everything this install puts on the machine is written down as it is created: one JSON
object per line in `~/.config/pagma/ledger.jsonl`. `UNINSTALL.md` walks that file, so it
removes exactly what pagma added and can say when nothing is left. Two rules:

- Record a thing only if **this run** created it. A tool that already resolved, a line
  already in an rc file, a link that already pointed here: no line. Uninstall never offers
  to remove what is not on the ledger.
- Record it right after creating it, with `jq -nc` so no quoting is done by hand. There are
  six kinds; each step below says when its line is written:

```bash
L="$HOME/.config/pagma/ledger.jsonl"; mkdir -p "$(dirname "$L")"
jq -nc --arg n bun --arg v installer --arg r 'rm -rf "$HOME/.bun"' '{kind:"dep",name:$n,via:$v,remove:$r}' >> "$L"
jq -nc --arg p "$HOME/.config/pagma/env" '{kind:"file",path:$p}' >> "$L"
jq -nc --arg f "$HOME/.profile" --arg t '[ -f "$HOME/.config/pagma/env" ] && . "$HOME/.config/pagma/env"' '{kind:"line",file:$f,text:$t}' >> "$L"
jq -nc --arg p "<clone path>" '{kind:"clone",path:$p}' >> "$L"
jq -nc --arg p "<descendant path>" --argjson i false '{kind:"descendant",path:$p,in_place:$i}' >> "$L"
jq -nc --arg p "$HOME/.claude/skills" --arg t "<descendant path>/home/claude/skills" '{kind:"symlink",path:$p,target:$t}' >> "$L"
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

**A machine without one.** An install from before v0.1.11, or one done by hand, has no
ledger. Build it by inspection with the same lines, and tell the person the list is
inferred, not recorded:

- `symlink`: each of `~/.claude/{skills,agents,tools}` that is a symlink into the descendant.
- `file`: `~/.config/pagma/env`, if it exists.
- `line`: each of `~/.profile`, `~/.bashrc`, `~/.zprofile`, `~/.zshrc` that carries the source line (`grep -xF`).
- `descendant`: its path. Ask whether the directory was the person's before pagma (`in_place`, step 2); `true` if unsure.
- `dep`: inspection cannot tell who installed a tool. Ask which of the six the person installed for pagma and record those, `via` read from where `command -v` finds the binary. No answer, no `dep` lines.
- `line` with `by: bun`, only if bun got a `dep` line through its installer: the lines that installer leaves in a startup file (`grep -n '^# bun$\|BUN_INSTALL' ~/.bashrc ~/.bash_profile ~/.zshrc`).

## Before you change anything

Look first and change nothing: which of the six tools in step 1 are missing (your
before-list), which row of step 2 you are in, and whether `~/.claude/{skills,agents,tools}`
exist. If bun or just will come from an installer script, fetch and read it now (step 1).
Then show the person the plan as one list:

| What | Where |
|---|---|
| tools to install | the missing ones; for each installer script, the four answers from reading it (step 1); and which of them the person may have to run themselves |
| a shell file | `~/.config/pagma/env`, new |
| one line that sources it | added to `~/.profile` and the top of `~/.bashrc` (`~/.zprofile` and `~/.zshrc` on macOS); show the line |
| the ledger | `~/.config/pagma/ledger.jsonl`, the record of everything on this list |
| the descendant | its directory; in the bootstrap row of step 2, ask where it should live as part of this question, and not again later |
| three links | `~/.claude/{skills,agents,tools}`, pointing into the descendant |

Close the plan by saying what happens once they agree, in order and in plain words, five
sentences at most, so the person agrees to a sequence and not to a table:

1. what you will run yourself, start to finish
2. where you will stop and hand them a command: an installer the harness will not run, a `sudo` you do not have
3. what the machine has at the end: the tools, the descendant at its path, `/hello` in a new session
4. that every item goes on the ledger, and `/pagma-uninstall` takes all of it back

Under that, offer the same four choices on every machine, in this order and in these
words. The question comes back after the middle two, until the person picks the first or
the last:

| Choice | What you do |
|---|---|
| **Go ahead** (recommended) | start step 1 |
| **Explain first** | ask which piece they want explained: one tool, one row of the plan, or all of it. Answer from the table below, in their terms and as briefly as it allows, then show the plan and the four choices again |
| **Change the plan** | a different directory for the descendant, or leave the rc lines to them (below). Show the changed plan and the four choices again |
| **Stop** | change nothing, and say that nothing was changed |

Why each piece is there. Explain from this, not from memory:

| Piece | What pagma uses it for | Without it |
|---|---|---|
| `git` | mounts the engine inside the descendant as a subtree pinned to a tag; an update pulls the next tag | no install, no update |
| `bun` | runs the renderer, the TypeScript that turns the manifest into the skill and agent files the harness reads | nothing renders |
| `just` | the command runner: every verb (`just forge render`, `status`, `elect-exact`) is a recipe in the engine's justfile, which needs 1.31 for its syntax | no verbs |
| `jq` | reads and edits the manifest `forge/elections.json` inside the verbs, and writes the ledger | no election can change |
| `fzf` | the pickers in the interactive verbs (`elect`, `move`, `retire`, `discover`) | only those verbs stop; the `-exact` ones do not use it. The setup check still asks for all six |
| `python3` | one read-only report, `just forge edges` | only that report stops. The setup check still asks for all six |
| `~/.config/pagma/env` | bun and just install outside the default `PATH`; this file puts them on it and records where the descendant is (`FORGE_ROOT`) | new shells find neither the tools nor the descendant |
| the rc lines | one line per startup file that reads the env file; two files because login shells and the shells tools start read different ones | the env file is never read |
| the ledger | the record uninstall walks, so removal is exact and can end on "nothing remains" | uninstall falls back to inspecting the machine |
| the descendant | the person's own repo: the manifest, every skill and agent version they write, and the engine mounted inside | nowhere for their skills to live |
| the three links | the harness reads `~/.claude/…`, the engine renders inside the descendant; the links join the two | the harness sees no rendered skills |

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
| Debian / Ubuntu | `sudo apt-get update && sudo apt-get install -y git jq fzf python3` then bun and just below |
| Fedora | `sudo dnf install -y git jq fzf python3 just` then bun below; check the just version |
| Windows | stop — use WSL2 and run this file inside it; native Windows is not supported |

bun (when the package manager has no package for it) and just (when the package manager's
is missing or below 1.31) come from their projects' installer scripts. Never pipe one into
a shell unread. Fetch it to a file while you are still looking, read all of it, and later
run that same file. This is how an installer is run here, not a second attempt after a
refusal. Note the directory's path; shell variables do not survive between your commands:

```bash
d=$(mktemp -d); echo "$d"
curl -fsSL https://bun.sh/install -o "$d/bun-install.sh"
curl -sSf https://just.systems/install.sh -o "$d/just-install.sh"
```

Answer four questions from each script itself, and put the answers in the plan:

| Question | bun's script, when this was written | just's script, when this was written |
|---|---|---|
| What does it download, and from where? | one release zip from `github.com/oven-sh/bun` | one release archive from `github.com/casey/just`, after asking `api.github.com` for the newest tag |
| Where does it write? | `~/.bun/bin/bun` | one binary in the `--to` directory |
| Does it edit shell startup files? | yes: it appends `# bun` and two `export` lines to the first writable of `~/.bash_profile`, `~/.bashrc` (bash), or to `~/.zshrc` (zsh) | no |
| Does it ask for root, or run what it downloaded? | no root; it runs the new `bun` once to place shell completions | neither |

The two right-hand columns are a baseline, not the answer: report what you read. A
different host, a `sudo`, a write outside the home directory, or code you cannot follow is
a stop: do not run it, and show the person what you found. Reading the script tells you
what the script does, not what is inside the binary it fetches. That trust rests on the
project and its release host; say so if the person asks.

Run each from the file you read. Take a marker and a copy of the startup files first, so
whatever the installer leaves behind can go on the ledger:

```bash
touch "$d/marker"; for f in .profile .bash_profile .bashrc .zprofile .zshrc; do [ -f "$HOME/$f" ] && cp "$HOME/$f" "$d/before$f"; done
bash "$d/bun-install.sh"
bash "$d/just-install.sh" --to "$HOME/.local/bin"
# lines an installer added to a startup file:
for f in .profile .bash_profile .bashrc .zprofile .zshrc; do [ -f "$d/before$f" ] && diff "$d/before$f" "$HOME/$f" | sed -n 's/^> //p'; done
# files it left outside its own directory:
find "$HOME" -maxdepth 5 -type f -newer "$d/marker" -not -path "$HOME/.bun/*" -not -path "$HOME/.claude/*" -not -path "$HOME/.cache/*" -not -path "$HOME/Library/*"
```

If your harness refuses to run an installer, do not work around it: hand the person that
same command, `bash <the file you read>`, together with your four answers, so they know
what they are running. Continue once the version check passes.

Both land outside the default `PATH`. pagma owns one shell file for that and for the
descendant's location, sourced by one guarded line per rc file — the rustup pattern
(`~/.cargo/env`). Write `~/.config/pagma/env` (create the directory) with exactly:

```bash
# pagma — sourced by the shell rc files; remove with UNINSTALL.md
export PATH="$HOME/.bun/bin:$HOME/.local/bin:$PATH"
```

`FORGE_ROOT` is added to it in step 2, once the descendant's path is known. Then add this
line, if it is not already there (grep first), to `~/.profile` and to the **top** of
`~/.bashrc` (Ubuntu's `.bashrc` returns early for non-interactive shells, so a line below
that guard never reaches a tool's shell), or to `~/.zprofile` and `~/.zshrc` on macOS:

```bash
[ -f "$HOME/.config/pagma/env" ] && . "$HOME/.config/pagma/env"
```

Source the file in your current shell too. If your harness starts every command in a fresh
shell, its picture of the startup files was taken before this file existed: begin each
later command with `. "$HOME/.config/pagma/env";` until the session is restarted.

Check, in a fresh shell rather than the current one:
`bash -lc 'command -v bun just'` and `bash -c 'command -v bun just'` both print two paths.

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
| `VERSION` and `scripts/render.ts` in the directory itself, origin `hefboom/pagma` | a clone of the engine repo: the bootstrap case | never mount the engine into itself. **Ask where the descendant should live.** Suggest `~/prompts`; offer an existing repo the person already keeps their shell or editor config in, which becomes the descendant in place. Create the directory if needed, then continue with the row that matches it, running every later command in that directory (`cd` or absolute paths; your session stays rooted in the clone). Record a `clone` line for the directory you are standing in. In step 5, add the cleanup line. |
| `forge/elections.json` and `forge/engine/VERSION` | an existing descendant (a clone of a template, or a second machine) | nothing here, go to step 3 |
| `forge/engine/VERSION` but no `forge/elections.json` | engine mounted, not yet scaffolded | `bash forge/engine/scripts/init.sh`, go to step 4 |
| neither, inside a git repo | a repo that should become a descendant | mount the engine (below), then `init.sh` |
| neither, not a git repo | nothing yet | `git init && git commit --allow-empty -m init`, then mount the engine, then `init.sh` |

Mount the engine as a git subtree at a pinned tag, never a clone or a fork:

```bash
git subtree add --prefix forge/engine https://github.com/hefboom/pagma.git v0.1.15 --squash
```

Check: `cat forge/engine/VERSION` prints `0.1.15`.

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
- it is already a symlink → read its target, show the person, ask before repointing
- it is a real directory with content → **stop and ask**. The person has hand-placed
  skills there. Offer two paths: move them into the cellar (one `forge/skills/global/<name>/v1.0.0/` each, then elect), or leave the directory and link per skill. Do not delete or overwrite anything.

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
a new session will have `/hello`, and the authoring loop is

```bash
cp -R forge/skills/global/hello/v1.0.0 forge/skills/global/<name>/v1.0.0
$EDITOR forge/skills/global/<name>/v1.0.0/SKILL.md
just forge elect-exact claude-code/global/<name> v1.0.0
```

If anything in this file did not match what you found, say so in the report — that is
a bug in this file.
