# A machine without a ledger

Part of `INSTALL.md` § The ledger, which has the line formats: read this from
`UNINSTALL.md` or `UPDATE.md` when the machine has pagma but no
`~/.config/pagma/ledger.jsonl`.

**A machine without one.** An install from before v0.1.11, or one done by hand, has no
ledger. Build it by inspection with the same lines, and tell the person the list is
inferred, not recorded:

- `symlink`: each of `~/.claude/{skills,agents,tools}` that is a symlink into the descendant, and the descendant's own `.claude/skills` if it is a link to its `home/claude/repos/hub/skills`.
- `aside`: each `~/.claude/{skills,agents,tools}.before-pagma` that exists.
- `file`: `~/.config/pagma/env`, if it exists.
- `line`: each of `~/.profile`, `~/.bashrc`, `~/.zprofile`, `~/.zshrc` that carries the source line (`grep -xF`).
- `uservar`, on Windows: the user variable `FORGE_ROOT`, if it is set and names the descendant (`install/windows.md` has the command that reads it).
- `descendant`: its path. Ask whether the directory was the person's before pagma (`in_place`, step 2); `true` if unsure.
- `dep`: inspection cannot tell who installed a tool. Ask which of the six the person installed for pagma and record those, `via` read from where `command -v` finds the binary. No answer, no `dep` lines.
- `line` with `by: bun`, only if bun got a `dep` line through its installer: the lines that installer leaves in a startup file (`grep -n '^# bun$\|BUN_INSTALL' ~/.bashrc ~/.bash_profile ~/.zshrc`).
