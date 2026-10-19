#!/bin/bash
# Writes Resources/CREDITS.txt, a plain-text list of every bundled photo's credit (TASL: title, author, source,
# licence, plus what it shows, reuse restrictions and how the bundled copy was modified), from the catalog in
# Sources/TensorTycoon/Data/ImageCredits.swift. build_app.sh copies it into the app bundle.
# Run it after changing ImageCredits.swift and commit the result; Scripts/check_images.sh checks the photos.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 -I - "$ROOT/Sources/TensorTycoon/Data/ImageCredits.swift" "$ROOT/Resources/CREDITS.txt" <<'PY'
import re, sys
src, out = sys.argv[1], sys.argv[2]
row = re.compile(r'ImageCredit\(id: "([^"]+)", subject: "((?:[^"\\]|\\.)*)", title: "((?:[^"\\]|\\.)*)", author: "((?:[^"\\]|\\.)*)", '
                 r'license: "([^"]*)", restrictions: "([^"]*)", page: "([^"]*)", modified: "((?:[^"\\]|\\.)*)"\)')
unesc = lambda s: s.replace('\\"', '"').replace("\\\\", "\\")

def deed(lic):
    if lic == "CC0":
        return "https://creativecommons.org/publicdomain/zero/1.0/"
    p = lic.split(" ")
    if len(p) >= 3 and p[0] == "CC" and p[1] in ("BY", "BY-SA"):
        return f"https://creativecommons.org/licenses/{p[1].lower()}/{p[2]}/" + (f"{p[3].lower()}/" if len(p) > 3 else "")
    return None

rows = [[unesc(g) for g in m.groups()] for m in row.finditer(open(src).read())]
lines = [
    "Tensor Tycoon: photo credits",
    "",
    f"The game bundles {len(rows)} photos from Wikimedia Commons. Every one is free for any use, including",
    "commercial use, under the licence named below (CC0, public domain, CC BY or CC BY-SA). Bundled copies are",
    "resized and re-encoded with camera metadata removed; each entry says how, including any crop. CC BY-SA",
    "photos remain under CC BY-SA in their modified form. Full terms are on each file's Commons page.",
    "",
    "Restrictions: \"trademarks visible\" and \"personality rights may apply\" are not copyright restrictions but",
    "may limit some uses; \"recent architecture (limited freedom of panorama)\" marks a modern building in a",
    "country where the architect's rights can extend to photos of it.",
    "",
]
for (i, subject, title, author, lic, restr, page, mod) in sorted(rows, key=lambda r: r[0]):
    lines += [
        f"{i}",
        f"  Shows:        {subject}",
        f"  Title:        {title}",
        f"  Author:       {author}",
        f"  Licence:      {lic}" + (f" ({deed(lic)})" if deed(lic) else ""),
        f"  Source:       {page}",
        f"  Restrictions: {restr}",
        f"  Modified:     {mod}",
        "",
    ]
open(out, "w").write("\n".join(lines))
print(f"Wrote {out} ({len(rows)} credits)")
PY
