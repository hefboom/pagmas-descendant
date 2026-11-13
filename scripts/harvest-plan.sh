#!/usr/bin/env bash
# Plan the next sssf-suite keg from the lab — `just forge harvest-plan <repo> [bump]`.
# Depth: scripts/README.md#harvest-plansh

set -euo pipefail
source "$(dirname "$0")/env.sh"

SUITE_DIR=kegs/sssf-suite
dev_root=${FORGE_DEV_ROOT:-$HOME/dev}

# One exit path owns all cleanup: the temp files and the extraction, on every exit,
# success included. Nothing reads the extraction after the plan is written.
src= member_rows= rendered= finished=
cleanup() {
  local rc=$?
  set +e
  [[ -z $src ]] || rm -rf "$src"
  rm -f "$member_rows" "$rendered"
  [[ $rc -ne 0 || -n $finished ]] || rc=1   # bash 3.2 hands a set -u exit to the trap as 0
  exit "$rc"
}
trap cleanup EXIT

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "usage: harvest-plan.sh <repo> [major|minor|patch]   e.g. harvest-plan.sh my-factory minor" >&2
  exit 2
fi
repo=$1
bump=${2:-patch}
case "$bump" in major|minor|patch) ;; *) echo "bump must be major, minor or patch (got '$bump')" >&2; exit 2;; esac

repo_dir=$dev_root/$repo
if [[ ! -d "$repo_dir" ]]; then
  echo "no repo at $repo_dir (FORGE_DEV_ROOT overrides the ~/dev default)" >&2
  exit 1
fi
if [[ ! -e "$repo_dir/.git" ]]; then
  echo "$repo_dir is not a git repo (no .git)" >&2
  exit 1
fi

lab_file=$SUITE_DIR/.lab
lab=
[[ -f "$lab_file" ]] && lab=$(tr -d '[:space:]' <"$lab_file")
if [[ -z "$lab" ]]; then
  echo "no lab is set ($lab_file is missing or empty) — write the lab repo's basename to $lab_file, then stamp the new lab" >&2
  exit 1
fi
if [[ "$lab" != "$repo" ]]; then
  echo "$repo is not this forge's lab ($lab) — harvest-plan only runs against it; to move the role, edit $lab_file, then stamp the new lab" >&2
  exit 1
fi

# ---- ends: vPrev (latest non-yanked keg) and vNext (bump) --------------------
# keg-core.sh owns latest-keg resolution; it prints an absolute path, kept forge-relative here.
keg=$(bash "$ENGINE/scripts/keg-core.sh") || exit 1
keg=${keg#"$PWD/"}
vprev=${keg##*/}
IFS=. read -r maj min pat <<<"${vprev#v}"
case "$bump" in
  major) vnext="v$((maj + 1)).0.0" ;;
  minor) vnext="v$maj.$((min + 1)).0" ;;
  patch) vnext="v$maj.$min.$((pat + 1))" ;;
esac

# ---- source: HEAD, extracted through git archive -----------------------------
head_sha=$(git -C "$repo_dir" rev-parse --short HEAD)
dirty=$(git -C "$repo_dir" status --porcelain | wc -l | tr -d ' ')

