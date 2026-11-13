#!/usr/bin/env bash
# Move a skill between cellar scopes, non-interactively — `just forge move-exact <label> <scope>` / `retire-exact <label>`.
# Depth: scripts/README.md#move-coresh

set -euo pipefail
source "$(dirname "$0")/env.sh"

JSON=scratch/move-core.json
MANIFEST=elections.json

if [[ $# -ne 2 ]]; then
  echo "usage: move-core.sh <label> <dest-scope>" >&2
  echo "  e.g. move-core.sh claude-code/global/access-surface keg-only" >&2
  exit 2
fi
label=$1
dest_scope=$2

mkdir -p scratch
bun run "$ENGINE/scripts/render.ts" --json >"$JSON"

if jq -e --arg l "$label" '.tools[] | select(.label == $l)' "$JSON" >/dev/null; then
  echo "\"$label\" is a tool election — rendered skills may declare it, moving is not supported" >&2
  exit 1
fi
if jq -e --arg l "$label" '.partials[] | select(.label == $l)' "$JSON" >/dev/null; then
  echo "\"$label\" is a partial election — the partials cellar has no scopes, moving is not supported" >&2
  exit 1
fi
if jq -e --arg l "$label" '.agents[] | select(.label == $l)' "$JSON" >/dev/null; then
  echo "\"$label\" is an agent election — the agents cellar has no scopes, moving is not supported" >&2
  exit 1
fi

entry=$(jq -c --arg l "$label" '
  .skills[] | select(.label == $l) | {label, harness, scope, name}
' "$JSON")

if [[ -z "$entry" ]]; then
  echo "unknown label \"$label\"" >&2
  near=$(jq -r '.skills[].label' "$JSON" | grep -F -- "${label##*/}" || true)
  if [[ -n "$near" ]]; then
    echo "did you mean:" >&2
    sed 's/^/  /' <<<"$near" >&2
  else
    echo "list all: just forge render --json | jq -r '.skills[].label'" >&2
  fi
  exit 1
fi

harness=$(jq -r .harness <<<"$entry")
scope=$(jq -r .scope <<<"$entry")
name=$(jq -r .name <<<"$entry")

if [[ "$dest_scope" == "$scope" ]]; then
  echo "\"$label\" is already in scope \"$scope\" — no move" >&2
  exit 1
fi

# A legal destination already exists — the dump's per-harness scopes array lists
# them (rooted scopes, multicast scopes, cellar scope dirs, keg-only). A brand-new scope is manifest
# authoring, not a move.
dest_entry=$(jq -c --arg h "$harness" --arg s "$dest_scope" '.scopes[$h][] | select(.name == $s)' "$JSON")
if [[ -z "$dest_entry" ]]; then
  echo "unknown destination scope \"$dest_scope\" — legal destinations:" >&2
  jq -r --arg h "$harness" '.scopes[$h][].name' "$JSON" | grep -vx "$scope" | sed 's/^/  /' >&2
  exit 1
fi
transplants=$(jq -r '.root // .multicast // empty' <<<"$dest_entry")

# The cellar move hits every election of this scope/name, not just this label —
# another harness still electing it would be left pointing at a missing entry.
others=$(jq -r --argjson e "$entry" '
  .skills[] | select(.scope == $e.scope and .name == $e.name and .label != $e.label) | .label
' "$JSON")
if [[ -n "$others" ]]; then
  echo "\"$scope/$name\" is still elected elsewhere — move those first:" >&2
  sed 's/^/  /' <<<"$others" >&2
  exit 1
fi

src="skills/$scope/$name"
dest="skills/$dest_scope/$name"
if [[ ! -d "$src" ]]; then
  echo "cellar entry $src missing — manifest and cellar disagree" >&2
  exit 1
fi
if [[ -e "$dest" ]]; then
  echo "$dest already exists — resolve the collision by hand" >&2
  exit 1
fi

tmp=scratch/elections.json.tmp
# Captured before the drop — the whole entry (version, tier override, bundle) is what
# transplants, not just the version string.
election=$(jq -c --argjson e "$entry" '.harnesses[$e.harness].elections[$e.scope][$e.name]' "$MANIFEST")

# (a) Drop the source election. The cellar entry is now unelected but still in place,
# which renders: prune removes the bin dir and nothing points at a missing source.
jq --argjson e "$entry" 'del(.harnesses[$e.harness].elections[$e.scope][$e.name])' "$MANIFEST" >"$tmp"
mv "$tmp" "$MANIFEST"

# (b) Move the cellar entry.
mkdir -p "skills/$dest_scope"
git mv "$src" "$dest"

# (c) Re-add the entry under the destination scope, now that the cellar entry is there
# to render from. A destination that is neither rooted nor multicast (keg-only
# included) skips this — an election in a scope with no root refuses to render.
if [[ -n "$transplants" ]]; then
  jq --argjson e "$entry" --arg d "$dest_scope" --argjson el "$election" \
    '.harnesses[$e.harness].elections[$d][$e.name] = $el' "$MANIFEST" >"$tmp"
  mv "$tmp" "$MANIFEST"
fi

# (d) Render.
bun run "$ENGINE/scripts/render.ts" | grep -E '^pruned:' || true
if [[ "$dest_scope" == "keg-only" ]]; then
  echo "$label retired — cellar at $dest, election removed, bin tree pruned"
elif [[ -n "$transplants" ]]; then
  echo "$label -> $harness/$dest_scope/$name — cellar moved, election transplanted, rendered"
else
  echo "$label -> $dest_scope/$name — cellar moved; \"$dest_scope\" has no root, election dropped (declare a root + election to render it)"
fi
echo "cellar move is staged; commit when ready"
