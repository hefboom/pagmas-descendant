# UPDATE.md — for the agent

You are a coding agent upgrading the **pagma** engine inside a descendant. Read the
whole file first. Ask before pulling; nothing before that step changes anything.

## 1. Where this descendant is

- `jq -r .engine forge/elections.json` — the pinned version.
- `cat forge/engine/VERSION` — the mounted engine. Normally equal to the pin without the `v`; if not, say so and stop, the descendant is mid-upgrade.
- Prerequisites: `git`, `bun`, `just` (1.31+), `jq`, `fzf`, `python3` still resolve. If one is missing, follow step 1 of `forge/engine/INSTALL.md` first.
- The working tree is committed (`git status --short` empty). A subtree pull refuses otherwise; ask the person to commit or stash.

## 2. What is upstream

```bash
git ls-remote --tags https://github.com/hefboom/pagma.git 'v*' | awk -F/ '{print $3}' | grep -v '\^{}' | sort -V | tail -1
```

That is the newest tag. If it equals the pin, report "up to date" and stop. Otherwise
fetch it and read the changelog between the two versions:

```bash
git fetch https://github.com/hefboom/pagma.git <newest-tag>
git show FETCH_HEAD:CHANGELOG.md
```

Show the person: current → newest, the entries in between, and every `manifest:` line
among them verbatim. Those are the hand steps the upgrade will apply. **Ask whether to
proceed.** Stop here if the answer is no.

## 3. Apply

```bash
git subtree pull --prefix forge/engine https://github.com/hefboom/pagma.git <newest-tag> --squash -m "forge: engine subtree at pagma <newest-tag>"
jq --arg v <newest-tag> '.engine = $v' forge/elections.json > forge/elections.json.tmp && mv forge/elections.json.tmp forge/elections.json
```

Then re-plant the rare book: for every file under `forge/engine/examples/descendant/.claude/`
and `forge/engine/examples/descendant/AGENTS.md`, copy it to the same relative path in the
descendant **only if that path is absent** (new skills such as `/pagma-update` arrive this
way; an existing file is the person's and is never overwritten). List what was added.

```bash
(cd forge/engine/examples/descendant && find .claude AGENTS.md -type f) | while read -r f; do
  [ -e "$f" ] || { mkdir -p "$(dirname "$f")"; cp "forge/engine/examples/descendant/$f" "$f"; echo "added $f"; }
done
```

Then every `manifest:` line from step 2, oldest version first. A jq expression is applied
the same way as the pin line above; a shell command is run as written. Skip a step whose
effect is already present (the key exists, the symlink exists). A step that creates
something on the machine (a symlink, a file outside the descendant) also gets its line in
`~/.config/pagma/ledger.jsonl`, written as `forge/engine/INSTALL.md` § The ledger shows, so
uninstall knows about it.

## 4. Verify and report

```bash
just forge install
just forge render
just forge render --check
```

Pass: the gate prints `N/N elections render byte-identical to the live bin trees`.
Report the versions crossed, each manifest step applied or skipped, any ledger lines
added, and the gate line.
Offer to commit (`git add -A && git commit -m "forge: engine <newest-tag>"`). If a step in
this file did not match what you found, say so — that is a bug in this file.
