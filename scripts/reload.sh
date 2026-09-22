#!/usr/bin/env bash
# Dev helper: copy the working tree into the installed plugin, let the
# shell's file watcher settle, then restart the shell (the QML cache does
# not refresh on the watcher alone). Restarting mid-reload can crash the
# old instance (Quickshell IpcHandler re-registration during exit).
set -euo pipefail
src="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
dst="$HOME/.config/omarchy/plugins/marcho78.yapper"
rsync -a --delete --exclude .git --exclude scripts "$src"/ "$dst"/
# The installed copy may be a git clone (omarchy plugin add): move its git to
# the commit just copied, so the plugin's update check does not count the
# working tree's own commits as an update.
if [[ -d $dst/.git ]]; then
  git -C "$dst" fetch -q "$src" HEAD
  git -C "$dst" reset -q --mixed FETCH_HEAD
fi
sleep 4
omarchy restart shell >/dev/null 2>&1 || true
sleep 9
omarchy-shell marcho78.yapper status
