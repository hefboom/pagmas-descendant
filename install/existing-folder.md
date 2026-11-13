# An existing `~/.claude` folder

Part of `INSTALL.md`: read this when one of `~/.claude/{skills,agents,tools}` is a real
directory with content. It has two halves: the question, asked before the plan, and what
to do with the answer in step 4. `$L` is the ledger path from that file.

## Before the plan: the question

**An existing folder.** If one of `~/.claude/{skills,agents,tools}` is a real directory
with content, settle it now, before the plan. pagma links each of the three as a whole,
and render owns a linked directory completely: it deletes whatever no election accounts
for. So what is there cannot stay in place. List what the directory holds, then ask, with
these choices in this order:

| Choice | What happens |
|---|---|
| **Adopt** (recommended) | the directory is set aside untouched. Each skill in it becomes `v1.0.0` in the hub and is elected, so the next session has it again. Then the directory is linked |
| **Start clean** | the directory is set aside untouched, then linked. What was in it is no longer available to sessions |
| **Do not link** | the directory stays as it is. The hub is built, but sessions do not see what it renders there |
| **Stop** | no install. Nothing was changed |

Set aside means renamed to `~/.claude/<dir>.before-pagma`, never deleted, and
`UNINSTALL.md` puts it back: say so with the first two choices. Adopt exists for `skills`
only; for `agents` and `tools` offer the other three. A directory that holds nothing but
the Claude app's `synced/` folder has nothing to adopt: do not ask, plan to set it aside
and carry `synced/` over (step 4). The plan's `Links` block shows each answer:

```text
Links
  ~/.claude/skills                existing folder, set aside to ~/.claude/skills.before-pagma
  adopted                         3 skills, each v1.0.0 in the hub: review, notes, deploy
  carried over                    synced/, the Claude app's own skills
  then linked                     to ~/pagmas-descendant/home/claude/skills
```

## In step 4: the answer

**Set aside** (the answers *Adopt* and *Start clean*). Rename the directory, record it,
then link as in the first case:

```bash
mv "$HOME/.claude/skills" "$HOME/.claude/skills.before-pagma"
jq -nc --arg p "$HOME/.claude/skills" --arg k "$HOME/.claude/skills.before-pagma" '{kind:"aside",path:$p,kept:$k}' >> "$L"
```

If the `.before-pagma` name is taken, stop and show the person. A `synced/` folder inside
is the Claude app's, which writes it and keeps it current. Copy it into the linked
directory so the app's built-in skills stay available:
`cp -R "$HOME/.claude/skills.before-pagma/synced" "$HOME/.claude/skills/synced"`. The
manifest exempts that name from render's cleanup (`unmanaged`).

**Adopt** (skills only). For each entry of the set-aside directory except `synced`:

- a directory holding a `SKILL.md`, under a name the cellar does not have yet →
  `cp -R "<set-aside>/<name>" "forge/skills/global/<name>/v1.0.0"`, then
  `just forge elect-exact claude-code/global/<name> v1.0.0`
- anything else (a loose file, a directory without `SKILL.md`, a link, a name already in
  the cellar) → not adopted. It stays in the set-aside directory; list it for the person.

An adopted skill changes in two ways. Tell the person both:

- it now runs on the hub's default tier (`workhorse` in the template: sonnet, high effort) unless its file has a `tier:` line. Before, it ran on the session's model. `just forge tier-exact claude-code/global/<name> <tier>` sets it per skill.
- render refuses a `SKILL.md` whose frontmatter names a `model:`. In the cellar copy, replace that line with the tier of its class (`haiku` → `lightweight`, `sonnet` → `workhorse`, `opus` → `sota`). The set-aside original is untouched.

**Do not link.** Leave the directory alone and write no `symlink` line for it. The hub is
built and renders; sessions do not see that directory's output until it is linked.
