# UNINSTALL.md — for the agent

You are a coding agent removing **pagma** from this machine. Everything here is
destructive, so: list what you are about to remove, ask, then remove, in that order, for
each of the three stages. The cellar is the person's own authored content — never remove
it without the explicit answer in stage 3.

## 1. The harness links

For each of `~/.claude/skills`, `~/.claude/agents`, `~/.claude/tools`:

- `readlink` it. If it is a symlink whose target is inside this descendant (`$PWD/home/claude/…`), it is pagma's: list it for removal.
- If it is a real directory, or a symlink pointing elsewhere, it is not pagma's: leave it, say so.

Ask, then `rm` the listed symlinks (the links only, never `rm -r`). Nothing else under
`~/.claude` belongs to pagma. The next Claude Code session will no longer see the rendered
skills and agents.

## 2. The bin trees

`home/claude/{skills,agents,tools}` and `forge/scratch/` inside the descendant are
regenerated output. Ask, then remove them. Harmless either way: `just forge render`
recreates them.

## 3. The descendant itself

The repository holds the person's manifest and every skill version they wrote. Ask
explicitly, naming the path, and only on a clear yes remove it. If they want to keep
their skills but drop the engine, the alternative is: keep the repo, remove `forge/engine/`
and the `justfile` mod line, and the cellar remains readable plain files.

## 4. What stays

`bun`, `just`, `jq`, `fzf`, `python3` were installed for pagma but are general tools; list
them so the person can remove them with their package manager if they wish. Report what
was removed and what was left.
