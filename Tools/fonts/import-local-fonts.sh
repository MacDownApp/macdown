#!/bin/sh
# Copies fonts that are NOT in git (commercial fonts you own) from your font folders into
# MacDown/Resources/Fonts, so the next macOS or iPad/iPhone build ships them.
#   Tools/fonts/import-local-fonts.sh
# Never commit these files: .gitignore excludes Cartograph* because the font is licensed to you.
set -e
cd "$(dirname "$0")/../.."
DEST="MacDown/Resources/Fonts"
mkdir -p "$DEST"
found=0
for dir in "$HOME/Library/Fonts" /Library/Fonts; do
  for f in "$dir"/CartographCFNerdFont-Regular.ttf "$dir"/CartographCFNerdFont-Italic.ttf \
           "$dir"/CartographCFNerdFont-Bold.ttf "$dir"/CartographCFNerdFont-BoldItalic.ttf \
           "$dir"/CartographCFNerdFont-Thin.ttf "$dir"/CartographCFNerdFont-ThinItalic.ttf; do
    if [ -f "$f" ]; then cp "$f" "$DEST/"; found=$((found+1)); fi
  done
done
echo "Imported $found Cartograph CF Nerd Font file(s) into $DEST (not tracked by git)."
