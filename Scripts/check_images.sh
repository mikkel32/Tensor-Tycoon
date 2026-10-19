#!/bin/bash
# Checks the bundled photos: every file in Resources/Images has a credit in ImageCredits.swift,
# every credit points at a file and carries a subject, licence, restrictions and a note of how the
# bundled copy was modified, every photo key the code names resolves to a file (image: "x",
# Photo(key: "x"), HeroBanner(image: "x"), and the topic pools, city galleries, university lists and
# facility photos in ImagePicker.swift), every photo is at most 2400 px wide and 1 MB, and every photo
# shown as a full-width hero is at least 1800 px wide.
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
  for field in subject title author license restrictions page modified; do
    grep -qE "$field: \"[^\"]+" <<<"$line" || { echo "credit $id: missing $field"; fail=1; }
  done
  lic=$(sed -E 's/.*license: "([^"]+)".*/\1/' <<<"$line")
  grep -qiE '^(CC0|Public domain|CC BY(-SA)? [0-9])' <<<"$lic" || { echo "credit $id: licence not CC0/PD/CC BY/CC BY-SA: $lic"; fail=1; }
  if grep -qE -- '-(NC|ND)' <<<"$lic"; then echo "credit $id: non-commercial or no-derivatives licence: $lic"; fail=1; fi
  grep -qE 'page: "https://commons\.wikimedia\.org/wiki/File:' <<<"$line" || { echo "credit $id: page is not a Commons file page"; fail=1; }
  r=$(sed -E 's/.*restrictions: "([^"]+)".*/\1/' <<<"$line")
  if [ "$r" != "none" ]; then
    tr ';' '\n' <<<"$r" | sed -E 's/^ +//' | while IFS= read -r part; do
      case "$part" in
        "attribution required"|"share-alike"|"personality rights may apply"|"trademarks visible"|"recent architecture (limited freedom of panorama)") ;;
        *) echo "credit $id: unknown restriction '$part'"; exit 1;;
      esac
    done || fail=1
  fi
done < <(grep -E '^\s*ImageCredit\(id: ' "$CREDITS")

keys=$( (grep -rhoE '(image: |Photo\(key: |HeroBanner\(image: )"[a-z0-9_]+"' "$SRC"
         grep -hE '^\s*\.[a-zA-Z]+: \["' "$PICKER" | grep -oE '"[a-z0-9_]+"'
         grep -hE '^\s*"[a-z0-9_]+": \.' "$PICKER" | grep -oE '^\s*"[a-z0-9_]+"'
         grep -hE '^\s*"[a-z0-9_]+": \["' "$PICKER" | sed -E 's/^\s*"[a-z0-9_]+": //' | grep -oE '"[a-z0-9_]+"'
         grep -hE 'static let facilityPhotos' "$PICKER" | sed -E 's/.*= //' | grep -oE '"[a-z0-9_]+"') \
       | sed -E 's/.*"([^"]+)"/\1/' | sort -u)
for k in $keys; do
  grep -qx "$k" <<<"$files" || { echo "missing photo for key: $k"; fail=1; }
done
unused=$(for f in $files; do grep -rqF "\"$f\"" "$SRC" --include=*.swift --exclude=ImageCredits.swift || echo "$f"; done)
[ -z "$unused" ] || echo "note: not referenced by name (may be chosen elsewhere): $(echo $unused)"

# Photos shown as full-width heroes: HeroBanner literals and full-size Photo literals (main menu), plus the
# heroes the code picks at run time — challenge cards (FunCatalog), lab cards (ScienceCatalog), era intros
# (Macro), the dashboard's location, office and colocation photos, and the game-over banner.
heroes=$( (grep -rhoE '(HeroBanner\(image: |Photo\(key: )"[a-z0-9_]+"(, thumb: false)?' "$SRC" | grep -E 'HeroBanner|thumb: false'
           grep -hoE 'image: "[a-z0-9_]+", stars:' "$SRC/Data/FunCatalog.swift"
           grep -hE 'LabDef\(' "$SRC/Data/ScienceCatalog.swift" | grep -oE 'image: "[a-z0-9_]+"'
           grep -hoE 'cash: [0-9_]+, image: "[a-z0-9_]+"' "$SRC/Data/Macro.swift"
           grep -hA1 'Location(id:' "$SRC/Data/World.swift" "$SRC/Data/Countries.swift" | grep -oE 'image: "[a-z0-9_]+"'
           grep -hoE '^\s*\("[^"]+", [0-9_]+, [0-9_]+, "[a-z0-9_]+"\)' "$SRC/Engine/Economy.swift" | grep -oE '"[a-z0-9_]+"\)$'
           printf '"%s"\n' dc_corridor sf_skyline stock_exchange) \
         | grep -oE '"[a-z0-9_]+"' | tr -d '"' | sort -u)

# Width and size limits (JPEG SOF / PNG IHDR read with python if available).
if command -v python3 >/dev/null; then
  problems=$(python3 -I - "$IMG" $heroes <<'PY'
import os, struct, sys
d, heroes = sys.argv[1], set(sys.argv[2:])
for f in sorted(os.listdir(d)):
    p = os.path.join(d, f)
    b = open(p, "rb").read()
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
    key = f.rsplit(".", 1)[0]
    if w > 2400: print(f"wider than 2400 px: {f} ({w} px)")
    if key in heroes and w < 1800: print(f"hero narrower than 1800 px: {f} ({w} px)")
    if len(b) > 1024 * 1024: print(f"larger than 1 MB: {f} ({len(b) // 1024} KB)")
PY
)
  [ -z "$problems" ] || { echo "$problems"; fail=1; }
fi

n=$(wc -w <<<"$files"); size=$(du -sh "$IMG" | cut -f1); nh=$(wc -w <<<"$heroes")
if [ $fail -eq 0 ]; then echo "OK: $n photos ($size), all credited with subject, restrictions and edits, every key resolves, $nh hero photos ≥1800 px"; else exit 1; fi
