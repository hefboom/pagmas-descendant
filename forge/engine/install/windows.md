# Install on Windows

Part of `INSTALL.md`: read this before the plan when `uname -s` starts with `MINGW` or
`MSYS`. Step numbers are that file's.

Those names mean Git Bash, the shell
that comes with Git for Windows and the one Claude Code runs its commands in. Inside WSL
you are on Linux and nothing here applies.

New in v0.1.19. One full install and one full uninstall have run on Windows 11; update
and the interactive verbs have not run there yet, so report every mismatch. The steps and the
ledger are the same, except:

| Where | On Windows |
|---|---|
| Tools (step 1) | `winget`, one tool per command, `jq` first so the ledger can be written. No installer scripts, so the plan has no installer blocks. `git` is there already: Git Bash came with it |
| `python3` | leave it alone and install none for pagma. The name may be a real Python or a Store alias that is not one, and the setup check only notes a missing one. `just forge edges` is untried on Windows |
| `PATH` | winget puts each tool on the `PATH` itself, the user's or the machine's. The env file carries no `PATH` line, only `FORGE_ROOT` from step 2 |
| Startup files | two files. The login file is the first that exists of `~/.bash_profile`, `~/.bash_login`, `~/.profile`: add the line to that one. Only when none of the three exists, create `~/.profile`. The second is `~/.bashrc`, created if absent |
| Links (step 4) | never `ln -s`: unless Developer Mode is on, Git Bash copies the directory, reports success, and the copy goes stale at the next render. Make a junction, the directory link that needs no admin rights |
| An existing `~/.claude/<dir>` | the same question and the same answers (`existing-folder.md`). If the `mv` that sets a directory aside is refused, the Claude app is holding it open: ask the person to close the app, then retry |
| `just forge link <repo>` | refuses on Windows for now. Make that link by hand with the junction command below |
| By hand | the interactive verbs run in a Git Bash window, not in PowerShell or cmd |

**Tools.** `winget show` is the read-first step here. A download host other than the
project's own is a stop. A permission prompt from Windows is the person's to answer.

| Tool | id | Download host, when this was written |
|---|---|---|
| jq | `jqlang.jq` | `github.com/jqlang/jq` |
| bun | `Oven-sh.Bun` | `github.com/oven-sh/bun` |
| just | `Casey.Just` | `github.com/casey/just` |
| fzf | `junegunn.fzf` | `github.com/junegunn/fzf` |

```bash
winget show    --id jqlang.jq -e --source winget --accept-source-agreements
winget install --id jqlang.jq -e --source winget --accept-source-agreements --accept-package-agreements
```

The `dep` line records `via` as `winget` and `remove` as `winget uninstall --id <id> -e`.

A program sees the new `PATH` only if it started after winget ran, and your session
started before. Until the person restarts it from a new terminal, begin each later
command with this line. It also replaces the fresh-shell check of step 1, which cannot
pass before a restart because a child shell inherits the session's old `PATH`:

```bash
export PATH="$PATH:$(cygpath -u -p "$(powershell -NoProfile -Command "[Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')" | tr -d '\r')")";
```

After step 2, `bash -lc 'echo "$FORGE_ROOT"'` prints the descendant's path.

**The ledger.** Begin each ledger command with `export MSYS_NO_PATHCONV=1;`. Git Bash
rewrites an argument that looks like a path before a Windows program such as jq sees it
(`/c/Users/…` becomes `C:/Users/…`), and the ledger has to hold paths in the form
`readlink` prints. Check: `MSYS_NO_PATHCONV=1 jq -nc --arg p "$HOME" '$p'` prints a path
starting with `/c/`.

**Links.** One junction per directory. The paths travel as environment variables, so a
space in one needs no quoting:

```bash
PAGMA_LINK=$(cygpath -w "$HOME/.claude/skills") PAGMA_TARGET=$(cygpath -w "$PWD/home/claude/skills") \
  powershell -NoProfile -Command 'New-Item -ItemType Junction -Path $env:PAGMA_LINK -Target $env:PAGMA_TARGET | Out-Null'
readlink "$HOME/.claude/skills"
```

Git Bash sees a junction as a symlink: `[ -L ]` is true, `readlink` prints the target,
and `rmdir` or a plain `rm` removes the link and leaves the target's contents where they are. So the
step 4 check, the `symlink` ledger line and `UNINSTALL.md` work unchanged. Write the
ledger line's `target` from what `readlink` printed, so uninstall compares like with
like. Never `rm -r` a junction.

**The plan.** Same labels, same order, these lines differ:

```text
Machine
  system     Windows 11, Git Bash, winget

Tools to install
  jq         edits the manifest   winget jqlang.jq       I run it; if refused, you run it

winget packages: shown, match the baseline
  jq         from github.com/jqlang/jq

Files pagma writes
  ~/.config/pagma/env             new: FORGE_ROOT
  ~/.profile                      new file, 1 line
  ~/.bashrc                       new file, 1 line

Links
  ~/.claude/skills                junction to ~/pagmas-descendant/home/claude/skills
```
