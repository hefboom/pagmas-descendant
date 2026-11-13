#!/usr/bin/env bash
# Stamp the sssf-suite into a target repo, interactively — `just forge stamp [repo-query] [version-query]`.
# Depth: scripts/README.md#stampsh

set -euo pipefail
source "$(dirname "$0")/env.sh"

SUITE_DIR=kegs/sssf-suite
dev_root=${FORGE_DEV_ROOT:-$HOME/dev}

if ! { : <"/dev/tty"; } 2>/dev/null; then
  echo "stamp.sh needs a terminal — it opens fzf pickers." >&2
  echo "non-interactive: bash scripts/stamp-core.sh <repo> [version]" >&2
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
    link=$d.claude/skills
    if [[ -L "$link" ]]; then
      root=$(jq -r --arg r "$repo" '.harnesses["claude-code"].roots[$r] // empty' elections.json)
      if [[ -n "$root" && $(readlink "$link") == "$dotfiles_root/$root" ]]; then
        printf '%s\t(tree-linked — stamp converts to per-skill)\n' "$repo"
      else
        printf '%s\t(foreign symlink — the engine will refuse)\n' "$repo"
      fi
    elif [[ -d "$link" ]]; then
      printf '%s\t(has .claude/skills)\n' "$repo"
    else
      printf '%s\t(no .claude/skills yet)\n' "$repo"
    fi
  done
)

if [[ -z "$candidates" ]]; then
  echo "nothing to stamp into — no git repos under $dev_root"
  exit 0
fi

pick=$(fzf \
  --prompt='stamp> ' \
  --layout=reverse \
  --query "${1:-}" --select-1 \
  --header "stamp sssf-suite — pick a target repo under $dev_root" <<<"$candidates") || true
[[ -z "$pick" ]] && {
  echo "aborted — no changes"
  exit 0
}
repo=${pick%%$'\t'*}

versions=$(
  for v in $(ls "$SUITE_DIR" | sort -rV); do
    [[ -d "$SUITE_DIR/$v" && ! -e "$SUITE_DIR/$v/.yanked" ]] && echo "$v"
  done
)
if [[ -z "$versions" ]]; then
  echo "no electable keg under $SUITE_DIR" >&2
  exit 1
fi

version=$(fzf \
  --prompt='version> ' \
  --layout=reverse \
  --query "${2:-}" --select-1 \
  --header "stamping into $repo — latest: $(head -1 <<<"$versions") (yanked excluded)" <<<"$versions") || true
[[ -z "$version" ]] && {
  echo "aborted — no changes"
  exit 0
}

exec bash "$ENGINE/scripts/stamp-core.sh" "$repo" "$version"
