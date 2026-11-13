# Installer scripts for bun and just

Part of `INSTALL.md` step 1: read this while you are still looking, before the plan, when
bun or just has to come from its project's installer script.

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
