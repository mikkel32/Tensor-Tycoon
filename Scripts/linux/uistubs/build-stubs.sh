#!/bin/bash
# Builds the stub modules (SwiftUI, Charts, AppKit, ...) as .swiftmodule files for type-checking only, into
# .build/linux/uistubs at the repo root (or $STUBS_OUT).
set -e
cd "$(dirname "$0")"
OUTDIR="${STUBS_OUT:-$(cd ../../.. && pwd)/.build/linux/uistubs}"
export PATH=$HOME/.nix-profile/bin:$PATH
mkdir -p "$OUTDIR"
build() { # name
    swiftc -emit-module -parse-as-library -swift-version 5 -module-name "$1" src/"$1"/*.swift \
        -I "$OUTDIR" -emit-module-path "$OUTDIR/$1".swiftmodule -suppress-warnings 2>&1
}
for m in CoreGraphics Combine CryptoKit Symbols ImageIO AppKit SwiftUI Charts; do
    [ -d src/$m ] || continue
    if ! out=$(build $m); then echo "$out" | grep -E "error" | head -${MAXERR:-40}; echo "STUB BUILD FAILED: $m"; exit 1; fi
done
echo "stubs OK"
