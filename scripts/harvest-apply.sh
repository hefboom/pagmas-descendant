#!/usr/bin/env bash
# Cut the next sssf-suite keg from an approved plan — `just forge harvest-apply <plan>`.
# Depth: scripts/README.md#harvest-applysh

set -euo pipefail
source "$(dirname "$0")/env.sh"

SUITE_DIR=kegs/sssf-suite
dev_root=${FORGE_DEV_ROOT:-$HOME/dev}

# One exit path owns all cleanup: the temp files, the extraction, and a vNext this
# run created but has not staged. `own_next` opens after the refusal of an existing
# vNext and closes at `git add`, so an existing keg is never removed.
member_disp= src= next= own_next= finished=
cleanup() {
  local rc=$?
  set +e
  [[ -z $own_next ]] || rm -rf "$next"
  [[ -z $src ]] || rm -rf "$src"
  rm -f "$member_disp"
  [[ $rc -ne 0 || -n $finished ]] || rc=1   # bash 3.2 hands a set -u exit to the trap as 0
  exit "$rc"
}
trap cleanup EXIT

if [[ $# -ne 1 ]]; then
  echo "usage: harvest-apply.sh <plan>   e.g. harvest-apply.sh scratch/harvest/my-factory-v1.4.0.plan.md" >&2
  exit 2
fi
plan=$1
[[ -f "$plan" ]] || { echo "no plan at $plan — run harvest-plan first" >&2; exit 1; }

# ---- read the plan ------------------------------------------------------------
hdr() { sed -n "s/^- $1: //p" "$plan" | head -1; }
vnext=$(sed -n '1s/^# harvest plan — sssf-suite \(v[0-9.]*\) from .*/\1/p' "$plan")
repo=$(sed -n '1s/^# harvest plan — sssf-suite v[0-9.]* from \(.*\)$/\1/p' "$plan")
sha=$(hdr source | sed -E 's/^[^@]*@ ([0-9a-f]+).*/\1/')
vprev=$(hdr base | sed -E 's/ · bump: .*//')
note=$(hdr note)
status=$(hdr status | awk '{print $1}')
[[ -n "$vnext" && -n "$repo" && -n "$sha" && -n "$vprev" ]] || { echo "$plan: header unreadable — regenerate with harvest-plan" >&2; exit 1; }

lab_file=$SUITE_DIR/.lab
lab=
[[ -f "$lab_file" ]] && lab=$(tr -d '[:space:]' <"$lab_file")
if [[ -z "$lab" ]]; then
  echo "no lab is set ($lab_file is missing or empty) — write the lab repo's basename to $lab_file, then stamp the new lab" >&2
  exit 1
fi
if [[ "$lab" != "$repo" ]]; then
  echo "$plan names $repo, which is not this forge's lab ($lab) — harvest-apply only runs against it; to move the role, edit $lab_file, then stamp the new lab" >&2
  exit 1
fi

case "$status" in
  approved) ;;
  applied) echo "$plan is already applied — the keg is $SUITE_DIR/$vnext" >&2; exit 1 ;;
  *) echo "$plan is '$status' — set 'status: approved' once the tables say what you mean" >&2; exit 1 ;;
esac
if [[ -z "$note" || "$note" == '<'* ]]; then
  echo "fill in the plan's '- note:' line — it becomes the charter's history entry for $vnext" >&2
  exit 1
fi

member_disp=$(mktemp)
awk -F'|' '
  /^## Members/ {t="m"; next} /^## / {t=""}
  t && /^\|/ && $2 !~ /disposition|member|^ *-+ *$/ {
    for (i=2;i<=NF;i++) gsub(/^ +| +$/, "", $i)
    if ($2=="harvest" || $2=="ride-along") print $2 "\t" $3 > "'"$member_disp"'"
  }' "$plan"
dispositions=$(cat "$member_disp")   # applied below, once the ends resolve the commit that names the members

# ---- the ends, re-checked against the world only to refuse, never to derive ---
repo_dir=$dev_root/$repo
[[ -e "$repo_dir/.git" ]] || { echo "no git repo at $repo_dir" >&2; exit 1; }
if ! git -C "$repo_dir" rev-parse --verify --quiet "$sha^{commit}" >/dev/null; then
  echo "commit $sha (the plan's source) is not in $repo — re-run harvest-plan" >&2
  exit 1
fi
latest=
for v in $(ls "$SUITE_DIR" | sort -rV); do
  [[ -d "$SUITE_DIR/$v" && ! -e "$SUITE_DIR/$v/.yanked" ]] && latest=$v && break
done
if [[ "$latest" != "$vprev" ]]; then
  echo "plan is based on $vprev but the latest non-yanked keg is now $latest — re-run harvest-plan" >&2
  exit 1
fi
next=$SUITE_DIR/$vnext
[[ -e "$next" ]] && { echo "$next already exists — kegs are immutable; bump again or remove it by hand" >&2; exit 1; }

