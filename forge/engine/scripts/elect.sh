#!/usr/bin/env bash
# Elect a version, interactively — `just forge elect [election-query] [version-query]`.
# Depth: scripts/README.md#electsh

set -euo pipefail
source "$(dirname "$0")/env.sh"

JSON=scratch/view.json

if ! { : <"/dev/tty"; } 2>/dev/null; then
  echo "elect.sh needs a terminal — it opens fzf pickers." >&2
  echo "non-interactive: bash scripts/elect-core.sh <label> <version>" >&2
  exit 2
fi

mkdir -p scratch
bun run "$ENGINE/scripts/render.ts" --json >"$JSON"

label=$(jq -r '.skills[].label, .tools[].label, .partials[].label, .agents[].label' "$JSON" | fzf \
  --prompt='elect> ' \
  --layout=reverse \
  --query "${1:-}" --select-1 \
  --preview-window=right,55% \
  --preview "bash '$(realpath "$ENGINE/scripts/view.sh")' --preview {}") || true
[[ -z "$label" ]] && {
  echo "aborted — no changes"
  exit 0
}

# Display data only — elect-core.sh re-derives and validates all of this.
entry=$(jq -c --arg l "$label" '
  (.skills[], .tools[], .partials[], .agents[]) | select(.label == $l) | {version, versions, yanked}
' "$JSON" | head -1)
current=$(jq -r .version <<<"$entry")

version=$(jq -r '(.versions - .yanked)[]' <<<"$entry" | fzf \
  --prompt='version> ' \
  --layout=reverse \
  --query "${2:-}" --select-1 \
  --header "electing $label — current: $current (yanked excluded)") || true
[[ -z "$version" ]] && {
  echo "aborted — no changes"
  exit 0
}

exec bash "$ENGINE/scripts/elect-core.sh" "$label" "$version"
