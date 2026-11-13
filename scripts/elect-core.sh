#!/usr/bin/env bash
# Elect a version, non-interactively — `just forge elect-exact <label> <version>`;
# or set an election's tier override — `just forge tier-exact <label> <tier>` (= --tier);
# or set/drop an agent variant — `just forge variant-exact <label> <name> [key=value ...]` (= --variant).
# Depth: scripts/README.md#elect-coresh

set -euo pipefail
source "$(dirname "$0")/env.sh"

JSON=scratch/elect-core.json
MANIFEST=elections.json

tiermode=0
variantmode=0
args=()
for a in "$@"; do
  case "$a" in
    --tier) tiermode=1 ;;
    --variant) variantmode=1 ;;
    *) args+=("$a") ;;
  esac
done
usage() {
  echo "usage: elect-core.sh <label> <version>" >&2
  echo "       elect-core.sh --tier <label> <tier|->" >&2
  echo "       elect-core.sh --variant <label> <name> [tier=<tier>] [effort=<effort>] [disallowedTools=<list>]" >&2
  echo "       elect-core.sh --variant <label> <name> -" >&2
  echo "  e.g. elect-core.sh claude-code/global/check-code v1.4.0" >&2
  echo "       elect-core.sh --tier claude-code/global/orchestrate 'sota[fable]'" >&2
  echo "       elect-core.sh --variant claude-code/agents/systems-architect systems-architect-medium effort=medium" >&2
  exit 2
}
if [[ $variantmode -eq 1 ]]; then
  [[ ${#args[@]} -ge 2 ]] || usage
elif [[ ${#args[@]} -ne 2 ]]; then
  usage
fi
label=${args[0]}
version=${args[1]}

mkdir -p scratch
bun run "$ENGINE/scripts/render.ts" --json >"$JSON"

# `kind` decides which manifest section the label addresses; harness/scope/name come
# from the dump rather than from splitting the label, so the path is authoritative.
entry=$(jq -c --arg l "$label" '
  (.skills[] | select(.label == $l) | {kind: "skill", harness, scope, name, version, versions, yanked}),
  (.tools[]  | select(.label == $l) | {kind: "tool",  harness,        name, version, versions, yanked}),
  (.partials[] | select(.label == $l) | {kind: "partial", harness,    name, version, versions, yanked}),
  (.agents[] | select(.label == $l) | {kind: "agent", harness,        name, version, versions, yanked, variant})
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

if [[ $variantmode -eq 1 ]]; then
  # Variant mode: `version` carries the rendered name; the rest are key=value overrides
  # (helm `--set` shape), or a lone `-` drops the variant. Whether a key is lowerable
  # and a tier exists is render's contract — the shadow render refuses.
  name=$version
  if [[ "$kind" != "agent" ]]; then
    echo "\"$label\" is a $kind election — only agents carry variants, refusing" >&2
    exit 1
  fi
  current=$(jq -c --argjson e "$entry" --arg n "$name" \
    '.harnesses[$e.harness].agents[$e.name].variants[$n] // "-"' "$MANIFEST")
  tmp=scratch/elections.json.tmp
  if [[ ${#args[@]} -eq 3 && "${args[2]}" == "-" ]]; then
    if [[ "$current" == '"-"' ]]; then
      echo "$label has no variant $name — no changes"
      exit 0
    fi
    # Dropping the last variant drops the key: the entry renders under its own name again.
    jq --argjson e "$entry" --arg n "$name" '
      .harnesses[$e.harness].agents[$e.name] |= (del(.variants[$n]) | if .variants == {} then del(.variants) else . end)
    ' "$MANIFEST" >"$tmp"
    next="-"
  else
    over='{}'
    for kv in "${args[@]:2}"; do
      if [[ "$kv" != *=* ]]; then
        echo "override \"$kv\" is not key=value" >&2
        exit 2
      fi
      over=$(jq -c --arg k "${kv%%=*}" --arg v "${kv#*=}" '. + {($k): $v}' <<<"$over")
    done
    if [[ "$current" == "$over" ]]; then
      echo "$label variant $name already is $over — no changes"
      exit 0
    fi
    jq --argjson e "$entry" --arg n "$name" --argjson o "$over" '
      .harnesses[$e.harness].agents[$e.name].variants[$n] = $o
    ' "$MANIFEST" >"$tmp"
    next=$over
  fi
elif [[ $tiermode -eq 1 ]]; then
  # Tier mode: `version` carries the tier (`-` clears the override). Whether the tier
  # and its qualifier exist is render's contract — the shadow render below refuses.
  tier=$version
  if [[ "$kind" != "skill" ]]; then
    echo "\"$label\" is a $kind election — tools and partials carry no tier, an agent's tier lives on its variants (--variant), refusing" >&2
    exit 1
  fi
  current=$(jq -r --argjson e "$entry" \
    '.harnesses[$e.harness].elections[$e.scope][$e.name].tier // "-"' "$MANIFEST")
  if [[ "$tier" == "$current" ]]; then
    echo "$label already has tier override $tier — no changes"
    exit 0
  fi
  tmp=scratch/elections.json.tmp
  if [[ "$tier" == "-" ]]; then
    jq --argjson e "$entry" \
      'del(.harnesses[$e.harness].elections[$e.scope][$e.name].tier)' "$MANIFEST" >"$tmp"
  else
    jq --argjson e "$entry" --arg t "$tier" \
      '.harnesses[$e.harness].elections[$e.scope][$e.name].tier = $t' "$MANIFEST" >"$tmp"
  fi
else
  current=$(jq -r .version <<<"$entry")

  if ! jq -e --arg v "$version" '.versions | index($v)' <<<"$entry" >/dev/null; then
    echo "\"$label\" has no version $version — eligible:" >&2
    jq -r '(.versions - .yanked)[]' <<<"$entry" | sed 's/^/  /' >&2
    exit 1
  fi
  if jq -e --arg v "$version" '.yanked | index($v)' <<<"$entry" >/dev/null; then
    echo "\"$label\" $version is yanked (do-not-elect) — refusing" >&2
    exit 1
  fi
  if [[ "$version" == "$current" ]]; then
    echo "$label already elects $version — no changes"
    exit 0
  fi

  tmp=scratch/elections.json.tmp
  case "$kind" in
    skill) jq --argjson e "$entry" --arg v "$version" \
      '.harnesses[$e.harness].elections[$e.scope][$e.name].version = $v' "$MANIFEST" >"$tmp" ;;
    tool) jq --argjson e "$entry" --arg v "$version" \
      '.harnesses[$e.harness].tools[$e.name].version = $v' "$MANIFEST" >"$tmp" ;;
    partial) jq --argjson e "$entry" --arg v "$version" \
      '.harnesses[$e.harness].partials[$e.name].version = $v' "$MANIFEST" >"$tmp" ;;
    agent) jq --argjson e "$entry" --arg v "$version" \
      '.harnesses[$e.harness].agents[$e.name].version = $v' "$MANIFEST" >"$tmp" ;;
  esac
fi

# Compile-then-commit: the candidate manifest renders into scratch before it replaces
# the live one, so a candidate that refuses leaves elections.json byte-identical.
shadow=scratch/elect-core-shadow
rm -rf "$shadow"
if ! bun run "$ENGINE/scripts/render.ts" --manifest "$tmp" --out "$shadow" >/dev/null; then
  echo "candidate manifest does not render — elections.json unchanged" >&2
  rm -f "$tmp"
  exit 1
fi
mv "$tmp" "$MANIFEST"

bun run "$ENGINE/scripts/render.ts" >/dev/null
if [[ $variantmode -eq 1 ]]; then
  echo "$label#$name: $current -> $next — manifest written, rendered"
elif [[ $tiermode -eq 1 ]]; then
  echo "$label: tier $current -> $tier — manifest written, rendered"
else
  echo "$label: $current -> $version — manifest written, rendered"
fi
