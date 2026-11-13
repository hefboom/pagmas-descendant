# Changelog

One entry per tag. A `manifest:` line is a change a descendant's `forge/elections.json`
needs by hand when crossing that version — `UPDATE.md` applies them in order.

## v0.1.27
- On Windows the install also stores `FORGE_ROOT` as a user variable, recorded on the ledger as `uservar`, and `UNINSTALL.md` removes it. Found live: Claude Code started from PowerShell runs its commands in a Git Bash that reads no startup file, so `FORGE_ROOT` was empty there, while a session started from a Git Bash window had it. The engine's own verbs were not affected, since they find the descendant by walking up; a skill that runs from another directory would have been.
- manifest: none. Machine: on Windows, if the user variable `FORGE_ROOT` is not set, set it and add its `uservar` line to the ledger (`install/windows.md`, the `FORGE_ROOT` paragraph).

## v0.1.26
- `install/explain.md` has a block for the manifest: what the file is, that rendering writes exactly what it lists, and how it is changed. Before, the word appeared in three other blocks and was explained in none.
- manifest: none.

## v0.1.25
- An explanation has a fixed layout: one block per piece, its name on a line and one to four dash lines under it, the last saying what stops without it. `install/explain.md` now holds the blocks in that layout, to be copied. v0.1.23 had asked for plain sentences, and the answer to "Explain first" came out as one run-on paragraph.
- manifest: none.

## v0.1.24
- `INSTALL.md` is a core and a router. Five situations moved to their own file under `install/`, read only when they apply: `windows.md`, `existing-folder.md`, `installers.md`, `explain.md`, `no-ledger.md`. The core went from 531 lines to 333. A pure move: every line is where it was or in one of the five, and eight lines were reworded to point at the new files.
- manifest: none.

## v0.1.23
- `INSTALL.md` fixes where each piece of a question goes: the plan and an explanation are ordinary message text, the question tool carries one line and the choices, and an option's preview pane is never used. An explanation is plain sentences, and the plan is not repeated after it. Found live: an agent put the answer to "Explain first" into a preview pane, which showed only while one option was highlighted and was empty for the others.
- manifest: none.

## v0.1.22
- An existing `~/.claude/skills` is settled before the plan, with four fixed choices: adopt (each skill becomes `v1.0.0` in the hub and is elected), start clean, do not link, stop. In the first two the directory is set aside as `~/.claude/skills.before-pagma`, never deleted, recorded on the ledger as `aside`, and `UNINSTALL.md` puts it back. Linking skill by skill is gone: a linked directory is the rendered output, and links nobody keeps current break that.
- The Claude app's `synced/` folder is carried into the linked directory, and the template manifest exempts it from render's cleanup. Before, a render deleted it.
- `elect-exact` gives a skill its first election. A skill that was in the cellar but not yet in the manifest was refused as an unknown label, so the authoring loop `INSTALL.md` ends on could not work for a new name. Found while testing adopt.
- manifest: `.harnesses["claude-code"].unmanaged.global += ["synced"]`, creating `unmanaged` if it is absent. Without it, render deletes the Claude app's built-in skills from a linked skills directory.

## v0.1.21
- `UNINSTALL.md` after the first Windows uninstall (every entry removed, closing line handed over). winget tools are checked with `winget list`: `command -v`, in a session older than the install, had reported all four as already gone. Junctions are removed with `rmdir`, named as the command; before, the file only warned against `rm -r`. A `~/.bun` left behind when bun goes through a package manager is offered for removal.
- manifest: none.

## v0.1.20
- `render.ts` finds its own location with `fileURLToPath`. Found live, on the first Windows install: `new URL(import.meta.url).pathname` gives `/C:/…` there, and every render failed.
- `INSTALL.md` § On Windows, after that install (Windows 11, gate 3/3). The `PATH` refresh reads the machine `PATH` as well as the user's, since fzf's package installs machine-wide. Ledger commands switch off Git Bash's path rewriting, which had turned `/c/…` into `C:/…` on the way into jq. The login-file rule is spelled out.
- Step 4 covers two cases it had no words for: an empty real directory (removed, then linked), and a `~/.claude/skills` that holds the Claude app's `synced/` folder (left alone, skills linked one by one). `UNINSTALL.md` finds per-skill links by their target, so links made after the install are removed too.
- The suggested descendant folder is `~/pagmas-descendant`; the template repo is now `hefboom/pagmas-descendant`.
- manifest: none.

