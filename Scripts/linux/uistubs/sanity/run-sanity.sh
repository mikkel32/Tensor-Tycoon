#!/bin/bash
# Sanity check for the stubs: copies one real view file, plants three deliberate mistakes in the copy, and
# type-checks the whole module with the copy substituted for the original (the repo is never touched).
# Passes when all three mistakes are reported.
#   run-sanity.sh          fast: only the copy's bodies are type-checked (against the whole module)
#   run-sanity.sh --full   whole-module check (as plain ./typecheck.sh does), errors filtered to the copy
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$HERE")"
REPO="$(cd "$(dirname "$0")/../../../.." && pwd)"
SRC=$REPO/Sources/TensorTycoon
ORIG=$SRC/Views/FundingView.swift
COPY=$HERE/FundingView.swift

cp "$ORIG" "$COPY"
python3 -I - "$COPY" <<'EOF'
import sys
p = sys.argv[1]
s = open(p).read()
def plant(old, new):
    global s
    assert s.count(old) >= 1, old
    s = s.replace(old, new, 1)
# 1. misspelled engine property (GameState.publicShares). Planted in a statement whose result nothing else uses:
#    Swift suppresses follow-on errors in any expression that touches an erroneous value, so a misspelling feeding
#    `total` would hide the other two mistakes (the same happens on macOS).
plant("if s.publicShares > 0 {", "if s.publicShare > 0 {")
# 2. wrong argument label on a SwiftUI modifier
plant("                                .font(.caption)\n", "                                .font(.caption)\n                                .padding(foo: 3)\n")
# 3. an Int where Text needs a String / LocalizedStringKey
plant("Text(sl.0).lineLimit(1)", "Text(42).lineLimit(1)")
open(p, "w").write(s)
EOF

LIST=$(mktemp)
find "$SRC/App" "$SRC/Engine" "$SRC/Model" "$SRC/Data" "$SRC/Util" "$SRC/Views" -name '*.swift' | sort | grep -vxF "$ORIG" > "$LIST"
echo "$COPY" >> "$LIST"

if [ "${1:-}" = "--full" ]; then
    OUT=$(SRC_LIST="$LIST" "$ROOT/typecheck.sh" 2>&1 | grep -F "$COPY")
else
    OUT=$(SRC_LIST="$LIST" "$ROOT/typecheck.sh" "$COPY" 2>&1)
fi
rm -f "$LIST"
echo "$OUT"
echo "----"
ok=1
check() { # description, regex
    if echo "$OUT" | grep -Eq "$2"; then echo "caught:  $1"; else echo "MISSED:  $1"; ok=0; fi
}
check "misspelled engine property (s.publicShare)" "FundingView.swift:18: error: .*has no member 'publicShare'"
check "wrong modifier label (.padding(foo:))"      "FundingView.swift:41: error: extraneous argument label 'foo:' in call"
check "Int passed to Text (Text(42))"              "FundingView.swift:36: error: no exact matches in call to initializer"
[ $ok = 1 ] && echo "SANITY OK" || { echo "SANITY FAILED"; exit 1; }
