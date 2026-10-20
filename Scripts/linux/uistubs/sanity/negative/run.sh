#!/bin/bash
# Negative tests for the stubs: every `bad_N` case in Negative.swift must be rejected (as the real SDK rejects it)
# and every `good_N` case accepted. Each case is type-checked on its own so one error cannot mask another.
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(dirname "$(dirname "$HERE")")"
export PATH=$HOME/.nix-profile/bin:$PATH
"$ROOT/build-stubs.sh" >/dev/null || exit 2
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
F="$HERE/Negative.swift"
HEADER=$(awk '/^struct (good|bad)_/{exit} {print}' "$F")
ok=1
for n in $(grep -oE '^struct (good|bad)_[0-9]+' "$F" | awk '{print $2}'); do
    { printf '%s\n' "$HEADER"; awk -v n="$n" '$0 ~ "^struct "n":" {p=1; print; next} p && /^struct /{exit} p{print}' "$F"; } > "$TMP/$n.swift"
    err=$(swiftc -typecheck -swift-version 5 -parse-as-library -I "${STUBS_OUT:-$(cd "$ROOT/../../.." && pwd)/.build/linux/uistubs}" -diagnostic-style llvm "$TMP/$n.swift" 2>&1 \
          | grep -E '^[^ ]+\.swift:[0-9]+:[0-9]+: error:' | head -1 | sed -E 's/^[^ ]+:[0-9]+:[0-9]+: error: //')
    case $n in
        good_*) if [ -n "$err" ]; then echo "FAIL $n: unexpected error: $err"; ok=0; else echo "ok   $n"; fi ;;
        bad_*)  if [ -z "$err" ]; then echo "FAIL $n: accepted"; ok=0; else echo "ok   $n -> $err"; fi ;;
    esac
done
[ $ok = 1 ] && echo "NEGATIVE TESTS OK" || { echo "NEGATIVE TESTS FAILED"; exit 1; }
