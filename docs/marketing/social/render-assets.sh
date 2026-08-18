#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
repo_dir="${script_dir:h:h:h}"
screens_dir="$repo_dir/docs/screenshots/6.9-inch"
icon="$repo_dir/Sources/Assets.xcassets/AppIcon.appiconset/icon-1024.png"
font="/System/Library/Fonts/SFNS.ttf"
navy="#182047"
ink="#12182f"
paper="#fffdf8"
yellow="#f7c843"
muted="#5d6275"

mkdir -p "$script_dir/output"

make_phone() {
  local source="$1" width="$2" output="$3" radius="$4" border="$5"
  magick "$source" -resize "${width}x" -bordercolor "$border" -border 3 "$output"
}

make_icon() {
  local size="$1" output="$2"
  magick "$icon" -resize "${size}x${size}" \
    \( +clone -alpha extract -draw "fill black polygon 0,0 0,24 24,0 fill white circle 24,24 24,0" \
      \( +clone -flip \) -compose Multiply -composite \
      \( +clone -flop \) -compose Multiply -composite \) \
    -alpha off -compose CopyOpacity -composite "$output"
}

make_pin() {
  local slug="$1" screenshot="$2" headline="$3" subhead="$4" label="$5"
  local tmp="/private/tmp/leafmark-${slug}"
  make_phone "$screenshot" 540 "${tmp}-phone.png" 58 "$paper"
  make_icon 92 "${tmp}-icon.png"

  magick -size 1000x1500 "radial-gradient:#fffdf8-#eee8dc" \
    -fill none -stroke "#d8d3c8" -strokewidth 2 \
    -draw "circle 860,300 1140,300 circle 80,1260 410,1260" \
    -fill "$navy" -stroke none -draw "roundrectangle 55,48 945,220 42,42" \
    "${tmp}-icon.png" -geometry +84+88 -composite \
    -font "$font" -pointsize 42 -fill "$paper" -gravity northwest -annotate +202+92 "Leafmark" \
    -pointsize 23 -fill "#d8dced" -annotate +202+148 "EPUB reader for iPhone & iPad" \
    -fill "$yellow" -draw "roundrectangle 70,270 86,420 8,8" \
    -pointsize 66 -fill "$ink" -interline-spacing 4 -annotate +116+270 "$headline" \
    -pointsize 32 -fill "$muted" -interline-spacing 8 -annotate +116+435 "$subhead" \
    \( "${tmp}-phone.png" -background black -shadow 30x14+0+14 \) -geometry +236+650 -composite \
    "${tmp}-phone.png" -geometry +230+636 -composite \
    -fill "$navy" -draw "roundrectangle 70,1320 930,1434 32,32" \
    -pointsize 28 -fill "$yellow" -annotate +108+1350 "$label" \
    -pointsize 25 -fill "$paper" -annotate +108+1391 "Available on the App Store" \
    "$script_dir/output/pinterest-${slug}.png"
}

make_bluesky() {
  local slug="$1" screenshot="$2" headline="$3" subhead="$4" label="$5"
  local tmp="/private/tmp/leafmark-bluesky-${slug}"
  make_phone "$screenshot" 370 "${tmp}-phone.png" 42 "$paper"
  make_icon 82 "${tmp}-icon.png"

  magick -size 1600x900 "radial-gradient:#fffdf8-#ebe4d7" \
    -fill none -stroke "#d8d3c8" -strokewidth 2 \
    -draw "circle 1400,170 1660,170 circle 1240,800 1620,800" \
    -fill "$navy" -stroke none -draw "roundrectangle 52,48 1008,852 46,46" \
    "${tmp}-icon.png" -geometry +98+92 -composite \
    -font "$font" -pointsize 38 -fill "$paper" -gravity northwest -annotate +206+108 "Leafmark" \
    -pointsize 22 -fill "#d8dced" -annotate +206+155 "EPUB reader for iPhone & iPad" \
    -fill "$yellow" -draw "roundrectangle 98,250 230,262 6,6" \
    -pointsize 64 -fill "$paper" -interline-spacing 5 -annotate +98+294 "$headline" \
    -pointsize 31 -fill "#d8dced" -interline-spacing 10 -annotate +98+518 "$subhead" \
    -pointsize 28 -fill "$yellow" -annotate +98+738 "$label" \
    -pointsize 24 -fill "$paper" -annotate +98+786 "Available on the App Store" \
    \( "${tmp}-phone.png" -background black -shadow 30x14+0+14 \) -geometry +1115+80 -composite \
    "${tmp}-phone.png" -geometry +1106+68 -composite \
    "$script_dir/output/bluesky-${slug}.png"
}

make_pin "01-own-your-highlights" "$screens_dir/05-highlights.png" $'Your highlights\nare yours.' $'Export reading notes\nto clean Markdown.' "NO LOCK-IN"
make_pin "02-buy-once" "$screens_dir/01-library.png" $'Buy once.\nRead for years.' $'One-time Pro purchase.\nNo subscription.' "ONE-TIME PURCHASE"
make_pin "03-private-by-design" "$screens_dir/06-statistics.png" $'Private by\ndesign.' $'No account. No ads.\nNo analytics SDKs.' "YOUR READING, YOUR DATA"

make_bluesky "01-own-your-highlights" "$screens_dir/05-highlights.png" $'Your highlights\nare yours.' $'Export reading notes to clean Markdown.\nKeep them in Obsidian, Notion, or plain text.' "NO LOCK-IN"
make_bluesky "02-buy-once" "$screens_dir/01-library.png" $'Buy once.\nRead for years.' $'Unlock Pro with one purchase.\nNo recurring subscription.' "ONE-TIME PURCHASE"
make_bluesky "03-private-by-design" "$screens_dir/06-statistics.png" $'Private by\ndesign.' $'No developer account. No ads.\nNo analytics SDKs.' "YOUR READING, YOUR DATA"

echo "Rendered six assets to $script_dir/output"
