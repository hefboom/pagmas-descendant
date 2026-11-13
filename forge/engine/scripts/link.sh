#!/usr/bin/env bash
# Bootstrap for a repo-targeted scope — `just forge link <repo>`.
# Depth: scripts/README.md#linksh

set -euo pipefail
source "$(dirname "$0")/env.sh"

if [[ $# -ne 1 ]]; then
  echo "usage: link.sh <repo>   e.g. link.sh hefboom-ops" >&2
  exit 2
fi
repo=$1

root=$(jq -r --arg r "$repo" '.harnesses["claude-code"].roots[$r] // empty' elections.json)
if [[ -z "$root" ]]; then
  echo "no root for scope \"$repo\" in elections.json — declared repo roots:" >&2
  jq -r '.harnesses["claude-code"].roots | to_entries[] | select(.key != "global" and .key != "dotfiles") | "  \(.key)"' elections.json >&2
  exit 1
fi

target=$(cd .. && pwd)/$root
if [[ ! -d "$target" ]]; then
  echo "$root is not rendered yet — run: just forge render" >&2
  exit 1
fi

repo_dir=${FORGE_DEV_ROOT:-$HOME/dev}/$repo
if [[ ! -d "$repo_dir" ]]; then
  echo "no repo at $repo_dir (FORGE_DEV_ROOT overrides the ~/dev default)" >&2
  exit 1
fi

# Git Bash on Windows: `ln -s` copies the directory instead of linking it, and the copy
# goes stale at the next render. Refuse until this script makes junctions itself.
case $(uname -s) in
  MINGW* | MSYS*)
    echo "just forge link does not run on Windows yet (ln -s copies there). Link by hand with a junction, INSTALL.md § On Windows: $repo_dir/.claude/skills -> $target" >&2
    exit 1
    ;;
esac

mode=$(jq -r --arg r "$repo" '.harnesses["claude-code"].linkModes[$r] // "tree"' elections.json)

if [[ "$mode" == "per-skill" ]]; then
  link_dir=$repo_dir/.claude/skills
  if [[ -L "$link_dir" ]]; then
    echo "$link_dir is a symlink ($(readlink "$link_dir")) — per-skill mode expects a real directory; remove the tree link by hand, then re-run" >&2
    exit 1
  fi
  mkdir -p "$link_dir"

  desired=$(find "$target" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort)

  # Refuse before any write: a rendered name whose slot holds something forge
  # does not own (a real dir/file, or a hand-made symlink pointing elsewhere).
  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    entry=$link_dir/$name
    if [[ -e "$entry" && ! -L "$entry" ]]; then
      echo "collision: $entry exists and is repo-owned — the \"$name\" election would shadow it; rename one side" >&2
      exit 1
    fi
    if [[ -L "$entry" ]]; then
      dest=$(readlink "$entry")
      case $dest in
        "$target"/*) ;;
        *)
          echo "collision: $entry is a symlink to $dest (not forge's) — move it aside, then re-run" >&2
          exit 1
          ;;
      esac
    fi
  done <<<"$desired"

  linked=0
  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    ln -sfn "$target/$name" "$link_dir/$name"
    linked=$((linked + 1))
  done <<<"$desired"

  # Prune forge-owned links whose election is gone. Only symlinks resolving
  # into this repo's rendered root qualify — hand-made links are never touched.
  pruned=0
  while IFS= read -r entry; do
    [[ -z "$entry" ]] && continue
    case $(readlink "$entry") in
      "$target"/*) ;;
      *) continue ;;
    esac
    if ! grep -qxF "$(basename "$entry")" <<<"$desired"; then
      rm "$entry"
      pruned=$((pruned + 1))
    fi
  done < <(find "$link_dir" -mindepth 1 -maxdepth 1 -type l)

  # Managed ignore block: forge-owned names in .git/info/exclude, rewritten
  # whole each run (so pruned names leave with their links). Empty election
  # set removes the block entirely.
  git_dir=$(git -C "$repo_dir" rev-parse --absolute-git-dir 2>/dev/null || true)
  if [[ -n "$git_dir" ]]; then
    exclude=$git_dir/info/exclude
    mkdir -p "${exclude%/*}"
    begin='# >>> forge per-skill links (managed) >>>'
    end='# <<< forge per-skill links (managed) <<<'
    tmp=$(mktemp)
    {
      if [[ -f "$exclude" ]]; then
        awk -v b="$begin" -v e="$end" '$0==b{skip=1} !skip{print} $0==e{skip=0}' "$exclude"
      fi
      if [[ -n "$desired" ]]; then
        echo "$begin"
        while IFS= read -r name; do
          [[ -n "$name" ]] && echo ".claude/skills/$name"
        done <<<"$desired"
        echo "$end"
      fi
    } >"$tmp"
    mv "$tmp" "$exclude"
  fi

  echo "$link_dir: $linked linked, $pruned pruned (per-skill)"
  exit 0
fi

link=$repo_dir/.claude/skills
if [[ -L "$link" ]]; then
  if [[ "$(readlink "$link")" == "$target" ]]; then
    echo "$link -> $target — already linked"
    exit 0
  fi
  echo "$link is a symlink to $(readlink "$link") — expected $target; retarget by hand" >&2
  exit 1
elif [[ -e "$link" ]]; then
  echo "$link already exists and is not a symlink — move it aside, then re-run" >&2
  exit 1
fi

mkdir -p "$repo_dir/.claude"
ln -s "$target" "$link"
echo "$link -> $target"
grep -qxF ".claude/skills" "$repo_dir/.gitignore" 2>/dev/null ||
  echo "reminder: add \".claude/skills\" to $repo/.gitignore"
