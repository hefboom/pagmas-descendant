#!/usr/bin/env bash
# Yank or unyank a version, non-interactively — `just forge yank-exact <label> <version>` / `unyank-exact` (= --undo).
# Depth: scripts/README.md#yank-coresh

set -euo pipefail
source "$(dirname "$0")/env.sh"

JSON=scratch/yank-core.json

undo=0
args=()
for a in "$@"; do
  if [[ "$a" == "--undo" ]]; then undo=1; else args+=("$a"); fi
done
if [[ ${#args[@]} -ne 2 ]]; then
  echo "usage: yank-core.sh <label> <version> [--undo]" >&2
  echo "  e.g. yank-core.sh claude-code/global/check-code v1.3.0" >&2
  exit 2
fi
label=${args[0]}
version=${args[1]}

mkdir -p scratch
bun run "$ENGINE/scripts/render.ts" --json >"$JSON"

# `kind` decides which cellar tree the label addresses; scope/name come from the
# dump rather than from splitting the label, so the path is authoritative.
entry=$(jq -c --arg l "$label" '
  (.skills[] | select(.label == $l) | {kind: "skill", scope, name, version, versions, yanked}),
  (.tools[]  | select(.label == $l) | {kind: "tool",         name, version, versions, yanked}),
  (.partials[] | select(.label == $l) | {kind: "partial",    name, version, versions, yanked}),
  (.agents[] | select(.label == $l) | {kind: "agent",        name, version, versions, yanked})
' "$JSON")

if [[ -z "$entry" ]]; then
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
if [[ $(wc -l <<<"$entry") -ne 1 ]]; then
  echo "label \"$label\" is ambiguous across skills, tools, partials and agents — refusing" >&2
  exit 1
fi
kind=$(jq -r .kind <<<"$entry")

if ! jq -e --arg v "$version" '.versions | index($v)' <<<"$entry" >/dev/null; then
  echo "\"$label\" has no version $version — in cellar:" >&2
  jq -r '.versions[]' <<<"$entry" | sed 's/^/  /' >&2
  exit 1
fi

case "$kind" in
  skill) dir=skills/$(jq -r .scope <<<"$entry")/$(jq -r .name <<<"$entry")/$version ;;
  tool) dir=tools/$(jq -r .name <<<"$entry")/$version ;;
  partial) dir=partials/$(jq -r .name <<<"$entry")/$version ;;
  agent) dir=agents/$(jq -r .name <<<"$entry")/$version ;;
esac
sentinel=$dir/.yanked

if [[ $undo -eq 0 ]]; then
  # The sentinel is a property of the cellar entry, not of the label that addressed it —
  # so the guard asks who elects this version anywhere, across every harness in the dump.
  case "$kind" in
    skill) electors=$(jq -r --argjson e "$entry" --arg v "$version" '
      .skills[] | select(.scope == $e.scope and .name == $e.name and .version == $v) | .label
    ' "$JSON") ;;
    tool) electors=$(jq -r --argjson e "$entry" --arg v "$version" '
      .tools[] | select(.name == $e.name and .version == $v) | .label
    ' "$JSON") ;;
    partial) electors=$(jq -r --argjson e "$entry" --arg v "$version" '
      .partials[] | select(.name == $e.name and .version == $v) | .label
    ' "$JSON") ;;
    agent) electors=$(jq -r --argjson e "$entry" --arg v "$version" '
      .agents[] | select(.name == $e.name and .version == $v) | .label
    ' "$JSON") ;;
  esac
  if [[ -n "$electors" ]]; then
    echo "$version is still elected — refusing; elect another version on each of these first:" >&2
    sed 's/^/  /' <<<"$electors" >&2
    exit 1
  fi
  if jq -e --arg v "$version" '.yanked | index($v)' <<<"$entry" >/dev/null; then
    echo "$label $version already yanked — no changes"
    exit 0
  fi
  touch "$sentinel"
  git add "$sentinel"
  echo "$label $version yanked (do-not-elect) — sentinel staged, not committed"
else
  if ! jq -e --arg v "$version" '.yanked | index($v)' <<<"$entry" >/dev/null; then
    echo "$label $version is not yanked — no changes"
    exit 0
  fi
  if git ls-files --error-unmatch "$sentinel" >/dev/null 2>&1; then
    git rm -q -f "$sentinel"
  else
    rm "$sentinel"
  fi
  echo "$label $version unyanked — sentinel removed, staged if it was tracked"
fi
