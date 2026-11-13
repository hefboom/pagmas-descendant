#!/usr/bin/env bash
# Resolve one sssf-suite keg to its path — `just forge keg [version]`.
# Depth: scripts/README.md#keg-coresh

set -euo pipefail
source "$(dirname "$0")/env.sh"

SUITE_DIR=kegs/sssf-suite

if [[ $# -gt 1 ]]; then
  echo "usage: keg-core.sh [version]   e.g. keg-core.sh v1.22.1" >&2
  exit 2
fi
version=${1:-}
[[ -n "$version" && "$version" != v* ]] && version=v$version

if [[ -z "$version" ]]; then
  for v in $(ls "$SUITE_DIR" | sort -rV); do
    [[ -d "$SUITE_DIR/$v" && ! -e "$SUITE_DIR/$v/.yanked" ]] && version=$v && break
  done
  if [[ -z "$version" ]]; then
    echo "no electable keg under $SUITE_DIR (every version is yanked, or none exists)" >&2
    exit 1
  fi
fi

keg=$SUITE_DIR/$version
if [[ ! -d "$keg" ]]; then
  echo "no keg $version under $SUITE_DIR — versions: $(ls "$SUITE_DIR" | grep '^v' | sort -V | tr '\n' ' ')" >&2
  exit 1
fi
if [[ -e "$keg/.yanked" ]]; then
  echo "$version is yanked — pick another version or unyank it first" >&2
  exit 1
fi
printf '%s\n' "$PWD/$keg"
