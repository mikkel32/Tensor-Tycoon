#!/bin/bash
# Checks the bundled photos: every file in Resources/Images has a credit in ImageCredits.swift,
# every credit points at a file, and every photo key the code names resolves to a file
# (image: "x", Photo(key: "x"), and the topic pools in ImagePicker.swift).
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMG="$ROOT/Resources/Images"
SRC="$ROOT/Sources/TensorTycoon"
fail=0

files=$(ls "$IMG" | sed -E 's/\.(jpg|png)$//' | sort)
credited=$(grep -oE 'ImageCredit\(id: "[^"]+"' "$SRC/Data/ImageCredits.swift" | sed -E 's/.*"([^"]+)"/\1/' | sort)

for f in $files; do
  grep -qx "$f" <<<"$credited" || { echo "no credit: $f"; fail=1; }
done
for c in $credited; do
  grep -qx "$c" <<<"$files" || { echo "credit without file: $c"; fail=1; }
done
dups=$(uniq -d <<<"$credited")
[ -z "$dups" ] || { echo "duplicate credits: $dups"; fail=1; }

keys=$( (grep -rhoE '(image: |Photo\(key: )"[a-z0-9_]+"' "$SRC"
         grep -hE '^\s*\.[a-zA-Z]+: \["' "$SRC/Data/ImagePicker.swift" | grep -oE '"[a-z0-9_]+"'
         grep -hE '^\s*"[a-z0-9_]+": \.' "$SRC/Data/ImagePicker.swift" | grep -oE '^\s*"[a-z0-9_]+"') \
       | sed -E 's/.*"([^"]+)"/\1/' | sort -u)
for k in $keys; do
  grep -qx "$k" <<<"$files" || { echo "missing photo for key: $k"; fail=1; }
done
unused=$(for f in $files; do grep -rqF "\"$f\"" "$SRC" --include=*.swift --exclude=ImageCredits.swift || echo "$f"; done)
[ -z "$unused" ] || echo "note: not referenced by name (may be chosen elsewhere): $(echo $unused)"

n=$(wc -w <<<"$files"); size=$(du -sh "$IMG" | cut -f1)
if [ $fail -eq 0 ]; then echo "OK: $n photos ($size), all credited, every key resolves"; else exit 1; fi
