#!/usr/bin/env bash
# Print the sssf-suite's members, one per line in suite order — `bash scripts/suite-members.sh <repo-dir> <commit>`.
# Depth: scripts/README.md#suite-memberssh

set -euo pipefail
core=sssf
repo_dir=$1 rev=$2
toml=.claude/skills/$core/conformance.toml
where="$(basename "$repo_dir") @ $rev: $toml"
git -C "$repo_dir" cat-file -e "$rev:$toml" 2>/dev/null \
  || { echo "$where: missing — $core names no suite; harvest from a source at or past v1.10.0, the keg that added it" >&2; exit 1; }
git -C "$repo_dir" show "$rev:$toml" | uv run --quiet --no-project --python '>=3.11' python -c '
import re, sys, tomllib
core, where = sys.argv[1:]
try:
    s = tomllib.load(sys.stdin.buffer).get("suite")
except tomllib.TOMLDecodeError as e:
    sys.exit(f"{where}: {e}")
if not (isinstance(s, list) and all(isinstance(n, str) and re.fullmatch("[a-z0-9][a-z0-9-]*", n) for n in s)
        and core in s and len(set(s)) == len(s)):
    sys.exit(f"{where}: suite must list distinct skill names ([a-z0-9-]), {core} among them")
print(*s, sep="\n")' "$core" "$where"
