#!/usr/bin/env bash
# Cut a plugin release: requires a "## [X.Y.Z]" section in CHANGELOG.md,
# sets the version in manifest.json, commits, tags vX.Y.Z and pushes.
#
#   scripts/release.sh 1.0.0
set -euo pipefail
v="${1:-}"
[[ $v =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "usage: $0 X.Y.Z" >&2; exit 2; }
cd "$(dirname "$0")/.."
[[ -z $(git status --porcelain) ]] || { echo "working tree not clean" >&2; exit 1; }
grep -q "^## \[$v\]" CHANGELOG.md || { echo "CHANGELOG.md has no \"## [$v]\" section" >&2; exit 1; }
python3 - "$v" <<'PY'
import json, sys
path = "manifest.json"
m = json.load(open(path))
m["version"] = sys.argv[1]
with open(path, "w") as f:
    json.dump(m, f, indent=2)
    f.write("\n")
PY
omarchy plugin validate . >/dev/null
git add manifest.json
git commit -qm "Release $v" || true
git tag -a "v$v" -m "Yapper $v"
git push -q && git push -q origin "v$v"
echo "released v$v"
