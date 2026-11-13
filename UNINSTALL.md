# UNINSTALL.md — for the agent

You are a coding agent removing **pagma** from this machine. Everything here is
destructive, so each stage goes: show what the ledger lists, check it is still what was
installed, ask, remove, confirm it is gone. The cellar is the person's own authored
content — never remove it without the explicit answer in stage 6.

## 1. Read the ledger

```bash
cat ~/.config/pagma/ledger.jsonl
```

One JSON object per line, written by `INSTALL.md` as each thing was created: the complete
list of what pagma put on this machine. If the file is absent (an install from before
v0.1.11, or one done by hand), build it first by inspection, following "A machine without
one" in `forge/engine/INSTALL.md` § The ledger, and say that the list is inferred.

Show the person the whole list as a table (kind, what, where) before removing anything.
Read it once and keep it: a later stage may remove `jq`, and you report against this list
at the end. Every entry ends in one of four states:

| State | Meaning |
|---|---|
| removed | it matched the ledger, the person said yes, and you checked it is gone |
| already gone | nothing is at that path any more |
| changed, left | something is there, but not what pagma created; not pagma's to remove |
| kept | the person said no |

Anything not on the ledger is not pagma's. Do not offer to remove it.

## 2. The harness links

For each `symlink` entry, `readlink` its `path`:

- it prints the entry's `target` → pagma's link, list it for removal
- it is a real directory, or a link pointing elsewhere → changed, left; say so

Where skills were linked one by one, links made after the install are not on the ledger.
List those too, marked as inferred: every link directly under `~/.claude/skills` whose
`readlink` points inside the descendant's `home/claude/skills/`. Its target says it is
pagma's.

Ask, then `rm` the listed links (the links only, never `rm -r`). If an entry has a
`replaced` field, offer to point the link back: `ln -s "<replaced>" "<path>"`. Nothing
else under `~/.claude` belongs to pagma. The next Claude Code session will no longer see
the rendered skills and agents.

On Windows the links are junctions (`INSTALL.md` § On Windows). `readlink` and a plain
`rm` treat one as a symlink, and `rm` leaves the descendant's contents in place; `rm -r`
may not. To point a link back, use the junction command there, not `ln -s`.

## 3. The shell file

The `file` entry for `~/.config/pagma/env` and each `line` entry without a `by` field: the
guarded line that sources it. Entries that carry `by` were left by a tool's own installer
and wait for stage 4. Check each `line` entry is still there verbatim:
`grep -cxF -- "<text>" "<file>"` prints 1. List them, ask, then delete the env file and
remove exactly that line from each rc file, nothing else in them. Write through the file
rather than replacing it, since rc files are often symlinks into a config repo:

```bash
f="<file>"; t='<text>'
grep -vxF -- "$t" "$f" > "$f.pagma-tmp"; [ $? -le 1 ] && cat "$f.pagma-tmp" > "$f"; rm -f "$f.pagma-tmp"
```

Check: the `grep -cxF` above now prints 0 for each rc file, and the env file is absent.
bun and just leave `PATH` in new shells from here on; the current shell keeps them until
it closes.

## 4. The dependencies

Only the `dep` entries: tools that were missing before the install and that it added. A
tool with no `dep` line was on the machine before pagma and is never offered. Take them
one at a time:

1. `command -v <name>`. If it no longer resolves: already gone.
2. Say what it is, and show what removing it would take along:

   | `via` | Look first |
   |---|---|
   | `apt` | `apt-get -s remove <name>` (a simulation; lists every package that would go) |
   | `dnf` | `dnf remove --assumeno <name>` |
   | `brew` | `brew uses --installed <name>` (what else needs it) |
   | `installer`, bun | `ls "$HOME/.bun/bin"` and `bun pm ls -g` (global packages live in the same tree) |
   | `installer`, just | nothing else; it is one binary |
   | `winget` | `winget list --id <id> -e`, the id from the entry's `remove` command (one package; nothing else goes with it) |

3. Ask yes or no for this one tool. The default is no: the person may use it for other
   things by now. For `git` and `python3`, say plainly that other software commonly
   depends on them.
