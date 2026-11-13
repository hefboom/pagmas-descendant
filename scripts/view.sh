#!/usr/bin/env bash
# Interactive viewer over the election model — `just forge view`; `--show <label>` is `just forge show`.
# Depth: scripts/README.md#viewsh

set -euo pipefail
source "$(dirname "$0")/env.sh"

JSON=scratch/view.json

if [[ "${1:-}" == "--show" || "${1:-}" == "--preview" ]]; then
  label=${2:-}
  if [[ -z "$label" ]]; then
    echo "usage: view.sh --show <label>" >&2
    echo "  e.g. view.sh --show claude-code/global/check-docs" >&2
    exit 2
  fi
  if [[ "$1" == "--show" ]]; then
    mkdir -p scratch
    bun run "$ENGINE/scripts/render.ts" --json >"$JSON"
  elif [[ ! -f "$JSON" ]]; then
    echo "no dump at $JSON — run: just forge show <label>" >&2
    exit 1
  fi
  # An agent election's dialect lives per variant: a single-variant entry (no
  # `variants` key) prints like a skill, a multi-variant one prints one block per
  # rendered name under a `variants` header.
  detail=$(jq -r --arg l "$label" '
    def dialect: [
      (if .tier != null then "tier      \(.tier) (\(.tierSource))" else empty end),
      (if .model != null then "model     \(.model)" else empty end),
      (if .effort != null then "effort    \(.effort) (\(.effortSource))" else empty end),
      (if (.disallowedTools // null) != null then "disallowed \(.disallowedTools)" else empty end),
      (if ((.tools // []) | length) > 0
        then "tools     " + ([.tools[] | "\(.name)@\(.version) → \(.entry)"] | join("\n          "))
        else empty end),
      (if ((.partials // []) | length) > 0
        then "partials  " + ([.partials[] | "\(.name)@\(.version)"] | join("\n          "))
        else empty end)
    ];
    (.skills[], .tools[], .partials[], .agents[]) | select(.label == $l) |
    [
      .label,
      "",
      "elected   \(.version)",
      "live      \(.live)",
      (if (.variant // false) then
        "", "variants",
        (.variants[] | "  #\(.name)  \(.live)", (dialect[] | "    " + .))
      else
        ((if .variants then .variants[0] else . end) | dialect[])
      end),
      (if (.consumers // null) != null then
        "", "consumers",
        (if (.consumers | length) > 0 then (.consumers[] | "  " + .) else "  (none yet)" end)
      else empty end),
      "",
      "versions",
      (.version as $v | .yanked as $y | .versions[] | . as $ver |
        (if $ver == $v then "  * " else "    " end) + $ver +
        (if ($y | index($ver)) != null then "  (yanked)" else "" end))
    ] | join("\n")
  ' "$JSON")
  if [[ -z "$detail" ]]; then
    echo "unknown label \"$label\"" >&2
    near=$(jq -r '.skills[].label, .tools[].label, .partials[].label, .agents[].label' "$JSON" | grep -F -- "${label##*/}" || true)
    if [[ -n "$near" ]]; then
      echo "did you mean:" >&2
      sed 's/^/  /' <<<"$near" >&2
    else
      echo "list all: just forge render --json | jq -r '.skills[].label, .tools[].label, .partials[].label, .agents[].label'" >&2
    fi
    exit 1
  fi
  printf '%s\n' "$detail"
  exit 0
fi

mkdir -p scratch
bun run "$ENGINE/scripts/render.ts" --json >"$JSON"

jq -r '.skills[].label, .tools[].label, .partials[].label, .agents[].label' "$JSON" | fzf \
  --prompt='forge> ' \
  --layout=reverse \
  --preview-window=right,55% \
  --preview "bash '$(realpath "$0")' --preview {}" || true
