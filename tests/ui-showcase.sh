#!/usr/bin/env bash
# The README pictures and preview.png, reproducibly: like ui-shots.sh a
# throwaway HOME (with the current theme linked in) and runtime directory,
# well-known cities, a few alarms, timers and pomodoros, Berlin as here,
# and tests/ui/showcase.qml stepping through the scenes. Sounds are only
# logged. The pictures go to the output directory; tools/build-preview.sh
# puts the README pictures and the preview together from them.
#   tests/ui-showcase.sh [output-dir]
set -u
root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d "${TMPDIR:-/tmp}/more-time-showcase.XXXXXX")
out=${1:-$work/shots}
shell="${OMARCHY_PATH:-/usr/share/omarchy}/shell"
settings="$work/home/.local/state/omarchy/settings"
mkdir -p "$out" "$work/config" "$settings" "$work/home/.local/state/omarchy/current" "$work/run"
chmod 700 "$work/run"
ln -s "$shell/Commons" "$work/config/Commons"
ln -s "$shell/Ui" "$work/config/Ui"
ln -s "$root" "$work/config/Time"
cp "$root/tests/ui/showcase.qml" "$work/config/shell.qml"
theme="$HOME/.local/state/omarchy/current/theme"
[ -e "$theme" ] && ln -s "$theme" "$work/home/.local/state/omarchy/current/theme"

# Here is Berlin (Omarchy's weather location), the cities well known.
echo '{"name": "Berlin", "latitude": 52.52, "longitude": 13.405}' > "$settings/weather.json"
cat > "$settings/more-time-cities.json" <<'JSON'
[
  {"name": "New York", "country": "United States", "tz": "America/New_York", "lat": 40.714, "lon": -74.006, "dial": "classic"},
  {"name": "London", "country": "United Kingdom", "tz": "Europe/London", "lat": 51.508, "lon": -0.126, "dial": "minimal"},
  {"name": "Paris", "country": "France", "tz": "Europe/Paris", "lat": 48.857, "lon": 2.352, "dial": "roman"},
  {"name": "Dubai", "country": "United Arab Emirates", "tz": "Asia/Dubai", "lat": 25.276, "lon": 55.296, "dial": "dots"},
  {"name": "Tokyo", "country": "Japan", "tz": "Asia/Tokyo", "lat": 35.690, "lon": 139.692, "dial": "twentyFour"},
  {"name": "Sydney", "country": "Australia", "tz": "Australia/Sydney", "lat": -33.868, "lon": 151.209, "dial": "classic"},
  {"name": "Rio de Janeiro", "country": "Brazil", "tz": "America/Sao_Paulo", "lat": -22.907, "lon": -43.173, "dial": "minimal"},
  {"name": "Cape Town", "country": "South Africa", "tz": "Africa/Johannesburg", "lat": -33.925, "lon": 18.424, "dial": "dots"}
]
JSON
echo '{"current": "here", "hereDial": "classic"}' > "$settings/more-time-place.json"
# 24 hours, English, the sounds only logged (MORE_TIME_SOUND_DRY_RUN).
echo '{"language": "en", "timeFormat": "24"}' > "$settings/more-time-general.json"

# The pictures show Saturday 3 October 2026, 15:40 in Berlin (the views'
# clock is moved there: Panel.clockOffsetMs, MT_CLOCK_AT), the Atlantic in
# daylight. Alarms (one at Tokyo's time), two timers running (one named),
# a pomodoro in focus and one in its break, and a week of finished rounds,
# all against that moment; nothing comes due while the pictures are taken.
now=$(TZ=Europe/Berlin date -d "2026-10-03 15:40:00" +%s%3N)
day() { TZ=Europe/Berlin date -d "2026-10-03 12:00 $1 days ago" +%F; }
cat > "$settings/more-time-items.json" <<JSON
{
 "version": 1,
 "alarms": [
  {"id": "a1", "label": "Stand-up", "hour": 9, "minute": 30, "days": [1, 2, 3, 4, 5], "enabled": true, "snoozeMinutes": 9, "armedAt": $now, "snoozeUntil": 0, "tz": "", "placeName": ""},
  {"id": "a2", "label": "Call Tokyo", "hour": 8, "minute": 0, "days": [1, 2, 3, 4, 5], "enabled": true, "snoozeMinutes": 5, "armedAt": $now, "snoozeUntil": 0, "tz": "Asia/Tokyo", "placeName": "Tokyo"},
  {"id": "a3", "label": "", "hour": 6, "minute": 45, "days": [], "enabled": false, "snoozeMinutes": 9, "armedAt": $now, "snoozeUntil": 0, "tz": "", "placeName": ""}
 ],
 "timers": [
  {"id": "t1", "label": "Tea", "duration": 240000, "state": "running", "endsAt": $((now + 162000)), "remaining": 0, "doneAt": 0, "sound": ""},
  {"id": "t2", "label": "Pasta", "duration": 660000, "state": "running", "endsAt": $((now + 530000)), "remaining": 0, "doneAt": 0, "sound": ""},
  {"id": "t3", "label": "", "duration": 1500000, "state": "paused", "endsAt": 0, "remaining": 1094000, "doneAt": 0, "sound": ""}
 ],
 "stopwatches": [],
 "pomodoros": [
  {"id": "p1", "label": "Writing", "work": 25, "shortBreak": 5, "longBreak": 15, "longEvery": 4, "autoContinue": true, "phase": "work", "state": "running", "endsAt": $((now + 912000)), "remaining": 0, "completed": 3},
  {"id": "p2", "label": "Review", "work": 50, "shortBreak": 10, "longBreak": 20, "longEvery": 0, "autoContinue": true, "phase": "break", "state": "running", "endsAt": $((now + 247000)), "remaining": 0, "completed": 2}
 ],
 "pomodoroLog": {"$(day 0)": 5, "$(day 1)": 6, "$(day 2)": 4, "$(day 3)": 7, "$(day 4)": 3}
}
JSON
env -u DBUS_SESSION_BUS_ADDRESS -u XDG_DATA_HOME -u XDG_CONFIG_HOME -u XDG_STATE_HOME HOME="$work/home" XDG_RUNTIME_DIR="$work/run" \
  XDG_CACHE_HOME="$work/home/.cache" MORE_PLUGINS_OFFLINE=1 MORE_TIME_SOUND_DRY_RUN=1 \
  LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 MT_SHOTS="$out" MT_CLOCK_AT="$now" TZ=Europe/Berlin QT_QPA_PLATFORM=offscreen \
  timeout 300 qs -n -p "$work/config" >"$work/log.txt" 2>&1
echo "log: $work/log.txt"
echo "shots: $out"
grep -E "SHOT|STEP FAILED|SHOWCASE" "$work/log.txt"
