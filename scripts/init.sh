#!/usr/bin/env bash
# forge init — scaffold a descendant around this engine (the rare book).
#
# Runs once, directly, before `just forge` exists in the new repo:
#   git subtree add --prefix forge/engine https://github.com/hefboom/pagma.git v0.1.0 --squash
#   bash forge/engine/scripts/init.sh
#
# Target is $FORGE_ROOT if set, else the engine's grandparent — the engine must sit at
# <descendant>/forge/engine/. Copies examples/descendant/ in (never overwriting a file
# that exists), pins the manifest to this engine's VERSION, installs bun deps, renders.
# Touches nothing outside the descendant: linking ~/.claude/* at the bin trees is yours.
set -euo pipefail

ENGINE=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
if [[ -n ${FORGE_ROOT:-} ]]; then
  ROOT=$(cd "$FORGE_ROOT" && pwd)
else
  [[ $(basename "$ENGINE") == engine && $(basename "$(dirname "$ENGINE")") == forge ]] \
    || { echo "forge init: engine is at $ENGINE, expected <descendant>/forge/engine — set FORGE_ROOT to the descendant" >&2; exit 1; }
  ROOT=$(cd "$ENGINE/../.." && pwd)
fi

missing=()
for t in bun just jq fzf python3; do command -v "$t" >/dev/null 2>&1 || missing+=("$t"); done
if (( ${#missing[@]} )); then
  echo "forge init: missing prerequisites: ${missing[*]} (bun runs the renderer, just the verbs, jq the manifest edits, fzf the pickers, python3 the edge ledger)" >&2
  echo "  install them, or hand INSTALL.md to a coding agent: $ENGINE/INSTALL.md" >&2
  exit 1
fi

just_floor=1.31.0
just_have=$(just --version | awk '{print $2}')
if [[ $(printf '%s\n%s\n' "$just_floor" "$just_have" | sort -V | head -1) != "$just_floor" ]]; then
  echo "forge init: just $just_have is too old — the justfile needs $just_floor or newer ([group], mod); distro packages often lag, see INSTALL.md" >&2
  exit 1
fi

[[ -e $ROOT/forge/elections.json ]] && { echo "forge init: $ROOT/forge/elections.json exists — already a descendant" >&2; exit 1; }

template=$ENGINE/examples/descendant
copied=() kept=()
while IFS= read -r rel; do
  src=$template/$rel dest=$ROOT/$rel
  if [[ -e $dest ]]; then kept+=("$rel"); continue; fi
  mkdir -p "$(dirname "$dest")"
  cp "$src" "$dest"
  copied+=("$rel")
done < <(cd "$template" && find . -type f -not -name README.md -not -path './home/*' -not -path './forge/scratch/*' | sed 's|^\./||' | sort)

version=v$(tr -d '[:space:]' < "$ENGINE/VERSION")
manifest=$ROOT/forge/elections.json
jq --arg v "$version" '.engine = $v' "$manifest" > "$manifest.tmp" && mv "$manifest.tmp" "$manifest"

(cd "$ENGINE" && bun install --silent)
FORGE_ROOT=$ROOT bun run "$ENGINE/scripts/render.ts" >/dev/null

echo "forge init: descendant at $ROOT, engine $version"
printf '  wrote  %s\n' ${copied[@]+"${copied[@]}"}
for k in ${kept[@]+"${kept[@]}"}; do
  echo "  kept   $k (exists — merge by hand against examples/descendant/$k)"
done
cat <<MSG

Next:
  just forge status                       the resolution table
  ln -s $ROOT/home/claude/skills ~/.claude/skills   point the harness at the bin trees (also agents/)
  cp -R forge/skills/global/hello/v1.0.0 forge/skills/global/<name>/v1.0.0   author, then elect-exact
MSG