# ---- members: sssf's `suite` at the plan's commit, each with its disposition from the plan ---
members=($(bash "$ENGINE/scripts/suite-members.sh" "$repo_dir" "$sha")) || exit 1
harvest=(); ride=()
for m in "${members[@]}"; do
  d=$(awk -F'\t' -v m="$m" '$2==m{print $1}' <<<"$dispositions")
  case "$d" in
    harvest) harvest+=("$m") ;;
    ride-along) ride+=("$m") ;;
    *) echo "member $m has no disposition in the plan — regenerate with harvest-plan" >&2; exit 1 ;;
  esac
done
if [[ ${#harvest[@]} -eq 0 ]]; then
  echo "no member is marked harvest — nothing to release" >&2
  exit 1
fi

# ---- materialize -----------------------------------------------------------------
fail() { echo "$1" >&2; exit 1; }
src=scratch/harvest/apply/$repo-$vnext
rm -rf "$src"; mkdir -p "$src"
git -C "$repo_dir" archive "$sha" .claude/skills | tar -x -C "$src"

own_next=1
cp -R "$SUITE_DIR/$vprev" "$next"
rm -f "$next/.yanked"
for m in "${harvest[@]}"; do
  rm -rf "$next/$m"
  cp -R "$src/.claude/skills/$m" "$next/$m"
done

# Charter: one appended paragraph, prior history untouched.
harvested_list=$(IFS=,; echo "${harvest[*]}" | sed 's/,/, /g')
ride_list=$(IFS=,; echo "${ride[*]:-}" | sed 's/,/, /g')
{
  echo
  echo "$vnext ($(date +%Y-%m-%d), harvested from $repo @ $sha) — $note"
  echo "Members harvested: $harvested_list.${ride:+ Unchanged from $vprev: $ride_list.}"
} >>"$next/SKILL.md"

# ---- validate --------------------------------------------------------------------
links=$(find "$next" -type l)
[[ -z "$links" ]] || fail "symlinks landed in $next — refusing:"$'\n'"$links"
for m in "${harvest[@]}"; do
  want=$(git -C "$repo_dir" ls-tree -r --name-only "$sha" ".claude/skills/$m" | sed "s|^.claude/skills/$m/||" | sort)
  have=$(cd "$next/$m" && find . -type f | sed 's|^\./||' | sort)
  [[ "$want" == "$have" ]] || fail "$m: keg file set differs from the repo's tracked set at $sha:"$'\n'"$(diff <(echo "$want") <(echo "$have") || true)"
  diff -rq "$src/.claude/skills/$m" "$next/$m" >/dev/null || fail "$m: keg content differs from the archive"
done
for m in "${members[@]}"; do
  [[ -d "$next/$m" ]] || fail "member $m missing from $next"
done
[[ -f "$next/SKILL.md" ]] || fail "charter SKILL.md missing from $next"

# every member's authoring rules, checked by the engine the keg itself ships — the rules
# and their check version together with the templates. No engine, no cut: a keg
# that cannot run its own check cannot vouch that its templates start in a
# consumer. An engine without clean-room is refused too: that check is the only
# place install.py is run before a consumer runs it (argparse rejects an unknown
# --check before --help can exit 0).
engine=$next/sssf/scripts/conformance.py
[[ -f "$engine" ]] || fail "conformance: sssf/scripts/conformance.py missing — harvest sssf (not ride-along) from a source that ships it"
PYTHONDONTWRITEBYTECODE=1 uv run --quiet "$engine" --check clean-room --help >/dev/null 2>&1 \
  || fail "conformance: sssf/scripts/conformance.py has no clean-room check — harvest sssf (not ride-along) from a source whose engine ships it"
out=$(PYTHONDONTWRITEBYTECODE=1 uv run --quiet "$engine" --suite "$next" --source "$repo_dir" --rev "$sha" 2>&1) \
  || fail "conformance: the suite breaks its own authoring rules (sssf/references/authoring-rules.md) — refusing $vnext:"$'\n'"$out"

# ---- record ------------------------------------------------------------------------
git add "$next"
own_next=   # staged: the keg is the release act's now
sed -i '' "s|^- status: approved.*|- status: applied   ($next, $(date '+%Y-%m-%d %H:%M'))|" "$plan"

echo "cut sssf-suite $vnext from $repo @ $sha (base $vprev)"
echo "  harvested:  $harvested_list"
[[ -n "${ride:-}" ]] && echo "  ride-along: $ride_list"
echo "  staged: $next"
echo "release act pending — commit in $(cd .. && pwd):"
echo "  git commit -m 'add sssf-suite at $vnext'"
echo "then stamp consumers: just forge stamp-exact <repo> $vnext, then render.py from each root"
echo "  (no sssf-overlay/: render.py capture each customized file before the stamp, not after)"
echo "  including $repo itself — tracked content there is unchanged, but the stamp writes its receipt at $vnext"
finished=1
