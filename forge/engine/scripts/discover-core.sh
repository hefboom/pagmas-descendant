#!/usr/bin/env bash
# Onboard a repo-targeted scope, non-interactively — `just forge discover-exact <repo>`.
# Depth: scripts/README.md#discover-coresh

set -euo pipefail
source "$(dirname "$0")/env.sh"

MANIFEST=elections.json
dev_root=${FORGE_DEV_ROOT:-$HOME/dev}

if [[ $# -ne 1 ]]; then
  echo "usage: discover-core.sh <repo>   e.g. discover-core.sh hefboom-ops" >&2
  exit 2
fi
repo=$1

case "$repo" in
global | dotfiles | keg-only | tools)
  echo "\"$repo\" is a reserved scope name — not a repo target" >&2
  exit 1
  ;;
esac
if jq -e --arg r "$repo" '(.harnesses["claude-code"].multicast // {}) | has($r)' "$MANIFEST" >/dev/null; then
  echo "\"$repo\" is a multicast scope (\"multicast\" in $MANIFEST) — its elections render into every subscriber, it is not a repo target" >&2
  exit 1
fi

repo_dir=$dev_root/$repo
if [[ ! -d "$repo_dir" ]]; then
  echo "no repo at $repo_dir (FORGE_DEV_ROOT overrides the ~/dev default)" >&2
  exit 1
fi
if [[ ! -e "$repo_dir/.git" ]]; then
  echo "$repo_dir is not a git repo (no .git)" >&2
  exit 1
fi

root=$(jq -r --arg r "$repo" '.harnesses["claude-code"].roots[$r] // empty' "$MANIFEST")
if [[ -z "$root" ]]; then
  root=home/claude/repos/$repo/skills
  mkdir -p scratch
  tmp=scratch/elections.json.tmp
  jq --arg r "$repo" --arg root "$root" \
    '.harnesses["claude-code"].roots[$r] = $root' "$MANIFEST" >"$tmp"
  mv "$tmp" "$MANIFEST"
  echo "declared root for \"$repo\": $root"
else
  echo "\"$repo\" already declared -> $root"
fi

bun run "$ENGINE/scripts/render.ts" >/dev/null
exec bash "$ENGINE/scripts/link.sh" "$repo"
