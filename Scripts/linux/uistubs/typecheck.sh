#!/bin/bash
# Type-checks the whole Tensor Tycoon app (App, Engine, Model, Data, Util, Views) on Linux against stub
# SwiftUI / Charts / AppKit / ImageIO / CryptoKit / Combine / Symbols / CoreGraphics modules (./stubs, built from
# ./src by build-stubs.sh). Nothing is linked or run, and the repo is only read.
#
#   ./typecheck.sh                     check every file; report every error              (~1-2 min on 4 cores)
#   ./typecheck.sh Views/Foo.swift ... report errors in these files only, checked against the whole module (seconds)
#   ./typecheck.sh -w [files...]       also report warnings
#
# Paths may be repo-relative (Sources/TensorTycoon/Views/Foo.swift), relative to Sources/TensorTycoon
# (Views/Foo.swift) or absolute. Output lines look like `Sources/TensorTycoon/Views/Foo.swift:12: error: ...`.
# Exit status: 0 = no (selected) errors, 1 = errors (or a compiler failure), 2 = setup problem.
#
# Environment: REPO (repo root, default: the checkout this script is in), SRC_LIST (file listing the exact sources to
# compile instead of scanning the repo; used by sanity/run-sanity.sh), JOBS (parallel jobs), SWIFTC_EXTRA.
set -o pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="${REPO:-$(cd "$HERE/../../.." && pwd)}"
OUTDIR="${STUBS_OUT:-$REPO/.build/linux/uistubs}"
export STUBS_OUT="$OUTDIR"
SRC="$REPO/Sources/TensorTycoon"
export PATH="$HOME/.nix-profile/bin:$PATH"

WARN=0
if [ "${1:-}" = "-w" ]; then WARN=1; shift; fi
LEVELS='error'
[ $WARN = 1 ] && LEVELS='error|warning'

