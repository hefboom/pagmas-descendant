#!/usr/bin/env bash
# Retire a skill, interactively — `just forge retire [query]`.
# Depth: scripts/README.md#retiresh

set -euo pipefail
source "$(dirname "$0")/env.sh"

JSON=scratch/view.json

if ! { : <"/dev/tty"; } 2>/dev/null; then
  echo "retire.sh needs a terminal — it opens an fzf picker." >&2
  echo "non-interactive: bash scripts/move-core.sh <label> keg-only" >&2
  exit 2
fi

mkdir -p scratch
bun run "$ENGINE/scripts/render.ts" --json >"$JSON"

label=$(jq -r '.skills[].label' "$JSON" | fzf \
  --prompt='retire> ' \
  --layout=reverse \
  --query "${1:-}" --select-1 \
  --preview-window=right,55% \
  --preview "bash '$(realpath "$ENGINE/scripts/view.sh")' --preview {}") || true
[[ -z "$label" ]] && {
  echo "aborted — no changes"
  exit 0
}

read -r -p "retire $label — move cellar entry to keg-only/, drop its election, prune the bin dir? [y/N] " ans </dev/tty
[[ "$ans" == [yY]* ]] || {
  echo "aborted — no changes"
  exit 0
}

exec bash "$ENGINE/scripts/move-core.sh" "$label" keg-only
