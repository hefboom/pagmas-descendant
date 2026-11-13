#!/usr/bin/env bash
# The derived edge ledger: one row per `just` call in an elected skill's body, plus one per declared engine floor — `just forge edges`.
# Depth: scripts/README.md#edgessh

set -euo pipefail
source "$(dirname "$0")/env.sh"
# The heredoc below is python's stdin, so the render dump travels by env, not pipe.
FORGE_JSON="$(bun run "$ENGINE/scripts/render.ts" --json)" FORGE_DEV_ROOT="${FORGE_DEV_ROOT:-$HOME/dev}" python3 - <<'PY'
import json, os, re, subprocess, sys
from pathlib import Path

forge = Path.cwd()
dotfiles = forge.parent
dev = Path(os.environ["FORGE_DEV_ROOT"])
data = json.loads(os.environ["FORGE_JSON"])

SPAN = re.compile(r"`([^`]*)`")
CALL = re.compile(r"(?<![\w/.-])just\b((?:\s+(?:-f\s+\S+|-[-\w]+|[A-Za-z0-9_][\w.-]*))*)")

dumps = {}
def dump(justfile):
    if justfile in dumps: return dumps[justfile]
    r = subprocess.run(["just", "-f", str(justfile), "--dump", "--dump-format", "json"], capture_output=True, text=True)
    dumps[justfile] = json.loads(r.stdout) if r.returncode == 0 else None
    return dumps[justfile]

def ver(v): return tuple(int(x) for x in v.lstrip("v").split("."))

def body(path):
    text = path.read_text()
    if text.startswith("---"):
        end = text.find("\n---", 3)
        if end != -1: text = text[end + 4:]
    return text

rows = set()
for s in data["skills"]:
    skill = forge / "skills" / s["scope"] / s["name"] / s["version"] / "SKILL.md"
    if not skill.exists(): continue
    for span in SPAN.findall(body(skill)):
        for m in CALL.finditer(span):
            toks = m.group(1).split()
            fpath = None; words = []; listing = False
            i = 0
            while i < len(toks):
                t = toks[i]
                if t == "-f": fpath = toks[i + 1] if i + 1 < len(toks) else None; i += 2; continue
                if t == "--list": listing = True
                if not t.startswith("-"): words.append(t)
                i += 1
            if fpath:
                target = Path(os.path.expanduser(fpath)); cls_anchor = target
            elif s["scope"] in ("hub", "dotfiles"): target = dotfiles / "justfile"; cls_anchor = target
            elif s["scope"] != "global": target = dev / s["scope"] / "justfile"; cls_anchor = target
            else: target = None; cls_anchor = None
            if target is not None and target.is_dir(): target = target / "justfile"
            cls = "unanchored" if target is None else ("same-repo" if dotfiles in cls_anchor.parents or cls_anchor == dotfiles else "cross-repo")
            tshow = "cwd" if target is None else str(target).replace(str(Path.home()), "~")
            d = dump(target) if target is not None and target.exists() else None
            recipe, check = None, None
            if d is not None and words:
                mods = d.get("modules", {})
                if words[0] in mods:
                    if len(words) > 1:
                        recipe = f"{words[0]}::{words[1]}"; check = "ok" if words[1] in mods[words[0]].get("recipes", {}) else "missing"
                    else: recipe = f"{words[0]}::"; check = "-"
                else:
                    recipe = words[0]; check = "ok" if words[0] in d.get("recipes", {}) else "missing"
            elif words:
                recipe = "::".join(words[:2]) if listing and len(words) > 1 else words[0]
                check = "unchecked"
            if listing and (recipe is None or check == "-" or not words):
                recipe = f"--list {' '.join(words)}".strip(); check = "-"
            if recipe is None: continue
            rows.add((s["label"], tshow, recipe, cls, check))
    for e in s.get("engines", []):  # a declared floor: provided by the target repo's stamp, checked against its receipt
        repo = dotfiles if s["scope"] in ("hub", "dotfiles") else dev / s["scope"] if s["scope"] != "global" else None
        receipt = None if repo is None else repo / ".claude" / "skills" / f"{e['suite']}.receipt.json"
        if receipt is None: check = "unchecked"
        elif not receipt.exists(): check = "no-receipt"
        else: check = "ok" if ver(json.loads(receipt.read_text()).get("version", "0.0.0")) >= ver(e["spec"].split(">=")[1]) else "skew"
        rows.add((s["label"], "cwd" if repo is None else str(repo).replace(str(Path.home()), "~"), e["spec"], "engine", check))

rows = sorted(rows, key=lambda r: ({"engine": 0, "cross-repo": 1, "unanchored": 2, "same-repo": 3}[r[3]], r[0], r[2]))
head = ("SKILL", "TARGET", "RECIPE", "CLASS", "CHECK")
w = [max(len(str(r[i])) for r in rows + [head]) for i in range(5)]
for r in [head] + rows:
    print("  ".join(str(c).ljust(w[i]) for i, c in enumerate(r)).rstrip())
PY