# Rebuild the stub modules when any stub source is newer than its module.
need=0
for d in "$HERE"/src/*/; do
    mod="$OUTDIR/$(basename "$d").swiftmodule"
    if [ ! -f "$mod" ] || [ -n "$(find "$d" -name '*.swift' -newer "$mod" 2>/dev/null)" ]; then need=1; fi
done
if [ $need = 1 ]; then "$HERE/build-stubs.sh" >&2 || exit 2; fi

# Sources: every .swift file under the six app directories, read in place.
if [ -n "${SRC_LIST:-}" ]; then
    mapfile -t FILES < "$SRC_LIST"
else
    mapfile -t FILES < <(find "$SRC/App" "$SRC/Engine" "$SRC/Model" "$SRC/Data" "$SRC/Util" "$SRC/Views" -name '*.swift' | sort)
fi
[ ${#FILES[@]} -gt 0 ] || { echo "no sources found under $SRC" >&2; exit 2; }

# Optional file selection, normalised to absolute paths that must be among the sources.
SELECT=()
for f in "$@"; do
    case "$f" in
        /*) p=$(realpath -m "$f") ;;
        Sources/*) p=$(realpath -m "$REPO/$f") ;;
        *) if [ -e "$SRC/$f" ]; then p=$(realpath -m "$SRC/$f"); else p=$(realpath -m "$f"); fi ;;
    esac
    printf '%s\n' "${FILES[@]}" | grep -qxF "$p" || { echo "typecheck: not an app source: $f" >&2; exit 2; }
    SELECT+=("$p")
done

# Darwin's Foundation also provides URLSession & co. and re-exports Observation; on Linux those live in
# FoundationNetworking / Observation, so both are imported implicitly into every file.
FLAGS=(-typecheck -swift-version 5 -parse-as-library -module-name TensorTycoon -I "$OUTDIR" -diagnostic-style llvm
       -Xfrontend -import-module -Xfrontend FoundationNetworking -Xfrontend -import-module -Xfrontend Observation)

if [ ${#SELECT[@]} -eq 0 ]; then
    # Whole module: the driver checks every file in parallel jobs; -continue-building-after-errors keeps it going
    # after the first failing job. Other work may save repo files while we run; the driver then aborts with
    # "was modified during the build". In that case re-run on a private snapshot of the same files (copied, never
    # written back) and map the snapshot paths back to the repo paths.
    RUN=("${FILES[@]}"); SNAP=""
    for attempt in 1 2; do
        OUT=$(swiftc "${FLAGS[@]}" -continue-building-after-errors -j "${JOBS:-$(nproc)}" ${SWIFTC_EXTRA:-} "${RUN[@]}" 2>&1)
        STATUS=$?
        if [ -n "$SNAP" ]; then OUT=$(printf '%s\n' "$OUT" | sed "s|^$SNAP/|/|"); rm -rf "$SNAP"; break; fi
        printf '%s\n' "$OUT" | grep -q 'was modified during the build' || break
        echo "typecheck: sources changed during the run; re-checking a snapshot of them" >&2
        mkdir -p "$OUTDIR/.snap"; SNAP=$(mktemp -d "$OUTDIR/.snap/run.XXXXXX"); RUN=()
        for f in "${FILES[@]}"; do mkdir -p "$SNAP$(dirname "$f")"; cp "$f" "$SNAP$f"; RUN+=("$SNAP$f"); done
    done
else
    # Selected files: a single frontend job whose primary files are exactly the selected files. All other files are
    # parsed and their declarations checked on demand, so the selection is checked against the whole module, but
    # only the selected files' function bodies are type-checked.
    CMD=$(swiftc -### -driver-filelist-threshold=100000 "${FLAGS[@]}" ${SWIFTC_EXTRA:-} "${FILES[@]}" 2>&1 | grep -m1 -- ' -frontend ')
    [ -n "$CMD" ] || { echo "typecheck: could not get the frontend command" >&2; exit 2; }
    CMD=" ${CMD//-primary-file /} "
    for f in "${SELECT[@]}"; do CMD="${CMD/ $f / -primary-file $f }"; done
    OUT=$(eval "$CMD" 2>&1)
    STATUS=$?
fi

# Per-file diagnostics, optionally restricted to the selection, as repo-relative `file:line: level: message`.
DIAG=$(printf '%s\n' "$OUT" | grep -E "^[^ ]+\.swift:[0-9]+:[0-9]+: ($LEVELS): " | sort -u)
if [ ${#SELECT[@]} -gt 0 ]; then
    KEEP=""
    for f in "${SELECT[@]}"; do KEEP+=$(printf '%s\n' "$DIAG" | grep -F "$f:")$'\n'; done
    DIAG=$KEEP
fi
DIAG=$(printf '%s\n' "$DIAG" | grep -v '^$' | sed -E "s|^$REPO/||; s|^([^ ]+\.swift):([0-9]+):[0-9]+: |\1:\2: |" | sort -t: -k1,1 -k2,2n -u)
[ -n "$DIAG" ] && printf '%s\n' "$DIAG"
NERR=$(printf '%s\n' "$DIAG" | grep -c ': error: ')

if [ "$NERR" -gt 0 ]; then
    echo "typecheck: $NERR error(s)" >&2
    exit 1
fi
# A failure without any per-file error (crash, driver problem) must not pass silently. When checking a selection,
# errors in unselected files are expected to be filtered out, so only unattributed errors count.
OTHER=$(printf '%s\n' "$OUT" | grep -E 'error:' | grep -vE '^[^ ]+\.swift:[0-9]+:[0-9]+: ' | grep -vE '^ ' | head -20)
if [ $STATUS -ne 0 ] && { [ ${#SELECT[@]} -eq 0 ] || [ -n "$OTHER" ]; }; then
    printf '%s\n' "${OTHER:-$(printf '%s\n' "$OUT" | tail -20)}" >&2
    echo "typecheck: compiler failed (status $STATUS)" >&2
    exit 1
fi
echo "typecheck: OK (${#FILES[@]} files${SELECT:+, ${#SELECT[@]} selected})" >&2
exit 0
