#!/usr/bin/env bash
# Move a skill between cellar scopes, interactively — `just forge move [election-query] [scope-query]`.
# Depth: scripts/README.md#movesh

set -euo pipefail
source "$(dirname "$0")/env.sh"

JSON=scratch/view.json

if ! { : <"/dev/tty"; } 2>/dev/null; then
  echo "move.sh needs a terminal — it opens fzf pickers." >&2
  echo "non-interactive: bash scripts/move-core.sh <label> <dest-scope>" >&2
  exit 2
fi

mkdir -p scratch
bun run "$ENGINE/scripts/render.ts" --json >"$JSON"

label=$(jq -r '.skills[].label' "$JSON" | fzf \
  --prompt='move> ' \
  --layout=reverse \
  --query "${1:-}" --select-1 \
  --preview-window=right,55% \
  --preview "bash '$(realpath "$ENGINE/scripts/view.sh")' --preview {}") || true
[[ -z "$label" ]] && {
  echo "aborted — no changes"
  exit 0
}

harness=$(jq -r --arg l "$label" '.skills[] | select(.label == $l) | .harness' "$JSON")
scope=$(jq -r --arg l "$label" '.skills[] | select(.label == $l) | .scope' "$JSON")

dest=$(jq -r --arg h "$harness" '.scopes[$h][].name' "$JSON" | grep -vx "$scope" | fzf \
    --prompt='scope> ' \
    --layout=reverse \
    --query "${2:-}" --select-1 \
    --header "moving $label — current scope: $scope (keg-only = retire)") || true
[[ -z "$dest" ]] && {
  echo "aborted — no changes"
  exit 0
}

exec bash "$ENGINE/scripts/move-core.sh" "$label" "$dest"
