# Changelog

One entry per tag. A `manifest:` line is a change a descendant's `forge/elections.json`
needs by hand when crossing that version — `UPDATE.md` applies them in order.

## v0.1.10
- The clone is a first-class bootstrap: the engine repo ships `/pagma-install` and `AGENTS.md` at its root; `INSTALL.md`'s engine-clone row asks where the descendant should live (suggests `~/prompts`, or an existing config repo in place), continues there, and ends with the cleanup line for the clone. Five agents stood in a clone today.

## v0.1.9
- `UPDATE.md` re-plants rare-book files that are absent in the descendant (`.claude/skills/*`, `AGENTS.md`), so skills added after a descendant was scaffolded arrive on update. Found live: a v0.1.2 descendant updated to v0.1.7 had no `/pagma-update`.

## v0.1.8
- `~/.config/pagma/env` owns PATH and `FORGE_ROOT`, sourced by one guarded line per rc file (rustup pattern). `INSTALL.md` writes it, `UNINSTALL.md` removes it.
- manifest: none. Shell: migrate the bare `export PATH=…` lines from `~/.profile`/`~/.bashrc` into `~/.config/pagma/env` and replace them with the source line (`INSTALL.md` § 1).

## v0.1.7
- `INSTALL.md`: PATH for bun and just goes in `~/.profile` and the top of `~/.bashrc`, checked from a fresh non-interactive shell. Second live run: `.bashrc`'s interactive guard hid bun from the next agent.

## v0.1.6
- `UPDATE.md` + `/pagma-update`, `UNINSTALL.md` + `/pagma-uninstall`, this changelog.

## v0.1.5
- Render materializes `toolsRoot`; the rare book declares it. The harness link is always three symlinks.
- manifest: `.harnesses["claude-code"] += {toolsRoot: "home/claude/tools", toolsOpt: "~/.claude/tools", tools: {}}`, then `ln -s "$PWD/home/claude/tools" ~/.claude/tools`.

## v0.1.4
- `INSTALL.md`: just 1.31 floor, fallback installer, hand-to-person rule. `init.sh` gates on the just version.

## v0.1.3
- `INSTALL.md`: a row for standing in a clone of the engine itself.

## v0.1.2
- The rare book ships `.claude/skills/pagma-install/` and `AGENTS.md`.

## v0.1.1
- `INSTALL.md`, agent-native install. README quickstart leads with the paste.

## v0.1.0
- `scripts/init.sh`, `examples/descendant/`, stranger README, MIT.

## v0.0.1
- The engine, extracted. Manifest `engine` pin checked against `VERSION`.
