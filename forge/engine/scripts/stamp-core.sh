#!/usr/bin/env bash
# Stamp the sssf-suite into a target repo, non-interactively — `just forge stamp-exact <repo> [version]`.
# Depth: scripts/README.md#stamp-coresh

set -euo pipefail
source "$(dirname "$0")/env.sh"

MANIFEST=elections.json
dev_root=${FORGE_DEV_ROOT:-$HOME/dev}

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "usage: stamp-core.sh <repo> [version]   e.g. stamp-core.sh my-factory v1.2.1" >&2
  exit 2
fi
repo=$1
version=${2:-}

repo_dir=$dev_root/$repo
if [[ ! -d "$repo_dir" ]]; then
  echo "no repo at $repo_dir (FORGE_DEV_ROOT overrides the ~/dev default)" >&2
  exit 1
fi
if [[ ! -e "$repo_dir/.git" ]]; then
  echo "$repo_dir is not a git repo (no .git)" >&2
  exit 1
fi

# keg-core.sh owns keg resolution: latest non-yanked by default, vX.Y.Z normalization,
# the unknown/yanked refusals. It prints an absolute path; keep it forge-relative here.
keg=$(bash "$ENGINE/scripts/keg-core.sh" ${version:+"$version"}) || exit 1
keg=${keg#"$PWD/"}
version=${keg##*/}

dest=$repo_dir/.claude/skills
if [[ -L "$dest" ]]; then
  root=$(jq -r --arg r "$repo" '.harnesses["claude-code"].roots[$r] // empty' "$MANIFEST")
  if [[ -n "$root" && $(readlink "$dest") == "$(cd .. && pwd)/$root" ]]; then
    mkdir -p scratch
    tmp=scratch/elections.json.tmp
    jq --arg r "$repo" '.harnesses["claude-code"].linkModes[$r] = "per-skill"' "$MANIFEST" >"$tmp"
    mv "$tmp" "$MANIFEST"
    rm "$dest"
    mkdir -p "$dest"
    bash "$ENGINE/scripts/link.sh" "$repo"
    echo "converted $repo: tree link -> per-skill (linkModes written, uncommitted)"
  else
    echo "$dest is a symlink to $(readlink "$dest") — not forge's tree link; move it aside, then re-run" >&2
    exit 1
  fi
fi
mkdir -p "$dest"

# peers: the floors the keg declares on the forge skills it works with — [peers] in the
# keg's sssf/conformance.toml, rendered into the receipt (the keg owns them). No table,
# or a keg from before the file existed: no peers key.
peers=
if [[ -f $keg/sssf/conformance.toml ]]; then
  peers=$(uv run --quiet --no-project --python '>=3.11' python -c '
import json, sys, tomllib
p = tomllib.load(sys.stdin.buffer).get("peers")
if p is not None and not (isinstance(p, dict) and all(isinstance(v, str) for v in p.values())):
    sys.exit(f"{sys.argv[1]}: [peers] must map skill names to \">=X.Y.Z\" strings")
print("" if p is None else json.dumps(p))' "$keg/sssf/conformance.toml" <"$keg/sssf/conformance.toml")
fi

stamped=()
for member in "$keg"/*/; do
  name=$(basename "$member")
  if [[ -L "$dest/$name" ]]; then
    echo "$dest/$name is a symlink (forge-linked, not stamp-owned) — refusing" >&2
    exit 1
  fi
  rsync -a --delete "$member" "$dest/$name/"
  stamped+=("$name")
done

# The receipt. keg_commit is the dotfiles commit that added the keg — null when
# the keg is still only staged (stamp before the release commit).
keg_commit=$(git log -1 --format=%h -- "$keg" 2>/dev/null || true)
jq -n --arg v "$version" --arg c "$keg_commit" --arg t "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --argjson p "${peers:-null}" \
  --args '{suite: "sssf-suite", version: $v, keg_commit: (if $c == "" then null else $c end),
           stamped_at: $t, members: $ARGS.positional} + (if $p == null then {} else {peers: $p} end)' \
  "${stamped[@]}" >"$dest/sssf-suite.receipt.json"

echo "stamped sssf-suite $version into $repo: ${stamped[*]}"
echo "receipt: $dest/sssf-suite.receipt.json${keg_commit:+ (keg commit $keg_commit)}"
echo "release act pending — commit in $repo_dir:"
echo "  git add .claude/skills && git commit -m 'Stamp sssf-suite $version'"