4. On yes, run the entry's `remove` command as recorded. The look in step 2 plus the
   person's yes is the confirmation, so a `-y` flag is fine after it and never before. If
   the command needs `sudo` you do not have, or your harness refuses it, hand the line to
   the person and continue once `command -v <name>` no longer resolves.
5. Then remove the entries that carry `by: <name>`, which its installer left behind: lines
   with the stage 3 snippet, files with `rm`. On a no, they stay with the tool.

## 5. The bootstrap clone

The `clone` entry, if there is one: the copy of the engine repo the install started from.
If the path is gone: already gone. If it is there, check it is still an engine clone
(`VERSION` and `scripts/render.ts` at its root), ask, and `rm -rf` it. If your session is
standing in it, do not run that yourself: give the person the line.

## 6. The descendant

The `descendant` entry. It holds the person's manifest and every skill version they wrote,
so this is the one question that needs an explicit answer naming the path. What you may
offer depends on `in_place`.

**`in_place: false`** — the directory exists only to be the descendant. Ask whether to
remove it, naming the path, and act only on a clear yes. The removal itself happens in
stage 7. If they want to keep their skills, the directory stays as plain readable files:
offer to remove just the regenerated output (`home/claude/{skills,agents,tools}`,
`forge/scratch/`) and, if they want the engine gone too, `forge/engine/` and the `mod forge`
line of the `justfile`.

**`in_place: true`** — the person's own repo, with pagma living inside it. Never remove
the directory. pagma's paths inside it:

| Path | What it is | Ask |
|---|---|---|
| `home/claude/{skills,agents,tools}`, `forge/scratch/` | rendered output, regenerable | once for the group |
| `forge/engine/` | the engine mount | once |
| `.claude/skills/pagma-{install,update,uninstall}/` | the three pointer skills | once |
| `forge/elections.json`, `forge/skills/`, `forge/agents/`, `forge/tools/` | the cellar: the person's authored content | explicitly, naming it; keep unless they say remove |
| `justfile`, `.gitignore`, `.gitattributes`, `AGENTS.md` | shared files that may predate pagma | show pagma's lines in each, ask per file; remove those lines, or the file if nothing else is in it |

Leave the result uncommitted and show `git status --short`, so the person reviews the
removal and commits it themselves.

## 7. Close the ledger

Check every entry once more against its final state: links absent, env file absent, rc
lines at count 0, removed tools no longer resolving, removed directories absent.

The ledger ends holding exactly what pagma still has on the machine. A dependency or a
descendant the person chose to keep is theirs from now on and comes off the list, a tool
together with its `by` entries. If
that leaves entries (changed, or the person stopped partway), rewrite the ledger to those
lines and say that a later uninstall finishes the job.

If it leaves none, close with one last line. Include the `rm -rf` and its check only on the
stage 6 yes. The line checks its own result, so whoever runs it sees the outcome:

```bash
cd "$HOME" && rm -rf "<descendant path>" && rm -f "$HOME/.config/pagma/ledger.jsonl" && rmdir "$HOME/.config/pagma" && [ ! -e "<descendant path>" ] && [ ! -e "$HOME/.config/pagma" ] && echo "pagma: nothing remains on this machine"
```

If your session is standing in the descendant, which it normally is, do not run this
yourself: it deletes the directory you are working in. Give the line to the person, and in
the report mark the descendant and the ledger as closed by that line. Otherwise run it.

## 8. Report

One row per ledger entry: what it was, where, and its final state. Then:

- If every row is `removed` or `already gone`, say so in these words: **nothing pagma
  created remains on this machine.**
- If the closing line is the person's to run, say that the descendant and the ledger are
  all that is left, and that the line prints that same sentence when it has succeeded.
- Otherwise list what remains and why (kept by the person, or changed since install).

Then what was never pagma's, so the person is not left wondering: tools that were on the
machine before the install; the harness's own session history under `~/.claude/projects/`;
and, if bun stays, its package cache (`bun pm cache rm` clears it). If a step in this
file did not match what you found, say so — that is a bug in this file.
