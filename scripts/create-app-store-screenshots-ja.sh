#!/bin/zsh

set -euo pipefail

repo_root="${0:A:h:h}"
source_dir="$repo_root/docs/screenshots/6.9-inch"
capture_dir="$repo_root/docs/app-store-screenshots/raw"
output_dir="$repo_root/docs/app-store-screenshots/ja/6.9-inch"
ipad_capture_dir="$repo_root/docs/app-store-screenshots/raw/ipad-13"
ipad_output_dir="$repo_root/docs/app-store-screenshots/ja/ipad-13-inch"
font_file="$(fc-match -f '%{file}' 'sans-serif:lang=ja')"

mkdir -p "$output_dir" "$ipad_output_dir"

compose() {
  local source="$1"
  local headline="$2"
  local detail="$3"
  local output="$4"
  local crop_height="${5:-2868}"

  local prepared
  prepared="$(mktemp -t leafmark-ui).png"

  magick "$source" \
    -crop "1320x${crop_height}+0+0" +repage \
    -resize '1120x' \
    -bordercolor '#D8D2C8' -border 1 \
    "$prepared"

  magick -size 1320x2868 'xc:#F6F1E8' \
    -fill '#0A84FF' -draw 'roundrectangle 90,92 158,106 7,7' \
    -font "$font_file" -weight 700 -fill '#171614' -pointsize 84 \
    -gravity NorthWest -interline-spacing 8 -annotate +90+142 "$headline" \
    -weight 400 -fill '#5F5A52' -pointsize 42 \
    -interline-spacing 5 -annotate +90+500 "$detail" \
    \( "$prepared" -background '#00000020' -shadow 0x22+0+18 \) \
    -gravity North -geometry +0+690 -composite \
    "$prepared" -gravity North -geometry +0+670 -composite \
    -alpha off -colorspace sRGB -depth 8 -strip "$output"

  rm -f "$prepared"
}

compose_ipad() {
  local source="$1"
  local crop_geometry="$2"
  local headline="$3"
  local detail="$4"
  local output="$5"

  local prepared
  prepared="$(mktemp -t leafmark-ipad-ui).png"

  magick "$source" \
    -crop "$crop_geometry" +repage \
    -resize '1740x' \
    -bordercolor '#D8D2C8' -border 1 \
    "$prepared"

  magick -size 2064x2752 'xc:#F6F1E8' \
    -fill '#0A84FF' -draw 'roundrectangle 132,90 224,106 8,8' \
    -font "$font_file" -weight 700 -fill '#171614' -pointsize 96 \
    -gravity NorthWest -interline-spacing 8 -annotate +132+132 "$headline" \
    -weight 400 -fill '#5F5A52' -pointsize 50 \
    -interline-spacing 5 -annotate +132+500 "$detail" \
    \( "$prepared" -background '#00000020' -shadow 0x24+0+18 \) \
    -gravity North -geometry +0+742 -composite \
    "$prepared" -gravity North -geometry +0+720 -composite \
    -alpha off -colorspace sRGB -depth 8 -strip "$output"

  rm -f "$prepared"
}

compose \
  "$source_dir/05-highlights.png" \
  $'EPUBの読書メモを、\n手元のノートへ。' \
  'ハイライトとメモをMarkdownで書き出せる' \
  "$output_dir/01-reading-notes.png" \
  1800

compose \
  "$source_dir/04-appearance.png" \
  $'文字も余白も、\n自分の読みやすさに。' \
  'フォント・行間・テーマまで細かく調整' \
  "$output_dir/02-reading-comfort.png"

compose \
  "$capture_dir/search-current.png" \
  $'うろ覚えの一節も、\n本の中からすぐ検索。' \
  '語句の出現箇所を一覧で確認' \
  "$output_dir/03-search-inside-book.png"

compose \
  "$source_dir/06-statistics.png" \
  $'今日どれだけ読めたか、\nひと目で。' \
  '今日・今週・累計と、本ごとの読書時間' \
  "$output_dir/04-reading-history.png" \
  1850

compose \
  "$capture_dir/paywall-current.png" \
  $'読むのは無料。\n必要になったら買い切りで。' \
  'サブスクなし。Proで注釈・書き出し・統計を解放' \
  "$output_dir/05-buy-once.png" \
  2050

magick montage "$output_dir"/*.png \
  -font "$font_file" \
  -thumbnail '264x574' \
  -tile 5x1 \
  -geometry '+18+18' \
  -background '#D8D2C8' \
  "$repo_root/docs/app-store-screenshots/ja/contact-sheet.png"

compose_ipad \
  "$ipad_capture_dir/highlights.png" \
  '1500x1750+282+500' \
  $'EPUBの読書メモを、\n手元のノートへ。' \
  'ハイライトとメモをMarkdownで書き出せる' \
  "$ipad_output_dir/01-reading-notes.png"

compose_ipad \
  "$ipad_capture_dir/appearance-source.png" \
  '1900x1980+82+280' \
  $'文字も余白も、\n自分の読みやすさに。' \
  'フォント・行間・テーマまで細かく調整' \
  "$ipad_output_dir/02-reading-comfort.png"

compose_ipad \
  "$ipad_capture_dir/search.png" \
  '1500x1750+282+500' \
  $'うろ覚えの一節も、\n本の中からすぐ検索。' \
  '語句の出現箇所を一覧で確認' \
  "$ipad_output_dir/03-search-inside-book.png"

compose_ipad \
  "$ipad_capture_dir/stats.png" \
  '1500x1900+282+250' \
  $'今日どれだけ読めたか、\nひと目で。' \
  '今日の読書時間は無料で確認' \
  "$ipad_output_dir/04-reading-history.png"

compose_ipad \
  "$repo_root/docs/screenshots/08-ipad-2column.png" \
  '1900x2050+82+0' \
  $'大きな画面なら、\n見開きのように読める。' \
  'iPadでは2カラム表示にも対応' \
  "$ipad_output_dir/05-two-columns.png"

magick montage "$ipad_output_dir"/*.png \
  -font "$font_file" \
  -thumbnail '310x414' \
  -tile 3x2 \
  -geometry '+18+18' \
  -background '#D8D2C8' \
  "$repo_root/docs/app-store-screenshots/ja/ipad-contact-sheet.png"

printf '%s\n' "$output_dir" "$ipad_output_dir"