## v0.1.19
- Windows, natively, through Git Bash: `INSTALL.md` § On Windows. Tools come from winget, the three links are junctions (Git Bash's `ln -s` copies the directory unless Developer Mode is on), and the env file carries no `PATH` line. Measured on one Windows 11 machine: a junction reads as a symlink to `[ -L ]`, `readlink` and `rm`, so the ledger and `UNINSTALL.md` work unchanged. Everything else in that section is unproven until its first full run.
- `.gitattributes` in the engine and in the rare book: text files check out with LF on every machine. Git for Windows converts to CRLF by default, which breaks the bash scripts.
- `init.sh` notes a missing `python3` and carries on; only `just forge edges` needs it.
- `just forge link <repo>` refuses on Windows until it makes junctions itself.
- manifest: none.

## v0.1.18
- `UNINSTALL.md`: the closing line checks its own result and prints "pagma: nothing remains on this machine". An agent standing in the descendant hands that line to the person instead of deleting its own directory. Found live, on the first full uninstall: the agent handed the line over, and the old line only printed "ledger closed".

## v0.1.17
- The descendant is explained before it is named: the hub repo every skill and agent is managed from, global or aimed at one repo. The noun is the only coined word; setting one up has no special verb. In `INSTALL.md` (vocabulary, plan, explanations) and the README.
- fzf is for the person: the interactive verbs are the hand-operated twins of the `-exact` verbs an agent runs. The README pairs them, and the install ends by recommending one pass by hand.
- `INSTALL.md` step 1 check: `bash -c '. "$HOME/.bashrc"; …'` in place of a bare `bash -c`, which reads no startup file. Found live: the old check could not pass on a correct install. The rc line is added alone, with no blank line around it.

## v0.1.16
- The plan has a fixed layout: one fact per line, a label with indented lines under it, columns lined up with spaces, no paragraphs. `INSTALL.md` carries the template. Found live: the plan arrived as prose inside a question box and could not be scanned.

## v0.1.15
- The plan ends with what happens on "go ahead": at most five plain sentences, in order — what the agent runs, where it will hand the person a command, what the machine has at the end, and that `/pagma-uninstall` takes all of it back.

## v0.1.14
- Installer scripts are read before they run. `INSTALL.md` fetches the bun and just installers to a file, answers four questions from the script itself (what it downloads and from where, where it writes, whether it edits startup files, whether it wants root), puts the answers in the plan, and runs that same file. Nothing is piped into a shell unread.
- What an installer leaves behind goes on the ledger with `by: <tool>` and is removed with that tool. Found live: the bun installer appended three lines to `~/.bashrc` that uninstall would have left.
- A harness that starts each command in a fresh shell sources `~/.config/pagma/env` at the start of each later command. Found live: `init.sh` could not see bun in the session that had just installed it.
- manifest: none. Machine: if the ledger has a `dep` line for bun with `via: installer`, add `line` entries with `by: bun` for the lines its installer left in the startup files (`grep -n '^# bun$\|BUN_INSTALL' ~/.bashrc ~/.bash_profile ~/.zshrc`).

## v0.1.13
- The plan question is a fixed menu that loops: go ahead, explain first, change the plan, stop. "Explain first" answers from a table in `INSTALL.md` that says what each tool and each piece is for and what stops without it, then returns to the same four choices. Before this the agent composed its own options, so no two installs asked the same thing.

## v0.1.12
- `INSTALL.md` opens with a plan: look first, show the person everything the install will put on the machine (tools, the env file, the rc lines, the ledger, the descendant, the links), ask once. After that, small commands, one change and its ledger line each; a change the harness still refuses is handed to the person. Found live: an agent put the env file, both rc edits and the ledger into one command, and its harness refused it as persistence nobody had approved.

## v0.1.11
- The ledger: `INSTALL.md` records everything it creates on the machine in `~/.config/pagma/ledger.jsonl`, one JSON line each (the tools it had to add, the env file, the rc lines, the harness links, the descendant, the bootstrap clone). `UNINSTALL.md` walks it: verify, ask, remove, confirm, with a yes/no per added tool, and ends on a per-entry report that can say "nothing pagma created remains". A tool that was on the machine before pagma is never on the ledger and never offered for removal.
- manifest: none. Machine: if `~/.config/pagma/ledger.jsonl` is absent, build it by inspection (`install/no-ledger.md`).

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
