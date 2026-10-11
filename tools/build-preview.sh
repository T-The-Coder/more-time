#!/usr/bin/env bash
# Puts the README pictures and preview.png together from a showcase run
# (tests/ui-showcase.sh), as More Weather's tools/build-preview.sh does: the
# app scenes as they are, the menu bar above the popup's view, and the
# preview with the feature list beside them. Colours come from the current
# Omarchy theme, the font is JetBrains Mono.
#   tools/build-preview.sh <showcase-output-dir>
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
in=${1:?usage: $0 <showcase-output-dir>}
theme="$HOME/.local/state/omarchy/current/theme/colors.toml"
color() { sed -n "s/^$1 *= *\"\\(#[0-9a-fA-F]*\\)\".*/\\1/p" "$theme" | head -n 1; }
bg=$(color background); bg=${bg:-#1a1b26}
fg=$(color foreground); fg=${fg:-#a9b1d6}
accent=$(color accent); accent=${accent:-#7aa2f7}
muted=$(color dark_foreground); muted=${muted:-#565f89}
line=$(color lighter_background); line=${line:-#24283b}
font=$(fc-match -f '%{file}' "JetBrainsMono Nerd Font:style=Regular")
bold=$(fc-match -f '%{file}' "JetBrainsMono Nerd Font:style=Bold")
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

mkdir -p "$root/screenshots"
for scene in world-globe world-map places astro astro-eclipse alarms timers pomodoros settings-changes; do
  cp "$in/$scene.png" "$root/screenshots/$scene.png"
done

# The bar (its middle, as wide as the popup) over the popup's view, with
# the accent line of the bar's edge between them.
magick "$in/bar.png" -gravity center -crop 512x32+0+0 +repage "$work/bar.png"
magick "$work/bar.png" \( -size 512x2 "xc:$accent" \) \( -size 512x8 "xc:$bg" \) \
  \( "$in/widget.png" -gravity north -crop 512x660+0+0 +repage -bordercolor "$accent" -border 1 -gravity north -crop 512x662+0+0 +repage \) \
  -append +repage "$root/screenshots/menubar-widget.png"

# The preview: the list on the left, the bar and the popup in the middle,
# the clock with the globe (New York, 12 hours) and the Astro tab's solar
# system before the stars on the right.
panel() {  # source crop-geometry width output
  magick "$1" -crop "$2" +repage -resize "$3x" -bordercolor "$line" -border 3 "$4"
}
panel "$in/world-globe.png" 941x672+0+0 900 "$work/p1.png"
panel "$in/astro.png" 941x540+0+30 900 "$work/p2.png"
magick "$root/screenshots/menubar-widget.png" -resize 480x -bordercolor "$line" -border 3 "$work/w.png"

bullets=("New: Astro, the sky as a clock" "World map, globe & Places" "Alarms, timers, pomodoros")
args=()
y=560
for text in "${bullets[@]}"; do
  args+=(-font "$font" -pointsize 34 -fill "$fg" -annotate "+156+$y" "$text"
    -fill "$accent" -annotate "+104+$y" "•")
  y=$((y + 70))
done

magick -size 2400x1350 "xc:$bg" \
  -fill "$accent" -draw "roundrectangle 90,150 470,206 8,8" \
  -font "$bold" -pointsize 30 -fill "$bg" -annotate +118+190 "NEW · VERSION 1.1" \
  -font "$bold" -pointsize 92 -fill "$accent" -annotate +86+330 "More Time" \
  -font "$font" -pointsize 40 -fill "$fg" -annotate +92+398 "for the Omarchy bar" \
  "${args[@]}" \
  -font "$font" -pointsize 30 -fill "$muted" -annotate +98+1040 "30 languages · 24 h / 12 h" \
  -annotate +98+1080 "full keyboard control" \
  "$work/w.png" -geometry +860+330 -composite \
  "$work/p1.png" -geometry +1440+110 -composite \
  "$work/p2.png" -geometry +1440+760 -composite \
  "$root/preview.png"
echo "preview.png and screenshots/ updated"
