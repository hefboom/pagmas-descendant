#!/usr/bin/env bash
# Compact human render of the verb lexicon — `just forge` (and `just forge all`).
# Depth: scripts/README.md#verbssh

set -euo pipefail
source "$(dirname "$0")/env.sh"
cd "$ENGINE" # just --dump reads the justfile here

# Colour only when stdout is a terminal, so a pipe or a capture stays clean.
if [ -t 1 ]; then B=$'\033[1m'; D=$'\033[2m'; H=$'\033[1;36m'; R=$'\033[0m'
else B=''; D=''; H=''; R=''; fi

show_all=0
[ "${1:-}" = "--all" ] && show_all=1

json=$(just --dump --dump-format json)
US=$'\x1f'

order=$(grep -o "^\[group('[^']*')\]" justfile | sed "s/^\[group('//;s/')\]\$//" | awk '!seen[$0]++')

printf '%sforge%s %s— versioned skill cellar + renderer%s\n' "$B" "$R" "$D" "$R"

for g in $order; do
  printf '\n  %s%s%s\n' "$H" "$g" "$R"
  jq -r --arg g "$g" --argjson all "$show_all" --arg us "$US" '
    (.recipes | keys) as $names
    | .recipes | to_entries[]
    | select([.value.attributes[]? | objects | .group?] | index($g))
    | .key as $k
    | (($k | endswith("-exact")) and (($names | index($k | rtrimstr("-exact"))) != null)) as $agent
    | select($all == 1 or ($agent | not))
    | (.value.parameters | map(
        if .kind == "star" then "[" + .name + "...]"
        elif .default != null then "[" + .name + "]"
        else "<" + .name + ">" end) | join(" ")) as $p
    | ($k + (if $p == "" then "" else " " + $p end)) as $sig
    | ((.value.doc // "") | split(". ")[0] | split(" — ")[0] | split(": ")[0]
       | rtrimstr(".")) as $short
    | [$sig, $short, ($agent | tostring)] | join($us)
  ' <<<"$json" | sort | while IFS="$US" read -r sig short agent; do
      [ ${#short} -gt 62 ] && short="${short:0:59}..."
      if [ "$agent" = true ]; then
        printf '    %s%-30s %s  (agent)%s\n' "$D" "$sig" "$short" "$R"
      else
        printf '    %s%-30s%s %s%s%s\n' "$B" "$sig" "$R" "$D" "$short" "$R"
      fi
    done
done

printf '\n  %sfull contract, every verb:  just --list forge' "$D"
[ "$show_all" = 1 ] || printf '     agent-only verbs:  just forge all'
printf '%s\n\n' "$R"