# The members: sssf's `suite` at HEAD (scripts/suite-members.sh), the list the gate fans out over.
members=($(bash "$ENGINE/scripts/suite-members.sh" "$repo_dir" "$head_sha")) || exit 1
for d in "$keg"/*/; do
  d=$(basename "$d")
  case " ${members[*]} " in *" $d "*) ;; *)
    echo "$vprev ships member $d, which sssf's suite at $head_sha does not name — the forge cannot remove a member yet" >&2; exit 1 ;;
  esac
done
for m in "${members[@]}"; do
  if ! git -C "$repo_dir" ls-files --error-unmatch ".claude/skills/$m" >/dev/null 2>&1; then
    echo "member .claude/skills/$m is not tracked in $repo — the suite is not live here" >&2
    exit 1
  fi
  if git -C "$repo_dir" ls-files -s ".claude/skills/$m" | awk '$1=="120000"{f=1} END{exit !f}'; then
    echo "member .claude/skills/$m contains tracked symlinks — a rendered copy, not a source" >&2
    exit 1
  fi
done

src=scratch/harvest/src/$repo
rm -rf "$src"
mkdir -p "$src"
git -C "$repo_dir" archive HEAD .claude/skills | tar -x -C "$src"

# ---- receipt: which keg the repo says it is at -------------------------------
receipt=$src/.claude/skills/sssf-suite.receipt.json
stamped_version=
receipt_line="none (stamped before receipts existed, or never stamped — stamp-exact writes one)"
if [[ -f "$receipt" ]]; then
  stamped_version=$(jq -r '.version // empty' "$receipt")
  stamped_at=$(jq -r '.stamped_at // empty' "$receipt")
  receipt_line="$stamped_version, stamped $stamped_at"
  [[ "$stamped_version" != "$vprev" ]] && receipt_line="$receipt_line — BEHIND: latest keg is $vprev; the member diff below mixes this repo's edits with every suite change since $stamped_version. Re-stamp $vprev first to see only the repo's own edits"
fi

# ---- member axis --------------------------------------------------------------
# rows: member<TAB>status<TAB>path   (path relative to the member dir)
member_rows=$(mktemp)
for m in "${members[@]}"; do
  if [[ ! -d "$keg/$m" ]]; then   # new to the suite: every file is added
    (cd "$src/.claude/skills/$m" && find . -type f | sed 's|^\./||' | sort) | awk -v m="$m" '{print m "\tadded\t" $0}' >>"$member_rows"
    continue
  fi
  diff -rq "$src/.claude/skills/$m" "$keg/$m" 2>/dev/null | awk -v m="$m" -v a="$src/.claude/skills/$m" -v b="$keg/$m" '
    /^Only in / {
      dir=$3; sub(/:$/, "", dir); name=$4
      p = (dir==a || dir==b) ? name : substr(dir, length((dir ~ "^"a) ? a : b)+2) "/" name
      print m "\t" ((dir ~ "^"a) ? "added" : "removed") "\t" p; next }
    /^Files / { p=substr($2, length(a)+2); print m "\tmodified\t" p }
  ' >>"$member_rows" || true
done

# ---- render: the source's own oracle at HEAD, one line ------------------------
# The extracted sssf's engine judges the repo at HEAD, outside its working tree,
# so it reads the overlay and the rendered roots from git: the keg's snapshot.
engine=$src/.claude/skills/sssf/scripts/conformance.py
render_line="none — $repo's sssf ships no render-oracle check"
if PYTHONDONTWRITEBYTECODE=1 uv run --quiet "$engine" --check render-oracle --help >/dev/null 2>&1; then
  rc=0
  out=$(PYTHONDONTWRITEBYTECODE=1 uv run --quiet "$engine" --check render-oracle --source "$repo_dir" --rev "$head_sha" 2>&1) || rc=$?
  case $rc in
    0) render_line=$out ;;
    1) render_line="FAIL — $(grep -c '^FAIL ' <<<"$out") line(s) from render-oracle at $head_sha: harvest-apply will refuse; fix it in $repo (each line names render.py or capture), commit, re-plan" ;;
    *) render_line="cannot run (exit $rc): $(tail -1 <<<"$out")" ;;
  esac
fi

# ---- the note: carried forward from this plan if it exists ---------------------
mkdir -p scratch/harvest
plan=scratch/harvest/$repo-$vnext.plan.md
note_placeholder='<one line for the charter: what this release carries>'
release_note=$note_placeholder
[[ -f "$plan" ]] && release_note=$(sed -n 's/^- note: //p' "$plan" | head -1)
[[ -z "$release_note" ]] && release_note=$note_placeholder

# ---- render the plan ----------------------------------------------------------
rendered=$plan.tmp   # renamed onto the plan once whole: a crash mid-render leaves an edited plan as it was
{
  echo "# harvest plan — sssf-suite $vnext from $repo"
  echo
  echo "- source: $repo @ $head_sha$( [[ "$dirty" -gt 0 ]] && echo " (WORKING TREE DIRTY: $dirty path(s) uncommitted — the plan reads HEAD, commit first if they belong in the keg)" )"
  echo "- base: $vprev · bump: $bump"
  echo "- receipt: $receipt_line"
  echo "- generated: $(date '+%Y-%m-%d %H:%M')"
  echo "- note: $release_note"
  echo "- render: $render_line"
  echo "- status: draft   <- set to \`approved\` once the tables below say what you mean"
  echo
  echo "## Members (must converge — a changed member rides into the keg whole)"
  echo
  echo "| disposition | member | added | removed | modified | unchanged |"
  echo "|---|---|---|---|---|---|"
  for m in "${members[@]}"; do
    a=$(awk -F'\t' -v m="$m" '$1==m && $2=="added"' "$member_rows" | wc -l | tr -d ' ')
    r=$(awk -F'\t' -v m="$m" '$1==m && $2=="removed"' "$member_rows" | wc -l | tr -d ' ')
    c=$(awk -F'\t' -v m="$m" '$1==m && $2=="modified"' "$member_rows" | wc -l | tr -d ' ')
    total=$(git -C "$repo_dir" ls-files ".claude/skills/$m" | wc -l | tr -d ' ')
    u=$((total - a - c))
    disp=ride-along; [[ $((a + r + c)) -gt 0 ]] && disp=harvest
    echo "| $disp | $m | $a | $r | $c | $u |"
  done
  echo
  if [[ -s "$member_rows" ]]; then
    echo "| member | status | path |"
    echo "|---|---|---|"
    awk -F'\t' '{print "| " $1 " | " $2 " | " $3 " |"}' "$member_rows"
  else
    echo "_no member differs from $vprev — nothing to release_"
  fi
  echo
} >"$rendered"
mv "$rendered" "$plan"

# ---- stdout -------------------------------------------------------------------
echo "harvest plan: sssf-suite $vnext from $repo @ $head_sha (base $vprev)"
[[ "$dirty" -gt 0 ]] && echo "  warning: $repo working tree has $dirty uncommitted path(s); the plan reads HEAD"
[[ -n "$stamped_version" && "$stamped_version" != "$vprev" ]] && echo "  warning: $repo receipt says $stamped_version but the base is $vprev — re-stamp first to isolate the repo's own edits"
[[ -z "$stamped_version" ]] && echo "  note: $repo has no stamp receipt — stamp-exact $repo <version> writes one"
awk -F'|' '/^\| (harvest|ride-along) /{gsub(/^ +| +$/,"",$2); gsub(/^ +| +$/,"",$3); printf "  %-11s %s\n", $2, $3}' "$plan"
echo "  render: $render_line"
echo "  plan: $plan"
echo "next: edit dispositions in the plan, then set status: approved — the cut (harvest-apply) reads it"
finished=1
