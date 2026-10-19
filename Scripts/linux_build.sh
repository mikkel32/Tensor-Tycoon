#!/bin/bash
# Builds the simulation engine and its headless harnesses on Linux (no SwiftUI) into .build/linux/tt, so the
# balance, save, determinism and scenario checks can run without a Mac:
#
#   Scripts/linux_build.sh            # optimised build (~4 min on 4 cores)
#   OPT=-Onone Scripts/linux_build.sh # quicker to compile, slower to run
#   .build/linux/tt --scenarios all
#
# Needs a Swift 6 toolchain on PATH (e.g. `nix profile add nixpkgs#swift`); set SWIFT_LIB to its lib directory if
# the linker can't find Foundation. Engine files that `import SwiftUI` only for `Color` get a stand-in.
set -euo pipefail
cd "$(dirname "$0")/.."
SRC=Sources/TensorTycoon
OUT=.build/linux
STAGE=$OUT/src
rm -rf "$STAGE" && mkdir -p "$STAGE"
for d in Util Model Data Engine; do
  for f in "$SRC/$d"/*.swift; do
    b=$(basename "$f")
    [ "$b" = "Images.swift" ] && continue   # ImageIO / AppKit image loading
    if grep -q "^import SwiftUI" "$f"; then
      sed 's/^import SwiftUI/import Foundation/' "$f" > "$STAGE/${d}_$b"
    else
      ln -s "$PWD/$f" "$STAGE/${d}_$b"
    fi
  done
done
LIB=${SWIFT_LIB:-$(dirname "$(dirname "$(readlink -f "$(command -v swiftc)")")")/lib}
[ -d "$HOME/.nix-profile/lib" ] && LIB=${SWIFT_LIB:-$HOME/.nix-profile/lib}
swiftc ${OPT:--O} -swift-version 5 -module-name TensorTycoon -j"$(nproc)" -num-threads "$(nproc)" \
  Scripts/linux/main.swift Scripts/linux/SwiftUIShim.swift "$STAGE"/*.swift \
  -L "$LIB" -Xlinker -rpath -Xlinker "$LIB" -o "$OUT/tt"
echo "Built $OUT/tt"
