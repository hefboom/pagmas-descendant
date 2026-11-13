# The hub scope on an older descendant

Part of `UPDATE.md`: read this when the v0.1.31 `Machine:` line of the changelog sends
you here. Run it in the descendant's root, after that version's `manifest:` step.

Before v0.1.31 a descendant carried three pointer skills as plain files in
`.claude/skills/`. From v0.1.31 `/pagma-update` and `/pagma-uninstall` are cellar skills
in the `hub` scope, rendered and linked like any other skill, and `/pagma-install` is the
command file `.claude/commands/pagma-install.md`, which the re-plant step of `UPDATE.md`
has already copied in.

1. Look: `ls -A .claude/skills`. If it lists anything other than `pagma-install`,
   `pagma-update` and `pagma-uninstall`, the person keeps skills of their own there:
   stop, change nothing, and say that the two procedures stay as the plain files they are.
   If `.claude/skills` is already a link, skip to step 4.
2. Remove the three plain copies. `rmdir` refuses if anything else is left:

   ```bash
   rm -r .claude/skills/pagma-install .claude/skills/pagma-update .claude/skills/pagma-uninstall && rmdir .claude/skills
   ```

3. Link, and keep the link out of git. On Windows make a junction instead
   (`install/windows.md`, the fourth link):

   ```bash
   ln -s "$PWD/home/claude/repos/hub/skills" .claude/skills
   grep -qxF 'home/claude/repos/' .gitignore || echo 'home/claude/repos/' >> .gitignore
   grep -qxF '.claude/skills' .gitignore || echo '.claude/skills' >> .gitignore
   ```

   Ledger: a `symlink` line for it, `path` the link and `target` what `readlink` prints.
4. Check, after the render in step 4 of `UPDATE.md`: `ls .claude/skills` lists
   `pagma-update` and `pagma-uninstall`.
