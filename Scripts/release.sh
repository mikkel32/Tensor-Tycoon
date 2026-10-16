#!/bin/zsh
# Publishes a new version of Tensor Tycoon. Every installed copy then offers it in-app
# (within six hours, or right away via Tensor Tycoon → Check for Updates…).
#
#   Scripts/release.sh 3.2 notes.md     # release notes from a Markdown file
#   Scripts/release.sh 3.2              # release notes generated from commit messages
#
# Builds a universal app, checks that old saves still load, zips it, signs the zip with the Ed25519 key in your login Keychain
# ("Tensor Tycoon update signing key"), checks the signature against the key the app trusts,
# commits VERSION, tags, pushes and creates the GitHub release with the zip and its .sig.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?usage: Scripts/release.sh <version> [notes.md]}"
NOTES="${2:-}"
REPO="mikkel32/Tensor-Tycoon"
KEY_SERVICE="Tensor Tycoon update signing key"
TAG="v$VERSION"

[[ "$VERSION" =~ '^[0-9]+(\.[0-9]+)*(-[0-9A-Za-z.]+)?$' ]] || { echo "Bad version: $VERSION"; exit 1; }
[[ -z "$NOTES" || -f "$NOTES" ]] || { echo "Notes file not found: $NOTES"; exit 1; }
if [[ -n "$(git status --porcelain -- . ':!VERSION')" ]]; then echo "Commit or stash your changes first."; exit 1; fi
if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then echo "$TAG already exists."; exit 1; fi
security find-generic-password -s "$KEY_SERVICE" >/dev/null 2>&1 || { echo "Signing key '$KEY_SERVICE' isn't in your Keychain."; exit 1; }

echo "$VERSION" > VERSION
git add VERSION
git diff --cached --quiet || git commit -q -m "Release $VERSION"

UNIVERSAL=1 ./build_app.sh
BIN="build/Tensor Tycoon.app/Contents/MacOS/TensorTycoon"

# Updates install themselves, so a release must never break a save: check the fixtures from shipped
# versions, then copies of your own saves (the originals aren't touched).
for f in Tests/Fixtures/*.json; do "$BIN" --check-save "$f"; done
for f in "$HOME/Library/Application Support/TensorTycoon/Saves"/*.json(N); do
    tmp="$(mktemp -d)/$(basename "$f")"
    cp "$f" "$tmp"
    "$BIN" --check-save "$tmp"
    rm -rf "$(dirname "$tmp")"
done

ZIP="build/Tensor-Tycoon-$VERSION.zip"
rm -f "$ZIP" "$ZIP.sig"
ditto -c -k --sequesterRsrc --keepParent "build/Tensor Tycoon.app" "$ZIP"

# Sign, then prove the app's trusted key accepts the signature before anything is published.
security find-generic-password -s "$KEY_SERVICE" -w | swift Scripts/update_signing.swift sign "$ZIP" "$VERSION" > "$ZIP.sig"
PUB="$(sed -n 's/.*static let publicKeys = \["\([^"]*\)".*/\1/p' Sources/TensorTycoon/App/Updater.swift)"
swift Scripts/update_signing.swift verify "$ZIP" "$VERSION" "$(cat "$ZIP.sig")" "$PUB"

git tag -a "$TAG" -m "Tensor Tycoon $VERSION"
git push -q origin HEAD "$TAG"
if [[ -n "$NOTES" ]]; then
    gh release create "$TAG" "$ZIP" "$ZIP.sig" --repo "$REPO" --title "Tensor Tycoon $VERSION" --notes-file "$NOTES"
else
    gh release create "$TAG" "$ZIP" "$ZIP.sig" --repo "$REPO" --title "Tensor Tycoon $VERSION" --generate-notes
fi
echo "Released $TAG."
