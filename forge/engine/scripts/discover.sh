#!/usr/bin/env bash
# Onboard a repo-targeted scope, interactively — `just forge discover [query]`.
# Depth: scripts/README.md#discoversh

set -euo pipefail
source "$(dirname "$0")/env.sh"

dev_root=${FORGE_DEV_ROOT:-$HOME/dev}

if ! { : <"/dev/tty"; } 2>/dev/null; then
  echo "discover.sh needs a terminal — it opens an fzf picker." >&2
  echo "non-interactive: bash scripts/discover-core.sh <repo>" >&2
  exit 2
fi

if [[ ! -d "$dev_root" ]]; then
  echo "no dev root at $dev_root (set FORGE_DEV_ROOT to override)" >&2
  exit 1
fi

dotfiles_root=$(cd .. && pwd)

candidates=$(
  for d in "$dev_root"/*/; do
    [[ -e "$d/.git" ]] || continue
    repo=$(basename "$d")
    root=$(jq -r --arg r "$repo" '.harnesses["claude-code"].roots[$r] // empty' elections.json)
    link=$d.claude/skills
    if [[ -z "$root" ]]; then
      printf '%s\t(new)\n' "$repo"
    elif [[ ! -e "$link" && ! -L "$link" ]]; then
      printf '%s\t(declared, unlinked)\n' "$repo"
    elif [[ -L "$link" && $(readlink "$link") == "$dotfiles_root/$root" ]]; then
      printf '%s\t(linked)\n' "$repo"
    else
      printf '%s\t(mislinked — link.sh will refuse with the fix)\n' "$repo"
    fi
  done
)

if [[ -z "$candidates" ]]; then
  echo "nothing to discover — no git repos under $dev_root"
  exit 0
fi

pick=$(fzf \
  --prompt='discover> ' \
  --layout=reverse \
  --query "${1:-}" --select-1 \
  --header "git repos under $dev_root — pick to declare + link" <<<"$candidates") || true
[[ -z "$pick" ]] && {
  echo "aborted — no changes"
  exit 0
}

exec bash "$ENGINE/scripts/discover-core.sh" "${pick%%$'\t'*}"
