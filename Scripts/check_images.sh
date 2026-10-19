#!/bin/bash
# Checks the bundled photos: every file in Resources/Images has a credit in ImageCredits.swift,
# every credit points at a file and carries a subject, licence and restrictions, every photo key the
# code names resolves to a file (image: "x", Photo(key: "x"), and the topic pools, city galleries
# and university lists in ImagePicker.swift), and every photo is at most 1600 px wide.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMG="$ROOT/Resources/Images"
SRC="$ROOT/Sources/TensorTycoon"
CREDITS="$SRC/Data/ImageCredits.swift"
PICKER="$SRC/Data/ImagePicker.swift"
fail=0

files=$(ls "$IMG" | sed -E 's/\.(jpg|png)$//' | sort)
credited=$(grep -oE 'ImageCredit\(id: "[^"]+"' "$CREDITS" | sed -E 's/.*"([^"]+)"/\1/' | sort)

for f in $files; do
  grep -qx "$f" <<<"$credited" || { echo "no credit: $f"; fail=1; }
done
for c in $credited; do
  grep -qx "$c" <<<"$files" || { echo "credit without file: $c"; fail=1; }
done
dups=$(uniq -d <<<"$credited")
[ -z "$dups" ] || { echo "duplicate credits: $dups"; fail=1; }

# Every credit line has all fields, a free licence and a known restriction vocabulary.
while IFS= read -r line; do
  id=$(sed -E 's/.*ImageCredit\(id: "([^"]+)".*/\1/' <<<"$line")
  for field in subject title author license restrictions page; do
    grep -qE "$field: \"[^\"]+" <<<"$line" || { echo "credit $id: missing $field"; fail=1; }
  done
  lic=$(sed -E 's/.*license: "([^"]+)".*/\1/' <<<"$line")
  grep -qiE '^(CC0|Public domain|CC BY(-SA)? [0-9])' <<<"$lic" || { echo "credit $id: licence not CC0/PD/CC BY/CC BY-SA: $lic"; fail=1; }
  r=$(sed -E 's/.*restrictions: "([^"]+)".*/\1/' <<<"$line")
  if [ "$r" != "none" ]; then
    tr ';' '\n' <<<"$r" | sed -E 's/^ +//' | while IFS= read -r part; do
      case "$part" in
        "attribution required"|"share-alike"|"personality rights may apply"|"trademarks visible") ;;
        *) echo "credit $id: unknown restriction '$part'"; exit 1;;
      esac
    done || fail=1
  fi
done < <(grep -E '^\s*ImageCredit\(id: ' "$CREDITS")

keys=$( (grep -rhoE '(image: |Photo\(key: )"[a-z0-9_]+"' "$SRC"
         grep -hE '^\s*\.[a-zA-Z]+: \["' "$PICKER" | grep -oE '"[a-z0-9_]+"'
         grep -hE '^\s*"[a-z0-9_]+": \.' "$PICKER" | grep -oE '^\s*"[a-z0-9_]+"'
         grep -hE '^\s*"[a-z0-9_]+": \["' "$PICKER" | sed -E 's/^\s*"[a-z0-9_]+": //' | grep -oE '"[a-z0-9_]+"') \
       | sed -E 's/.*"([^"]+)"/\1/' | sort -u)
for k in $keys; do
  grep -qx "$k" <<<"$files" || { echo "missing photo for key: $k"; fail=1; }
done
unused=$(for f in $files; do grep -rqF "\"$f\"" "$SRC" --include=*.swift --exclude=ImageCredits.swift || echo "$f"; done)
[ -z "$unused" ] || echo "note: not referenced by name (may be chosen elsewhere): $(echo $unused)"

# Width limit (JPEG SOF / PNG IHDR read with python if available).
if command -v python3 >/dev/null; then
  wide=$(python3 -I - "$IMG" <<'PY'
import os, struct, sys
d = sys.argv[1]
for f in sorted(os.listdir(d)):
    b = open(os.path.join(d, f), "rb").read()
    w = 0
    if b[:8] == b"\x89PNG\r\n\x1a\n":
        w = struct.unpack(">I", b[16:20])[0]
    else:
        i = 2
        while i < len(b) - 9:
            if b[i] != 0xFF: i += 1; continue
            m = b[i + 1]
            if m in (0xC0, 0xC1, 0xC2):
                w = struct.unpack(">H", b[i + 7:i + 9])[0]; break
            i += 2 + struct.unpack(">H", b[i + 2:i + 4])[0]
    if w > 1600: print(f"{f} ({w} px)")
PY
)
  [ -z "$wide" ] || { echo "wider than 1600 px: $(echo $wide)"; fail=1; }
fi

n=$(wc -w <<<"$files"); size=$(du -sh "$IMG" | cut -f1)
if [ $fail -eq 0 ]; then echo "OK: $n photos ($size), all credited with subject and restrictions, every key resolves"; else exit 1; fi
