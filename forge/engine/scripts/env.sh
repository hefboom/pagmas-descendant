#!/usr/bin/env bash
# Sourced by every forge script, never run: resolves where the engine is and where the
# descendant is, then cds to the manifest dir so `elections.json`, `skills/`, `kegs/`
# and `scratch/` resolve as bare relative paths.
#
#   ENGINE  the dir holding this scripts/ tree and the justfile — call siblings via "$ENGINE/scripts/<x>"
#   ROOT    the descendant: $FORGE_ROOT if set, else the nearest ancestor of ENGINE holding forge/elections.json
#   FORGE   $ROOT/forge — the manifest, the cellars, scratch; the cwd from here on
#
# The engine owns no paths: ROOT plus the manifest own all of them.

ENGINE=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
if [[ -n ${FORGE_ROOT:-} ]]; then
  ROOT=$(cd "$FORGE_ROOT" && pwd)
else
  ROOT=$ENGINE
  until [[ -f $ROOT/forge/elections.json ]]; do
    if [[ $ROOT == / ]]; then
      echo "forge: no ancestor of $ENGINE holds forge/elections.json — set FORGE_ROOT to the descendant" >&2
      exit 1
    fi
    ROOT=$(dirname "$ROOT")
  done
fi
FORGE=$ROOT/forge
[[ -f $FORGE/elections.json ]] || { echo "forge: $FORGE/elections.json not found (FORGE_ROOT=$ROOT)" >&2; exit 1; }
cd "$FORGE"
