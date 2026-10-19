#!/bin/bash
# Builds the simulation engine and its headless harnesses on Linux (no SwiftUI) into .build/linux/tt, so the
# balance, save, determinism and scenario checks can run without a Mac:
#
#   Scripts/linux_build.sh                 # optimised, incremental: only changed files and their dependents rebuild
#   CLEAN=1 Scripts/linux_build.sh         # from scratch (~4 min on 4 cores)
#   WMO=1 Scripts/linux_build.sh          # whole-module optimisation: ~1.5x faster binary, always a full rebuild
#   OPT=-Onone Scripts/linux_build.sh      # quicker to compile, slower to run (kept in its own build directory)
#   MODE=typecheck Scripts/linux_build.sh  # type-check the engine only (no binary)
#   .build/linux/tt --scenarios all
#
# Needs a Swift 6 toolchain on PATH (e.g. `nix profile add nixpkgs#swift`); set SWIFT_LIB to its lib directory if
# the linker can't find Foundation. Engine files that `import SwiftUI` only for `Color` get a stand-in.
set -euo pipefail
cd "$(dirname "$0")/.."

# At most three compiles at once across every checkout on the machine (each needs ~3 GB of memory).
acquire_slot() {
  while true; do
    for i in ${BUILD_SLOTS:-1 2 3}; do
      exec {LOCKFD}>"/tmp/tensor-tycoon-build-$i.lock"
      if flock -n "$LOCKFD"; then return 0; fi
      exec {LOCKFD}>&-
    done
    sleep 3
  done
}

SRC=Sources/TensorTycoon
OUT=.build/linux
OPT=${OPT:--O}
OBJ=$OUT/obj${OPT}
STAGE=$OUT/src
[ "${CLEAN:-0}" = "1" ] && rm -rf "$STAGE" "$OBJ"
mkdir -p "$STAGE" "$OBJ"

# Stage copies of the engine sources under stable names, so editing while a build runs can't break it. A copy is only
# rewritten when its content changed, which keeps timestamps for the incremental build; files that left the engine
# are removed.
declare -A WANT
for d in Util Model Data Engine; do
  for f in "$SRC/$d"/*.swift; do
    b=$(basename "$f")
    [ "$b" = "Images.swift" ] && continue   # ImageIO / AppKit image loading
    dest="$STAGE/${d}_$b"
    WANT["$dest"]=1
    tmp="$dest.tmp"
    sed 's/^import SwiftUI/import Foundation/' "$f" > "$tmp"
    if [ -L "$dest" ] || ! cmp -s "$tmp" "$dest"; then rm -f "$dest"; mv "$tmp" "$dest"; else rm -f "$tmp"; fi
  done
done
for f in "$STAGE"/*.swift; do
  [ -n "${WANT[$f]:-}" ] || rm -f "$f"
done

FILES=(Scripts/linux/main.swift Scripts/linux/SwiftUIShim.swift "$STAGE"/*.swift)
acquire_slot

if [ "${MODE:-build}" = "typecheck" ]; then
  swiftc -typecheck -swift-version 5 -module-name TensorTycoon "${FILES[@]}"
  echo "Type-checked the engine"
  exit 0
fi

# Output file map for incremental builds: one object and dependency file per source.
MAP=$OBJ/output-file-map.json
{
  echo "{"
  echo "  \"\": { \"swift-dependencies\": \"$PWD/$OBJ/module.swiftdeps\" },"
  n=${#FILES[@]}
  for ((k = 0; k < n; k++)); do
    f=${FILES[$k]}
    base=$(basename "$f" .swift)
    [ "$f" = Scripts/linux/main.swift ] && base=main_linux
    sep=","; [ $k -eq $((n - 1)) ] && sep=""
    echo "  \"$PWD/$f\": { \"object\": \"$PWD/$OBJ/$base.o\", \"swift-dependencies\": \"$PWD/$OBJ/$base.swiftdeps\" }$sep"
  done
  echo "}"
} > "$MAP"
ABS=()
for f in "${FILES[@]}"; do ABS+=("$PWD/$f"); done

LIB=${SWIFT_LIB:-$(dirname "$(dirname "$(readlink -f "$(command -v swiftc)")")")/lib}
[ -d "$HOME/.nix-profile/lib" ] && LIB=${SWIFT_LIB:-$HOME/.nix-profile/lib}
if [ "${WMO:-0}" = "1" ]; then
  swiftc "$OPT" -wmo -swift-version 5 -module-name TensorTycoon -num-threads "${JOBS:-2}" "${ABS[@]}" \
    -L "$LIB" -Xlinker -rpath -Xlinker "$LIB" -o "$OUT/tt"
else
  swiftc "$OPT" -swift-version 5 -module-name TensorTycoon -incremental -output-file-map "$MAP" \
    -j"${JOBS:-2}" "${ABS[@]}" \
    -L "$LIB" -Xlinker -rpath -Xlinker "$LIB" -o "$OUT/tt"
fi
echo "Built $OUT/tt"
