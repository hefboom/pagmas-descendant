#!/usr/bin/env bash
# The sssf playground: one persistent consumer stamped and installed from a keg, toured by hand — `just forge playground [version]`.
# Depth: scripts/README.md#playgroundsh

set -euo pipefail
source "$(dirname "$0")/env.sh"

dev_root=${FORGE_DEV_ROOT:-$HOME/dev}
name=sssf-playground
repo_dir=$dev_root/$name

if [[ $# -gt 1 ]]; then
  echo "usage: playground.sh [version]   e.g. playground.sh v1.14.0" >&2
  exit 2
fi
version=${1:-}
# keg-core.sh owns keg resolution: latest non-yanked by default, vX.Y.Z normalization,
# the unknown/yanked refusals.
keg=$(bash "$ENGINE/scripts/keg-core.sh" ${version:+"$version"}) || exit 1
version=${keg##*/}

# The role README: what the playground is for, how a refresh works, that nothing
# flows back — never what it holds. Written fresh every run (step 3), so a stale
# copy never survives, and once at creation (step 1) so the first commit is never
# empty of it.
write_role_readme() {
  printf '%s\n' \
    '# sssf playground' '' \
    'Role: tour a keg by hand — run it, inspect its trace, try something against a' \
    'stamped consumer. Never the lab.' '' \
    'Refresh: `just -f ~/dotfiles/justfile forge playground [version]` stamps the keg,' \
    'runs `install.py --force` (every stamped file overwritten — safe only here), and' \
    '`render.py --force` too when this repo holds an `sssf-overlay/`.' '' \
    'Nothing flows back: a bug found here is fixed in the lab (`just -f ~/dotfiles/justfile' \
    'forge lab`) and arrives with the next keg.' \
    >"$repo_dir/README.md"
}

# 1. Target: create when missing, otherwise use what is there.
if [[ ! -d "$repo_dir" ]]; then
  mkdir -p "$repo_dir"
  git -C "$repo_dir" init -q
  write_role_readme
  git -C "$repo_dir" add README.md
  git -C "$repo_dir" commit -q -m "playground: empty consumer"
  echo "playground: created $repo_dir"
elif [[ ! -e "$repo_dir/.git" ]]; then
  echo "$repo_dir exists and is not a git repo — move it aside" >&2
  exit 1
else
  echo "playground: present $repo_dir"
fi

# 2. Guard: a dirty tree would ride into the stamp commit.
dirty=$(git -C "$repo_dir" status --porcelain)
if [[ -n "$dirty" ]]; then
  n=$(printf '%s\n' "$dirty" | wc -l | tr -d ' ')
  echo "dirty tree ($n path(s)) — commit, stash or reset in $repo_dir first:" >&2
  printf '%s\n' "$dirty" | head -10 >&2
  [[ $n -gt 10 ]] && echo "  … and $((n - 10)) more" >&2
  exit 1
fi

# 3. Role README: rewritten every run, past the guard so a stale copy from an
# older script version is never mistaken for an operator's dirty tree. Left
# unstaged here; step 7's `git add -A` is what actually commits it (step 4's
# stamp commit, when it runs, stages only .claude/skills).
write_role_readme

# 4. Stamp: the members and the receipt, unless the receipt already says so.
receipt=$repo_dir/.claude/skills/sssf-suite.receipt.json
at=$(jq -r '.version // empty' "$receipt" 2>/dev/null || true)
if [[ "$at" == "$version" ]]; then
  echo "stamp: already at $version"
else
  bash "$ENGINE/scripts/stamp-core.sh" "$name" "$version" >/dev/null
  git -C "$repo_dir" add .claude/skills
  git -C "$repo_dir" commit -q -m "Stamp sssf-suite $version"
  keg_commit=$(jq -r '.keg_commit // "staged"' "$receipt")
  echo "stamp: $version (keg commit $keg_commit)${at:+, was $at}"
fi

# 5. Install: every rendered file from this keg's templates. --force is safe here only.
out=$(cd "$repo_dir" && uv run .claude/skills/sssf/scripts/install.py --force)
n=$(printf '%s\n' "$out" | grep -c '^ *+ ' || true)
echo "install: $n files from $version"
# 5b. An overlay (Rung 95): the rendered roots are templates plus sssf-overlay/, so render
# writes the playground's own entries back over the fresh install (its --force is for
# exactly this: an install's or an earlier render's uncommitted output).
if [[ -f "$repo_dir/sssf-overlay/overlay.toml" ]]; then
  if ! out=$(cd "$repo_dir" && uv run --quiet .claude/skills/sssf/scripts/render.py --force 2>&1); then
    echo "render: refused — fix the overlay, then re-run:" >&2
    printf '%s\n' "$out" >&2
    exit 1
  fi
  tail -1 <<<"$out"      # render.py's own summary line, e.g. `render: 1 written, 81 unchanged`
fi

# 6. Env: never stamped, so never touched when present.
if [[ -e "$repo_dir/.env" ]]; then
  echo "env: kept"
else
  cp "$repo_dir/.env.sample" "$repo_dir/.env"
  echo "env: created from .env.sample — set OPENROUTER_API_KEY in $repo_dir/.env"
fi

# 7. Commit: what a consumer would commit (the role README included); the stamped
# .gitignore keeps the runtime out.
git -C "$repo_dir" add -A
if git -C "$repo_dir" diff --cached --quiet; then
  echo "commit: nothing to commit"
else
  git -C "$repo_dir" commit -q -m "install sssf-suite $version"
  echo "commit: $(git -C "$repo_dir" log -1 --format=%h) install sssf-suite $version"
fi

# 8. The tour.
cat <<EOF
tour, from $repo_dir:
  just demo             two cheap read-only runs, end to end (needs the key)
  just sessions         the last 10 runs, from adws/adw_data/sssf.db
  just phases <adw_id>  one run, phase by phase
  uv run .claude/skills/sssf/scripts/conformance.py --suite --source .
                        the suite's own gate, from inside a consumer (minutes: clean-room)
EOF
