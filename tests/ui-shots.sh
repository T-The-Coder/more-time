#!/usr/bin/env bash
# Screenshots of the app view without touching the real settings: a throw-
# away HOME (with the current theme linked in) and runtime directory, an
# offscreen Quickshell, and tests/ui/shell.qml stepping through the views.
# Sounds and chimes are only logged (MORE_TIME_SOUND_DRY_RUN), never played.
#   tests/ui-shots.sh [output-dir]
# MT_HARNESS=audit runs tests/ui/audit.qml instead (every view at one width:
# MT_WIDTH, 500 by default); MT_THEME=<theme dir> uses that Omarchy theme
# instead of the current one.
set -u
root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d "${TMPDIR:-/tmp}/more-time-ui.XXXXXX")
out=${1:-$work/shots}
shell="${OMARCHY_PATH:-/usr/share/omarchy}/shell"
mkdir -p "$out" "$work/config" "$work/home/.local/state/omarchy/current" "$work/run"
chmod 700 "$work/run"
ln -s "$shell/Commons" "$work/config/Commons"
ln -s "$shell/Ui" "$work/config/Ui"
ln -s "$root" "$work/config/Time"
cp "$root/tests/ui/${MT_HARNESS:-shell}.qml" "$work/config/shell.qml"
# More Weather's saved places, for the import (Settings → General → Places).
mkdir -p "$work/home/.local/state/omarchy/settings"
cat > "$work/home/.local/state/omarchy/settings/more-weather-locations.json" <<'JSON'
[{"name":"Bobingen","latitude":48.27091,"longitude":10.8339},{"name":"London","latitude":51.5072,"longitude":-0.1276},{"name":"Klaksvík","latitude":62.2266,"longitude":-6.589}]
JSON
theme="${MT_THEME:-$HOME/.local/state/omarchy/current/theme}"
[ -e "$theme" ] && ln -s "$theme" "$work/home/.local/state/omarchy/current/theme"
HOME="$work/home" XDG_CACHE_HOME="$work/home/.cache" MORE_PLUGINS_OFFLINE=1 MORE_TIME_SOUND_DRY_RUN=1 XDG_RUNTIME_DIR="$work/run" MT_SHOTS="$out" QT_QPA_PLATFORM=offscreen \
  timeout 450 qs -n -p "$work/config" >"$work/log.txt" 2>&1
echo "log: $work/log.txt"
echo "shots: $out"
grep -E "SHOT|MENUBAR|TOOLTIP|ASTRO|SKY|PLACE|GLOBE|DIALS|MOON|CHECK|IMPORT|SEARCH|STATUS|CHIME|dry run|STEP FAILED|ERROR|WARN|Error|error" "$work/log.txt" | grep -v "^$" | head -80
